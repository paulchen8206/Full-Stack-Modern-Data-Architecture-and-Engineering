# ADR-0007: Platform Observability Stack with Prometheus, Grafana, and Blackbox Exporter

- Status: Accepted
- Date: 2026-04-20

## Purpose

This section defines the purpose of this document.
Record the decision to standardize local platform observability on Prometheus, Grafana, and Blackbox Exporter with repository-managed configuration.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `docker compose up -d blackbox-exporter prometheus grafana`
- `make ops-status`
- `curl -fsS http://localhost:9090/-/ready`
- `curl -fsS http://localhost:3000/api/health`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming all observability services are healthy, Grafana dashboard provisioning succeeds, and Prometheus probe metrics are present.
Use `make ops-status` for endpoint checks and query Prometheus for `probe_success{job="docker_services"}` to verify blackbox probes.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If dashboards load without data, first validate Prometheus target health and blackbox relabel configuration in `observability/prometheus/prometheus.yml`.
If Grafana does not show the provisioned dashboard, verify datasource and dashboard provider files under `observability/grafana/provisioning` are mounted into the container.

## References

This section defines the primary cross-references for this document.

- [../runbook.md](../runbook.md)
- [../../docker-compose.yml](../../docker-compose.yml)
- [../../observability/prometheus/prometheus.yml](../../observability/prometheus/prometheus.yml)
- [../../observability/blackbox/blackbox.yml](../../observability/blackbox/blackbox.yml)
- [../../observability/grafana/provisioning/datasources/prometheus.yml](../../observability/grafana/provisioning/datasources/prometheus.yml)
- [../../observability/grafana/provisioning/dashboards/dashboards.yml](../../observability/grafana/provisioning/dashboards/dashboards.yml)
- [../../observability/grafana/dashboards/docker-services-health.json](../../observability/grafana/dashboards/docker-services-health.json)

## Context

The platform already included many independently running services in Compose, but operational visibility was fragmented and mostly manual.

Routine A needed a centralized way to answer:

- Which core services are currently reachable?
- Which endpoints have degraded over time?
- How can operators quickly correlate health changes across the stack?

A dashboard-only approach without probe-based collection was insufficient because endpoint reachability must be measured continuously and stored as time series.

## Decision

Adopt a repository-managed observability stack for local runtime based on:

- Prometheus for time-series collection and query
- Blackbox Exporter for endpoint probing
- Grafana for dashboard visualization and operational status

Key design choices:

- Add `prometheus`, `blackbox-exporter`, and `grafana` as first-class services in `docker-compose.yml`
- Configure Prometheus to scrape `docker_services` through Blackbox Exporter using `/probe`
- Track service health with `probe_success`, response status with `probe_http_status_code`, and latency with `probe_duration_seconds`
- Provision Grafana datasource and dashboards from version-controlled files
- Ship a default dashboard (`docker-services-health`) under a `Docker` folder so operators have immediate visibility after startup
- Include Prometheus, Grafana, and Blackbox health checks in `make ops-status`

## Consequences

- Positive:
  - Observability is available by default in Routine A without manual Grafana setup
  - Health and latency signals are retained and queryable over time
  - Dashboard definitions are reproducible and reviewable in Git
  - Day-2 checks become faster because operators can rely on both CLI checks and dashboards
- Trade-offs:
  - Adds additional containers and configuration to maintain
  - Requires correct relabeling and probe configuration; misconfiguration can silently produce empty panels
  - Local resource usage increases due to Prometheus TSDB and Grafana runtime

## Alternatives considered

- Grafana only with ad-hoc data sources: rejected because it does not collect metrics itself and would still require a metrics backend
- Prometheus only without Grafana: rejected because raw PromQL is less accessible for routine operational triage
- Direct service `/metrics` scraping only: rejected because several critical services are better represented by HTTP health probes rather than exporter metrics
- External SaaS monitoring: out of scope for local-first development and would reduce reproducibility

## Detailed References

- `docker-compose.yml` — observability service definitions and mounts
- `observability/prometheus/prometheus.yml` — scrape jobs and blackbox relabel flow
- `observability/blackbox/blackbox.yml` — probe module configuration
- `observability/grafana/provisioning/datasources/prometheus.yml` — Grafana datasource provisioning
- `observability/grafana/provisioning/dashboards/dashboards.yml` — dashboard provider configuration
- `observability/grafana/dashboards/docker-services-health.json` — default Docker services health dashboard
