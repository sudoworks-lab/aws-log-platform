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

variable "reader_principals" {
  description = "IAM role/user ARNs or OpenSearch Serverless SAML identities granted read-only data access."
  type        = set(string)

  validation {
    condition = length(var.reader_principals) > 0 && alltrue([
      for principal in var.reader_principals :
      can(regex("^arn:[^:]+:iam::${try(split(":", var.pipeline_role_arn)[4], "")}:(role|user)/.+$", principal)) ||
      can(regex("^saml/${try(split(":", var.pipeline_role_arn)[4], "")}/[^/]+/(user|group)/.+$", principal))
    ])
    error_message = "Each reader principal must be an IAM role/user ARN or an AOSS SAML user/group identity in the collection account."
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

variable "search_retention_days" {
  description = "Minimum index data retention in the time-series search collection."
  type        = number
  default     = 30

  validation {
    condition     = var.search_retention_days >= 1 && var.search_retention_days <= 3650 && floor(var.search_retention_days) == var.search_retention_days
    error_message = "search_retention_days must be a whole number from 1 through 3650."
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
