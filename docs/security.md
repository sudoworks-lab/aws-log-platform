# Security model

## Data protection

The raw bucket uses S3-managed encryption (`AES256`), versioning, public-access blocking, bucket-owner-enforced object ownership, and a bucket policy denying insecure transport. SSE-S3 keeps the reference deployable without introducing a KMS key policy surface. A production design may select customer-managed KMS keys when compliance, separation of duties, or cross-account access justifies the additional lifecycle and recovery burden.

SQS and the DLQ use SQS-managed server-side encryption. No payload is copied into Terraform state; SQS messages contain S3 event metadata and S3 remains the content store.

OpenSearch Serverless encryption is mandatory. This reference uses an AWS-owned key and a time-series collection. A customer-managed key is an extension requiring explicit key ownership, grants, rotation, and disaster-recovery decisions.

## Network controls

The user/search path is private. Terraform creates an OpenSearch Serverless-managed VPC endpoint and a network policy that permits the collection and Dashboards only through that endpoint. The VPC, subnets, and security groups are inputs because this repository does not own a network.

The ingestion-to-collection path uses the OSIS-managed PrivateLink behavior documented by AWS. OSIS creates or updates the named ingestion network policy with its generated endpoint. That policy name is separate from the Terraform-managed user network policy to prevent competing owners of the same JSON policy document.

## Authorization layers

OpenSearch Serverless requires both layers:

1. IAM identity permissions allow a principal to call the collection APIs (`aoss:APIAccessAll`, and `aoss:DashboardsAccessAll` for Dashboards).
2. The data access policy limits collection and index operations.

The module grants the pipeline role only create/update/describe index and write-document data permissions. Reader principals receive describe and read permissions, not write or delete. The external IAM policies for human or federated reader roles remain owned by the identity platform and are intentionally not created here.

## IAM wildcard exception

One ingestion-role statement uses `Resource = "*"` for OpenSearch Serverless control-plane operations used to discover the collection and create/update the OSIS-managed network policy. AWS does not expose resource ARNs for these security-policy create/get/update operations. The statement is restricted to the exact action list and an `aoss:collection` condition matching one collection name.

The `aoss:APIAccessAll` statement uses an ARN limited to the queue's partition, Region, account, and a collection ID wildcard, plus the exact collection-name condition. The collection ID is not known without creating a module cycle. The Serverless data access policy independently restricts the role to the target collection and index pattern. An authorized deployment review should confirm the condition behavior in the target partition and provider version.

The OSIS S3 source also requires `s3:ListAllMyBuckets` to validate bucket ownership. AWS defines that action without resource-level permissions, so its isolated statement uses `Resource = "*"`. Object reads, bucket location, and prefix listing remain scoped to the canonical bucket and raw prefix.

The S3 bucket policy uses `s3:*` only in an explicit `Deny` for insecure transport. It grants no capability and ensures every present and future S3 bucket operation is rejected over non-TLS transport. Allow statements always enumerate actions and exact resources.

## Secrets and credentials

- Terraform files contain no credentials, passwords, tokens, or private keys.
- Backend examples contain no credential fields.
- AWS account IDs, resource IDs, and IAM principal ARNs are configuration identifiers, not authentication secrets.
- CI performs no plan or apply and requires no AWS credential.
- Local verification must not inspect `~/.aws`, environment credential values, credential stores, or secret-bearing files.

## Pre-production review

Before any separately authorized deployment, review IAM with Access Analyzer, confirm VPC DNS and security-group paths, validate service quotas and regional feature availability, decide customer-managed key requirements, test a denied public request, test reader and writer separation, and exercise DLQ and archive replay in a non-production account.
