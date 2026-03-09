output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — add this to your GitHub Actions workflow"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
