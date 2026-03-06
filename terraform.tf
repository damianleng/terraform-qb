terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

  # Uncomment after first successful deployment
  # backend "s3" {
  #   bucket         = "qb-financial-warehouse-dev-qb-terraform-state"
  #   key            = "terraform.tfstate"
  #   region         = "us-east-1"
  #   use_lockfile   = true
  #   encrypt        = true
  # }
}
