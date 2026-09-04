# Migration from a 2022-style design

The earlier architecture was useful for learning the underlying mechanics: Fluentd collected data, multiple Firehose delivery streams moved it, Lambda filled transport or notification gaps, OpenSearch served queries, S3 retained selected output, and CloudWatch alarms triggered Slack notifications. That work exposed batching, retries, formats, permissions, and operational failures directly.

AWS Log Platform moves undifferentiated runtime responsibilities to managed services while keeping the platform contract explicit.

| Comparison | 2022-style design | AWS Log Platform |
| --- | --- | --- |
| Durability | Search delivery and archive delivery could be parallel or downstream concerns | The raw S3 object is written first and remains canonical |
| Search tier | OpenSearch often looked like the primary destination | AOSS is a time-bounded, rebuildable search projection |
| Ingestion ownership | Fluentd, Firehose, and Lambda shared transport behavior | OSIS owns the managed runtime; Terraform owns the AOSS index and schema lifecycle |
| Retry and backpressure | Distributed across agents, streams, Lambda, and service retries | SQS is the explicit object/event buffer with visibility extension, retry, and a source DLQ |
| Failed records | Transport and indexing failures could share one operational path | The SQS source DLQ holds object/event failures; the S3 sink DLQ holds individual rejected documents |
| Event time | Collection and processing time could be used interchangeably | Required millisecond ISO-8601 `timestamp` and `@timestamp` are occurrence time; `ingested_at` is source-received time |
| Parse failure | Malformed payload behavior depended on transport code | Malformed JSON retains the raw `message`, is explicitly marked, and does not stop the pipeline |
| Schema | Dynamic fields could become searchable without a review boundary | Terraform creates the AOSS `logs` index with `dynamic: false`; OSIS runs with index management disabled and unknown fields remain in `_source` until schema review maps them |
| Environment isolation | Terraform Workspace could be the main boundary | Dev and prod use separate roots, state keys, accounts, permissions, and lifecycle inputs |
| IAM and identity | Broad service actions were expedient while integrations evolved | Source prefix, queues, sink-DLQ prefix, templates, indexes, and IAM/SAML reader principals have separate least-privilege rules |
| Search lifecycle | Search storage terminology could imply placement control | `search_retention_days` controls retention only and does not select hot/warm placement |
| Buffering | Additional runtime buffers could be treated as the durability layer | S3 plus SQS are the explicit durability boundary; OSIS persistent buffering is not adopted pending a separate OCU/KMS/cost design |
| Capacity | A single default could be copied across environments | Dev starts at 1 ingestion OCU for cost; prod starts at 2 for 2-AZ distribution, then tunes for throughput, cost, and SLO |
| Observability | Component alarms and Slack delivery were tightly coupled | AWS-documented metric names are kept separate from notification integrations |
| Recovery | Search restoration could depend on downstream backups or ad hoc replay | S3 inventory and time ranges drive controlled reconstruction of the search projection |

This change is about responsibility placement rather than dismissing the earlier architecture. AWS operates the managed ingestion runtime; platform engineering retains occurrence-time semantics, parsing outcomes, index schema governance, archive and search retention, access, monitoring, failure classification, and replay. Managed OSIS with AOSS uses `management_disabled`, so the index mapping is Terraform desired state rather than an OSIS template: ingestion runtime and schema lifecycle remain separate.

The backend examples now use `aws-log-platform/dev/terraform.tfstate` and `aws-log-platform/prod/terraform.tfstate`. If an existing deployment used an older key, do not initialize it as an empty state location; back up the existing state and perform a separately authorized backend state migration before any plan or apply.
