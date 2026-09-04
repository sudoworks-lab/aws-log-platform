mock_provider "aws" {
  override_during = plan

  mock_resource "aws_opensearchserverless_collection" {
    defaults = {
      id = "abcdefghijklmnop"
    }
  }

  mock_resource "aws_opensearchserverless_vpc_endpoint" {
    defaults = {
      id = "vpce-0123456789abcdef0"
    }
  }
}

mock_provider "awscc" {
  override_during = plan
}

run "renders_default_private_index_schema_access_and_search_retention" {
  command = plan

  variables {
    collection_name             = "platform-dev"
    pipeline_role_arn           = "arn:aws:iam::111122223333:role/platform-osis"
    index_manager_principal_arn = "arn:aws:iam::111122223333:role/terraform-deployer"
    reader_principals = [
      "arn:aws:iam::111122223333:role/log-readers",
      "saml/111122223333/corporate/group/LogReaders",
    ]
    vpc_id                = "vpc-0123456789abcdef0"
    subnet_ids            = ["subnet-0123456789abcdef0"]
    security_group_ids    = ["sg-0123456789abcdef0"]
    search_retention_days = 30
  }

  assert {
    condition = (
      length(aws_opensearchserverless_security_policy.provisioning_public) == 0 &&
      output.provisioning_public_access_enabled == false &&
      output.provisioning_public_policy_name == "platform-dev-provision"
    )
    error_message = "The temporary public policy must be absent by default and report the reserved policy name."
  }

  assert {
    condition = (
      length(jsondecode(aws_opensearchserverless_security_policy.search_network.policy)) == 1 &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].AllowFromPublic == false &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].SourceVPCEs == ["vpce-0123456789abcdef0"] &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules[0].ResourceType == "collection" &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules[0].Resource == ["collection/platform-dev"] &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules[1].ResourceType == "dashboard" &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules[1].Resource == ["collection/platform-dev"]
    )
    error_message = "The default network policy must keep collection and Dashboards access private through the exact VPC endpoint."
  }

  assert {
    condition = (
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Principal[0] == "arn:aws:iam::111122223333:role/terraform-deployer" &&
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Resource[0] == "index/platform-dev/logs" &&
      toset(jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission) == toset([
        "aoss:CreateIndex",
        "aoss:UpdateIndex",
        "aoss:DescribeIndex",
        "aoss:DeleteIndex",
      ])
    )
    error_message = "The Terraform index manager must own the exact logs index lifecycle."
  }

  assert {
    condition = (
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[1].Rules[0].Resource[0] == "index/platform-dev/logs" &&
      toset(jsondecode(aws_opensearchserverless_access_policy.data.policy)[1].Rules[0].Permission) == toset([
        "aoss:CreateIndex",
        "aoss:UpdateIndex",
        "aoss:DescribeIndex",
        "aoss:WriteDocument",
      ])
    )
    error_message = "The OSIS role must have only the documented minimum permissions on the exact logs index."
  }

  assert {
    condition = (
      awscc_opensearchserverless_collection_index.logs.index_name == "logs" &&
      awscc_opensearchserverless_collection_index.logs.collection_index_id == aws_opensearchserverless_collection.logs.id
    )
    error_message = "The logs index must reference the Terraform-managed collection."
  }

  assert {
    condition = (
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.dynamic == false &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties["@timestamp"].type == "date" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.timestamp.type == "date" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.ingested_at.type == "date" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.status_code.type == "integer" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.status_code.coerce == false &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.duration_ms.type == "long" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.duration_ms.coerce == false &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.log_platform.properties.environment.type == "keyword" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.log_platform.properties.ingested_by.type == "keyword" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.log_platform.properties.parse_status.type == "keyword"
    )
    error_message = "The Terraform-managed index must render the timestamp, strict HTTP numeric, and platform metadata mappings."
  }

  assert {
    condition     = jsondecode(aws_opensearchserverless_lifecycle_policy.search.policy).Rules[0].MinIndexRetention == "30d"
    error_message = "Search retention must render as the time-series index data-retention contract."
  }
}

