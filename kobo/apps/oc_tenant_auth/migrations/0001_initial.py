from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    """
    Adopts the existing bossoidc_keycloak table under the tenant_auth app label.
    On production upgrades (table already exists) the CREATE TABLE is a no-op.
    On fresh installs the table is created by the IF NOT EXISTS guard.
    """

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.CreateModel(
                    name='KeycloakTenantUser',
                    fields=[
                        ('UID', models.CharField(
                            max_length=37, primary_key=True, serialize=False
                        )),
                        ('subdomain', models.CharField(default='', max_length=64)),
                        ('user_type', models.CharField(default='', max_length=64)),
                        ('user', models.OneToOneField(
                            on_delete=django.db.models.deletion.CASCADE,
                            related_name='keycloak_tenant',
                            to=settings.AUTH_USER_MODEL,
                        )),
                    ],
                    options={
                        'db_table': 'bossoidc_keycloak',
                    },
                ),
            ],
            database_operations=[
                migrations.RunSQL(
                    sql="""
                        CREATE TABLE IF NOT EXISTS "bossoidc_keycloak" (
                            "UID" varchar(37) NOT NULL PRIMARY KEY,
                            "subdomain" varchar(64) NOT NULL DEFAULT '',
                            "user_type" varchar(64) NOT NULL DEFAULT '',
                            "user_id" integer NOT NULL UNIQUE
                                REFERENCES "auth_user" ("id")
                                    DEFERRABLE INITIALLY DEFERRED
                        );
                    """,
                    reverse_sql=migrations.RunSQL.noop,
                ),
            ],
        ),
    ]
