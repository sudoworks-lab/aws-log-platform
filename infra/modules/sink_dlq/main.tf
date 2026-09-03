resource "aws_s3_bucket" "sink_dlq" {
  bucket        = var.bucket_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "sink_dlq" {
  bucket = aws_s3_bucket.sink_dlq.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "sink_dlq" {
  bucket = aws_s3_bucket.sink_dlq.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sink_dlq" {
  bucket = aws_s3_bucket.sink_dlq.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "sink_dlq" {
  bucket = aws_s3_bucket.sink_dlq.id

  rule {
    id     = "expire-sink-failures"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }
  }
}

resource "aws_s3_bucket_policy" "sink_dlq" {
  bucket = aws_s3_bucket.sink_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"

        # This wildcard is in an explicit Deny. It grants nothing and ensures
        # every current and future S3 operation on this bucket requires TLS.
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.sink_dlq.arn,
          "${aws_s3_bucket.sink_dlq.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.sink_dlq]
}
