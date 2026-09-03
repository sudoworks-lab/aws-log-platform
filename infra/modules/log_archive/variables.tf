variable "bucket_name" {
  description = "Globally unique name for the raw log archive bucket."
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid 3-63 character S3 bucket name."
  }
}

variable "object_prefix" {
  description = "Prefix containing canonical raw log objects; include a trailing slash."
  type        = string
  default     = "raw/"

  validation {
    condition     = can(regex("^[A-Za-z0-9!_.*'()/-]+/$", var.object_prefix)) && !startswith(var.object_prefix, "/")
    error_message = "object_prefix must be relative, non-empty, and end with a slash."
  }
}

variable "archive_lifecycle" {
  description = "Lifecycle days for current and noncurrent raw objects. Null expiration retains objects indefinitely."
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

  validation {
    condition = (
      var.archive_lifecycle.infrequent_access_days >= 30 &&
      var.archive_lifecycle.archive_days > var.archive_lifecycle.infrequent_access_days &&
      (var.archive_lifecycle.expiration_days == null || var.archive_lifecycle.expiration_days > var.archive_lifecycle.archive_days)
    )
    error_message = "Lifecycle order must be Standard-IA at 30+ days, then Deep Archive, then optional expiration."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete a non-empty archive bucket. Keep false for durable logs."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to archive resources."
  type        = map(string)
  default     = {}
}
