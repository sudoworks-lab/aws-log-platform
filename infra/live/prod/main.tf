locals {
  name_prefix       = "${var.project_name}-${var.environment}"
  collection_name   = local.name_prefix
  pipeline_name     = "${local.name_prefix}-ingest"
  sub_pipeline_name = "${local.name_prefix}-logs"
  osis_network_name = "${local.name_prefix}-osis-net"
  archive_bucket    = "${var.project_name}-${var.environment}-${var.aws_account_id}-${var.aws_region}-raw"
  sink_dlq_bucket   = "${var.project_name}-${var.environment}-${var.aws_account_id}-${var.aws_region}-sink-dlq"
  sink_dlq_prefix   = "failed-documents/"
  ingestion_role    = "${local.name_prefix}-osis-pipeline"
  ingestion_queue   = "${local.name_prefix}-ingestion"
}

module "sink_dlq" {
  source = "../../modules/sink_dlq"

  bucket_name    = local.sink_dlq_bucket
  retention_days = var.sink_dlq_retention_days
}

module "log_archive" {
  source = "../../modules/log_archive"

  bucket_name       = local.archive_bucket
  object_prefix     = var.raw_log_prefix
  archive_lifecycle = var.archive_lifecycle
}

module "ingestion_queue" {
  source = "../../modules/ingestion_queue"

  name                       = local.ingestion_queue
  source_bucket_arn          = module.log_archive.bucket_arn
  source_account_id          = var.aws_account_id
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  message_retention_seconds  = var.queue_message_retention_seconds
  dlq_retention_seconds      = var.dlq_message_retention_seconds
}

resource "aws_s3_bucket_notification" "ingestion" {
  bucket = module.log_archive.bucket_id

  queue {
    queue_arn     = module.ingestion_queue.queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = var.raw_log_prefix
  }

  depends_on = [module.ingestion_queue]
}

module "ingestion_identity" {
  source = "../../modules/ingestion_identity"

  role_name                = local.ingestion_role
  archive_bucket_arn       = module.log_archive.bucket_arn
  archive_object_prefix    = var.raw_log_prefix
  queue_arn                = module.ingestion_queue.queue_arn
  sink_dlq_bucket_arn      = module.sink_dlq.bucket_arn
  sink_dlq_key_path_prefix = local.sink_dlq_prefix
  collection_name          = local.collection_name
}

module "opensearch_serverless" {
  source = "../../modules/opensearch_serverless"

  collection_name                    = local.collection_name
  pipeline_role_arn                  = module.ingestion_identity.role_arn
  index_manager_principal_arn        = var.index_manager_principal_arn
  provisioning_public_access_enabled = var.provisioning_public_access_enabled
  reader_principals                  = var.reader_principals
  vpc_id                             = var.vpc_id
  subnet_ids                         = var.subnet_ids
  security_group_ids                 = var.security_group_ids
  search_retention_days              = var.search_retention_days
  standby_replicas                   = "ENABLED"
}

module "observability" {
  source = "../../modules/observability"

  name_prefix                 = local.name_prefix
  pipeline_name               = local.pipeline_name
  sub_pipeline_name           = local.sub_pipeline_name
  queue_name                  = module.ingestion_queue.queue_name
  dlq_name                    = module.ingestion_queue.dlq_name
  queue_age_threshold_seconds = var.queue_age_alarm_seconds
  alarm_action_arns           = var.alarm_action_arns
  log_retention_days          = 90
}

module "opensearch_ingestion" {
  source = "../../modules/opensearch_ingestion"

  pipeline_name                    = local.pipeline_name
  sub_pipeline_name                = local.sub_pipeline_name
  region                           = var.aws_region
  environment                      = var.environment
  queue_url                        = module.ingestion_queue.queue_url
  queue_visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  pipeline_role_arn                = module.ingestion_identity.role_arn
  collection_endpoint              = module.opensearch_serverless.collection_endpoint
  index_name                       = module.opensearch_serverless.index_name
  network_policy_name              = local.osis_network_name
  sink_dlq_bucket_name             = module.sink_dlq.bucket_id
  sink_dlq_key_path_prefix         = local.sink_dlq_prefix
  cloudwatch_log_group_name        = module.observability.pipeline_log_group_name
  min_units                        = 2
  max_units                        = 4
}
