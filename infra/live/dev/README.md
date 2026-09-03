# dev root

This is an independent development composition and state boundary. The example identifiers are placeholders and contain no credentials.

Development defaults use one minimum Ingestion OCU for cost-conscious validation, seven days of minimum search retention, and 14 days of S3 sink-DLQ retention. The S3 raw archive remains independent and does not expire by default.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a dev-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.
