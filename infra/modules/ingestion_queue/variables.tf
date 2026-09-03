variable "name" {
  description = "Name of the standard ingestion queue."
  type        = string

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 76 && can(regex("^[A-Za-z0-9_-]+$", var.name))
    error_message = "name must leave room for the -dlq suffix and contain only SQS-supported characters."
  }
}

variable "source_bucket_arn" {
  description = "Exact S3 bucket ARN permitted to send event notifications."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:s3:::[^/]+$", var.source_bucket_arn))
    error_message = "source_bucket_arn must be an S3 bucket ARN without an object suffix."
  }
}

variable "source_account_id" {
  description = "AWS account ID that owns the source bucket."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.source_account_id))
    error_message = "source_account_id must contain exactly 12 digits."
  }
}

variable "visibility_timeout_seconds" {
  description = "Seconds a received ingestion message remains invisible."
  type        = number
  default     = 300

  validation {
    condition     = var.visibility_timeout_seconds >= 30 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 30 and 43200."
  }
}

variable "message_retention_seconds" {
  description = "Retention for unprocessed ingestion messages."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 60 seconds and 14 days."
  }
}

variable "dlq_retention_seconds" {
  description = "Retention for messages after redrive to the DLQ."
  type        = number
  default     = 1209600

  validation {
    condition     = var.dlq_retention_seconds >= var.message_retention_seconds && var.dlq_retention_seconds <= 1209600
    error_message = "dlq_retention_seconds must be at least queue retention and no more than 14 days."
  }
}

variable "max_receive_count" {
  description = "Receive attempts before SQS moves a message to the DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "tags" {
  description = "Tags applied to queue resources."
  type        = map(string)
  default     = {}
}

