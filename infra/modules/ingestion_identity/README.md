# ingestion_identity

Owns the single IAM role assumed by OpenSearch Ingestion for the pull-based S3/SQS source, the Serverless sink, and the S3 sink DLQ. It restricts reads to one canonical archive prefix, consumption to one queue, and `s3:PutObject` to one document-failure DLQ prefix.

OpenSearch Serverless control-plane APIs used for the OSIS-managed PrivateLink network policy require `Resource = "*"`. Those statements enumerate actions and use the exact `aoss:collection` condition. The S3 source also needs `s3:ListAllMyBuckets` for bucket ownership validation; AWS does not support resource-level scoping for that one action. See `docs/security.md` before changing them.

This is a separate module because the role must exist before the Serverless data access policy, while the pipeline itself needs the resulting collection endpoint. Splitting identity from runtime prevents a dependency cycle without duplicating IAM across live roots.
