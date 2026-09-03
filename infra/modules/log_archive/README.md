# log_archive

Owns the durable raw S3 archive: public-access blocking, bucket-owner-enforced object ownership, versioning, SSE-S3, TLS-only bucket policy, and configurable Standard-IA/Deep Archive lifecycle transitions.

Expiration is `null` by default. Enabling it is a data-retention decision, not an ingestion setting. `force_destroy` also defaults to `false` so Terraform cannot silently empty the source of truth.

The module does not create event notifications because the destination queue policy depends on this bucket ARN. The live root owns that integration edge after both modules exist.

