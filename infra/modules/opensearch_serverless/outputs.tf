output "collection_name" {
  description = "OpenSearch Serverless collection name."
  value       = aws_opensearchserverless_collection.logs.name
}

output "collection_arn" {
  description = "OpenSearch Serverless collection ARN."
  value       = aws_opensearchserverless_collection.logs.arn
}

output "collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint."
  value       = aws_opensearchserverless_collection.logs.collection_endpoint
}

output "index_name" {
  description = "Terraform-managed OpenSearch Serverless index name."
  value       = awscc_opensearchserverless_collection_index.logs.index_name
}

output "provisioning_public_access_enabled" {
  description = "Whether the temporary exact-collection public network policy is enabled. False is the canonical steady state."
  value       = var.provisioning_public_access_enabled
}

output "provisioning_public_policy_name" {
  description = "Reserved name of the temporary public network policy; the policy exists only when provisioning_public_access_enabled is true."
  value       = local.provisioning_public_policy_name
}

output "dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint."
  value       = aws_opensearchserverless_collection.logs.dashboard_endpoint
}

output "search_vpc_endpoint_id" {
  description = "Terraform-managed OpenSearch Serverless VPC endpoint ID."
  value       = aws_opensearchserverless_vpc_endpoint.search.id
}
