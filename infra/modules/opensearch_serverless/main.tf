locals {
  provisioning_public_policy_name = "${var.collection_name}-provision"

  index_schema = {
    mappings = {
      dynamic = false
      properties = {
        "@timestamp" = { type = "date" }
        timestamp    = { type = "date" }
        ingested_at  = { type = "date" }
        service      = { type = "keyword" }
        environment  = { type = "keyword" }
        level        = { type = "keyword" }
        message      = { type = "text" }
        trace_id     = { type = "keyword" }
        tags         = { type = "keyword" }
        http = {
          properties = {
            method      = { type = "keyword" }
            route       = { type = "keyword" }
            status_code = { type = "integer", coerce = false }
            duration_ms = { type = "long", coerce = false }
          }
        }
        error = {
          properties = {
            type      = { type = "keyword" }
            retryable = { type = "boolean" }
          }
        }
        log_platform = {
          properties = {
            environment  = { type = "keyword" }
            ingested_by  = { type = "keyword" }
            parse_status = { type = "keyword" }
          }
        }
      }
    }
  }
}

resource "aws_opensearchserverless_vpc_endpoint" "search" {
  name               = "${var.collection_name}-search"
  vpc_id             = var.vpc_id
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids
}

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.collection_name}-enc"
  type        = "encryption"
  description = "Encryption policy for ${var.collection_name}"

  policy = jsonencode({
    Rules = [
      {
        Resource     = ["collection/${var.collection_name}"]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "search_network" {
  name        = "${var.collection_name}-search"
  type        = "network"
  description = "Private search and Dashboards access for ${var.collection_name}"

  policy = jsonencode([
    {
      Description = "Private access through the Terraform-managed Serverless VPC endpoint"
      Rules = [
        {
          Resource     = ["collection/${var.collection_name}"]
          ResourceType = "collection"
        },
        {
          Resource     = ["collection/${var.collection_name}"]
          ResourceType = "dashboard"
        }
      ]
      AllowFromPublic = false
      SourceVPCEs     = [aws_opensearchserverless_vpc_endpoint.search.id]
    }
  ])
}

resource "aws_opensearchserverless_access_policy" "data" {
  name        = "${var.collection_name}-data"
  type        = "data"
  description = "Separate ingestion writer and investigation reader access"

  policy = jsonencode([
    {
      Description = "Terraform owns the logs index schema lifecycle"
      Principal   = [var.index_manager_principal_arn]
      Rules = [
        {
          Resource     = ["index/${var.collection_name}/${var.index_name}"]
          ResourceType = "index"
          Permission = [
            "aoss:CreateIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:DeleteIndex",
          ]
        }
      ]
    },
    {
      Description = "OpenSearch Ingestion can write but not read or delete indexes"
      Principal   = [var.pipeline_role_arn]
      Rules = [
        {
          Resource     = ["index/${var.collection_name}/${var.index_name}"]
          ResourceType = "index"
          Permission = [
            "aoss:CreateIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:WriteDocument",
          ]
        }
      ]
    },
    {
      Description = "Investigation principals have read-only data access"
      Principal   = sort(tolist(var.reader_principals))
      Rules = [
        {
          Resource     = ["collection/${var.collection_name}"]
          ResourceType = "collection"
          Permission   = ["aoss:DescribeCollectionItems"]
        },
        {
          Resource     = ["index/${var.collection_name}/*"]
          ResourceType = "index"
          Permission = [
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
          ]
        }
      ]
    }
  ])
}

resource "aws_opensearchserverless_lifecycle_policy" "search" {
  name        = "${var.collection_name}-retention"
  type        = "retention"
  description = "Minimum searchable index data retention for ${var.collection_name}"

  policy = jsonencode({
    Rules = [
      {
        Resource          = ["index/${var.collection_name}/*"]
        ResourceType      = "index"
        MinIndexRetention = "${var.search_retention_days}d"
      }
    ]
  })
}

resource "aws_opensearchserverless_collection" "logs" {
  name             = var.collection_name
  type             = "TIMESERIES"
  standby_replicas = var.standby_replicas
  description      = "Rebuildable log search projection; S3 is canonical"
  tags             = var.tags

  depends_on = [
    aws_opensearchserverless_access_policy.data,
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.search_network,
  ]
}

resource "aws_opensearchserverless_security_policy" "provisioning_public" {
  count = var.provisioning_public_access_enabled ? 1 : 0

  name        = local.provisioning_public_policy_name
  type        = "network"
  description = "Temporary index lifecycle access for ${var.collection_name}"

  policy = jsonencode([
    {
      Rules = [
        {
          Resource     = ["collection/${var.collection_name}"]
          ResourceType = "collection"
        }
      ]
      AllowFromPublic = true
    }
  ])

  depends_on = [
    aws_opensearchserverless_access_policy.data,
    aws_opensearchserverless_collection.logs,
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.search_network,
  ]
}

resource "awscc_opensearchserverless_collection_index" "logs" {
  collection_index_id = aws_opensearchserverless_collection.logs.id
  index_name          = var.index_name
  index_schema        = jsonencode(local.index_schema)

  depends_on = [aws_opensearchserverless_security_policy.provisioning_public]
}
