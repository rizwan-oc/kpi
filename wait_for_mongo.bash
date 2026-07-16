#!/bin/bash
set -e
echo "Waiting for MongoDB..."
wait-for-it "${KPI_MONGO_HOST:-wekan-db}:${KPI_MONGO_PORT:-27017}" --timeout=30 --strict
echo "MongoDB is up."
