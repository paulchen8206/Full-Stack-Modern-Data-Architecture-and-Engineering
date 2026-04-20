# ADR-0007: Airflow for Orchestration

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to use Apache Airflow as the orchestration layer for scheduling and managing recurring dbt runs.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make airflow-up`
- `make airflow-dbt-reboot`
- `make airflow-trigger-dbt-dag`
- `make airflow-dbt-check-dev`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming the `dbt_warehouse_schedule` DAG is enabled, runs complete successfully, and bronze/silver/gold layer row counts increase on each cycle.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If no dbt runs appear in the Airflow UI, check that the DAG is unpaused and that Airflow can reach the Postgres warehouse. Use `make airflow-logs` to inspect scheduler output.

## References

This section defines the primary cross-references for this document.

- [../runbook.md](../runbook.md)
- [../../airflow/dags/dbt_warehouse_schedule.py](../../airflow/dags/dbt_warehouse_schedule.py)

## Context

dbt transformations must run on a regular cadence to keep bronze, silver, and gold layers fresh relative to landing data that is continuously written by Kafka Connect and PySpark sync.

Running dbt manually on each deployment is not repeatable and breaks the separation between operational startup and data freshness concerns.

## Decision

Use Apache Airflow to schedule and orchestrate recurring dbt runs.

Key design choices:

- DAG ID: `dbt_warehouse_schedule`
- DAG location: `airflow/dags/dbt_warehouse_schedule.py`
- Schedule: every 5 minutes
- Each DAG run executes `dbt deps` followed by `dbt run` against the local Postgres warehouse
- Airflow runs inside the same Docker Compose stack (Routine A) or the same Helm release (Routine B) as the rest of the platform
- Airflow UI is accessible at `http://localhost:8084` (Routine A) or via port-forward at `http://localhost:8084` (Routine B)
- Airflow credentials: username `admin`, password `admin`

## Consequences

- Positive:
  - dbt refresh cadence is decoupled from deployment operations
  - DAG history provides an audit trail of transformation runs
  - The same DAG file works in both Compose and Kubernetes paths without change
  - Airflow can be extended to orchestrate additional pipelines beyond dbt
- Trade-offs:
  - Adds an Airflow service dependency to both runtime paths
  - Airflow scheduler must be healthy for scheduled runs to fire; manual `make dbt-run` remains the fallback
  - In the Helm path, the Airflow pod must have access to the dbt project mounted via ConfigMap

## Alternatives considered

- Cron job directly on the host: rejected because it is not portable, not visible in a shared UI, and not easily extensible to multi-step pipelines
- Kubernetes CronJob without Airflow: rejected because it lacks DAG-level visibility, retry logic, and the operator ecosystem needed for pipeline growth
- dbt Cloud scheduler: out of scope for local demo; the Airflow DAG pattern is intentionally kept compatible so migration to dbt Cloud or Prefect is additive only

## Detailed References

- `airflow/dags/dbt_warehouse_schedule.py` — DAG definition
- `airflow/Dockerfile` — Airflow image with dbt installed
- ADR-0006: Medallion Architecture with dbt for ELT Transformations
