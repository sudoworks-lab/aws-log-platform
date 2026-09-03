mock_provider "aws" {}

run "renders_durable_s3_source_contract" {
  command = plan

  variables {
    pipeline_name                    = "reference-ingest"
    sub_pipeline_name                = "reference-logs"
    region                           = "ap-northeast-1"
    environment                      = "dev"
    queue_url                        = "https://sqs.ap-northeast-1.amazonaws.com/111122223333/reference-ingestion"
    queue_visibility_timeout_seconds = 300
    pipeline_role_arn                = "arn:aws:iam::111122223333:role/reference-osis"
    collection_endpoint              = "https://example.ap-northeast-1.aoss.amazonaws.com"
    network_policy_name              = "reference-osis-net"
    cloudwatch_log_group_name        = "/aws/vendedlogs/OpenSearchIngestion/reference-ingest/audit-logs"
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["reference-logs"].source.s3.compression == "automatic"
    error_message = "The S3 source must support both plain and gzip-compressed NDJSON."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["reference-logs"].source.s3.delete_s3_objects_on_read == false
    error_message = "The ingestion pipeline must never delete canonical S3 objects."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["reference-logs"].source.s3.acknowledgments == true
    error_message = "End-to-end acknowledgement must remain enabled."
  }

  assert {
    condition     = yamldecode(output.pipeline_configuration_yaml)["reference-logs"].sink[0].opensearch.aws.serverless_options.network_policy_name == "reference-osis-net"
    error_message = "The sink must name the dedicated OSIS-managed network policy."
  }
}

