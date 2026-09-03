variable "role_name" {
  description = "IAM role name assumed by OpenSearch Ingestion."
  type        = string

  validation {
    condition     = length(var.role_name) <= 64 && can(regex("^[A-Za-z0-9+=,.@_-]+$", var.role_name))
    error_message = "role_name must be a valid IAM role name no longer than 64 characters."
  }
}

variable "archive_bucket_arn" {
  description = "ARN of the canonical raw archive bucket."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:s3:::[^/]+$", var.archive_bucket_arn))
    error_message = "archive_bucket_arn must be an S3 bucket ARN."
  }
}

variable "archive_object_prefix" {
  description = "Only this archive prefix can be read by the pipeline role."
  type        = string

  validation {
    condition     = length(var.archive_object_prefix) > 1 && endswith(var.archive_object_prefix, "/") && !startswith(var.archive_object_prefix, "/")
    error_message = "archive_object_prefix must be relative and end with a slash."
  }
}

variable "queue_arn" {
  description = "Exact ingestion queue ARN consumed by the pipeline role."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:sqs:[^:]+:[0-9]{12}:[A-Za-z0-9_-]+$", var.queue_arn))
    error_message = "queue_arn must be a valid SQS queue ARN."
  }
}

variable "collection_name" {
  description = "Exact OpenSearch Serverless collection name used in IAM conditions."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.collection_name))
    error_message = "collection_name must match OpenSearch Serverless naming rules."
  }
}

variable "tags" {
  description = "Tags applied to the IAM role."
  type        = map(string)
  default     = {}
}

