# dev root

This is an independent development composition and state boundary. The example identifiers are placeholders and contain no credentials. `index_manager_principal_arn` identifies the IAM role or user running Terraform so the AOSS data access policy can authorize the managed `logs` index lifecycle; that principal also needs IAM `aoss:APIAccessAll`.

Development defaults use one minimum Ingestion OCU for cost-conscious validation, seven days of minimum search retention, and 14 days of S3 sink-DLQ retention. The S3 raw archive remains independent and does not expire by default.

`provisioning_public_access_enabled` defaults to `false` and must remain false in steady state. Any separately authorized AWSCC index Create/Update or destroy must use `scripts/aoss-index-lifecycle.sh` from the repository root with `--root infra/live/dev`; see `docs/operations.md`.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a dev-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.
