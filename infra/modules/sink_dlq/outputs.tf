output "bucket_name" {
  description = "OpenSearch sink DLQ bucket name."
  value       = aws_s3_bucket.sink_dlq.bucket
}

output "bucket_id" {
  description = "OpenSearch sink DLQ bucket ID, equal to its name."
  value       = aws_s3_bucket.sink_dlq.id
}

output "bucket_arn" {
  description = "OpenSearch sink DLQ bucket ARN."
  value       = aws_s3_bucket.sink_dlq.arn
}
