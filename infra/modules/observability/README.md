# observability

Owns the OSIS CloudWatch log group and alarms whose metric names are verified in AWS documentation: ingestion queue age, visible source-DLQ messages, S3 source SQS-message failures, canonical S3 object-read failures, event-date match failures, OpenSearch sink document errors, and S3 sink-DLQ write failures.

A sink-DLQ write failure is high severity because both search indexing and the document-level failure-preservation path failed. No parse-JSON-specific alarm is synthesized because AWS does not document a stable OSIS metric name for that processor failure.

It intentionally does not guess workload thresholds for OSIS buffers/capacity or OpenSearch Serverless capacity and latency. Those monitoring requirements are recorded in `docs/operations.md` for calibration during an authorized runtime exercise.

Alarm action ARNs are inputs. This module does not create Slack, incident automation, or an SNS topic.
