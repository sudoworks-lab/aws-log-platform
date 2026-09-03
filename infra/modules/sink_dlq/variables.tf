variable "bucket_name" {
  description = "Globally unique name for the OpenSearch sink failure DLQ bucket."
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid 3-63 character S3 bucket name."
  }
}

variable "retention_days" {
  description = "Whole number of days to retain OpenSearch document-level failure objects."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a positive whole number."
  }
}

variable "tags" {
  description = "Tags applied to the sink DLQ bucket."
  type        = map(string)
  default     = {}
}
