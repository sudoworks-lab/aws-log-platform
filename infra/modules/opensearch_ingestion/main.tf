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
            queue_url          = var.queue_url
            visibility_timeout = "${var.queue_visibility_timeout_seconds}s"
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
            source        = "message"
            delete_source = true
          }
        },
        {
          date = {
            from_time_received = true
            destination        = "@timestamp"
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
            hosts = [var.collection_endpoint]
            index = var.index_name
            aws = {
              region       = var.region
              sts_role_arn = var.pipeline_role_arn
              serverless   = true
              serverless_options = {
                network_policy_name = var.network_policy_name
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

  buffer_options {
    persistent_buffer_enabled = var.persistent_buffer_enabled
  }

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

