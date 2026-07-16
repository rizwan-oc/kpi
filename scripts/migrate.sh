#!/usr/bin/env bash
set -e

# Skipping fix_migrations_for_kobocat — kobocat DB not in use
python manage.py runscript fix_migrations_for_kpi
echo '########## KPI migrations ############'

# Run required long-running migrations before Django migrations to unblock the
# long_running_migrations.E001 system check when restoring from a backup.
python scripts/run_required_long_running_migrations.py

set +e
MIGRATE_OUT=$(DJANGO_SETTINGS_MODULE=kobo.settings.guardian python manage.py migrate --noinput 2>&1)
MIGRATE_STATUS=$?
set -e

if [ $MIGRATE_STATUS -ne 0 ]; then
    if echo "$MIGRATE_OUT" | grep -q "cannot alter type of a column used by a view"; then
        echo "⚠️ Materialized view schema lock detected! Automatically resolving..."
        DJANGO_SETTINGS_MODULE=kobo.settings.guardian python manage.py manage_user_reports_mv --drop
        echo "Retrying KPI migrations..."
        DJANGO_SETTINGS_MODULE=kobo.settings.guardian python manage.py migrate --noinput
        DJANGO_SETTINGS_MODULE=kobo.settings.guardian python manage.py manage_user_reports_mv --create
        echo "Schema lock resolved successfully."
    else
        echo "❌ KPI migrations failed. Details below:"
        echo "$MIGRATE_OUT"
        exit $MIGRATE_STATUS
    fi
else
    echo "$MIGRATE_OUT"
fi

# Ensure user_reports MV exists — create it synchronously if SKIP_HEAVY_MIGRATIONS
# deferred it (user_reports.0007 records without creating the MV, and 0008 then
# resets the LRM record to 'created' expecting a Celery worker). Running this here
# after migrate guarantees the MV is always present when the migrate job completes,
# regardless of whether the LRM worker runs.
DJANGO_SETTINGS_MODULE=kobo.settings.guardian python manage.py manage_user_reports_mv --create --force

# Skipping kobocat DB migrations — kobocat not in use
python manage.py runscript create_anonymous_user
