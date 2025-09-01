terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "721500739616-tf-state"
    key    = "sentinel/sentinel-prod.tfstate"
    region = "us-west-2"
    
    # Enable encryption
    encrypt = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = "production"
      Project     = "RapydSentinel"
      ManagedBy   = "Terraform"
    }
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}