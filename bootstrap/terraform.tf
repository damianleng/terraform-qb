terraform {
  required_version = ">= 1.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bootstrap uses a local state file intentionally.
  # Do NOT move this to S3 — the bootstrap resources must be manageable
  # even if the S3 state buckets have been deleted.
  # Commit bootstrap/terraform.tfstate to a private repo or store it securely.
}

provider "aws" {
  region = var.aws_region
}
