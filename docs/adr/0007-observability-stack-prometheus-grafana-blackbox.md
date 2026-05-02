# ADR-0007: Platform Observability Stack with Prometheus, Grafana, and Blackbox Exporter

- Status: Accepted
- Date: 2026-04-20

## 1. Summary

Local platform observability is standardized on Prometheus, Grafana, and Blackbox Exporter with repository-managed configuration.

## 2. Context

Service-level visibility was fragmented across manual checks and isolated logs. Operators needed a single surface for availability and probe-health monitoring.

## 3. Decision

Adopt a built-in observability stack in local runtime:

- Prometheus for collection and query
- Blackbox Exporter for endpoint probes
- Grafana for dashboards

All core config remains version-controlled in repository paths under observability.

## 4. Operational References

- docker compose up -d prometheus grafana blackbox-exporter
- curl -fsS http://localhost:9090/-/ready
- curl -fsS http://localhost:3000/api/health

## 5. Validation

Validation is successful when:

- observability services are healthy
- Prometheus targets are up
- probe_success metrics exist for configured endpoints
- default Grafana dashboards render with live data

## 6. Consequences

Positive outcomes:

- shared operational visibility
- reproducible dashboard and scrape configuration

Trade-offs:

- extra compute and memory footprint
- configuration-drift risk if service names change without probe updates

## 7. Alternatives Considered

- Grafana-only setup: rejected because Grafana is not a metrics collector
- Prometheus-only setup: rejected because dashboard usability is lower for routine triage

## 8. References

- [../../observability/prometheus/prometheus.yml](../../observability/prometheus/prometheus.yml)
- [../../observability/blackbox/blackbox.yml](../../observability/blackbox/blackbox.yml)
- [../../observability/grafana/provisioning](../../observability/grafana/provisioning)
- [../runbook.md](../runbook.md)
