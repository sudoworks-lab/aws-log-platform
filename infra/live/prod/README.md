# prod root

This is an independent production composition and state boundary. The example identifiers are placeholders and contain no credentials. Production defaults keep standby replicas enabled, use two minimum Ingestion OCUs for two-AZ distribution, retain SQS events for 14 days, set 30 days of minimum search retention, retain sink-DLQ documents for 90 days, and do not expire the S3 archive.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a production-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.
