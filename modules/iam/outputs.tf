output "cloudtrail_arn" {
  description = "ARN of CloudTrail"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_kms_key_arn" {
  description = "ARN of the KMS key used for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail.arn
}

output "access_analyzer_arn" {
  description = "ARN of IAM Access Analyzer"
  value       = var.enable_access_analyzer ? aws_accessanalyzer_analyzer.main[0].arn : null
}
