provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.tags, {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "aws-log-platform"
    })
  }
}

provider "awscc" {
  region = var.aws_region
}
