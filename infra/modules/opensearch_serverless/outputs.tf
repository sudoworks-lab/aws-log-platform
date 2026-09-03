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

output "dashboard_endpoint" {
  description = "OpenSearch Dashboards endpoint."
  value       = aws_opensearchserverless_collection.logs.dashboard_endpoint
}

output "search_vpc_endpoint_id" {
  description = "Terraform-managed OpenSearch Serverless VPC endpoint ID."
  value       = aws_opensearchserverless_vpc_endpoint.search.id
}

