output "staging_bucket_arn" {
  description = "ARN of the staging bucket"
  value       = aws_s3_bucket.staging.arn
}

output "staging_bucket_name" {
  description = "Name of the staging bucket"
  value       = aws_s3_bucket.staging.id
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "logs_bucket_name" {
  description = "Name of the logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "terraform_state_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.id
}

output "analytics_backups_bucket_arn" {
  description = "ARN of the analytics backups bucket"
  value       = aws_s3_bucket.analytics_backups.arn
}

output "analytics_backups_bucket_name" {
  description = "Name of the analytics backups bucket"
  value       = aws_s3_bucket.analytics_backups.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3.arn
}
