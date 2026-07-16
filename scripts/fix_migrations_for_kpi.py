from django.contrib.auth.management import DEFAULT_DB_ALIAS
from django.db import connection

from .fix_migrations_for_kobocat import are_migrations_already_applied


def run():

    if not are_migrations_already_applied(DEFAULT_DB_ALIAS):
        print('Skipping KPI migration fixes...')
        return

    if should_fix_internal_mfa_app_label():
        fix_internal_mfa_app_label()

    # Upstream: fake-apply kobo_auth.0001 when upgrading from a release predating
    # the kobo_auth app (custom User model moved here, reusing `auth_user`).
    fix_kobo_auth_initial()

    # Fix: kobo_auth.0001_initial recorded but auth.0012 (Django 4.0+) not recorded.
    # Must run AFTER fix_kobo_auth_initial so kobo_auth.0001_initial is guaranteed
    # recorded before we check for the auth dependency gap.
    fix_auth_migration_for_kobo_auth()

    # Ensure the anonymous user exists before data migrations that assign object
    # permissions to it (e.g. kpi.0055); create_anonymous_user only runs AFTER migrate.
    ensure_anonymous_user()

    # Fix: kpi.0044 recorded but its organizations dependency not recorded.
    # We added ('organizations', '0009') to kpi.0044 so the data migration's
    # user.organization access is safe; existing DBs that ran kpi.0044 before
    # organizations.0009 existed need the missing records inserted.
    fix_organizations_for_kpi_0044()

    # OpenClinica: repair migration/schema drift introduced by the Keycloak/SSO
    # upgrades before `manage.py migrate` runs later in scripts/migrate.sh.
    fix_bossoidc2_keycloak_usertype()
    fix_oauth2_provider_application_columns()

    # OpenClinica: create the user_reports MV if SKIP_HEAVY_MIGRATIONS deferred it
    # and the LRM worker didn't finish the job.
    fix_user_reports_mv()


