output "pipeline_name" {
  description = "OpenSearch Ingestion pipeline name."
  value       = aws_osis_pipeline.logs.pipeline_name
}

output "pipeline_arn" {
  description = "OpenSearch Ingestion pipeline ARN."
  value       = aws_osis_pipeline.logs.pipeline_arn
}

output "pipeline_configuration_yaml" {
  description = "Rendered pipeline YAML for review; contains resource identifiers but no secrets."
  value       = aws_osis_pipeline.logs.pipeline_configuration_body
}

