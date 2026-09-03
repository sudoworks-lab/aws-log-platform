# ingestion_identity

Owns the single IAM role assumed by OpenSearch Ingestion for both the pull-based S3/SQS source and the Serverless sink. It restricts reads to one archive prefix and consumption to one queue.

OpenSearch Serverless control-plane APIs used for the OSIS-managed PrivateLink network policy require `Resource = "*"`. Those statements enumerate actions and use the exact `aoss:collection` condition. The S3 source also needs `s3:ListAllMyBuckets` for bucket ownership validation; AWS does not support resource-level scoping for that one action. See `docs/security.md` before changing them.

This is a separate module because the role must exist before the Serverless data access policy, while the pipeline itself needs the resulting collection endpoint. Splitting identity from runtime prevents a dependency cycle without duplicating IAM across live roots.
