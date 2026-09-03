resource "aws_cloudwatch_log_group" "osis" {
  name              = "/aws/vendedlogs/OpenSearchIngestion/${var.pipeline_name}/audit-logs"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_metric_alarm" "queue_age" {
  alarm_name          = "${var.name_prefix}-ingestion-queue-age"
  alarm_description   = "Search freshness is delayed because the oldest SQS event is too old."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.queue_age_threshold_seconds
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    QueueName = var.queue_name
  }
}

resource "aws_cloudwatch_metric_alarm" "dlq_visible" {
  alarm_name          = "${var.name_prefix}-dlq-visible-messages"
  alarm_description   = "One or more ingestion events require poison-message investigation."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.dlq_message_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    QueueName = var.dlq_name
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_source_failures" {
  alarm_name          = "${var.name_prefix}-osis-s3-source-failures"
  alarm_description   = "OpenSearch Ingestion failed to process one or more SQS messages from the S3 source."
  namespace           = "AWS/OSIS"
  metric_name         = "${var.sub_pipeline_name}.s3.sqsMessagesFailed.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    PipelineName = var.pipeline_name
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_object_failures" {
  alarm_name          = "${var.name_prefix}-osis-s3-object-failures"
  alarm_description   = "OpenSearch Ingestion failed to read one or more canonical S3 objects."
  namespace           = "AWS/OSIS"
  metric_name         = "${var.sub_pipeline_name}.s3.s3ObjectsFailed.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    PipelineName = var.pipeline_name
  }
}

resource "aws_cloudwatch_metric_alarm" "date_match_failures" {
  alarm_name          = "${var.name_prefix}-osis-date-match-failures"
  alarm_description   = "One or more structured records contained an unsupported event timestamp."
  namespace           = "AWS/OSIS"
  metric_name         = "${var.sub_pipeline_name}.date.dateProcessingMatchFailure.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    PipelineName = var.pipeline_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sink_document_errors" {
  alarm_name          = "${var.name_prefix}-osis-document-errors"
  alarm_description   = "OpenSearch rejected one or more documents after ingestion retries."
  namespace           = "AWS/OSIS"
  metric_name         = "${var.sub_pipeline_name}.opensearch.documentErrors.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    PipelineName = var.pipeline_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sink_dlq_write_failures" {
  alarm_name          = "${var.name_prefix}-osis-sink-dlq-write-failures"
  alarm_description   = "HIGH: OpenSearch rejected documents and OSIS also failed to preserve them in the S3 sink DLQ."
  namespace           = "AWS/OSIS"
  metric_name         = "${var.sub_pipeline_name}.opensearch.s3.dlqS3RecordsFailed.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_action_arns

  dimensions = {
    PipelineName = var.pipeline_name
  }
}
