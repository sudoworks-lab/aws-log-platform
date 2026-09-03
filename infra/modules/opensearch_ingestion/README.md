# opensearch_ingestion

Owns the Amazon OpenSearch Ingestion runtime and its declarative Data Prepper pipeline. The source reads S3 event notifications from SQS, automatically detects uncompressed or gzip input, splits newline records, parses JSON, separates event occurrence time from ingestion time, and writes to an OpenSearch Serverless index with end-to-end acknowledgement enabled.

`delete_s3_objects_on_read` is explicitly false. S3 is never treated as a disposable transport buffer.

The sink installs the core `dynamic: false` index template and routes individual documents rejected by OpenSearch to a separate S3 sink DLQ. The pipeline uses the default in-memory buffer because the raw S3 archive and SQS queue are the explicit durability boundary for this design.

The `network_policy_name` is reserved for the policy that OSIS creates or updates with its service-managed PrivateLink endpoint. It must not identify the Terraform-managed human/search network policy.

`terraform validate` checks Terraform and provider schema, not whether the OSIS service accepts every Data Prepper option in a particular Region. Runtime semantic validation remains unverified until a separately authorized non-production deployment.
