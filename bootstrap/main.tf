data "aws_caller_identity" "current" {}

# GitHub OIDC Provider
# This resource is global per AWS account — only one can exist.
# It is managed here (not in modules/iam) so it survives terraform destroy
# on the main infrastructure.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name      = "github-actions-oidc"
    Project   = var.project
    ManagedBy = "Terraform"
  }
}

# GitHub Actions IAM Role
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:damianleng/terraform-qb:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project}-github-actions-role"
    Project   = var.project
    ManagedBy = "Terraform"
  }
}

# GitHub Actions IAM Policy
resource "aws_iam_policy" "github_actions" {
  name        = "${var.project}-github-actions-policy"
  description = "Policy for GitHub Actions to manage Terraform infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EC2VPCNetworking"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "RDSFullAccess"
        Effect   = "Allow"
        Action   = ["rds:*"]
        Resource = "*"
      },
      {
        Sid      = "S3FullAccess"
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = "*"
      },
      {
        Sid      = "LambdaFullAccess"
        Effect   = "Allow"
        Action   = ["lambda:*"]
        Resource = "*"
      },
      {
        Sid      = "IAMFullAccess"
        Effect   = "Allow"
        Action   = ["iam:*"]
        Resource = "*"
      },
      {
        Sid      = "StepFunctionsFullAccess"
        Effect   = "Allow"
        Action   = ["states:*"]
        Resource = "*"
      },
      {
        Sid      = "SecretsManagerFullAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudWatchFullAccess"
        Effect   = "Allow"
        Action   = ["cloudwatch:*", "logs:*"]
        Resource = "*"
      },
      {
        Sid      = "KMSFullAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = "*"
      },
      {
        Sid      = "CloudTrailFullAccess"
        Effect   = "Allow"
        Action   = ["cloudtrail:*"]
        Resource = "*"
      },
      {
        Sid      = "AccessAnalyzerFullAccess"
        Effect   = "Allow"
        Action   = ["access-analyzer:*"]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBStateLocking"
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project}-dev-terraform-locks",
          "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project}-prod-terraform-locks"
        ]
      },
      {
        Sid      = "SNSFullAccess"
        Effect   = "Allow"
        Action   = ["sns:*"]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateBuckets"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project}-dev-qb-terraform-state",
          "arn:aws:s3:::${var.project}-dev-qb-terraform-state/*",
          "arn:aws:s3:::${var.project}-prod-qb-terraform-state",
          "arn:aws:s3:::${var.project}-prod-qb-terraform-state/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
