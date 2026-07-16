import base64
import json
import logging
import time

import requests
from allauth.core.exceptions import ImmediateHttpResponse
from allauth.socialaccount.adapter import DefaultSocialAccountAdapter
from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponseForbidden

from .backend import get_realm_name, get_client_secret
from .models import KeycloakTenantUser
from .utils import get_subdomain

LOGGER = logging.getLogger(__name__)

_CACHE_TTL = 86400  # 1 day; if realm/secret/customer changes, clear stale keys:
# docker exec redis redis-cli KEYS "oc:*" | xargs docker exec redis redis-cli DEL


def _cached_realm_name(request):
    subdomain = get_subdomain(request)
    key = f'oc:realm_name:{subdomain}'
    val = cache.get(key)
    if val is None:
        val = get_realm_name(request)
        cache.set(key, val, _CACHE_TTL)
    return val


def _cached_client_secret(realm_name):
    key = f'oc:client_secret:{realm_name}'
    val = cache.get(key)
    if val is None:
        val = get_client_secret(realm_name)
        if val:
            cache.set(key, val, _CACHE_TTL)
    return val


def _decode_jwt_payload(token):
    part = token.split('.')[1]
    part += '=' * (-len(part) % 4)
    return json.loads(base64.urlsafe_b64decode(part))


