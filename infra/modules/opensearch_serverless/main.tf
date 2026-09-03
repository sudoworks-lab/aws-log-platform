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
      Description = "OpenSearch Ingestion can write but not read or delete indexes"
      Principal   = [var.pipeline_role_arn]
      Rules = [
        {
          Resource     = ["collection/${var.collection_name}"]
          ResourceType = "collection"
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems",
          ]
        },
        {
          Resource     = ["index/${var.collection_name}/*"]
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
