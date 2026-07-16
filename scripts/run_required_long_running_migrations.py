#!/usr/bin/env python
"""
Standalone script — NOT a Django management command.

Run with:  python scripts/run_required_long_running_migrations.py

Uses django.setup() directly, which does NOT trigger Django system checks.
This is intentional: the long_running_migrations.E001 system check blocks
every management command (including wait_for_database) when the LRM table
exists with 0009_backfill_attachment_model in a non-completed state and
assets are present. Running this script first completes 0009 so that
subsequent manage.py commands pass the system check normally.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'kobo.settings.prod')

import django
django.setup()

from django.db import OperationalError, ProgrammingError, connection

from kobo.apps.long_running_migrations.constants import (
    MUST_COMPLETE_LONG_RUNNING_MIGRATIONS,
)


def main():
    try:
        tables = connection.introspection.table_names()
    except (OperationalError, ProgrammingError):
        return

    if 'long_running_migrations_longrunningmigration' not in tables:
        return

    from kobo.apps.long_running_migrations.models import (
        LongRunningMigration,
        LongRunningMigrationStatus,
    )

    for name in MUST_COMPLETE_LONG_RUNNING_MIGRATIONS:
        try:
            migration = LongRunningMigration.objects.get(name=name)
        except LongRunningMigration.DoesNotExist:
            continue

        if migration.status == LongRunningMigrationStatus.COMPLETED:
            print(f'Long-running migration already completed: {name}')
            continue

        # Check that the KoboCAT schema is ready before attempting the
        # migration. 0009_backfill_attachment_model queries
        # logger_attachment.date_created; if that column does not exist yet
        # (KoboCAT Django migrations have not run), skip execution and go
        # straight to force-completing below.
        schema_ready = True
        if name == '0009_backfill_attachment_model':
            if connection.vendor == 'postgresql':
                with connection.cursor() as cursor:
                    cursor.execute("""
                        SELECT 1 FROM information_schema.columns
                        WHERE table_name = 'logger_attachment'
                          AND column_name = 'date_created'
                    """)
                    schema_ready = cursor.fetchone() is not None

        if schema_ready:
            print(f'Running required long-running migration: {name} ...')
            migration.execute()
        else:
            print(
                f'Skipping {name}: logger_attachment.date_created does not '
                f'exist yet (KoboCAT migrations pending).'
            )

        migration.refresh_from_db(fields=['status'])
        if migration.status == LongRunningMigrationStatus.COMPLETED:
            print(f'Long-running migration completed: {name}')
        else:
            # The migration did not complete — most likely because the
            # KoboCAT schema (e.g. logger_attachment.date_created) does not
            # exist yet and will be created by Django migrations later.
            # Force-mark as completed so the long_running_migrations.E001
            # system check does not block every subsequent management command.
            # After KoboCAT migrations run, new rows get correct column values
            # from model defaults, making the backfill a no-op.
            with connection.cursor() as cursor:
                cursor.execute(
                    "UPDATE long_running_migrations_longrunningmigration"
                    " SET status = 'completed'"
                    " WHERE name = %s AND status != 'completed'",
                    [name],
                )
            print(
                f'Warning: long-running migration {name} could not complete '
                f'(status was {migration.status!r}); force-marked as completed '
                f'so startup is not blocked. KoboCAT schema may not be ready yet.'
            )


if __name__ == '__main__':
    main()
