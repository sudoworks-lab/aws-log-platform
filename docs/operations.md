# Operations and failure handling

This repository does not automate incidents. It records the signals and recovery intent that a production implementation must turn into runbooks, ownership, paging policy, and tested automation.

## Implemented signals

The observability module creates alarms for:

- `AWS/SQS` `ApproximateAgeOfOldestMessage` on the ingestion queue.
- `AWS/SQS` `ApproximateNumberOfMessagesVisible` on the DLQ.
- `AWS/OSIS` `<sub-pipeline>.s3.sqsMessagesFailed.count`.
- `AWS/OSIS` `<sub-pipeline>.opensearch.documentErrors.count`.

It also creates the required `/aws/vendedlogs/OpenSearchIngestion/...` CloudWatch log group and enables pipeline logging. Alarm actions are optional ARN inputs; no Slack or notification integration is created.

## Monitoring requirements not encoded as alarms

The following require workload-specific baselines or additional confirmation during an authorized deployment, so Terraform does not guess thresholds or metric names:

- OSIS compute-unit saturation, buffer utilization, throughput, and throttling.
- OpenSearch Serverless indexing/search latency, OCU capacity, throttling, and cost.
- S3 notification delivery failures and expected object-to-queue arrival latency.
- Search correctness checks using a synthetic object and a known query.
- Archive age, lifecycle transition completion, restore duration, and restore cost.

## Failure scenarios

### Malformed log

The JSON processor logs parse failures and sends the original event onward with its raw `message` field preserved. Inspect pipeline logs and the source object, correct the producer schema, and decide whether to replay the whole object to a quarantine pipeline. Do not edit or delete the canonical raw object.

An object-level read or processing failure leaves the SQS message available for retry and can eventually move it to the DLQ. A malformed individual line is different from an unreadable object and may not cause queue redrive.

### S3 event delivery problem

Compare recently created objects under the raw prefix with SQS receive activity. Verify notification prefix, queue policy `aws:SourceArn` and `aws:SourceAccount`, and S3 notification configuration. Once repaired, generate a controlled inventory of missing object keys and replay notifications; never assume notification repair backfills old events.

### SQS backlog

Use oldest-message age to distinguish a growing backlog from a harmless burst. Check pipeline state, OSIS compute units, S3 read errors, sink errors, and collection availability. Increase capacity only after identifying the bottleneck. Raw data remains safe in S3 even if messages expire, but lost queue notifications require inventory-based replay.

### Poison message

Inspect the DLQ message metadata without changing the referenced S3 object. Determine whether the failure is object format, permissions, missing object/version, or a transient service condition. Fix the cause, then redrive a bounded set and watch both queue age and OSIS errors. Repeated redrive without a fix creates noise and cost.

### Ingestion pipeline unavailable

Search freshness degrades and queue age grows. Restore the pipeline or create an explicitly reviewed replacement using the same S3/SQS contract. Do not bypass S3 by writing producers directly to OpenSearch as an incident shortcut.

### OpenSearch unavailable

The pipeline retries and the queue buffers within its retention period. Investigate collection network policy, data access policy, IAM role, OSIS service-managed network policy, quotas, and regional health. Search is unavailable; the log archive is not lost.

### Accidental search-index deletion

Stop uncontrolled replay, define the affected S3 key/time range, recreate index mappings or templates, and feed those objects through a separate bounded replay queue or scheduled scan. Expect duplicates unless the schema and collection type provide a stable idempotency key. Validate counts and representative queries before declaring recovery.

### Archive restoration

Deep Archive objects require an S3 restore request and time. Restore only the required prefix/time partitions, monitor completion and cost, then replay restored objects. Versioning can recover overwritten or deleted current objects when a retained noncurrent version exists. Archive restoration is a data-recovery procedure, not an OpenSearch snapshot restore.

## Recovery objectives to decide before production

- Maximum acceptable time from S3 write to searchability.
- SQS and DLQ retention relative to the maximum tolerated outage.
- Hot-search retention and expected daily indexed volume.
- Raw archive legal/compliance retention and permitted deletion process.
- Replay throughput, duplicate tolerance, and cost guardrails.
- Named owners for producer schema, archive, ingestion, search, and incident command.

