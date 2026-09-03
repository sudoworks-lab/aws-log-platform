# Repository contract

This repository is a reference architecture, not a production deployment project.

- AWS deployment is forbidden unless a later user request explicitly authorizes it.
- Never run `terraform apply`, deploy resources, or perform AWS API writes.
- Never read AWS credentials, credential files, environment secrets, or secret-bearing `.env` files.
- Never hardcode credentials, passwords, tokens, account secrets, or private keys.
- Preserve least-privilege IAM. Any wildcard action or resource must be required by an AWS API and explained next to the policy or in `docs/security.md`.
- Keep the S3 raw archive as the durable source of truth. OpenSearch is a rebuildable search tier.
- Keep environment roots and state boundaries separate under `infra/live/<environment>`.
- Treat producer adapters as integrations outside the core Terraform scope.
- Validation must distinguish local syntax and structural checks from actual AWS runtime validation.
- Never report a command as passing unless it was executed successfully.
- Do not run `terraform plan` in credentialless CI; do not run `terraform apply` anywhere for this repository without a new explicit authorization.
- Do not commit, push, release, or publish unless explicitly requested later.

