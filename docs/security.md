# Security model

## Data protection

The canonical raw bucket uses S3-managed encryption (`AES256`), versioning, public-access blocking, bucket-owner-enforced object ownership, and a bucket policy denying insecure transport. SSE-S3 avoids introducing a KMS key-policy surface into this repository. A deployment may select customer-managed KMS keys only after key ownership, grants, rotation, cost, and recovery are designed.

The ingestion queue and SQS source DLQ use SQS-managed server-side encryption. Their messages contain S3 event metadata; S3 remains the content store.

The S3 sink DLQ has a different purpose: it preserves individual documents that OSIS could not write to AOSS. Its bucket remains private, encrypted, and lifecycle-controlled; the pipeline role's write permission is limited to the designated prefix. It is failure evidence, not a second canonical archive.

AOSS encryption is mandatory. The search projection is rebuildable from canonical S3 objects. A customer-managed AOSS key is an extension requiring explicit key ownership, grants, rotation, recovery, and cost decisions.

## Network controls

The user/search path is private. Terraform creates an AOSS-managed VPC endpoint and a network policy that permits the collection and Dashboards only through that endpoint. The VPC, subnets, and security groups are inputs because this repository does not own a network.

The ingestion-to-collection path uses OSIS-managed PrivateLink behavior. OSIS creates or updates the named ingestion network policy with its generated endpoint. That policy name remains separate from the Terraform-managed user network policy to prevent competing owners of the same JSON policy document.

## Reader identities

`reader_principals` accepts principals in the forms supported by AOSS data access policies:

- IAM role ARN.
- IAM user ARN.
- SAML user identity: `saml/<account-id>/<provider-name>/user/<user-id>`.
- SAML group identity: `saml/<account-id>/<provider-name>/group/<group-id>`.

These are authorization identifiers, not credentials, and their account component must match the collection account. A cross-account user must assume a role in the collection account and supply that role ARN instead of a foreign principal. The SAML provider, identity lifecycle, group membership, metadata, and federation configuration are owned by the external identity platform and are not created by this repository. Reader rules remain read-only.

## Authorization layers

AOSS requires both authorization layers:

1. IAM identity permissions allow IAM principals to call the collection APIs (`aoss:APIAccessAll`, and `aoss:DashboardsAccessAll` for Dashboards). SAML identities are authorized through the AOSS SAML provider and data access policy instead of IAM identity policies.
2. The AOSS data access policy limits collection and index operations.

The ingestion principal's collection rule supports index-template operations with only:

- `aoss:CreateCollectionItems`
- `aoss:UpdateCollectionItems`
- `aoss:DescribeCollectionItems`

It does not grant `aoss:DeleteCollectionItems`. Its index rule grants only `aoss:CreateIndex`, `aoss:UpdateIndex`, `aoss:DescribeIndex`, and `aoss:WriteDocument`; index and document deletion remain excluded.

Reader principals receive collection describe plus index describe/read permissions, not write or delete. IAM policies for human or federated IAM roles and users remain owned by the identity platform.

## Pipeline role boundaries

The OSIS role is limited to:

- Read the configured canonical S3 prefix and locate/list that bucket as required by the S3 source.
- Receive, change visibility for, and delete messages only on the ingestion queue.
- Write failed individual records only to the designated S3 sink-DLQ bucket and prefix.
- Call the target AOSS collection and create/update the OSIS-owned network policy with the exact control-plane actions required by the service integration.

Visibility duplication protection depends on `sqs:ChangeMessageVisibility`: while an object/event message remains in flight, OSIS extends its visibility timeout until acknowledgement or the configured two-hour protection limit. This reduces premature duplicate processing but does not provide exactly-once delivery.

## IAM wildcard exceptions

One ingestion-role statement uses `Resource = "*"` for AOSS control-plane operations used to discover the collection and create or update the OSIS-managed network policy. AWS does not expose resource ARNs for these security-policy create/get/update operations. The statement must remain restricted to the exact action list and an `aoss:collection` condition matching one collection name.

The `aoss:APIAccessAll` statement uses an ARN limited to the queue's partition, Region, account, and a collection-ID wildcard, plus the exact collection-name condition. The collection ID is not known without creating a module cycle. The AOSS data access policy independently restricts the role to the target collection and index pattern. An authorized deployment review must confirm condition behavior in the target partition and provider version.

The OSIS S3 source also requires `s3:ListAllMyBuckets` for bucket ownership validation. AWS defines that action without resource-level permissions, so its isolated statement uses `Resource = "*"`. Object reads, bucket location, and prefix listing remain scoped to the canonical bucket and raw prefix. Sink-DLQ writes do not use a wildcard bucket resource.

The S3 bucket policy uses `s3:*` only in an explicit `Deny` for insecure transport. It grants no capability. Allow statements enumerate actions and resources.

## Persistent buffer and KMS

The OSIS persistent buffer is not configured, so the pipeline uses its default in-memory buffer. Canonical S3 plus SQS are the durability boundary. If a future design enables persistent buffering, that change must account for OCUs allocated to buffering, the selected AWS-owned or customer-managed KMS key, required key permissions, recovery behavior, and cost. Persistent buffering must not become a reason to shorten canonical S3 retention or remove SQS replay.

## Secrets and credentials

- Terraform files contain no credentials, passwords, tokens, or private keys.
- Backend examples contain no credential fields.
- AWS account IDs, resource IDs, IAM principal ARNs, and AOSS SAML identity strings are configuration identifiers, not authentication secrets.
- Local verification performs no standalone plan or apply and requires no AWS credential.
- Local verification must not inspect AWS credential files, environment credential values, credential stores, or secret-bearing files.

## Pre-production review

Before any separately authorized deployment, review IAM with Access Analyzer, verify VPC DNS and security-group paths, validate service quotas and regional feature availability, decide KMS requirements for the archive, sink DLQ, persistent buffer, and AOSS, test denied public access, test reader/writer separation, and exercise source-DLQ, sink-DLQ, and archive replay in a non-production account.
