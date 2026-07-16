# Copyright 2016 The Johns Hopkins University Applied Physics Laboratory
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import base64
import datetime
import json
import logging

import requests
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils.translation import gettext as _
from rest_framework.authentication import get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.settings import import_from_string

from kpi.utils.log import logging as kpi_logging

from kobo.apps.oc_tenant_auth.models import KeycloakTenantUser as KeycloakModel
from kobo.apps.oc_tenant_auth.utils import get_subdomain

LOGGER = logging.getLogger(__name__)


def load_user_roles(user, roles):
    """Default implementation of the LOAD_USER_ROLES callback

    Args:
        user (UserModel): Django user object for the user logging in
        roles (list[str]): List of Keycloak roles assigned to the user
                           Note: Contains both realm roles and client roles
    """
    pass


LOAD_USER_ROLES = getattr(settings, 'LOAD_USER_ROLES', None)
if LOAD_USER_ROLES is None:
    # DP NOTE: had issues with import_from_string loading
    # bossoidc.backend.load_user_roles
    LOAD_USER_ROLES_FUNCTION = load_user_roles
else:  # pragma: no cover
    LOAD_USER_ROLES_FUNCTION = import_from_string(LOAD_USER_ROLES, 'LOAD_USER_ROLES')


def update_user_data(user, userinfo):
    """Default implementation of the UPDATE_USER_DATA callback

    Args:
        user (UserModel): Django user object for the user logging in
        userinfo (dict): Dictionary of userinfo requested from Keycloak with the
                         user's profile data
    """
    pass


UPDATE_USER_DATA = getattr(settings, 'UPDATE_USER_DATA', None)
if UPDATE_USER_DATA is None:
    UPDATE_USER_DATA_FUNCTION = update_user_data
else:  # pragma: no cover
    UPDATE_USER_DATA_FUNCTION = import_from_string(UPDATE_USER_DATA, 'UPDATE_USER_DATA')


def check_username(username):
    """Ensure that the given username does exceed the current user models field
    length

    Args:
        username (str): Username of the user logging in

    Raises:
        AuthenticationFailed: If the username length exceeds the fields max length
    """
    username_field = get_user_model()._meta.get_field('username')
    if len(username) > username_field.max_length:
        raise AuthenticationFailed(_('Username is too long for Django'))


def get_user_by_id(request, userinfo):
    """Get or create the user object based on the user's information

    Note: Taken from djangooidc.backends.OpenIdConnectBackend and made common for
    drf-oidc-auth to make use of the same create user functionality

    Note: The user's token is loaded from the request session or header
    to load_user_roles the user's Keycloak roles

    Args:
        request (Request): Django request from the user
        userinfo (dict): Dictionary of userinfo requested from Keycloak with the
                         user's profile data

    Returns:
        UserModel: user object for the requesting user
        None: If the requesting user's token's audience is not valid

    Raises:
        AuthenticationFailed: If the requesting user's username is too long
    """

    access_token = get_access_token(request)
    subdomain = request.session['subdomain']

    return get_user_with_id(access_token, userinfo, subdomain)


def get_user_with_id(access_token, userinfo, subdomain=None):
    """Common functionality for getting or creating the user.  Used by both
    mozilla_django_oidc and drf-oidc-auth.

    Args:
        access_token ():
        userinfo (dict): Dictionary of userinfo requested from Keycloak with the

    Returns:
        UserModel: user object for the requesting user
        None: If the requesting user's token's audience is not valid

    Raises:
        AuthenticationFailed: If the requesting user's username is too long
    """
    UserModel = get_user_model()
    uid = userinfo['sub']
    usersubdomain = subdomain
    username = userinfo['preferred_username'] + '+' + usersubdomain
    usertype = userinfo['https://www.openclinica.com/userContext']['userType']

    check_username(username)

    # Some OP may withhold some information, so we must test each field is present
    openid_data = {'last_login': datetime.datetime.now()}
    if 'first_name' in userinfo.keys():
        openid_data['first_name'] = userinfo['first_name']
    if 'given_name' in userinfo.keys():
        openid_data['first_name'] = userinfo['given_name']
    if 'christian_name' in userinfo.keys():
        openid_data['first_name'] = userinfo['christian_name']
    if 'family_name' in userinfo.keys():
        openid_data['last_name'] = userinfo['family_name']
    if 'last_name' in userinfo.keys():
        openid_data['last_name'] = userinfo['last_name']
    if 'email' in userinfo.keys():
        openid_data['email'] = userinfo['email']

    # DP NOTE: The thing that we are trying to prevent is the user account being
    #          deleted and recreated in Keycloak (all user data the same, but a
    #          different uid) and getting the application permissions of the old
    #          user account.

    try:  # try to lookup by keycloak UID first
        kc_user = KeycloakModel.objects.get(UID=uid, subdomain=usersubdomain)
        user = kc_user.user
        # Always sync user_type so Keycloak changes are reflected on the next login
        if kc_user.user_type != usertype:
            kc_user.user_type = usertype
            kc_user.save()
    except KeycloakModel.DoesNotExist:  # no keycloak UID + subdomain match
        try:
            user = UserModel.objects.get_by_natural_key(username)
            # UID changed in Keycloak — replace only the KeycloakModel entry
            # so the user retains their library entries and other KPI data.
            KeycloakModel.objects.filter(user=user).delete()
        except UserModel.DoesNotExist:
            args = {UserModel.USERNAME_FIELD: username, 'defaults': openid_data}
            user, _ = UserModel.objects.update_or_create(**args)

        kc_user = KeycloakModel.objects.create(
            user=user, UID=uid, subdomain=usersubdomain
        )
        if kc_user:
            kc_user.user_type = usertype
            kc_user.save()

    roles = get_roles(access_token)
    user.is_staff = 'admin' in roles or 'superuser' in roles
    user.is_superuser = 'superuser' in roles

    LOAD_USER_ROLES_FUNCTION(user, roles)
    UPDATE_USER_DATA_FUNCTION(user, userinfo)

    user.save()
    return user


