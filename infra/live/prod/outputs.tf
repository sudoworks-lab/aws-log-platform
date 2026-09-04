output "raw_archive_bucket" {
  description = "Canonical raw log archive bucket name."
  value       = module.log_archive.bucket_id
}

output "ingestion_queue_url" {
  description = "SQS ingestion queue URL."
  value       = module.ingestion_queue.queue_url
}

output "ingestion_dlq_arn" {
  description = "SQS dead-letter queue ARN."
  value       = module.ingestion_queue.dlq_arn
}

output "sink_dlq_bucket" {
  description = "S3 bucket containing individual OpenSearch sink document failures."
  value       = module.sink_dlq.bucket_id
}

output "opensearch_collection_endpoint" {
  description = "Private OpenSearch Serverless collection endpoint."
  value       = module.opensearch_serverless.collection_endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Private OpenSearch Dashboards endpoint."
  value       = module.opensearch_serverless.dashboard_endpoint
}

output "aoss_provisioning_public_access_enabled" {
  description = "Whether the temporary exact-collection AOSS public network policy is enabled. False is the required steady state."
  value       = module.opensearch_serverless.provisioning_public_access_enabled
}

output "aoss_provisioning_public_policy_name" {
  description = "Reserved name of the temporary AOSS public network policy."
  value       = module.opensearch_serverless.provisioning_public_policy_name
}

output "ingestion_pipeline_arn" {
  description = "OpenSearch Ingestion pipeline ARN."
  value       = module.opensearch_ingestion.pipeline_arn
}
