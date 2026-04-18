#!/usr/bin/env sh

set -eu

airflow db migrate

airflow users create \
  --role Admin \
  --username "${AIRFLOW_ADMIN_USERNAME:-admin}" \
  --password "${AIRFLOW_ADMIN_PASSWORD:-admin}" \
  --firstname Local \
  --lastname Admin \
  --email admin@example.com || true

airflow scheduler &
exec airflow webserver
