locals {
  pipeline_configuration = {
    version = "2"
    (var.sub_pipeline_name) = {
      source = {
        s3 = {
          acknowledgments           = true
          notification_type         = "sqs"
          compression               = "automatic"
          delete_s3_objects_on_read = false
          on_error                  = "retain_messages"
          codec                     = { newline = null }
          sqs = {
            queue_url                               = var.queue_url
            visibility_timeout                      = "${var.queue_visibility_timeout_seconds}s"
            visibility_duplication_protection       = true
            visibility_duplicate_protection_timeout = "${var.visibility_duplicate_protection_timeout_seconds}s"
          }
          aws = {
            region       = var.region
            sts_role_arn = var.pipeline_role_arn
          }
        }
      }
      processor = [
        {
          parse_json = {
            source                          = "message"
            overwrite_if_destination_exists = true
            delete_source                   = false
            tags_on_failure                 = ["parse_json_failure"]
          }
        },
        {
          add_entries = {
            entries = [
              {
                key                     = "log_platform/parse_status"
                value                   = "parsed"
                overwrite_if_key_exists = true
              }
            ]
          }
        },
        {
          add_entries = {
            entries = [
              {
                key                     = "log_platform/parse_status"
                value                   = "malformed_json"
                overwrite_if_key_exists = true
                add_when                = "hasTags(\"parse_json_failure\")"
              }
            ]
          }
        },
        {
          date = {
            match = [
              {
                key      = "timestamp"
                patterns = ["yyyy-MM-dd'T'HH:mm:ss.SSSXXX"]
              }
            ]
            destination   = "@timestamp"
            output_format = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX"
            date_when     = "/timestamp != null"
          }
        },
        {
          date = {
            from_time_received = true
            destination        = "ingested_at"
          }
        },
        {
          add_entries = {
            entries = [
              {
                key                     = "log_platform/environment"
                value                   = var.environment
                overwrite_if_key_exists = true
              },
              {
                key                     = "log_platform/ingested_by"
                value                   = "amazon-opensearch-ingestion"
                overwrite_if_key_exists = true
              }
            ]
          }
        }
      ]
      sink = [
        {
          opensearch = {
            hosts      = [var.collection_endpoint]
            index      = var.index_name
            index_type = "management_disabled"
            aws = {
              region       = var.region
              sts_role_arn = var.pipeline_role_arn
              serverless   = true
              serverless_options = {
                network_policy_name = var.network_policy_name
              }
            }
            dlq = {
              s3 = {
                bucket          = var.sink_dlq_bucket_name
                key_path_prefix = var.sink_dlq_key_path_prefix
                region          = var.region
                sts_role_arn    = var.pipeline_role_arn
              }
            }
          }
        }
      ]
    }
  }
}

resource "aws_osis_pipeline" "logs" {
  pipeline_name               = var.pipeline_name
  pipeline_configuration_body = yamlencode(local.pipeline_configuration)
  pipeline_role_arn           = var.pipeline_role_arn
  min_units                   = var.min_units
  max_units                   = var.max_units

  log_publishing_options {
    is_logging_enabled = true

    cloudwatch_log_destination {
      log_group = var.cloudwatch_log_group_name
    }
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.pipeline_name != var.sub_pipeline_name
      error_message = "pipeline_name and sub_pipeline_name must differ so CloudWatch metric names remain unambiguous."
    }

    precondition {
      condition     = var.max_units >= var.min_units
      error_message = "max_units must be greater than or equal to min_units."
    }
  }
}
