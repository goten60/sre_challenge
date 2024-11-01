# Terraform Block
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

  }
}

# Provider Block
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
