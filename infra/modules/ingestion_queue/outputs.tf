output "queue_name" {
  description = "Ingestion queue name."
  value       = aws_sqs_queue.ingestion.name
}

output "queue_url" {
  description = "Ingestion queue URL consumed by OpenSearch Ingestion."
  value       = aws_sqs_queue.ingestion.id
}

output "queue_arn" {
  description = "Ingestion queue ARN."
  value       = aws_sqs_queue.ingestion.arn
}

output "dlq_name" {
  description = "Dead-letter queue name."
  value       = aws_sqs_queue.dlq.name
}

output "dlq_arn" {
  description = "Dead-letter queue ARN."
  value       = aws_sqs_queue.dlq.arn
}

