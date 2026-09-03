# ingestion_queue

Owns one standard ingestion queue and its DLQ, including SQS-managed encryption, visibility and retention, redrive policy, redrive allow policy, and the resource policy permitting only the exact S3 bucket/account to send messages.

SQS is an explicit boundary for burst absorption, consumer outages, retry visibility, and poison-message isolation. It is not the durable log store; message bodies point to objects in the S3 archive.

