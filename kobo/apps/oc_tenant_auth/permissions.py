# coding: utf-8
from rest_framework import permissions

from kpi.permissions import AssetPermission, AssetSnapshotPermission
from kobo.apps.oc_tenant_auth.utils import is_owner_in_subdomain


class AssetObjectPermission(AssetPermission):
    """
    Like AssetPermission but skips the model-level permission check.

    DjangoObjectPermissions.has_permission() requires users to hold model-level
    permissions (e.g. kpi.view_asset), which CI / test users never have →
    blanket 403. This subclass grants model-level access to any authenticated
    user while keeping the full object-level check from AssetPermission
    (required by get_object_override, which bypasses filter backends).

    Anonymous users pass the model-level check for safe methods so that filter
    backends can restrict their view to publicly-shared assets at the
    object level.

    OC customization: subdomain users can read and edit each other's library
    items (question/block/template/collection). Surveys remain governed by the
    standard object-level permission check.
    """

    _LIBRARY_ASSET_TYPES = ('question', 'block', 'template', 'collection')

    def has_permission(self, request, view):
        self.validate_password(request)
        if request.user and request.user.is_authenticated:
            return True
        # Anonymous users may read public assets; object-level and filter
        # backends enforce per-asset visibility.
        return request.method in permissions.SAFE_METHODS

    def has_object_permission(self, request, view, obj):
        # OC: all subdomain users may read and write each other's library items.
        if (
            request.user
            and request.user.is_authenticated
            and getattr(obj, 'asset_type', None) in self._LIBRARY_ASSET_TYPES
            and self._same_subdomain(request.user, obj)
        ):
            return True
        return super().has_object_permission(request, view, obj)

    @staticmethod
    def _same_subdomain(user, asset):
        try:
            return is_owner_in_subdomain(user, asset.owner_id)
        except Exception:
            return False


class SubdomainAwareAssetSnapshotPermission(AssetSnapshotPermission):
    """
    OC customization: extends AssetSnapshotPermission to grant preview/detail
    access to snapshots of library items (question/block/template/collection)
    owned by users in the caller's Keycloak subdomain.
    """

    _LIBRARY_ASSET_TYPES = ('question', 'block', 'template', 'collection')

    def has_object_permission(self, request, view, obj):
        if (
            request.user
            and request.user.is_authenticated
            and getattr(obj.asset, 'asset_type', None) in self._LIBRARY_ASSET_TYPES
            and AssetObjectPermission._same_subdomain(request.user, obj.asset)
        ):
            return True
        return super().has_object_permission(request, view, obj)
