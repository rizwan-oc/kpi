# coding: utf-8
import logging

from django.db.models import Q
from rest_framework import filters

from kobo.apps.oc_tenant_auth.models import KeycloakTenantUser as KeycloakModel
from kobo.apps.oc_tenant_auth.utils import get_subdomain_user_ids
from kpi.filters import KpiObjectPermissionsFilter
from kpi.models import Asset

logger = logging.getLogger(__name__)


class SubdomainFilter(filters.BaseFilterBackend):
    """
    Restricts asset/collection querysets to users in the caller's Keycloak
    subdomain (tenant). No-ops gracefully when the caller has no Keycloak
    record (anonymous users, test environments without Keycloak).
    """

    SUPPORTED_MODELS = ('asset', 'collection')

    def filter_queryset(self, request, queryset, view):
        user = request.user
        if user.is_anonymous:
            return queryset
        if queryset.model._meta.model_name not in self.SUPPORTED_MODELS:
            return queryset
        try:
            subdomain_user_ids = get_subdomain_user_ids(user)
            return queryset.filter(owner__in=subdomain_user_ids)
        except KeycloakModel.DoesNotExist:
            # No Keycloak record — fall through to standard permission filtering
            return queryset
        except Exception:
            logger.exception(
                'Unexpected error while filtering queryset by subdomain '
                'for user %s', user
            )
            raise


class SubdomainAwareObjectPermissionsFilter(KpiObjectPermissionsFilter):
    """
    OC customization: extends KpiObjectPermissionsFilter to include library
    items (question/block/template/collection) owned by users in the caller's
    Keycloak subdomain. Surveys are still governed by standard permissions.
    Falls back to standard behavior when the user has no Keycloak record.
    """

    _LIBRARY_ASSET_TYPES = ('question', 'block', 'template', 'collection')

    def filter_queryset(self, request, queryset, view):
        standard = super().filter_queryset(request, queryset, view)
        user = request.user
        if user.is_anonymous:
            return standard
        try:
            subdomain_user_ids = get_subdomain_user_ids(user)
            subdomain_library_qs = Asset.objects.filter(
                owner__in=subdomain_user_ids,
                asset_type__in=self._LIBRARY_ASSET_TYPES,
            ).values('pk')
        except KeycloakModel.DoesNotExist:
            return standard
        except Exception:
            logger.exception(
                'Unexpected error while building subdomain library filter for user %s',
                user,
            )
            raise
        # Union via DB-level subqueries — avoids materialising pk sets into Python.
        return queryset.filter(
            Q(pk__in=standard.values('pk')) | Q(pk__in=subdomain_library_qs)
        )
