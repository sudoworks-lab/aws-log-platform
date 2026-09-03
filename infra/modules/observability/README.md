# observability

Owns the OSIS CloudWatch log group and alarms whose metric names are verified in AWS documentation: ingestion queue age, visible DLQ messages, S3 source SQS-message failures, and OpenSearch sink document errors.

It intentionally does not guess workload thresholds for OSIS buffers/capacity or OpenSearch Serverless capacity and latency. Those monitoring requirements are recorded in `docs/operations.md` for calibration during an authorized runtime exercise.

Alarm action ARNs are inputs. This module does not create Slack, incident automation, or an SNS topic.

