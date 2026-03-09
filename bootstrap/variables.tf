variable "project" {
  description = "Project name — must match the value used in main infrastructure"
  type        = string
  default     = "qb-financial-warehouse"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format"
  type        = string
  default     = "damianleng/terraform-qb"
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the role"
  type        = string
  default     = "main"
}
