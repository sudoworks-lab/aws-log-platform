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
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "The prod root can manage only the prod environment."
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
  description = "Explicit production AWS account ID; used in resource policies without reading caller credentials."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "vpc_id" {
  description = "Existing production VPC for private search access."
  type        = string
}

variable "subnet_ids" {
  description = "Existing production subnets for the OpenSearch Serverless VPC endpoint."
  type        = set(string)
}

variable "security_group_ids" {
  description = "Existing security groups for the private search endpoint."
  type        = set(string)
}

variable "reader_principals" {
  description = "Production IAM role/user ARNs or OpenSearch Serverless SAML identities granted read-only log data access."
  type        = set(string)

  validation {
    condition = length(var.reader_principals) > 0 && alltrue([
      for principal in var.reader_principals :
      can(regex("^arn:[^:]+:iam::${var.aws_account_id}:(role|user)/.+$", principal)) ||
      can(regex("^saml/${var.aws_account_id}/[^/]+/(user|group)/.+$", principal))
    ])
    error_message = "Each reader principal must be an IAM role/user ARN or an AOSS SAML user/group identity in aws_account_id."
  }
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

variable "search_retention_days" {
  description = "Minimum index data-retention days in the production time-series search collection."
  type        = number
  default     = 30

  validation {
    condition     = var.search_retention_days >= 1 && var.search_retention_days <= 3650 && floor(var.search_retention_days) == var.search_retention_days
    error_message = "search_retention_days must be a whole number from 1 through 3650."
  }
}

variable "sink_dlq_retention_days" {
  description = "Days to retain production OpenSearch sink document failures in the S3 DLQ."
  type        = number
  default     = 90

  validation {
    condition     = var.sink_dlq_retention_days >= 1 && floor(var.sink_dlq_retention_days) == var.sink_dlq_retention_days
    error_message = "sink_dlq_retention_days must be a positive whole number."
  }
}

variable "queue_visibility_timeout_seconds" {
  description = "Shared SQS and S3-source visibility timeout."
  type        = number
  default     = 300
}

variable "queue_message_retention_seconds" {
  description = "Production ingestion queue retention."
  type        = number
  default     = 1209600
}

variable "dlq_message_retention_seconds" {
  description = "Production DLQ retention."
  type        = number
  default     = 1209600
}

variable "queue_age_alarm_seconds" {
  description = "Age at which delayed production searchability alarms."
  type        = number
  default     = 600
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
