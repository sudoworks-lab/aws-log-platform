mock_provider "aws" {}

run "renders_template_permissions_and_search_retention" {
  command = plan

  variables {
    collection_name   = "platform-dev"
    pipeline_role_arn = "arn:aws:iam::111122223333:role/platform-osis"
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
    condition = contains(
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission,
      "aoss:CreateCollectionItems",
      ) && contains(
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission,
      "aoss:UpdateCollectionItems",
      ) && contains(
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission,
      "aoss:DescribeCollectionItems",
      ) && !contains(
      jsondecode(aws_opensearchserverless_access_policy.data.policy)[0].Rules[0].Permission,
      "aoss:DeleteCollectionItems",
    )
    error_message = "The pipeline must manage index templates without delete permission."
  }

  assert {
    condition     = jsondecode(aws_opensearchserverless_lifecycle_policy.search.policy).Rules[0].MinIndexRetention == "30d"
    error_message = "Search retention must render as the time-series index data-retention contract."
  }
}

run "rejects_unrelated_aoss_arn_as_reader" {
  command = plan

  variables {
    collection_name    = "platform-dev"
    pipeline_role_arn  = "arn:aws:iam::111122223333:role/platform-osis"
    reader_principals  = ["arn:aws:aoss:ap-northeast-1:111122223333:collection/example"]
    vpc_id             = "vpc-0123456789abcdef0"
    subnet_ids         = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }

  expect_failures = [var.reader_principals]
}

run "rejects_cross_account_reader" {
  command = plan

  variables {
    collection_name    = "platform-dev"
    pipeline_role_arn  = "arn:aws:iam::111122223333:role/platform-osis"
    reader_principals  = ["saml/444455556666/corporate/group/LogReaders"]
    vpc_id             = "vpc-0123456789abcdef0"
    subnet_ids         = ["subnet-0123456789abcdef0"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }

  expect_failures = [var.reader_principals]
}
