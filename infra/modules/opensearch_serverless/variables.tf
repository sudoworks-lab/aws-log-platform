variable "collection_name" {
  description = "Name of the OpenSearch Serverless time-series collection."
  type        = string

  validation {
    condition     = length(var.collection_name) <= 20 && can(regex("^[a-z][a-z0-9-]{2,19}$", var.collection_name))
    error_message = "collection_name must be 3-20 lowercase alphanumeric/hyphen characters and start with a letter."
  }
}

variable "pipeline_role_arn" {
  description = "IAM role ARN granted write-only data access for ingestion."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.pipeline_role_arn))
    error_message = "pipeline_role_arn must be an IAM role ARN."
  }
}

variable "reader_principal_arns" {
  description = "IAM or SAML principal ARNs granted read-only collection/index data access."
  type        = set(string)

  validation {
    condition     = length(var.reader_principal_arns) > 0 && alltrue([for arn in var.reader_principal_arns : can(regex("^arn:[^:]+:(iam|aoss):", arn))])
    error_message = "At least one IAM or OpenSearch Serverless SAML reader principal ARN is required."
  }
}

variable "vpc_id" {
  description = "VPC containing the private Serverless endpoint for search users."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must look like an AWS VPC ID."
  }
}

variable "subnet_ids" {
  description = "Subnets for the private OpenSearch Serverless-managed endpoint."
  type        = set(string)

  validation {
    condition     = length(var.subnet_ids) > 0 && alltrue([for id in var.subnet_ids : can(regex("^subnet-[0-9a-f]+$", id))])
    error_message = "At least one valid subnet ID is required."
  }
}

variable "security_group_ids" {
  description = "Security groups controlling traffic to the private Serverless endpoint."
  type        = set(string)

  validation {
    condition     = length(var.security_group_ids) > 0 && alltrue([for id in var.security_group_ids : can(regex("^sg-[0-9a-f]+$", id))])
    error_message = "At least one valid security group ID is required."
  }
}

variable "hot_retention_days" {
  description = "Minimum hot document retention in the time-series collection."
  type        = number
  default     = 30

  validation {
    condition     = var.hot_retention_days >= 1 && var.hot_retention_days <= 3650 && floor(var.hot_retention_days) == var.hot_retention_days
    error_message = "hot_retention_days must be a whole number from 1 through 3650."
  }
}

variable "standby_replicas" {
  description = "Whether Serverless standby replicas are enabled."
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.standby_replicas)
    error_message = "standby_replicas must be ENABLED or DISABLED."
  }
}

variable "tags" {
  description = "Tags applied to supported Serverless resources."
  type        = map(string)
  default     = {}
}