class TenantAwareSocialAccountAdapter(DefaultSocialAccountAdapter):
    """
    allauth SocialAccountAdapter for OpenClinica multi-tenant Keycloak OIDC.

    Replaces oc.backend.OpenIdConnectBackend for allauth-based OIDC flows.
    Preserves all tenant isolation and OC session population behaviour.
    """

    def get_app(self, request, provider, client_id=None):
        """Inject per-subdomain Keycloak realm URL and client secret."""
        app = super().get_app(request, provider, client_id=client_id)
        if request is not None and getattr(settings, 'OC_BUILD_URL', None):
            try:
                realm_name = _cached_realm_name(request)
            except Exception as exc:
                LOGGER.warning('get_app: failed to determine realm name: %s', exc)
                return app
            if not realm_name:
                LOGGER.warning('get_app: empty realm name, skipping injection')
                return app
            client_secret = _cached_client_secret(realm_name)
            realm_url = f'{settings.KEYCLOAK_AUTH_URI}/auth/realms/{realm_name}'
            app.settings = {**app.settings, 'server_url': realm_url}
            if client_secret:
                app.secret = client_secret
        return app

    def pre_social_login(self, request, sociallogin):
        """
        Called after token validation, before login/user-creation.
        Sets subdomain in session and enforces tenant-isolated user lookup.
        """
        subdomain = get_subdomain(request)
        request.session['subdomain'] = subdomain

        uid = sociallogin.account.uid
        try:
            kc_user = KeycloakTenantUser.objects.get(UID=uid, subdomain=subdomain)
            sociallogin.connect(request, kc_user.user)
            self._ensure_user_profile(kc_user.user)
            self._clear_existing_email_addresses(kc_user.user, sociallogin)
            return
        except KeycloakTenantUser.DoesNotExist:
            pass

        # UID not found — Keycloak may have re-created the user with a new UUID.
        # Fall back to username lookup and re-key the stored UID if matched.
        preferred_username = sociallogin.account.extra_data.get(
            'preferred_username'
        ) or sociallogin.account.extra_data.get('userinfo', {}).get(
            'preferred_username'
        )
        if not preferred_username:
            LOGGER.error(
                'pre_social_login: UID %s not found and preferred_username absent '
                'from Keycloak token on subdomain %s — check token mapper config',
                uid,
                subdomain,
            )
            raise ImmediateHttpResponse(
                HttpResponseForbidden(
                    'Login failed: preferred_username missing from Keycloak token. '
                    'Contact your administrator.'
                )
            )
        if preferred_username:
            expected_username = f'{preferred_username}+{subdomain}'
            try:
                from django.contrib.auth import get_user_model
                existing_user = get_user_model().objects.get(username=expected_username)
                KeycloakTenantUser.objects.filter(
                    user=existing_user, subdomain=subdomain
                ).update(UID=uid)
                LOGGER.warning(
                    'Keycloak UID rotated for %s on subdomain %s — updated to %s',
                    expected_username, subdomain, uid,
                )
                sociallogin.connect(request, existing_user)
                self._ensure_user_profile(existing_user)
                self._clear_existing_email_addresses(existing_user, sociallogin)
                return
            except get_user_model().DoesNotExist:
                pass

    def save_user(self, request, sociallogin, form=None):
        """
        After user save: sync roles, populate OC session values,
        upsert KeycloakTenantUser.
        """
        user = super().save_user(request, sociallogin, form)
        subdomain = get_subdomain(request)

        # allauth sets username from preferred_username; append +subdomain
        if not user.username.endswith(f'+{subdomain}'):
            user.username = f'{user.username}+{subdomain}'
            user.save(update_fields=['username'])
        extra_data = sociallogin.account.extra_data
        uid = sociallogin.account.uid
        access_token = (
            sociallogin.token.token if sociallogin.token else None
        )

        # Sync Keycloak roles → Django is_staff / is_superuser
        from .backend import get_roles

        roles = []
        if access_token:
            try:
                token_payload = _decode_jwt_payload(access_token)
                roles = get_roles(token_payload)
            except Exception as exc:
                LOGGER.warning('Failed to extract roles from access_token: %s', exc)
        user.is_staff = 'admin' in roles or 'superuser' in roles
        user.is_superuser = 'superuser' in roles
        user.save(update_fields=['is_staff', 'is_superuser'])

        # Populate OC session values from access token
        if access_token and request:
            self._store_user_info(request, access_token)
            self._store_customer_info(request, access_token)
            request.session['oc_access_token'] = access_token
            request.session['oc_token_validated_at'] = time.time()
            request.session['oc_fd_base_username'] = user.username.rsplit('+', 1)[0]

        user_type = extra_data.get(
            'https://www.openclinica.com/userContext', {}
        ).get('userType', '')

        KeycloakTenantUser.objects.update_or_create(
            UID=uid,
            subdomain=subdomain,
            defaults={'user': user, 'user_type': user_type},
        )
        self._ensure_user_profile(user)
        return user

    def _ensure_user_profile(self, user):
        from kobo.apps.openrosa.apps.main.models import UserProfile
        UserProfile.objects.get_or_create(
            user_id=user.pk,
            defaults={'validated_password': True},
        )

    def _clear_existing_email_addresses(self, user, sociallogin):
        """Remove email addresses already on the account so allauth won't re-insert."""
        from allauth.account.models import EmailAddress
        existing = set(
            EmailAddress.objects.filter(user=user).values_list('email', flat=True)
        )
        sociallogin.email_addresses = [
            ea for ea in sociallogin.email_addresses
            if ea.email not in existing
        ]

    def _store_user_info(self, request, access_token):
        """Store oc_user_uuid in session from the access token userContext claim."""
        try:
            payload = _decode_jwt_payload(access_token)
            user_uuid = payload.get(
                'https://www.openclinica.com/userContext', {}
            ).get('userUuid')
        except Exception as exc:
            LOGGER.error('Failed to extract userUuid from access_token: %s', exc)
            return
        if not user_uuid:
            LOGGER.error('Empty userUuid received from access_token')
            return
        request.session['oc_user_uuid'] = user_uuid

    def _store_customer_info(self, request, access_token):
        """Store oc_customer_name and oc_customer_shared_infra from Customer API."""
        try:
            payload = _decode_jwt_payload(access_token)
            customer_uuid = payload.get(
                'https://www.openclinica.com/userContext', {}
            ).get('customerUuid')
        except Exception as exc:
            LOGGER.error('Failed to extract customerUuid from access_token: %s', exc)
            return
        if not customer_uuid:
            LOGGER.error('Empty customerUuid received from access_token')
            return

        key = f'oc:customer_info:{customer_uuid}'
        data = cache.get(key)
        if data is None:
            customer_url = (
                f'{settings.OC_BUILD_URL}/customer-service'
                f'/api/customers/{customer_uuid}'
            )
            headers = {'Authorization': f'Bearer {access_token}'}
            try:
                response = requests.get(customer_url, headers=headers, timeout=10)
                response.raise_for_status()
                raw = response.json()
                data = {
                    'name': raw.get('name'),
                    'sharedInfra': raw.get('sharedInfra', False),
                }
                cache.set(key, data, _CACHE_TTL)
            except Exception as exc:
                LOGGER.error(
                    'Failed to retrieve customer info for customerUuid %s: %s',
                    customer_uuid, exc,
                )
                return

        request.session['oc_customer_name'] = data['name']
        request.session['oc_customer_shared_infra'] = data['sharedInfra']
