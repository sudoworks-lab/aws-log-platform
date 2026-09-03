# Architecture

## System boundary

The core contract begins with a complete object under the S3 raw prefix. Objects contain newline-delimited JSON and may be uncompressed or gzip-compressed. The Data Prepper S3 source uses automatic compression detection and the newline codec, so each line becomes one event before JSON processing.

Producer-specific delivery is outside the Terraform scope. Common adapters include:

- Fluent Bit for host, container, and application log shipping.
- OpenTelemetry Collector where logs already participate in an OpenTelemetry pipeline.
- CloudWatch Logs subscriptions or export workflows for AWS-native log groups.
- Amazon Data Firehose where producer buffering, format conversion, or delivery integrations justify it.

The architecture does not provision these adapters. Each adapter must write the canonical object to S3 before search ingestion begins.

## Data flow

1. A producer adapter writes an immutable NDJSON or gzip NDJSON object under the archive prefix.
2. S3 sends an `ObjectCreated` notification to the standard SQS ingestion queue.
3. OSIS polls SQS, reads the referenced S3 object, decompresses it when necessary, and splits it by newline.
4. The pipeline records source-received time as `ingested_at`, parses each line, derives `@timestamp` from the required occurrence-time `timestamp`, and adds `log_platform` metadata.
5. The OpenSearch sink applies the core index template and writes documents to an AOSS time-series collection. Individual documents that exhaust sink handling go to the S3 sink DLQ.
6. End-to-end acknowledgement deletes the SQS message only after sink acknowledgement. The source never deletes the canonical S3 object.

S3 notifications and SQS standard queues are at-least-once. The source does not rely only on a fixed visibility timeout: visibility duplication protection extends visibility, up to the configured two-hour limit, while a message remains in flight. This reduces duplicate consumers during long object handling but does not provide exact de-duplication. Consumers and investigations must tolerate duplicates.

## Event and timestamp contract

Every valid JSON event must contain these fields:

- `timestamp`: event occurrence time in ISO-8601 format with exactly millisecond precision and a timezone, for example `2026-09-03T10:15:30.123Z`.
- `message`: the application log message.

The pipeline retains `timestamp` and parses the same occurrence time into `@timestamp`. `ingested_at` is produced separately from source event metadata and represents source-received or processing time. It is useful for freshness and lag analysis, but must never be substituted for a missing or invalid occurrence timestamp.

JSON outcomes are explicit:

- Successful parse: parsed fields are added at the event root, the application's `message` remains `message`, and no malformed-JSON marker is added.
- Malformed JSON: the processor sends the event onward instead of stopping the pipeline, the original line remains in `message`, and `log_platform.parse_status` is `malformed_json`. No occurrence time is invented.

A syntactically valid event with a missing or invalid `timestamp` violates the producer contract. It must be investigated as a schema failure; processing time must not be relabeled as event occurrence time.

## Core index template

The core index template sets `dynamic: false` at the mapping root and explicitly lists fields under the `http`, `error`, and `log_platform` objects. `_source` remains enabled. The searchable mapping is deliberately limited to:

| Field | Mapping | Meaning |
| --- | --- | --- |
| `timestamp` | `date` | Required producer occurrence time with milliseconds |
| `@timestamp` | `date` | Parsed occurrence time used by time-based search |
| `ingested_at` | `date` | Source-received or processing time |
| `service` | `keyword` | Producing service |
| `environment` | `keyword` | Producer environment |
| `level` | `keyword` | Log level |
| `message` | `text` | Application message, or raw line when JSON is malformed |
| `trace_id` | `keyword` | Trace correlation identifier |
| `tags` | `keyword` | Processor tags, including the JSON parse-failure tag |
| `http.method` | `keyword` | HTTP method |
| `http.route` | `keyword` | Normalized route |
| `http.status_code` | `integer` | HTTP response status |
| `http.duration_ms` | `long` | HTTP duration in milliseconds |
| `error.type` | `keyword` | Error classification |
| `error.retryable` | `boolean` | Whether the producer considers the error retryable |
| `log_platform.environment` | `keyword` | Platform-owned environment marker |
| `log_platform.ingested_by` | `keyword` | Platform-owned ingestion implementation marker |
| `log_platform.parse_status` | `keyword` | Explicit `malformed_json` failure marker |

