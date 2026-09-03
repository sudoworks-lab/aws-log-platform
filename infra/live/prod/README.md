# prod root

This is an independent production composition and state boundary. The example identifiers are placeholders and contain no credentials. Production defaults keep standby replicas enabled, retain SQS events for 14 days, retain hot documents for 30 days, and do not expire the S3 archive.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a production-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.

