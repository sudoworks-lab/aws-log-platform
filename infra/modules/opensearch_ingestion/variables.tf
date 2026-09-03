variable "pipeline_name" {
  description = "Regional OpenSearch Ingestion pipeline name."
  type        = string

  validation {
    condition     = length(var.pipeline_name) >= 3 && length(var.pipeline_name) <= 28 && can(regex("^[a-z][a-z0-9-]+$", var.pipeline_name))
    error_message = "pipeline_name must be 3-28 lowercase alphanumeric/hyphen characters and start with a letter."
  }
}

variable "sub_pipeline_name" {
  description = "Distinct Data Prepper sub-pipeline name used in metric prefixes."
  type        = string

  validation {
    condition     = length(var.sub_pipeline_name) >= 3 && length(var.sub_pipeline_name) <= 28 && can(regex("^[a-z][a-z0-9-]+$", var.sub_pipeline_name))
    error_message = "sub_pipeline_name must use lowercase alphanumeric characters and hyphens."
  }
}

variable "region" {
  description = "AWS Region shared by SQS, S3 source access, pipeline, and collection."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.region))
    error_message = "region must look like an AWS Region name."
  }
}

variable "environment" {
  description = "Environment value added to every indexed event."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.environment))
    error_message = "environment must be 2-15 lowercase alphanumeric/hyphen characters."
  }
}

variable "queue_url" {
  description = "SQS URL containing S3 event notifications."
  type        = string

  validation {
    condition     = startswith(var.queue_url, "https://sqs.")
    error_message = "queue_url must be an HTTPS Amazon SQS queue URL."
  }
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout applied by the S3 source while processing an object."
  type        = number
  default     = 300

  validation {
    condition     = var.queue_visibility_timeout_seconds >= 30 && var.queue_visibility_timeout_seconds <= 43200
    error_message = "queue_visibility_timeout_seconds must be between 30 and 43200."
  }
}

variable "pipeline_role_arn" {
  description = "Role assumed by OpenSearch Ingestion for source and sink access."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.pipeline_role_arn))
    error_message = "pipeline_role_arn must be an IAM role ARN."
  }
}

variable "collection_endpoint" {
  description = "HTTPS endpoint of the target OpenSearch Serverless collection."
  type        = string

  validation {
    condition     = startswith(var.collection_endpoint, "https://") && strcontains(var.collection_endpoint, ".aoss.amazonaws.com")
    error_message = "collection_endpoint must be an HTTPS OpenSearch Serverless endpoint."
  }
}

variable "index_name" {
  description = "Static index name for the hot log projection."
  type        = string
  default     = "logs"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_-]*$", var.index_name)) && length(var.index_name) <= 255
    error_message = "index_name must be a lowercase OpenSearch index name."
  }
}

variable "network_policy_name" {
  description = "Name reserved for the OSIS-managed collection PrivateLink network policy."
  type        = string

  validation {
    condition     = length(var.network_policy_name) >= 3 && length(var.network_policy_name) <= 32 && can(regex("^[a-z][a-z0-9-]+$", var.network_policy_name))
    error_message = "network_policy_name must match OpenSearch Serverless policy naming rules."
  }
}

variable "cloudwatch_log_group_name" {
  description = "Existing CloudWatch Logs group for OSIS pipeline logs."
  type        = string

  validation {
    condition     = startswith(var.cloudwatch_log_group_name, "/aws/vendedlogs/")
    error_message = "OSIS log groups must use the /aws/vendedlogs/ prefix."
  }
}

variable "min_units" {
  description = "Minimum OpenSearch Ingestion compute units."
  type        = number
  default     = 1

  validation {
    condition     = var.min_units >= 1 && var.min_units <= 96 && floor(var.min_units) == var.min_units
    error_message = "min_units must be a whole number from 1 through 96."
  }
}

variable "max_units" {
  description = "Maximum OpenSearch Ingestion compute units."
  type        = number
  default     = 4

  validation {
    condition     = var.max_units >= 1 && var.max_units <= 96 && floor(var.max_units) == var.max_units
    error_message = "max_units must be a whole number from 1 through 96."
  }
}

variable "persistent_buffer_enabled" {
  description = "Whether to enable OSIS persistent buffering in addition to the durable SQS boundary."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to the OpenSearch Ingestion pipeline."
  type        = map(string)
  default     = {}
}

