# opensearch_ingestion

Owns the Amazon OpenSearch Ingestion runtime and its declarative Data Prepper pipeline. The source reads S3 event notifications from SQS, automatically detects uncompressed or gzip input, splits newline records, parses JSON, adds ingestion metadata, and writes to an OpenSearch Serverless index with end-to-end acknowledgement enabled.

`delete_s3_objects_on_read` is explicitly false. S3 is never treated as a disposable transport buffer.

The `network_policy_name` is reserved for the policy that OSIS creates or updates with its service-managed PrivateLink endpoint. It must not identify the Terraform-managed human/search network policy.

`terraform validate` checks Terraform and provider schema, not whether the OSIS service accepts every Data Prepper option in a particular Region. Runtime semantic validation remains unverified until a separately authorized non-production deployment.

