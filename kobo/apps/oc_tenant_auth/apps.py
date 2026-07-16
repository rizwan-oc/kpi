from django.apps import AppConfig


class TenantAuthConfig(AppConfig):
    name = 'kobo.apps.oc_tenant_auth'
    label = 'oc_tenant_auth'
    verbose_name = 'Tenant Authentication'
