# Operations and failure handling

This repository does not automate incidents. It defines the signals and recovery intent that an authorized deployment must turn into runbooks, ownership, paging policy, and tested automation.

## Observability contract

Use only metric names published in the AWS service documentation. The alarm contract is:

- `AWS/SQS` `ApproximateAgeOfOldestMessage` for delayed searchability on the ingestion queue.
- `AWS/SQS` `ApproximateNumberOfMessagesVisible` for messages in the SQS source DLQ.
- `AWS/OSIS` `<sub-pipeline>.s3.sqsMessagesFailed.count` for S3-source SQS message parsing failures.
- `AWS/OSIS` `<sub-pipeline>.s3.s3ObjectsFailed.count` for canonical S3 object-read failures.
- `AWS/OSIS` `<sub-pipeline>.date.dateProcessingMatchFailure.count` for occurrence timestamps that do not match the required pattern.
- `AWS/OSIS` `<sub-pipeline>.opensearch.documentErrors.count` for documents that the OpenSearch sink failed to send.
- `AWS/OSIS` `<sub-pipeline>.opensearch.s3.dlqS3RecordsFailed.count` for failure to preserve rejected documents in the S3 sink DLQ. This signal is high severity.

OSIS metrics use the `PipelineName` dimension. SQS metrics use the applicable `QueueName`. Pipeline logging goes to the required `/aws/vendedlogs/OpenSearchIngestion/...` CloudWatch log group. Alarm actions are optional pre-existing ARN inputs; no notification integration is created here.

The source SQS DLQ alarm and the sink S3 DLQ alarms must not be conflated. The former reports repeatedly failing object/event messages. The latter reports failure to preserve individual documents already rejected by the OpenSearch sink.

## Monitoring requirements that need runtime calibration

The following require workload baselines or an authorized runtime exercise; do not invent metric names or thresholds for them:

- OSIS OCU utilization, throughput, scaling, and throttling.
- AOSS indexing/search latency, capacity, throttling, and cost.
- S3 notification delivery and expected object-to-queue latency.
- Visibility extension failures and duplicate-rate impact.
- JSON parse-status counts and representative search correctness checks.
- Archive lifecycle completion, restore duration, and restore cost.

Development starts at 1 ingestion OCU to reduce cost. Production requires a minimum of 2 ingestion OCUs for 2-AZ distribution. Tune minimum and maximum capacity against measured throughput, cost, queue age, and the search-freshness SLO; no fixed setting is a throughput guarantee.

The persistent buffer is not configured because S3 plus SQS are the durability boundary; OSIS uses its default in-memory buffer. Enabling persistent buffering later requires a reviewed OCU, KMS, recovery, and cost design.

## AOSS index lifecycle procedure

Private-only is the canonical steady state, expressed by `provisioning_public_access_enabled = false` in both live roots and their example tfvars. The temporary exception is necessary only for the Terraform-managed AWSCC index lifecycle. It exposes the exact collection at the network layer, never Dashboards, and does not change IAM or AOSS data access authorization.

Initialize the explicitly selected live root with its intended backend before using the helper. The helper does not initialize or reconfigure a backend, so existing backend and state boundaries remain intact. Pass shared Terraform options after `--` using `-option=value` form; for example:

```bash
terraform -chdir=infra/live/dev init -backend-config=backend.hcl
./scripts/aoss-index-lifecycle.sh apply --root infra/live/dev -- -var-file=terraform.tfvars
```

The `apply` mode is the canonical Create/Update sequence:

1. Apply with `provisioning_public_access_enabled = true`. Terraform creates the exact-collection public policy before creating or updating the AWSCC index.
2. Only if phase 1 succeeds, apply the same configuration and caller options with `provisioning_public_access_enabled = false`.
3. Confirm the helper reports private-only steady state. The root output `aoss_provisioning_public_access_enabled` must be `false`; `aoss_provisioning_public_policy_name` reports the reserved policy name for investigation.

The `destroy` mode is the canonical deletion sequence:

```bash
./scripts/aoss-index-lifecycle.sh destroy --root infra/live/dev -- -var-file=terraform.tfvars
```

It first applies with the provisioning switch true. Only after that succeeds does it run Terraform destroy with the same true value, so the AWSCC index Delete completes before Terraform removes the temporary policy. Do not make a direct destroy with the false steady-state value the canonical procedure.

The helper uses `set -euo pipefail` and does not continue after a failed phase. It rejects caller overrides of the provisioning variable, targeted operations, saved plans, and refresh-only/destroy flags that could break the two-phase guarantee. It logs phase names but not caller arguments. If the second apply fails, the public exception may remain: correct the failure and rerun `apply`. If destroy fails, retry `destroy` with the helper, or run `apply` to return to private steady state if destruction is abandoned. Any temporary exception left in place outside an active lifecycle operation is a steady-state violation.

## Failure model A–H

### A. raw archive loss

**Classification:** raw loss.

If a producer never completes its S3 write, or a canonical object and every retained version become unrecoverable, the platform has lost raw evidence. Treat this as more severe than search unavailability. Stop downstream replay assumptions, determine the affected object and time range, preserve remaining versions, and use producer-side recovery where available.

If a current object is inaccessible but a retained object or version remains recoverable, use scenario H rather than declaring permanent raw loss. An AOSS document or sink-DLQ record is not a replacement for the canonical raw object.

### B. S3 event/SQS object-processing failure

**Classification:** search delayed; raw data remains in S3.

This category covers missing S3 notifications, an SQS backlog, premature in-flight visibility expiry, source-DLQ messages, and an unavailable OSIS pipeline.

