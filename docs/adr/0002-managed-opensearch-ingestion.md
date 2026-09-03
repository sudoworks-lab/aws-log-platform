# ADR 0002: Use Amazon OpenSearch Ingestion

- Status: Accepted
- Date: 2026-09-03

## Context

Lambda functions and repeated Firehose streams can accumulate parsing, buffering, retry, scaling, deployment, and patching responsibilities. Those mechanics matter, but most are not differentiating capabilities for this platform.

## Decision

Use Amazon OpenSearch Ingestion with an S3/SQS source, newline codec, automatic compression detection, failure-aware JSON parsing, explicit event and ingestion timestamps, small schema enrichment, a core `dynamic: false` index template, end-to-end acknowledgement, an OpenSearch Serverless sink, and a separate S3 DLQ for documents rejected by that sink.

## Consequences

AWS operates the ingestion runtime and scaling. The platform still owns pipeline semantics, schema compatibility, IAM, network access, capacity limits, observability, both object-level and document-level DLQ handling, and replay. OSIS also owns the PrivateLink endpoint and a dedicated network policy used to reach the private collection; that service-managed policy is intentionally separate from Terraform-managed user access.

This design does not configure OSIS persistent buffering. The canonical S3 archive and durable SQS queue are its explicit durability boundary; enabling persistent buffering later requires a separate OCU, KMS, and cost contract.
