from django.conf import settings
from django.db import models


class KeycloakTenantUser(models.Model):
    UID = models.CharField(max_length=37, primary_key=True)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='keycloak_tenant',
    )
    subdomain = models.CharField(max_length=64, default='')
    user_type = models.CharField(max_length=64, default='')

    class Meta:
        db_table = 'bossoidc_keycloak'
