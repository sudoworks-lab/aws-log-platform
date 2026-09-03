mock_provider "aws" {}

run "renders_durable_s3_source_contract" {
  command = plan

  variables {
    pipeline_name                    = "platform-ingest"
    sub_pipeline_name                = "platform-logs"
    region                           = "ap-northeast-1"
    environment                      = "dev"
    queue_url                        = "https://sqs.ap-northeast-1.amazonaws.com/111122223333/platform-ingestion"
    queue_visibility_timeout_seconds = 300
    pipeline_role_arn                = "arn:aws:iam::111122223333:role/platform-osis"
    collection_endpoint              = "https://example.ap-northeast-1.aoss.amazonaws.com"
    network_policy_name              = "platform-osis-net"
    sink_dlq_bucket_name             = "platform-dev-111122223333-ap-northeast-1-sink-dlq"
    sink_dlq_key_path_prefix         = "failed-documents/"
    cloudwatch_log_group_name        = "/aws/vendedlogs/OpenSearchIngestion/platform-ingest/audit-logs"
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].source.s3.compression == "automatic"
    error_message = "The S3 source must support both plain and gzip-compressed NDJSON."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].source.s3.delete_s3_objects_on_read == false
    error_message = "The ingestion pipeline must never delete canonical S3 objects."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].source.s3.acknowledgments == true
    error_message = "End-to-end acknowledgement must remain enabled."
  }

  assert {
    condition = (
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[0].parse_json.overwrite_if_destination_exists == true &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[0].parse_json.delete_source == false
    )
    error_message = "Root JSON parsing must retain the source key so the parsed application message survives the root overwrite."
  }

  assert {
    condition     = contains(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[0].parse_json.tags_on_failure, "parse_json_failure")
    error_message = "Malformed JSON must be tagged without stopping the pipeline."
  }

  assert {
    condition = (
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[1].add_entries.entries[0].key == "log_platform/parse_status" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[1].add_entries.entries[0].value == "parsed" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[2].add_entries.add_when == "hasTags(\"parse_json_failure\")" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[2].add_entries.entries[0].key == "log_platform/parse_status" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[2].add_entries.entries[0].value == "malformed_json"
    )
    error_message = "Parsed JSON and malformed raw records must receive distinct parse status markers."
  }

  assert {
    condition = (
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[3].date.match[0].key == "timestamp" &&
      contains(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[3].date.match[0].patterns, "yyyy-MM-dd'T'HH:mm:ss.SSSXXX") &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[3].date.destination == "@timestamp" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[3].date.date_when == "/timestamp != null"
    )
    error_message = "The input timestamp must be conditionally parsed into @timestamp using the documented ISO-8601 pattern."
  }

  assert {
    condition = (
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[4].date.from_time_received == true &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].processor[4].date.destination == "ingested_at"
    )
    error_message = "Source-received time must be stored as ingested_at rather than @timestamp."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].source.s3.sqs.visibility_duplication_protection == true
    error_message = "Long-running object processing must extend SQS visibility while acknowledgements are pending."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].source.s3.sqs.visibility_duplicate_protection_timeout == "7200s"
    error_message = "Visibility duplication protection must render the documented two-hour extension limit."
  }

  assert {
    condition = (
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.dlq.s3.bucket == "platform-dev-111122223333-ap-northeast-1-sink-dlq" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.dlq.s3.key_path_prefix == "failed-documents/" &&
      yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.dlq.s3.sts_role_arn == "arn:aws:iam::111122223333:role/platform-osis"
    )
    error_message = "The OpenSearch sink must render its dedicated S3 document DLQ bucket, prefix, and role."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.aws.serverless_options.network_policy_name == "platform-osis-net"
    error_message = "The sink must name the dedicated OSIS-managed network policy."
  }

  assert {
    condition = (
      jsondecode(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.template_content).template.mappings.properties["@timestamp"].type == "date" &&
      jsondecode(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.template_content).template.mappings.properties.ingested_at.type == "date" &&
      jsondecode(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.template_content).template.mappings.properties.http.properties.status_code.type == "integer"
    )
    error_message = "The core index template must render event, ingestion, and nested HTTP mappings."
  }

  assert {
    condition     = !contains(keys(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch), "index_type")
    error_message = "A Serverless sink that manages an index template must omit index_type to satisfy OSIS validation."
  }

  assert {
    condition     = jsondecode(yamldecode(output.pipeline_configuration_yaml)["platform-logs"].sink[0].opensearch.template_content).template.mappings.dynamic == false
    error_message = "Unknown fields must remain in _source without dynamic mapping expansion."
  }

  assert {
    condition     = length(aws_osis_pipeline.logs.buffer_options) == 0
    error_message = "This design must not render the half-supported OSIS persistent buffer option."
  }
}