run "renders_exact_collection_provisioning_public_exception" {
  command = plan

  variables {
    collection_name                    = "platform-dev"
    pipeline_role_arn                  = "arn:aws:iam::111122223333:role/platform-osis"
    index_manager_principal_arn        = "arn:aws:iam::111122223333:role/terraform-deployer"
    provisioning_public_access_enabled = true
    reader_principals = [
      "arn:aws:iam::111122223333:role/log-readers",
      "saml/111122223333/corporate/group/LogReaders",
    ]
    vpc_id                = "vpc-0123456789abcdef0"
    subnet_ids            = ["subnet-0123456789abcdef0"]
    security_group_ids    = ["sg-0123456789abcdef0"]
    search_retention_days = 30
  }

  assert {
    condition = (
      length(aws_opensearchserverless_security_policy.provisioning_public) == 1 &&
      aws_opensearchserverless_security_policy.provisioning_public[0].name == "platform-dev-provision" &&
      output.provisioning_public_access_enabled == true &&
      output.provisioning_public_policy_name == "platform-dev-provision"
    )
    error_message = "The provisioning phase must create exactly one explicitly reported temporary public policy."
  }

  assert {
    condition = (
      toset(keys(jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0])) == toset(["AllowFromPublic", "Rules"]) &&
      jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0].AllowFromPublic == true &&
      length(jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0].Rules) == 1 &&
      toset(keys(jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0].Rules[0])) == toset(["Resource", "ResourceType"]) &&
      jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0].Rules[0].ResourceType == "collection" &&
      jsondecode(aws_opensearchserverless_security_policy.provisioning_public[0].policy)[0].Rules[0].Resource == ["collection/platform-dev"]
    )
    error_message = "The temporary policy must expose only the exact collection and must not contain a Dashboards rule."
  }

  assert {
    condition = (
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].AllowFromPublic == false &&
      length(jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules) == 2 &&
      jsondecode(aws_opensearchserverless_security_policy.search_network.policy)[0].Rules[1].ResourceType == "dashboard"
    )
    error_message = "The temporary exception must not replace or widen the private collection and Dashboards policy."
  }

  assert {
    condition = (
      length(jsondecode(aws_opensearchserverless_access_policy.data.policy)) == 3 &&
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Principal == ["arn:aws:iam::111122223333:role/terraform-deployer"] &&
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Resource == ["index/platform-dev/logs"] &&
      toset(jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission) == toset([
        "aoss:CreateIndex",
        "aoss:UpdateIndex",
        "aoss:DescribeIndex",
        "aoss:DeleteIndex",
      ]) &&
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[1].Principal == ["arn:aws:iam::111122223333:role/platform-osis"] &&
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[1].Rules[0].Resource == ["index/platform-dev/logs"] &&
      toset(jsondecode(aws_opensearchserverless_access_policy.data.policy)[1].Rules[0].Permission) == toset([
        "aoss:CreateIndex",
        "aoss:UpdateIndex",
        "aoss:DescribeIndex",
        "aoss:WriteDocument",
      ])
    )
    error_message = "Enabling the network exception must not change the exact-index data access policy."
  }

  assert {
    condition = (
      awscc_opensearchserverless_collection_index.logs.index_name == "logs" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.dynamic == false &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.status_code.type == "integer" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.status_code.coerce == false &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.duration_ms.type == "long" &&
      jsondecode(awscc_opensearchserverless_collection_index.logs.index_schema).mappings.properties.http.properties.duration_ms.coerce == false
    )
    error_message = "The provisioning phase must preserve the Terraform-managed strict index schema."
  }
}

run "rejects_unrelated_aoss_arn_as_reader" {
  command = plan

  variables {
    collection_name             = "platform-dev"
    pipeline_role_arn           = "arn:aws:iam::111122223333:role/platform-osis"
    index_manager_principal_arn = "arn:aws:iam::111122223333:role/terraform-deployer"
    reader_principals           = ["arn:aws:aoss:ap-northeast-1:111122223333:collection/example"]
    vpc_id                      = "vpc-0123456789abcdef0"
    subnet_ids                  = ["subnet-0123456789abcdef0"]
    security_group_ids          = ["sg-0123456789abcdef0"]
  }

  expect_failures = [var.reader_principals]
}

run "rejects_cross_account_reader" {
  command = plan

  variables {
    collection_name             = "platform-dev"
    pipeline_role_arn           = "arn:aws:iam::111122223333:role/platform-osis"
    index_manager_principal_arn = "arn:aws:iam::111122223333:role/terraform-deployer"
    reader_principals           = ["saml/444455556666/corporate/group/LogReaders"]
    vpc_id                      = "vpc-0123456789abcdef0"
    subnet_ids                  = ["subnet-0123456789abcdef0"]
    security_group_ids          = ["sg-0123456789abcdef0"]
  }

  expect_failures = [var.reader_principals]
}
