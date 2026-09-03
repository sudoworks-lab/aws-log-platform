mock_provider "aws" {}

run "enforces_security_and_retention" {
  command = plan

  variables {
    bucket_name    = "platform-test-sink-dlq"
    retention_days = 45
    tags = {
      Environment = "test"
      Purpose     = "opensearch-sink-dlq"
    }
  }

  override_resource {
    target          = aws_s3_bucket.sink_dlq
    override_during = plan
    values = {
      arn = "arn:aws:s3:::platform-test-sink-dlq"
      id  = "platform-test-sink-dlq"
    }
  }

  assert {
    condition     = aws_s3_bucket.sink_dlq.force_destroy == false
    error_message = "The sink DLQ bucket must not allow Terraform to destroy non-empty contents."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.sink_dlq.block_public_acls &&
      aws_s3_bucket_public_access_block.sink_dlq.block_public_policy &&
      aws_s3_bucket_public_access_block.sink_dlq.ignore_public_acls &&
      aws_s3_bucket_public_access_block.sink_dlq.restrict_public_buckets
    )
    error_message = "Every S3 public-access-block control must remain enabled."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.sink_dlq.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "The sink DLQ bucket must enforce bucket-owner ownership."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.sink_dlq.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "The sink DLQ bucket must use SSE-S3 AES256 encryption."
  }

  assert {
    condition = (
      aws_s3_bucket_lifecycle_configuration.sink_dlq.rule[0].status == "Enabled" &&
      aws_s3_bucket_lifecycle_configuration.sink_dlq.rule[0].expiration[0].days == 45
    )
    error_message = "The enabled lifecycle rule must use retention_days for object expiration."
  }

  assert {
    condition = (
      jsondecode(aws_s3_bucket_policy.sink_dlq.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.sink_dlq.policy).Statement[0].Action == "s3:*" &&
      jsondecode(aws_s3_bucket_policy.sink_dlq.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false"
    )
    error_message = "The bucket policy must deny every non-TLS S3 action."
  }

  assert {
    condition = toset(jsondecode(aws_s3_bucket_policy.sink_dlq.policy).Statement[0].Resource) == toset([
      "arn:aws:s3:::platform-test-sink-dlq",
      "arn:aws:s3:::platform-test-sink-dlq/*",
    ])
    error_message = "The TLS deny must cover the sink DLQ bucket and all of its objects."
  }

  assert {
    condition     = aws_s3_bucket.sink_dlq.tags["Purpose"] == "opensearch-sink-dlq"
    error_message = "Caller tags must be applied to the sink DLQ bucket."
  }
}

run "rejects_non_positive_retention" {
  command = plan

  variables {
    bucket_name    = "platform-test-sink-dlq"
    retention_days = 0
  }

  expect_failures = [var.retention_days]
}
