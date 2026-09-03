output "role_name" {
  description = "OpenSearch Ingestion pipeline role name."
  value       = aws_iam_role.pipeline.name
}

output "role_arn" {
  description = "OpenSearch Ingestion pipeline role ARN."
  value       = aws_iam_role.pipeline.arn
}

