# ADR-0004: CDC-Based MDM Enrichment Flow

- Status: Accepted
- Date: 2026-04-18

## Purpose

This section defines the purpose of this document.
Record the decision to use CDC-based MDM enrichment for master data propagation across streaming and analytics layers.

## Commands

This section defines the primary commands for this document.
Primary commands related to this decision:

- `make mdm-topics-check`
- `make mdm-topics-check-dev`
- Shared targets: `make help`, `make validate`

## Validation

This section defines the primary validation approach for this document.
Validate this decision by confirming records flow through curated MDM topics and into landing tables used by downstream models.
Use `make help` to verify target discoverability and `make validate` to confirm baseline build/render checks pass.

## Troubleshooting

This section defines the primary troubleshooting approach for this document.
If MDM topics or landing tables are empty, troubleshoot connector health and sync services before changing dbt logic.

## References

This section defines the primary cross-references for this document.

- [../runbook.md](../runbook.md)
- [../../connect/connector-configs/debezium-mysql-mdm.json](../../connect/connector-configs/debezium-mysql-mdm.json)

## Context

Customer and product master data changes must be propagated consistently into streaming and analytics layers with low lag and clear lineage.

## Decision

Implement MDM enrichment through a CDC-driven flow:

1. MySQL MDM stores source-of-truth master data.
2. Debezium captures row-level changes.
3. CDC events are republished into curated topics (`mdm_customer`, `mdm_product`).
4. `mdm-pyspark-sync` mirrors MDM tables into Postgres landing tables for downstream dbt models.

## Consequences

- Positive:
  - Near-realtime master data propagation
  - Clear separation between source CDC events and curated domain topics
  - Better downstream consistency for dbt dimensions and facts
- Trade-offs:
  - More moving parts and connector operational dependencies
  - Requires connector/topic health checks in routine operations

## Alternatives considered

- Batch-only master data sync: rejected due to slower freshness and weaker event lineage
- Direct table polling without CDC: rejected due to higher load and less robust change capture semantics

## Detailed References

- ../runbook.md
- ../../connect/connector-configs/debezium-mysql-mdm.json
