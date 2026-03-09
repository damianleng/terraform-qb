terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"

  backend "s3" {
    bucket         = "qb-financial-warehouse-dev-qb-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "qb-financial-warehouse-dev-terraform-locks"
    encrypt        = true
  }
}