def fix_kobo_auth_initial():
    """
    Fake-apply kobo_auth.0001_initial when upgrading from a release that predates
    the kobo_auth app (upstream moved the custom User model into its own app,
    reusing the existing `auth_user` table via db_table='auth_user').

    On such databases `auth_user` already exists and `account.0001_initial`
    (allauth) is recorded, but `kobo_auth.0001_initial` is not, so Django raises
    InconsistentMigrationHistory ("account.0001_initial is applied before its
    dependency kobo_auth.0001_initial"). kobo_auth.0001 only creates the User
    model (db_table 'auth_user', already present) and a proxy model (no table),
    so recording it as applied is safe and reproduces the intent of
    `manage.py migrate kobo_auth 0001 --fake`.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT EXISTS (SELECT FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = 'auth_user')"
        )
        if not cursor.fetchone()[0]:
            return

        cursor.execute(
            "SELECT * FROM django_migrations "
            "WHERE app = 'kobo_auth' AND name = '0001_initial'"
        )
        if cursor.fetchone() is not None:
            return

        cursor.execute(
            "INSERT INTO django_migrations (app, name, applied) "
            "VALUES ('kobo_auth', '0001_initial', NOW())"
        )
        print(
            'Fake-applying kobo_auth.0001_initial '
            '(existing auth_user table; custom User moved to kobo_auth).'
        )


def ensure_anonymous_user():
    """
    Create the anonymous user (settings.ANONYMOUS_USER_ID, default -1) before
    `manage.py migrate` runs.

    kpi data migrations such as kpi.0055_set_require_auth_per_project assign
    object permissions to the anonymous user. On an upgraded database that user
    may not exist yet — create_anonymous_user (which calls get_anonymous_user())
    is only invoked AFTER migrate in scripts/migrate.sh — so the migration hits a
    foreign-key violation ("Key (user_id)=(-1) is not present in table auth_user").

    Insert a minimal auth_user row mirroring get_anonymous_user() (pk + username,
    model defaults otherwise). Raw SQL keeps this independent of model/schema state
    mid-migration. create_anonymous_user later finds this row and fills in the rest.
    """
    from django.conf import settings

    anon_id = getattr(settings, 'ANONYMOUS_USER_ID', -1)
    username = getattr(
        settings, 'ANONYMOUS_DEFAULT_USERNAME_VALUE', 'AnonymousUser'
    )
    with connection.cursor() as cursor:
        cursor.execute('SELECT 1 FROM auth_user WHERE id = %s', [anon_id])
        if cursor.fetchone() is not None:
            return

        cursor.execute(
            'INSERT INTO auth_user '
            '(id, password, is_superuser, username, first_name, last_name, '
            'email, is_staff, is_active, date_joined) '
            "VALUES (%s, '', false, %s, '', '', '', false, true, NOW()) "
            'ON CONFLICT (id) DO NOTHING',
            [anon_id, username],
        )
        print(f'Creating anonymous user (id={anon_id}) before data migrations.')


def should_fix_internal_mfa_app_label():
    """
    Checks for accounts_mfa migrations with the previous app label
    """
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT * FROM django_migrations WHERE app = 'mfa' AND name = '0002_add_mfa_available_to_user_model';"
        )
        return cursor.fetchone() is not None


def fix_internal_mfa_app_label():
    """
    Changes the known migration names for the internal accounts_mfa app
    """
    with connection.cursor() as cursor:
        cursor.execute("""
        UPDATE django_migrations SET app='accounts_mfa' WHERE app='mfa' AND name IN (
            '0001_initial',
            '0002_add_mfa_available_to_user_model',
            '0003_rename_kobo_mfa_method_model',
            '0004_alter_mfamethod_date_created_and_more'
        )
        """)
        print(f'Fixing accounts_mfa app migration records. Modified {cursor.rowcount} records in django_migrations')


def fix_auth_migration_for_kobo_auth():
    """
    OpenClinica: fix InconsistentMigrationHistory when upgrading from pre-Django-4.0 DB.

    auth.0012_alter_user_first_name_max_length was introduced in Django 4.0. On a DB
    where kobo_auth.0001_initial was already fake-applied (it depends on auth.0012),
    Django's check_consistent_history raises InconsistentMigrationHistory if auth.0012
    is absent from django_migrations. All auth schema changes are already in the DB;
    only the migration records are missing. Insert any missing auth records so
    `manage.py migrate` can proceed.
    """
    AUTH_MIGRATIONS = [
        '0001_initial',
        '0002_alter_permission_name_max_length',
        '0003_alter_user_email_max_length',
        '0004_alter_user_username_opts',
        '0005_alter_user_last_login_null',
        '0006_require_contenttypes_0002',
        '0007_alter_validators_add_error_messages',
        '0008_alter_user_username_max_length',
        '0009_alter_user_last_name_max_length',
        '0010_alter_group_name_max_length',
        '0011_update_proxy_permissions',
        '0012_alter_user_first_name_max_length',
    ]
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT id FROM django_migrations "
            "WHERE app = 'kobo_auth' AND name = '0001_initial'"
        )
        if not cursor.fetchone():
            return  # kobo_auth.0001_initial not recorded; no inconsistency possible

        cursor.execute("SELECT name FROM django_migrations WHERE app = 'auth'")
        recorded = {row[0] for row in cursor.fetchall()}
        missing = [m for m in AUTH_MIGRATIONS if m not in recorded]
        if not missing:
            return

        print(
            f'Fake-applying {len(missing)} missing auth migrations to satisfy '
            f'kobo_auth.0001_initial dependency: {missing}'
        )
        for name in missing:
            cursor.execute(
                "INSERT INTO django_migrations (app, name, applied) "
                "VALUES ('auth', %s, NOW())",
                [name],
            )


def fix_organizations_for_kpi_0044():
    """
    OpenClinica: fix InconsistentMigrationHistory when upgrading from a DB where
    kpi.0044_standardize_searchable_fields was applied before organizations.0009 existed.

    We added ('organizations', '0009_update_db_state_with_auth_user') as a dependency
    to kpi.0044 so that its data migration accesses user.organization safely (including
    mmo_override, added in organizations.0005). On an existing DB that ran kpi.0044
    before these organizations migrations existed, the records are absent from
    django_migrations, causing check_consistent_history to fail. The schema for all
    these columns already exists; only the records are missing.

    The squash 0001_squashed_0004 is considered logically applied by Django if the
    four individual migrations it replaces are all recorded — so we only insert the
    squash name when neither it nor all four replaces entries are present.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT id FROM django_migrations "
            "WHERE app = 'kpi' AND name = '0044_standardize_searchable_fields'"
        )
        if not cursor.fetchone():
            return  # kpi.0044 not recorded; no inconsistency possible

        cursor.execute("SELECT name FROM django_migrations WHERE app = 'organizations'")
        recorded = {row[0] for row in cursor.fetchall()}

        # The squash covers 0001-0004. Django considers it satisfied if the squash
        # name is recorded OR if all four replaced migrations are recorded.
        SQUASH = '0001_squashed_0004_remove_organization_uid'
        REPLACES = {
            '0001_initial',
            '0002_alter_organization_id_to_kpiuidfield',
            '0003_copy_organization_uid_to_id',
            '0004_remove_organization_uid',
        }
        squash_satisfied = SQUASH in recorded or REPLACES.issubset(recorded)

        needed = []
        if not squash_satisfied:
            needed.append(SQUASH)
        for name in [
            '0005_add_mmo_override_field_to_organization',
            '0006_add_organization_type_and_website',
            '0007_update_organization_name_website_and_type',
            '0008_alter_mmo_override_verbose_name',
            '0009_update_db_state_with_auth_user',
        ]:
            if name not in recorded:
                needed.append(name)

        # Apply actual DDL for columns that may be missing even when their migration
        # records were already fake-inserted by a prior run. Check column existence
        # directly so this is idempotent regardless of what django_migrations says.
        # Only run when the table exists — if it doesn't, the real Django migrations
        # will create it with all columns and no ALTER TABLE is needed.
        cursor.execute(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema='public' AND table_name='organizations_organization'"
        )
        if cursor.fetchone()[0] > 0:
            cursor.execute(
                "SELECT COUNT(*) FROM information_schema.columns "
                "WHERE table_name='organizations_organization' AND column_name='mmo_override'"
            )
            if cursor.fetchone()[0] == 0:
                cursor.execute(
                    "ALTER TABLE organizations_organization "
                    "ADD COLUMN IF NOT EXISTS mmo_override boolean NOT NULL DEFAULT false"
                )
                print('Applied DDL for organizations.0005 (mmo_override column).')

            cursor.execute(
                "SELECT COUNT(*) FROM information_schema.columns "
                "WHERE table_name='organizations_organization' AND column_name='website'"
            )
            if cursor.fetchone()[0] == 0:
                cursor.execute(
                    "ALTER TABLE organizations_organization "
                    "ADD COLUMN IF NOT EXISTS organization_type varchar(20) NOT NULL DEFAULT 'none', "
                    "ADD COLUMN IF NOT EXISTS website varchar(255) NOT NULL DEFAULT ''"
                )
                print('Applied DDL for organizations.0006 (organization_type, website columns).')

        if not needed:
            return

        print(
            f'Fake-applying {len(needed)} missing organizations migrations to satisfy '
            f'kpi.0044 dependency: {needed}'
        )
        for name in needed:
            cursor.execute(
                "INSERT INTO django_migrations (app, name, applied) "
                "VALUES ('organizations', %s, NOW())",
                [name],
            )


