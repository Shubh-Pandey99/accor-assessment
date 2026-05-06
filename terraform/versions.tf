# Terraform & provider config
# The Redemption - Accor Hotel Point Deduction Service

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "accor-redemption-tfstate"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "accor-redemption-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "the-redemption"
      ManagedBy   = "terraform"
      Environment = var.environment
      Team        = "sre"
      CostCenter  = "hotel-loyalty"
    }
  }
}

