# sink_dlq

Owns the S3 dead-letter bucket for OpenSearch document-level sink failures. This bucket is a bounded troubleshooting aid and is separate from the canonical raw archive, which remains the durable source of truth.

The module blocks public access, enforces bucket-owner ownership, uses SSE-S3 (`AES256`), denies non-TLS requests, and expires all failure objects after `retention_days` (30 days by default). `force_destroy` is fixed to `false`, and versioning is intentionally not enabled.
