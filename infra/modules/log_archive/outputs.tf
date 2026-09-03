output "bucket_id" {
  description = "Raw archive bucket name."
  value       = aws_s3_bucket.raw.id
}

output "bucket_arn" {
  description = "Raw archive bucket ARN."
  value       = aws_s3_bucket.raw.arn
}

output "object_prefix" {
  description = "Canonical raw log prefix."
  value       = var.object_prefix
}