def get_roles(decoded_token):
    """Get roles declared in the input token

    Note: returns both the realm roles and client roles

    Args:
        decoded_token (dict): The user's decoded bearer token

    Returns:
        list[str]: List of role names
    """

    # Extract realm scoped roles
    try:
        # Session logins and Bearer tokens from password Grant Types
        if 'realm_access' in decoded_token:
            roles = decoded_token['realm_access']['roles']
        else:  # Bearer tokens from authorization_code Grant Types
            # DP ???: a session login uses an authorization_code code, not sure
            #         about the difference
            roles = decoded_token['resource_access']['account']['roles']
    except KeyError:
        roles = []

    # Extract all client scoped roles
    for name, client in decoded_token.get('resource_access', {}).items():
        if name == 'account':
            continue

        try:
            roles.extend(client['roles'])
        except KeyError:  # pragma no cover
            pass

    return roles


def get_access_token(request):
    """Retrieve access token from the request

    The access token is searched first the request's session. If it is not
    found it is then searched in the request's ``Authorization`` header.

    Args:
        request (Request): Django request from the user

    Returns:
        dict: JWT payload of the bearer token
    """
    access_token = request.session.get('access_token')
    if access_token is None:  # Bearer token login
        access_token = get_authorization_header(request).split()[1]
    if isinstance(access_token, bytes):
        access_token = access_token.decode('utf-8')
    part = access_token.split('.')[1]
    part += '=' * (-len(part) % 4)
    return json.loads(base64.urlsafe_b64decode(part))


def get_realm_name(request):
    subdomain = get_subdomain(request)
    realm_name = subdomain

    allowed_connections_url = '{}/customer-service/api/allowed-connections'.format(
        settings.OC_BUILD_URL
    )
    allowed_connections_response = None
    try:
        allowed_connections_response = requests.get(
            allowed_connections_url,
            params={'subdomain': subdomain},
        )
    except Exception as e:
        kpi_logging.error(
            'oc.backend __get_realm {}'.format(str(e)), exc_info=True
        )

    if isinstance(allowed_connections_response, requests.Response):
        realm_name = allowed_connections_response.json()[0]

    return realm_name


def get_client_secret(realm_name):
    from keycloak import KeycloakAdmin
    try:
        keycloak_admin = KeycloakAdmin(
            server_url=settings.KEYCLOAK_AUTH_URI + '/auth/',
            realm_name=realm_name,
            user_realm_name='master',  # admin credentials live in master realm
            client_id='admin-cli',  # Keycloak admin SA; only client that reads secrets
            client_secret_key=settings.KEYCLOAK_ADMIN_CLIENT_SECRET,
            verify=True,
        )
        clients = keycloak_admin.get_clients()
        client = next(
            (c for c in clients if c['clientId'] == settings.KEYCLOAK_CLIENT_ID),
            None,
        )
        if client:
            secret = keycloak_admin.get_client_secrets(client['id']).get('value')
            if secret:
                return secret
            return getattr(settings, 'KEYCLOAK_CLIENT_SECRET', None)
    except Exception as e:
        LOGGER.error(
            'get_client_secret failed for realm %s: %s', realm_name, e,
            exc_info=True,
        )
    return getattr(settings, 'KEYCLOAK_CLIENT_SECRET', None)
