mock_provider "aws" {}

run "uses_documented_osis_metric_names" {
  command = plan

  variables {
    name_prefix       = "log-platform-dev"
    pipeline_name     = "log-platform-dev-ingest"
    sub_pipeline_name = "log-platform-dev-logs"
    queue_name        = "log-platform-dev-ingestion"
    dlq_name          = "log-platform-dev-ingestion-dlq"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.s3_object_failures.metric_name == "log-platform-dev-logs.s3.s3ObjectsFailed.count"
    error_message = "The canonical S3 object-read alarm must use the documented OSIS metric name."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.date_match_failures.metric_name == "log-platform-dev-logs.date.dateProcessingMatchFailure.count"
    error_message = "The event timestamp alarm must use the documented Date processor metric name."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.sink_document_errors.metric_name == "log-platform-dev-logs.opensearch.documentErrors.count"
    error_message = "The rejected-document alarm must use the documented OpenSearch sink metric name."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.sink_dlq_write_failures.metric_name == "log-platform-dev-logs.opensearch.s3.dlqS3RecordsFailed.count"
    error_message = "The sink-DLQ alarm must use the documented S3 DLQ writer metric name."
  }
}
