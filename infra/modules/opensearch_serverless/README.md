# opensearch_serverless

Owns the rebuildable search projection: a time-series collection, AWS-owned-key encryption policy, private OpenSearch Serverless-managed VPC endpoint, private search/Dashboards network policy, index data-retention policy, and separate writer/reader data access rules.

The pipeline role can create/update/describe indexes, write documents, and create/update/describe collection-level index templates. It cannot read documents or delete indexes/templates. Reader principals can be collection-account IAM roles/users or OpenSearch Serverless SAML identities and can describe and read but cannot write or delete. Cross-account users must assume a role in the collection account. IAM readers also need external `aoss:APIAccessAll` and, when using Dashboards, `aoss:DashboardsAccessAll`; the identity platform owns SAML provider configuration and reader identity policies.

The OSIS-created PrivateLink endpoint is authorized through a separate service-managed network policy named by the ingestion module. Do not point OSIS at this Terraform-managed search policy or both systems will attempt to own the policy document.
