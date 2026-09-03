data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["osis-pipelines.amazonaws.com"]
    }
  }
}

locals {
  archive_partition = split(":", var.archive_bucket_arn)[1]
  queue_region      = split(":", var.queue_arn)[3]
  queue_account_id  = split(":", var.queue_arn)[4]
  collection_arn    = "arn:${local.archive_partition}:aoss:${local.queue_region}:${local.queue_account_id}:collection/*"
}

resource "aws_iam_role" "pipeline" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "pipeline" {
  statement {
    sid    = "ReadArchivePrefix"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = ["${var.archive_bucket_arn}/${var.archive_object_prefix}*"]
  }

  statement {
    sid    = "LocateArchiveBucket"
    effect = "Allow"

    actions   = ["s3:GetBucketLocation"]
    resources = [var.archive_bucket_arn]
  }

  statement {
    sid    = "ListArchivePrefix"
    effect = "Allow"

    actions   = ["s3:ListBucket"]
    resources = [var.archive_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.archive_object_prefix}*"]
    }
  }

  statement {
    sid    = "ValidateArchiveBucketOwnership"
    effect = "Allow"

    # The OSIS S3 source uses this API for bucket ownership validation. AWS
    # defines ListAllMyBuckets without resource-level permissions.
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    sid    = "ConsumeExactQueue"
    effect = "Allow"

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:ReceiveMessage",
    ]

    resources = [var.queue_arn]
  }

  statement {
    sid    = "WriteTargetCollection"
    effect = "Allow"

    actions   = ["aoss:APIAccessAll"]
    resources = [local.collection_arn]

    condition {
      test     = "StringEquals"
      variable = "aoss:collection"
      values   = [var.collection_name]
    }
  }

  statement {
    sid    = "ManageOSISPrivateLinkNetworkPolicy"
    effect = "Allow"

    # These control-plane APIs do not support resource ARNs. The collection
    # condition and exact action list are the available least-privilege bounds.
    actions = [
      "aoss:BatchGetCollection",
      "aoss:CreateSecurityPolicy",
      "aoss:GetSecurityPolicy",
      "aoss:UpdateSecurityPolicy",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aoss:collection"
      values   = [var.collection_name]
    }
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "${var.role_name}-least-privilege"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}
