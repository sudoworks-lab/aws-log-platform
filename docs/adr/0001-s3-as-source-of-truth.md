# ADR 0001: S3 is the durable source of truth

- Status: Accepted
- Date: 2026-09-03

## Context

Search clusters optimize for indexing and investigation, not for being the only durable evidence store. Index deletion, mapping mistakes, retention, access-policy errors, or service outages should not destroy the raw log.

## Decision

Every core pipeline input is an immutable NDJSON or gzip NDJSON object in S3. S3 retains and transitions raw objects independently of OpenSearch. OpenSearch is a hot, rebuildable projection.

## Consequences

Search can be rebuilt from an explicit S3 key/time range. S3 lifecycle, versioning, access, restore latency, and replay cost become first-class operational concerns. The architecture accepts eventual searchability and at-least-once duplicate risk rather than treating OpenSearch acknowledgement as the durability boundary.