Unknown root or object fields remain in `_source` but are not indexed because dynamic mapping is disabled. Making an unknown field searchable requires schema review, an explicit mapping update, and replay or reindexing where historical search is required.

The ingestion principal receives collection-level `aoss:CreateCollectionItems`, `aoss:UpdateCollectionItems`, and `aoss:DescribeCollectionItems` so it can create, update, and describe index templates. It does not receive `aoss:DeleteCollectionItems`. Index-level create, update, describe, and write permissions remain separate and exclude index and document deletion.

## Failure boundaries

The architecture has two DLQs with different units of failure:

| Boundary | Store | Failure unit | Recovery source |
| --- | --- | --- | --- |
| S3 source and SQS | SQS source DLQ | S3 object/event message after repeated source processing failures | Referenced canonical S3 object |
| OpenSearch sink | S3 sink DLQ | Individual document rejected after sink handling | Sink-DLQ record plus canonical S3 object |

With end-to-end acknowledgement enabled, a document rejected by the OpenSearch sink is acknowledged after it is preserved in the S3 sink DLQ. One poison document therefore does not force its whole S3 object into permanent reprocessing.

Failure to write a failed individual document to the S3 sink DLQ is high severity because both search indexing and the immediate per-document failure record are unavailable. It is not canonical raw loss while the original S3 object remains recoverable.

## Responsibility boundaries

| Component | Owns | Does not own |
| --- | --- | --- |
| Producer adapter | batching, object naming, required timestamp and NDJSON schema, successful S3 write | search availability |
| S3 raw archive | canonical raw retention, encryption, lifecycle, object versions | parsing or indexing |
| SQS and source DLQ | burst absorption, retry visibility, object/event redrive | canonical log contents or individual sink failures |
| OSIS | polling, visibility extension, decompression, parsing runtime, sink retries and sink-DLQ delivery | canonical retention or schema governance |
| AOSS | bounded search capacity and index storage | the only copy of a log |
| Platform operations | schema, index template, access, alarms, replay, capacity and cost review | application instrumentation |

## Network model

Search and Dashboards are reachable only through an AOSS-managed VPC endpoint supplied with VPC, subnet, and security group inputs. Data access policies remain a separate authorization layer.

OSIS creates a service-managed PrivateLink endpoint to a private Serverless collection. AWS requires the pipeline to name a network policy that it can create or update with that endpoint. To avoid competing owners of the same JSON policy, the ingestion policy name is reserved for OSIS and is not also managed by an `aws_opensearchserverless_security_policy` resource. The human/search VPC policy remains Terraform-managed.

## Lifecycle model

The archive and search projection have independent lifecycles:

- S3 transitions raw objects from Standard to Standard-IA and then Deep Archive. Expiration is off by default.
- `search_retention_days` configures the minimum AOSS time-series retention period. This retention policy does not expose or control hot/warm placement.
- Rehydration restores archived S3 objects when required, then republishes object events or a controlled replay manifest to a queue.

## Capacity and buffering

The OSIS persistent buffer is not configured; the pipeline uses its default in-memory buffer. S3 stores canonical objects and SQS supplies the durable retry boundary, so another durability layer is not part of this contract. Future enablement requires a design for additional buffer OCUs, KMS key ownership and IAM permissions, buffer recovery expectations, and cost. It must not weaken S3 retention or remove SQS replay.

Production sets the OSIS minimum to 2 OCUs, which distributes active ingestion OCUs across 2 Availability Zones. Development uses a 1 OCU minimum as an explicit cost tradeoff. These are starting bounds, not throughput guarantees: tune minimum and maximum OCUs using measured event volume, processor cost, backlog behavior, cost, and the search-freshness SLO.

## Module boundaries

Modules represent a lifecycle, owner, security boundary, or reuse point:

- `log_archive`: canonical raw bucket and archive controls.
- `ingestion_queue`: ingestion queue, SQS source DLQ, encryption, redrive, and S3 sender policy.
- `ingestion_identity`: the OSIS role joining source, S3 sink DLQ, template, and index permission boundaries.
- `opensearch_serverless`: collection, encryption, private search network, data access, and search retention.
- `opensearch_ingestion`: pipeline configuration, visibility protection, parsing, core template, S3 sink DLQ, and managed runtime.
- `observability`: pipeline log destination and alarms based only on documented AWS metric names.

The separate identity module avoids a dependency cycle between the collection data policy and the pipeline while keeping IAM consistent across environment roots.