- For notification delivery, compare recently created canonical objects with ingestion-queue receive activity. Verify the notification prefix, queue policy conditions for `aws:SourceArn` and `aws:SourceAccount`, and the bucket notification configuration. Repairing notification delivery does not backfill old events; create a controlled inventory of missing object keys for replay.
- For a backlog, use `ApproximateAgeOfOldestMessage` to distinguish sustained lag from a short burst. Check OSIS state, S3 object-read failures, sink errors, and AOSS availability before changing capacity.
- Visibility duplication protection extends the visibility timeout, up to the configured two-hour limit, while an object/event message remains in flight and end-to-end acknowledgement is pending. This reduces premature redelivery but does not make the standard queue exactly once.
- For a source-DLQ message, inspect its metadata and referenced S3 object without editing the object. Determine whether the failure is the event envelope, object format or compression, permission, missing object/version, or a transient service problem. One source-DLQ message can represent an entire object's events; it is not an individual-document sink DLQ.
- If OSIS is unavailable, restore the pipeline or create an explicitly reviewed replacement using the same S3/SQS contract. Do not bypass S3 by directing producers to AOSS.

After correcting the cause, replay or redrive a bounded object set and monitor queue age, source errors, acknowledgements, and duplicates. If SQS retention expired, derive the missing event set from S3 inventory.

### C. malformed record/schema failure

**Classification:** individual event quality incident; the pipeline continues and the raw S3 object remains canonical.

For malformed JSON, the event continues downstream with the original line in `message` and `log_platform.parse_status = malformed_json`. A successful parse keeps the application's `message` and does not receive that failure marker. Inspect the marker, pipeline logs, and source object, then correct the producer. Do not edit or delete the canonical object.

Every valid event requires an ISO-8601 `timestamp` with milliseconds and a timezone. `timestamp` and `@timestamp` are occurrence time; `ingested_at` is source-received or processing time. Do not substitute `ingested_at` when occurrence time is missing or invalid. Investigate date-match failures and any resulting sink-DLQ records before replay.

Unknown fields remain in `_source` under the core `dynamic: false` mapping but are not searchable. A request to search an unknown field requires schema review, an explicit Terraform-managed index mapping update, and replay or reindexing if historical search is required.

### D. OpenSearch sink rejected document -> S3 sink DLQ

**Classification:** an individual document is not searchable; raw data remains in S3 and the rejection is preserved in the S3 sink DLQ.

`<sub-pipeline>.opensearch.documentErrors.count` identifies documents that the OpenSearch sink could not send after its handling. These individual failures go to the S3 sink DLQ, not the SQS source DLQ. Inspect the rejection status, mapping compatibility, index permissions, sink-DLQ record, and canonical source line. Correct the cause and replay a bounded document or source-object set.

Once a rejected document is preserved in the S3 sink DLQ, end-to-end acknowledgement can complete for that failure instead of permanently replaying the entire source object because of one poison document.

### E. sink DLQ write failure

**Classification:** high-severity ingestion incident; an individual document is absent from search and its immediate failure record was not preserved, while raw data remains in S3.

If `<sub-pipeline>.opensearch.s3.dlqS3RecordsFailed.count` is nonzero, page at high severity. Protect the canonical S3 object range, repair sink-DLQ access or availability, identify affected documents from source and pipeline evidence, and perform a controlled replay. Do not classify this as canonical raw loss while the original object remains recoverable.

### F. OpenSearch unavailable

**Classification:** search unavailable; raw data remains in S3.

Investigate AOSS collection state, the private network policy, data access policy, pipeline IAM, the OSIS-managed network policy, quotas, and regional health. SQS buffers object notifications within its retention period while search delivery is blocked. When service recovers, monitor sink errors, queue age, and search freshness. Do not bypass the canonical S3 path.

`search_retention_days` governs the time-series search-retention policy only. It does not control hot/warm placement and does not change raw S3 retention.

### G. search index deletion/rebuild

**Classification:** search unavailable for the deleted range; raw data remains in S3.

Stop uncontrolled replay, restore the Terraform-managed `logs` index and mapping, define the affected S3 key and time range, and replay through a separate bounded queue or reviewed scan. Expect duplicates because the search projection is at-least-once. Validate document counts, occurrence-time ranges, malformed-record markers, and representative queries before declaring the search projection rebuilt.

### H. archive restore/replay

**Classification:** raw data is temporarily unavailable for replay, but is not permanently lost while a retained object or version is recoverable; search remains unavailable or incomplete for the affected range.

Deep Archive objects require an S3 restore before OSIS can read them. Restore only the required prefix and time partitions, monitor completion and cost, and then replay restored objects through a bounded queue or reviewed scan. Versioning can recover an overwritten or deleted current object when a retained noncurrent version exists. Validate the restored object set before replay and apply the same duplicate and search-correctness checks as scenario G.

Archive restore/replay is a canonical-data recovery workflow, not an OpenSearch snapshot restore. If no retained source can be recovered, reclassify the incident as scenario A.

## Recovery objectives to decide before production

- Maximum acceptable time from S3 write to searchability.
- SQS and source-DLQ retention relative to the maximum tolerated outage.
- Search retention and expected daily indexed volume.
- Raw archive legal/compliance retention and permitted deletion process.
- Replay throughput, duplicate tolerance, and cost guardrails.
- Sink-DLQ retention, access, alarm severity, and replay ownership.
- Named owners for producer schema, archive, ingestion, search, identity, and incident command.
