resource "aws_s3_bucket" "raw" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "raw" {
  bucket = aws_s3_bucket.raw.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }

    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "raw" {
  bucket = aws_s3_bucket.raw.id

  rule {
    id     = "raw-log-tiering"
    status = "Enabled"

    filter {
      prefix = var.object_prefix
    }

    transition {
      days          = var.archive_lifecycle.infrequent_access_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.archive_lifecycle.archive_days
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = var.archive_lifecycle.infrequent_access_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = var.archive_lifecycle.archive_days
      storage_class   = "DEEP_ARCHIVE"
    }

    dynamic "expiration" {
      for_each = var.archive_lifecycle.expiration_days == null ? [] : [var.archive_lifecycle.expiration_days]

      content {
        days = expiration.value
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.raw]
}

data "aws_iam_policy_document" "raw" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    # This wildcard is in an explicit Deny. It grants nothing and ensures that
    # every current and future S3 operation on this bucket requires TLS.
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id
  policy = data.aws_iam_policy_document.raw.json

  depends_on = [aws_s3_bucket_public_access_block.raw]
}