def fix_bossoidc2_keycloak_usertype():
    """
    OpenClinica: fake-apply bossoidc2 0003_keycloak_usertype when upgrading from
    a legacy Keycloak/SSO deployment.

    On older OC deployments the `bossoidc_keycloak` table already carries the
    user_type column, so running the real migration raises
    'column "user_type" already exists' (and leaves an InconsistentMigrationHistory
    if it bails). This reproduces the original
    `manage.py migrate bossoidc2 0003_keycloak_usertype --fake` intent by inserting
    a fake django_migrations row when the legacy table exists and the migration has
    not yet been recorded.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT EXISTS (SELECT FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = 'bossoidc_keycloak')"
        )
        legacy_table_exists = cursor.fetchone()[0]
        if not legacy_table_exists:
            return

        cursor.execute(
            "SELECT * FROM django_migrations "
            "WHERE app = 'bossoidc2' AND name = '0003_keycloak_usertype'"
        )
        if cursor.fetchone() is not None:
            return

        cursor.execute(
            "INSERT INTO django_migrations (app, name, applied) "
            "VALUES ('bossoidc2', '0003_keycloak_usertype', NOW())"
        )
        print(
            'Fake-applying bossoidc2 0003_keycloak_usertype '
            '(legacy bossoidc_keycloak table present).'
        )


def fix_oauth2_provider_application_columns():
    """
    OpenClinica: repair oauth2_provider schema drift.

    oauth2_provider 0005 may have been recorded as applied without actually
    creating the `created`/`updated` columns on oauth2_provider_application,
    which blocks 0006. Adding them here is idempotent (IF NOT EXISTS) and runs
    before `manage.py migrate` is invoked further down scripts/migrate.sh.
    """
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT EXISTS (SELECT FROM information_schema.tables "
            "WHERE table_schema = 'public' "
            "AND table_name = 'oauth2_provider_application')"
        )
        table_exists = cursor.fetchone()[0]
        if not table_exists:
            return

        cursor.execute("""
        ALTER TABLE oauth2_provider_application
          ADD COLUMN IF NOT EXISTS created timestamp with time zone NOT NULL DEFAULT now(),
          ADD COLUMN IF NOT EXISTS updated timestamp with time zone NOT NULL DEFAULT now()
        """)
        print('Repairing oauth2_provider_application schema drift (created/updated columns).')


def fix_user_reports_mv():
    """
    OpenClinica: create user_reports_userreportsmv if SKIP_HEAVY_MIGRATIONS deferred it.

    user_reports.0007 skips MV creation when SKIP_HEAVY_MIGRATIONS=True and instead
    relies on the LRM Celery task 0019_recreate_user_reports_mv. If that task fails
    or gets stuck the MV is never built. This function detects the gap (0007 recorded
    but MV absent) and creates the MV synchronously so it is always present after the
    migrate job completes.

    Safe for fresh installs — 0007 won't be recorded yet, so this is a no-op.
    Idempotent — skipped when the MV already exists.
    """
    from django.core.management import call_command

    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT 1 FROM django_migrations "
            "WHERE app = 'user_reports' "
            "AND name = '0007_fix_mfa_is_active_new_table'"
        )
        if not cursor.fetchone():
            return  # fresh install — migrate will handle it via LRM

        cursor.execute(
            "SELECT 1 FROM pg_matviews "
            "WHERE schemaname = 'public' "
            "AND matviewname = 'user_reports_userreportsmv'"
        )
        if cursor.fetchone():
            return  # already present, nothing to do

    print(
        'user_reports_userreportsmv missing after SKIP_HEAVY_MIGRATIONS — creating now.'
    )
    call_command('manage_user_reports_mv', create=True, force=True)
