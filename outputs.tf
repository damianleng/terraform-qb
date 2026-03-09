output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
}

output "rds_password_secret_arn" {
  description = "ARN of RDS password in Secrets Manager"
  value       = module.rds.db_password_secret_arn
}

output "staging_bucket_name" {
  description = "Name of the staging S3 bucket"
  value       = module.s3.staging_bucket_name
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = module.lambda.state_machine_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.lambda.sns_topic_arn
}