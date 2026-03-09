# KMS key for CloudTrail
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-cloudtrail-kms"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_kms_alias" "cloudtrail" {
  name          = "alias/${var.project}-${var.environment}-cloudtrail"
  target_key_id = aws_kms_key.cloudtrail.key_id
}

data "aws_caller_identity" "current" {}

# IAM Account Password Policy
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = var.password_min_length
  require_lowercase_characters   = var.password_require_lowercase
  require_numbers                = var.password_require_numbers
  require_uppercase_characters   = var.password_require_uppercase
  require_symbols                = var.password_require_symbols
  allow_users_to_change_password = true
  max_password_age               = var.password_max_age > 0 ? var.password_max_age : null
  password_reuse_prevention      = 24
  hard_expiry                    = false
}

# MFA Enforcement Policy
resource "aws_iam_policy" "enforce_mfa" {
  name        = "${var.project}-${var.environment}-enforce-mfa"
  description = "Deny all actions except MFA setup if MFA not enabled"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# IAM Group with MFA enforcement
resource "aws_iam_group" "mfa_required" {
  name = "${var.project}-${var.environment}-mfa-required"
}

resource "aws_iam_group_policy_attachment" "enforce_mfa" {
  group      = aws_iam_group.mfa_required.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

# CloudTrail for API logging
resource "aws_cloudtrail" "main" {
  name                          = "${var.project}-${var.environment}-cloudtrail"
  s3_bucket_name                = var.cloudtrail_s3_bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]

  tags = {
    Name        = "${var.project}-${var.environment}-cloudtrail"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = var.cloudtrail_s3_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}",
          "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# IAM Access Analyzer
resource "aws_accessanalyzer_analyzer" "main" {
  count         = var.enable_access_analyzer ? 1 : 0
  analyzer_name = "${var.project}-${var.environment}-analyzer"
  type          = "ACCOUNT"

  tags = {
    Name        = "${var.project}-${var.environment}-analyzer"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}
