# dev root

This is an independent development composition and state boundary. The example identifiers are placeholders and contain no credentials.

Local structural validation:

```bash
terraform init -backend=false
terraform validate
```

The backend example uses a dev-specific state key and native S3 lockfile. Initializing or deploying against a real backend is outside the current authorization.

