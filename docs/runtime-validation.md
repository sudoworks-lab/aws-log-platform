# Runtime Validation Report

## Summary

This report is the public summary of the AWS runtime validation performed on 2026-09-04. It records a temporary development deployment in `ap-northeast-1`; no production deployment was used. The deployment, test data, and test resources were removed after validation, and a direct residual inventory returned zero.

The report is intentionally abstracted from the runtime receipts. It does not include receipt contents, AWS account IDs, IAM identities, resource IDs, ARNs, service endpoints, absolute local paths, or runtime directory names.

## Validation result

| Check | Result | Evidence summary |
| --- | --- | --- |
| Terraform deploy | PASS | A temporary dev root was applied, including the Terraform-managed `logs` index and the OSIS pipeline. |
| OSIS `ACTIVE` | PASS | The ingestion pipeline reached `ACTIVE`. |
| S3 → SQS → OSIS → private AOSS | PASS | A sample object was processed through the canonical archive, source queue, managed ingestion, and private search collection. |
| Private SigV4 query | PASS | A request signed for the `aoss` service returned results through the private probe path. |
| `timestamp` / `ingested_at` | PASS | The event occurrence timestamp was preserved and copied to `@timestamp`; `ingested_at` was added separately. |
| Malformed JSON preservation | PASS | The raw line remained in `message` and received `log_platform.parse_status = malformed_json`; the pipeline continued. |
| Terraform-managed strict mapping | PASS | Runtime mapping showed `http.status_code` as `integer` with `coerce=false` and `http.duration_ms` as `long` with `coerce=false`. |
| Numeric mapping rejection | PASS | A numeric-looking string for `http.status_code` was rejected by the strict mapping. |
| Rejected document → S3 sink DLQ | PASS | The rejected document and mapping failure metadata were preserved in the S3 sink DLQ. |
| Source DLQ remained empty | PASS | Source queue visible, in-flight, and delayed depths were zero; the source SQS DLQ also remained empty. |
| Terraform destroy | PASS | The dev stack, managed index, temporary lifecycle policy, and bootstrap resources were destroyed. |
| Direct residual inventory | PASS | Direct checks across the temporary EC2, S3, IAM, Lambda, CloudWatch Logs, SQS, CloudWatch alarms, OSIS, and AOSS resources returned zero. |

The final runtime sequence also confirmed that one rejected document did not force the whole source object into the source DLQ. The original S3 object remained the canonical recovery source throughout the test.

## Runtime findings and design evolution

1. `management_disabled` in the OSIS sink did not make `template_content` the owner of the AOSS mapping. The deployed index did not reflect the intended strict numeric mapping when the schema was expressed as an OSIS template.
2. Schema ownership was moved to the Terraform-managed AOSS `logs` index. The OSIS sink now writes to that pre-created index with index management disabled.
3. The private-only collection exposed an AWS Cloud Control index lifecycle constraint: the AWSCC index handler could not complete the index lifecycle while the collection was reachable only through private network policies.
4. The repository therefore contains a default-off, exact-collection lifecycle exception. `scripts/aoss-index-lifecycle.sh` scopes the temporary collection-only network access to the index lifecycle phase, removes it after a successful create/update, and keeps it until index deletion during destroy. The final helper's input guards and phase orchestration were checked locally with a mock Terraform runner and shell validation. The final helper itself was not rerun through a full AWS end-to-end lifecycle; the runtime results above do not certify that final automation.
5. Private-only remains the steady state. The temporary network exception does not add Dashboards access, change AOSS data authorization, or grant a broader reader/writer capability.

The initial runtime attempts also exposed two integration failures:

- OSIS rejected `add_when` at the wrong processor level during `CreatePipeline`. Moving the condition into the affected `entries` element corrected the placement; a regression assertion covers it.
- The AOSS control-plane collection condition did not provide an effective identity allow for OSIS calls. The unusable condition was removed while retaining the exact required action list and the separate exact-index data access scope. See the [IAM wildcard rationale](security.md#iam-wildcard-exceptions).

These issues and the template-versus-index ownership mismatch were corrected before the final data-path and failure-path checks recorded above.

## Fact boundary

### Confirmed in real AWS

- The core S3 → SQS → OSIS → private AOSS data path.
- Private signed search through the probe path.
- Occurrence-time and source-received-time separation.
- Malformed JSON preservation.
- Terraform-owned strict mapping and numeric mapping rejection.
- Individual rejected-document preservation in the S3 sink DLQ.
- Source queue and source DLQ remaining empty for the tested flow.
- Terraform destroy and direct residual inventory of zero.

### Confirmed locally or with mocked providers

- Terraform formatting, initialization without a backend, validation, and module mock tests.
- Shell syntax and the lifecycle helper's input guards and phase orchestration with a mock Terraform runner.

### Not validated

- A full AWS end-to-end rerun using the final lifecycle helper itself.
- Production deployment.
- Production load, throughput, indexing or search latency, and service quota behavior.
- Long-duration operation, multi-AZ failure behavior, and disaster recovery.
- A production alerting, paging, ownership, or replay process.
- Actual AWS cost. No cost figure is inferred from this report.

This report is evidence of a bounded development validation, not a production availability or capacity claim.
