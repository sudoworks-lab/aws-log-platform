# Migration from a 2022-style design

The earlier architecture was a valuable way to learn the underlying mechanics: Fluentd collected data, multiple Firehose delivery streams moved it, Lambda filled transport or notification gaps, OpenSearch served queries, S3 retained selected output, and CloudWatch alarms triggered Slack notifications. That work built practical understanding of batching, retries, formats, permissions, and operational failure.

The 2026 design uses that understanding to move undifferentiated runtime responsibilities to managed services while keeping the important platform decisions explicit.

| Comparison | 2022-style design | 2026 reference design |
| --- | --- | --- |
| Durability | Search delivery and archive delivery could be parallel or downstream concerns | Raw S3 object is written first and is canonical |
| Search tier | OpenSearch often looked like the primary destination | OpenSearch Serverless is a time-bounded, rebuildable projection |
| Ingestion ownership | Fluentd, Firehose, and Lambda shared transport behavior | OpenSearch Ingestion owns the managed runtime; platform code owns its declarative pipeline |
| Retry and backpressure | Distributed across agents, streams, Lambda, and service retries | SQS is the explicit buffer with age, visibility, retry, and DLQ semantics |
| IaC module design | Similar Firehose modules could be copied for each stream | Modules follow lifecycle and security boundaries; variation is expressed as inputs |
| Environment isolation | Terraform Workspace could be the main boundary | Dev and prod have separate roots, state keys, accounts, permissions, and lifecycle inputs |
| IAM | Broad service actions were expedient while integration boundaries evolved | Source prefix, queue, collection, index, and principal are restricted wherever AWS supports it |
| Secret handling | Long-lived credentials or Terraform values could enter delivery configuration | Workload roles and external credential resolution are expected; no secret is stored in source |
| Lifecycle | Archive behavior could follow delivery-stream implementation | S3 and search retention are independent first-class policies |
| Observability | Component alarms and Slack delivery were tightly coupled | Platform health signals are defined separately from notification integrations |
| Recovery | Search restoration could depend on downstream backups or ad hoc replay | S3 inventory/time ranges are the basis for controlled index rebuilds |

This is not a claim that the older architecture was wrong for its time. The change is one of responsibility placement. After learning and operating the mechanics directly, the current design deliberately delegates scaling, buffering runtime, patching, and retry execution to AWS, while retaining schema, lifecycle, access, monitoring, failure semantics, and recovery as platform engineering responsibilities.

