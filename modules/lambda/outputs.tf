output "extract_function_arn" {
  description = "ARN of the Extract Lambda function"
  value       = aws_lambda_function.extract.arn
}

output "transform_function_arn" {
  description = "ARN of the Transform Lambda function"
  value       = aws_lambda_function.transform.arn
}

output "load_function_arn" {
  description = "ARN of the Load Lambda function"
  value       = aws_lambda_function.load.arn
}

output "extract_role_arn" {
  description = "ARN of the Extract Lambda IAM role"
  value       = aws_iam_role.extract.arn
}

output "transform_role_arn" {
  description = "ARN of the Transform Lambda IAM role"
  value       = aws_iam_role.transform.arn
}

output "load_role_arn" {
  description = "ARN of the Load Lambda IAM role"
  value       = aws_iam_role.load.arn
}

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.etl_pipeline.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for ETL alerts"
  value       = aws_sns_topic.etl_alerts.arn
}
