variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket for CloudTrail logs"
  type        = string
}

variable "enable_access_analyzer" {
  description = "Enable IAM Access Analyzer"
  type        = bool
  default     = true
}

variable "password_min_length" {
  description = "Minimum password length"
  type        = number
  default     = 14
}

variable "password_require_symbols" {
  description = "Require symbols in password"
  type        = bool
  default     = true
}

variable "password_require_numbers" {
  description = "Require numbers in password"
  type        = bool
  default     = true
}

variable "password_require_uppercase" {
  description = "Require uppercase in password"
  type        = bool
  default     = true
}

variable "password_require_lowercase" {
  description = "Require lowercase in password"
  type        = bool
  default     = true
}

variable "password_max_age" {
  description = "Password expiration in days (0 = no expiration)"
  type        = number
  default     = 90
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_aws_config" {
  description = "Enable AWS Config compliance recording"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for GuardDuty finding alerts"
  type        = string
}

