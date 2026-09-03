# Architecture

## System boundary

The core contract begins with a complete object under the S3 raw prefix. Objects contain newline-delimited JSON and may be uncompressed or gzip-compressed. The OpenSearch Data Prepper S3 source uses `compression: automatic` and the newline codec, so each line becomes one event before the JSON processor runs.

Producer-specific delivery is outside the Terraform scope. Common adapters include:

- Fluent Bit for host, container, and application log shipping.
- OpenTelemetry Collector where logs already participate in an OpenTelemetry pipeline.
- CloudWatch Logs subscriptions or export workflows for AWS-native log groups.
- Amazon Data Firehose where producer buffering, format conversion, or delivery integrations justify it.

The architecture does not provision all adapters. Adding every transport by default would recreate the ownership and duplication problems this repository is intended to avoid.

## Data flow

1. A producer adapter writes an immutable NDJSON or gzip NDJSON object under the archive prefix.
2. S3 sends an `ObjectCreated` notification to the ingestion SQS queue.
3. OpenSearch Ingestion polls SQS, reads the referenced S3 object, decompresses it when necessary, and splits it by newline.
4. The pipeline parses JSON, adds an ingestion timestamp, and adds platform environment metadata.
5. The OpenSearch sink writes documents to a time-series Serverless collection.
6. End-to-end acknowledgement causes the SQS message to be deleted only after sink acknowledgement. The source never deletes the S3 object.

S3 notifications and SQS standard queues are at-least-once. Consumers and investigations must tolerate duplicates. This reference uses a time-series collection, which does not support custom document IDs, so exact de-duplication is not promised by the search projection. Raw objects remain the authoritative evidence.

## Responsibility boundaries

| Component | Owns | Does not own |
| --- | --- | --- |
| Producer adapter | batching, object naming, NDJSON schema, successful S3 write | search availability |
| S3 archive | durable raw retention, encryption, lifecycle, object versions | parsing or indexing |
| SQS | burst absorption, retry visibility, redrive | durable log contents |
| OpenSearch Ingestion | polling, decompression, parsing runtime, retries, sink delivery | canonical retention or schema governance |
| OpenSearch Serverless | hot search capacity and index storage | the only copy of a log |
| Platform operations | schema contract, access, alarms, replay, capacity and cost review | application instrumentation |

## Network model

Search and Dashboards are reachable only through an OpenSearch Serverless-managed VPC endpoint supplied with VPC, subnet, and security group inputs. Data access policies remain a separate authorization layer.

OpenSearch Ingestion creates a service-managed PrivateLink endpoint to a private Serverless collection. AWS requires the pipeline to name a network policy that it can create or update with that endpoint. To avoid Terraform continually removing the service-added endpoint, the ingestion policy name is reserved for OSIS and is not also managed by an `aws_opensearchserverless_security_policy` resource. The human/search VPC policy remains fully Terraform-managed.

## Lifecycle model

The archive and search tier have independent lifecycles:

- S3 transitions raw objects from Standard to Standard-IA and then Deep Archive. Expiration is off by default.
- OpenSearch Serverless retains hot documents for the configured period. Serverless retention enforcement is best effort, so it is not a precise deletion clock.
- Rehydration restores archived S3 objects when required, then republishes object events or a controlled replay manifest to a queue.

## Module boundaries

Modules are not one-resource wrappers. Each boundary represents a lifecycle, owner, security boundary, or reuse point:

- `log_archive`: raw bucket and all archive controls.
- `ingestion_queue`: ingestion queue, DLQ, encryption, redrive, and S3 sender policy.
- `ingestion_identity`: the single OSIS role joining the source and sink permission boundaries.
- `opensearch_serverless`: collection, encryption, private search network, data access, and hot retention.
- `opensearch_ingestion`: pipeline configuration and managed runtime.
- `observability`: pipeline log destination and alarms based on verified metric names.

The extra identity module avoids a module dependency cycle between the collection data policy and the pipeline while keeping IAM identical across environment roots.

