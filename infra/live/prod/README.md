# prod root

This is an independent production composition and state boundary. The example identifiers are placeholders and contain no credentials. `index_manager_principal_arn` identifies the IAM role or user running Terraform so the AOSS data access policy can authorize the managed `logs` index lifecycle; that principal also needs IAM `aoss:APIAccessAll`. Production defaults keep standby replicas enabled, use two minimum Ingestion OCUs for two-AZ distribution, retain SQS events for 14 days, set 30 days of minimum search retention, retain sink-DLQ documents for 90 days, and do not expire the S3 archive.

`provisioning_public_access_enabled` defaults to `false` and must remain false in steady state. Any separately authorized AWSCC index Create/Update or destroy must use `scripts/aoss-index-lifecycle.sh` from the repository root with `--root infra/live/prod`; see `docs/operations.md`. The helper never selects this root by default.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a production-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.
