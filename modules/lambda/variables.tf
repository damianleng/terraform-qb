variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "subnet_ids" {
  description = "List of private subnet IDs for Lambda"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  type        = string
}

variable "staging_bucket_arn" {
  description = "ARN of the staging S3 bucket"
  type        = string
}

variable "staging_bucket_name" {
  description = "Name of the staging S3 bucket"
  type        = string
}

variable "logs_bucket_arn" {
  description = "ARN of the logs S3 bucket"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the RDS password secret in Secrets Manager"
  type        = string
}

variable "rds_endpoint" {
  description = "RDS instance endpoint"
  type        = string
}

variable "alert_email" {
  description = "Email address for ETL alerts"
  type        = string
}

variable "qb_api_secret_arn" {
  description = "ARN of the QuickBooks API credentials secret in Secrets Manager"
  type        = string
}

variable "rds_identifier" {
  description = "RDS instance identifier for dashboard metrics"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
