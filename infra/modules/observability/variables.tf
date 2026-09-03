variable "name_prefix" {
  description = "Prefix for log group and alarm names."
  type        = string

  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 40 && can(regex("^[a-z][a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must be 3-40 lowercase alphanumeric/hyphen characters."
  }
}

variable "pipeline_name" {
  description = "OpenSearch Ingestion pipeline name used as the CloudWatch dimension."
  type        = string
}

variable "sub_pipeline_name" {
  description = "Data Prepper sub-pipeline name used in OSIS metric names."
  type        = string
}

variable "queue_name" {
  description = "SQS ingestion queue name used as the CloudWatch dimension."
  type        = string
}

variable "dlq_name" {
  description = "SQS dead-letter queue name used as the CloudWatch dimension."
  type        = string
}

variable "queue_age_threshold_seconds" {
  description = "Oldest ingestion message age that indicates delayed searchability."
  type        = number
  default     = 900

  validation {
    condition     = var.queue_age_threshold_seconds >= 60
    error_message = "queue_age_threshold_seconds must be at least 60 seconds."
  }
}

variable "dlq_message_threshold" {
  description = "Visible DLQ messages that trigger an alarm."
  type        = number
  default     = 0

  validation {
    condition     = var.dlq_message_threshold >= 0
    error_message = "dlq_message_threshold cannot be negative."
  }
}

variable "log_retention_days" {
  description = "CloudWatch retention for OpenSearch Ingestion runtime logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs-supported retention value."
  }
}

variable "alarm_action_arns" {
  description = "Optional SNS or other CloudWatch alarm action ARNs; no notification integration is created."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.alarm_action_arns : startswith(arn, "arn:")])
    error_message = "Every alarm action must be an ARN."
  }
}

variable "tags" {
  description = "Tags applied to the pipeline log group."
  type        = map(string)
  default     = {}
}

