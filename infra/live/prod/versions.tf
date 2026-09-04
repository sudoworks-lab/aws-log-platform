terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.87, < 2.0"
    }
  }
}
