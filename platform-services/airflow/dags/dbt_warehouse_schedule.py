from __future__ import annotations

from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator


with DAG(
    dag_id="dbt_warehouse_schedule",
    description="Run dbt models against Trino and Postgres on a schedule.",
    start_date=datetime(2026, 4, 17),
    schedule="*/5 * * * *",
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=1)},
    tags=["dbt", "warehouse", "mdm"],
) as dag:
    run_dbt = BashOperator(
        task_id="run_dbt",
        bash_command=(
            "rm -rf /tmp/dbt && mkdir -p /tmp/dbt /opt/airflow/logs/dbt && "
            "cp -R /opt/airflow/dbt/. /tmp/dbt/ && "
            "cd /tmp/dbt && "
            "dbt deps --project-dir /tmp/dbt --profiles-dir /tmp/dbt "
            "--log-path /opt/airflow/logs/dbt && "
            "dbt run --project-dir /tmp/dbt --profiles-dir /tmp/dbt --target trino "
            "--log-path /opt/airflow/logs/dbt --target-path /tmp/dbt/target"
        ),
    )

    run_dbt_mdm = BashOperator(
        task_id="run_dbt_mdm",
        bash_command=(
            "rm -rf /tmp/dbt && mkdir -p /tmp/dbt /opt/airflow/logs/dbt && "
            "cp -R /opt/airflow/dbt/. /tmp/dbt/ && "
            "cd /tmp/dbt && "
            "dbt run --project-dir /tmp/dbt --profiles-dir /tmp/dbt "
            "--target trino "
            "--log-path /opt/airflow/logs/dbt --target-path /tmp/dbt/target "
            "--select stg_mdm_customer360 stg_mdm_product_master stg_mdm_date "
            "dim_mdm_customer dim_mdm_product dim_mdm_date"
        ),
    )

    run_dbt_postgres = BashOperator(
        task_id="run_dbt_postgres",
        bash_command=(
            "rm -rf /tmp/dbt && mkdir -p /tmp/dbt /opt/airflow/logs/dbt && "
            "cp -R /opt/airflow/dbt/. /tmp/dbt/ && "
            "cd /tmp/dbt && "
            "dbt run --project-dir /tmp/dbt --profiles-dir /tmp/dbt --target dev "
            "--log-path /opt/airflow/logs/dbt --target-path /tmp/dbt/target"
        ),
    )

    run_dbt_mdm >> run_dbt >> run_dbt_postgres
