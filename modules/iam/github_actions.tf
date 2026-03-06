# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.project}-${var.environment}-github-oidc"
    Environment = var.environment
    Project     = var.project
  }
}

# GitHub Actions IAM Role
resource "aws_iam_role" "github_actions" {
  name = "qb-financial-warehouse-github-actions-role"

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
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-github-actions-role"
    Environment = var.environment
    Project     = var.project
  }
}

# GitHub Actions Policy
resource "aws_iam_policy" "github_actions" {
  name        = "qb-financial-warehouse-github-actions-policy"
  description = "Policy for GitHub Actions to manage Terraform infrastructure"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2VPCNetworking"
        Effect = "Allow"
        Action = [
          "ec2:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSFullAccess"
        Effect = "Allow"
        Action = [
          "rds:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3FullAccess"
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaFullAccess"
        Effect = "Allow"
        Action = [
          "lambda:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMFullAccess"
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "StepFunctionsFullAccess"
        Effect = "Allow"
        Action = [
          "states:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerFullAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchFullAccess"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSFullAccess"
        Effect = "Allow"
        Action = [
          "kms:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudTrailFullAccess"
        Effect = "Allow"
        Action = [
          "cloudtrail:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "AccessAnalyzerFullAccess"
        Effect = "Allow"
        Action = [
          "access-analyzer:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/qb-financial-warehouse-terraform-locks"
      },
      {
        Sid    = "SNSFullAccess"
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}
