output "pipeline_log_group_name" {
  description = "CloudWatch Logs group configured on the OSIS pipeline."
  value       = aws_cloudwatch_log_group.osis.name
}

output "alarm_names" {
  description = "Created CloudWatch alarm names."
  value = [
    aws_cloudwatch_metric_alarm.queue_age.alarm_name,
    aws_cloudwatch_metric_alarm.dlq_visible.alarm_name,
    aws_cloudwatch_metric_alarm.s3_source_failures.alarm_name,
    aws_cloudwatch_metric_alarm.sink_document_errors.alarm_name,
  ]
}

