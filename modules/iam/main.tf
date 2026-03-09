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

# AWS Guard Duty
resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-guardduty"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# SNS topic for GuardDuty findings
resource "aws_sns_topic" "guardduty_alerts" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project}-${var.environment}-guardduty-alerts"

  tags = {
    Name        = "${var.project}-${var.environment}-guardduty-alerts"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  count     = var.enable_guardduty ? 1 : 0
  topic_arn = aws_sns_topic.guardduty_alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge rule to forward GuardDuty findings to SNS
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_guardduty ? 1 : 0
  name        = "${var.project}-${var.environment}-guardduty-findings"
  description = "Forward GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 4] }]
    }
  })

  tags = {
    Name        = "${var.project}-${var.environment}-guardduty-findings"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  count     = var.enable_guardduty ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts[0].arn
}

resource "aws_sns_topic_policy" "guardduty_alerts" {
  count = var.enable_guardduty ? 1 : 0
  arn   = aws_sns_topic.guardduty_alerts[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgePublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.guardduty_alerts[0].arn
      }
    ]
  })
}

# IAM role for AWS Config
resource "aws_iam_role" "config" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project}-${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-config-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "config" {
  count      = var.enable_aws_config ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Allow Config to write to the existing logs S3 bucket
resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_aws_config ? 1 : 0
  name  = "${var.project}-${var.environment}-config-s3-policy"
  role  = aws_iam_role.config[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}",
          "arn:aws:s3:::${var.cloudtrail_s3_bucket_name}/config/*"
        ]
      }
    ]
  })
}

# Config recorder
resource "aws_config_configuration_recorder" "main" {
  count    = var.enable_aws_config ? 1 : 0
  name     = "${var.project}-${var.environment}-config-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# Config delivery channel — uses existing logs bucket with config/ prefix
resource "aws_config_delivery_channel" "main" {
  count          = var.enable_aws_config ? 1 : 0
  name           = "${var.project}-${var.environment}-config-delivery"
  s3_bucket_name = var.cloudtrail_s3_bucket_name
  s3_key_prefix  = "config"
  depends_on     = [aws_config_configuration_recorder.main]
}

# Enable the recorder
resource "aws_config_configuration_recorder_status" "main" {
  count      = var.enable_aws_config ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# RDS storage encryption enabled
resource "aws_config_config_rule" "rds_storage_encrypted" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-rds-storage-encrypted"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# RDS backup enabled
resource "aws_config_config_rule" "rds_backup_enabled" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-rds-backup-enabled"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "DB_INSTANCE_BACKUP_ENABLED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# S3 bucket server side encryption enabled
resource "aws_config_config_rule" "s3_bucket_encrypted" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-s3-bucket-encrypted"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# S3 bucket public access blocked
resource "aws_config_config_rule" "s3_public_access_blocked" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-s3-public-access-blocked"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM MFA enabled for root
resource "aws_config_config_rule" "root_mfa_enabled" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-root-mfa-enabled"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# CloudTrail enabled
resource "aws_config_config_rule" "cloudtrail_enabled" {
  count      = var.enable_aws_config ? 1 : 0
  name       = "${var.project}-${var.environment}-cloudtrail-enabled"
  depends_on = [aws_config_configuration_recorder_status.main]

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}