# opensearch_serverless

Owns the rebuildable hot search tier: a time-series collection, AWS-owned-key encryption policy, private OpenSearch Serverless-managed VPC endpoint, private search/Dashboards network policy, hot data lifecycle policy, and separate writer/reader data access rules.

The pipeline role can create/update/describe indexes and write documents but cannot read or delete. Reader principals can describe and read but cannot write or delete. Those readers also need external IAM `aoss:APIAccessAll` and, when using Dashboards, `aoss:DashboardsAccessAll`; this module does not own federated identity policies.

The OSIS-created PrivateLink endpoint is authorized through a separate service-managed network policy named by the ingestion module. Do not point OSIS at this Terraform-managed search policy or both systems will attempt to own the policy document.

