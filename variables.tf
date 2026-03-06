variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "qb-financial-warehouse"
}

variable "alert_email" {
  description = "Email address for ETL alerts"
  type        = string
}

variable "qb_api_secret_arn" {
  description = "ARN of the QuickBooks API credentials secret in Secrets Manager"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for OIDC trust"
  type        = string
  default     = "damianleng/terraform-qb"
}

variable "github_branch" {
  description = "GitHub branch for OIDC trust"
  type        = string
  default     = "main"
}