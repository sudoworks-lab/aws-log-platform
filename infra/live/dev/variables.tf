variable "project_name" {
  description = "Short lowercase name used in globally and regionally scoped resource names."
  type        = string
  default     = "log-platform"

  validation {
    condition     = length(var.project_name) <= 15 && can(regex("^[a-z][a-z0-9-]+$", var.project_name))
    error_message = "project_name must be at most 15 lowercase alphanumeric/hyphen characters."
  }
}

variable "environment" {
  description = "Fixed environment identity for this root."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "The dev root can manage only the dev environment."
  }
}

variable "aws_region" {
  description = "AWS Region for all workload resources."
  type        = string
  default     = "ap-northeast-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must look like an AWS Region name."
  }
}

variable "aws_account_id" {
  description = "Explicit dev AWS account ID; used in resource policies without reading caller credentials."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "vpc_id" {
  description = "Existing dev VPC for private search access."
  type        = string
}

variable "subnet_ids" {
  description = "Existing dev subnets for the OpenSearch Serverless VPC endpoint."
  type        = set(string)
}

variable "security_group_ids" {
  description = "Existing security groups for the private search endpoint."
  type        = set(string)
}

variable "reader_principal_arns" {
  description = "Dev IAM or SAML principals granted read-only log data access."
  type        = set(string)
}

variable "raw_log_prefix" {
  description = "S3 prefix that accepts canonical NDJSON or gzip NDJSON objects."
  type        = string
  default     = "raw/"
}

variable "archive_lifecycle" {
  description = "Raw archive transitions and optional expiration."
  type = object({
    infrequent_access_days = number
    archive_days           = number
    expiration_days        = optional(number)
  })
  default = {
    infrequent_access_days = 30
    archive_days           = 90
    expiration_days        = null
  }
}

variable "hot_retention_days" {
  description = "Minimum days logs remain searchable in the dev time-series collection."
  type        = number
  default     = 7
}

variable "queue_visibility_timeout_seconds" {
  description = "Shared SQS and S3-source visibility timeout."
  type        = number
  default     = 300
}

variable "queue_message_retention_seconds" {
  description = "Dev ingestion queue retention."
  type        = number
  default     = 345600
}

variable "dlq_message_retention_seconds" {
  description = "Dev DLQ retention."
  type        = number
  default     = 1209600
}

variable "queue_age_alarm_seconds" {
  description = "Age at which delayed dev searchability alarms."
  type        = number
  default     = 900
}

variable "alarm_action_arns" {
  description = "Optional pre-existing CloudWatch alarm action ARNs."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags merged into provider default tags."
  type        = map(string)
  default     = {}
}

