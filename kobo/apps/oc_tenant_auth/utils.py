from urllib.parse import urlparse

from django_request_cache import cache_for_request
from tldextract import extract


def get_current_domain(request):
    full_uri_with_path = request.build_absolute_uri()
    parsed_full_uri_with_path = urlparse(full_uri_with_path)
    return parsed_full_uri_with_path.netloc


def get_subdomain(request):
    full_uri_with_path = request.build_absolute_uri()
    extracted_full_uri_with_path = extract(full_uri_with_path)
    subdomain = extracted_full_uri_with_path.subdomain.split('.')[0]
    return subdomain


@cache_for_request
def get_subdomain_user_ids(user):
    """
    Returns a QuerySet of user_ids belonging to the same Keycloak subdomain
    as `user`. Raises KeycloakTenantUser.DoesNotExist if `user` has no Keycloak
    record.
    Use for queryset filters (owner__in=...). For a single membership check,
    prefer `is_owner_in_subdomain()` to avoid loading all IDs into memory.
    """
    from kobo.apps.oc_tenant_auth.models import KeycloakTenantUser

    kc_user = KeycloakTenantUser.objects.get(user=user)
    return KeycloakTenantUser.objects.filter(
        subdomain=kc_user.subdomain
    ).values_list('user_id', flat=True)


@cache_for_request
def is_owner_in_subdomain(user, owner_id: int) -> bool:
    """
    Returns True if `owner_id` belongs to the same Keycloak subdomain as
    `user`, via a DB-level EXISTS check. Raises KeycloakTenantUser.DoesNotExist
    if `user` has no Keycloak record.
    """
    from kobo.apps.oc_tenant_auth.models import KeycloakTenantUser

    kc_user = KeycloakTenantUser.objects.get(user=user)
    return KeycloakTenantUser.objects.filter(
        subdomain=kc_user.subdomain,
        user_id=owner_id,
    ).exists()


def get_parent_collection_queryset(user):
    """
    Returns the queryset for the AssetSerializer `parent` field, scoped to
    collections owned by users in the caller's Keycloak subdomain. Falls back
    to all collections when the caller has no Keycloak record (test environments
    without Keycloak); write access is still enforced by validate_parent().
    """
    from kobo.apps.oc_tenant_auth.models import KeycloakTenantUser
    from kpi.constants import ASSET_TYPE_COLLECTION
    from kpi.models import Asset

    if user.is_anonymous:
        return Asset.objects.none()
    try:
        subdomain_user_ids = get_subdomain_user_ids(user)
        return Asset.objects.filter(
            asset_type=ASSET_TYPE_COLLECTION,
            owner__in=subdomain_user_ids,
        )
    except KeycloakTenantUser.DoesNotExist:
        return Asset.objects.filter(asset_type=ASSET_TYPE_COLLECTION)
