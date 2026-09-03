# ADR 0002: Use Amazon OpenSearch Ingestion

- Status: Accepted
- Date: 2026-09-03

## Context

Lambda functions and repeated Firehose streams can accumulate parsing, buffering, retry, scaling, deployment, and patching responsibilities. Those mechanics matter, but most are not differentiating capabilities for this platform.

## Decision

Use Amazon OpenSearch Ingestion with an S3/SQS source, newline codec, automatic compression detection, JSON parsing, small schema enrichment, end-to-end acknowledgement, and an OpenSearch Serverless sink.

## Consequences

AWS operates the ingestion runtime and scaling. The platform still owns pipeline semantics, schema compatibility, IAM, network access, capacity limits, observability, DLQ handling, and replay. OSIS also owns the PrivateLink endpoint and a dedicated network policy used to reach the private collection; that service-managed policy is intentionally separate from Terraform-managed user access.

