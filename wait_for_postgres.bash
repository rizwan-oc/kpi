#!/bin/bash
set -e
echo "Waiting for PostgreSQL..."
wait-for-it "${KPI_POSTGRES_HOST:-postgresdb}:${KPI_POSTGRES_PORT:-5432}" --timeout=30 --strict
echo "PostgreSQL is up."
