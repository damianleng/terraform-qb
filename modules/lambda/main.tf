# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "extract" {
  name              = "/aws/lambda/${var.project}-${var.environment}-qb-extract"
  retention_in_days = 90

  tags = {
    Name        = "${var.project}-${var.environment}-qb-extract-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "transform" {
  name              = "/aws/lambda/${var.project}-${var.environment}-qb-transform"
  retention_in_days = 90

  tags = {
    Name        = "${var.project}-${var.environment}-qb-transform-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_group" "load" {
  name              = "/aws/lambda/${var.project}-${var.environment}-qb-load"
  retention_in_days = 90

  tags = {
    Name        = "${var.project}-${var.environment}-qb-load-logs"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# IAM Role for Extract Lambda
resource "aws_iam_role" "extract" {
  name = "${var.project}-${var.environment}-qb-extract-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-extract-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "extract" {
  name        = "${var.project}-${var.environment}-qb-extract-policy"
  description = "Policy for Extract Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_secret_arn,
          var.qb_api_secret_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.staging_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.extract.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-extract-policy"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "extract" {
  role       = aws_iam_role.extract.name
  policy_arn = aws_iam_policy.extract.arn
}

# IAM Role for Transform Lambda
resource "aws_iam_role" "transform" {
  name = "${var.project}-${var.environment}-qb-transform-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-transform-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "transform" {
  name        = "${var.project}-${var.environment}-qb-transform-policy"
  description = "Policy for Transform Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${var.staging_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.transform.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-transform-policy"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "transform" {
  role       = aws_iam_role.transform.name
  policy_arn = aws_iam_policy.transform.arn
}

# IAM Role for Load Lambda
resource "aws_iam_role" "load" {
  name = "${var.project}-${var.environment}-qb-load-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-load-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "load" {
  name        = "${var.project}-${var.environment}-qb-load-policy"
  description = "Policy for Load Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${var.staging_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.db_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.load.arn}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-qb-load-policy"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "load" {
  role       = aws_iam_role.load.name
  policy_arn = aws_iam_policy.load.arn
}

# Lambda Function: Extract
data "archive_file" "extract" {
  type        = "zip"
  output_path = "${path.module}/extract.zip"

  source {
    content  = <<-EOT
      def lambda_handler(event, context):
          import os
          print(f"Extract Lambda - Environment: {os.environ.get('ENVIRONMENT')}")
          print(f"Staging Bucket: {os.environ.get('STAGING_BUCKET')}")
          # TODO: Implement QuickBooks API extraction logic
          return {
              'statusCode': 200,
              'body': 'Extract completed',
              'extractedFiles': ['raw_data_001.json']
          }
    EOT
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "extract" {
  filename         = data.archive_file.extract.output_path
  function_name    = "${var.project}-${var.environment}-qb-extract"
  role             = aws_iam_role.extract.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.extract.output_base64sha256
  runtime          = "python3.12"
  timeout          = 600
  memory_size      = 1024

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      PROJECT        = var.project
      STAGING_BUCKET = var.staging_bucket_name
      DB_SECRET_ARN  = var.db_secret_arn
      RDS_ENDPOINT   = var.rds_endpoint
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-qb-extract"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.extract,
    aws_iam_role_policy_attachment.extract
  ]
}

# Lambda Function: Transform
data "archive_file" "transform" {
  type        = "zip"
  output_path = "${path.module}/transform.zip"

  source {
    content  = <<-EOT
      def lambda_handler(event, context):
          import os
          print(f"Transform Lambda - Environment: {os.environ.get('ENVIRONMENT')}")
          print(f"Input: {event}")
          # TODO: Implement data transformation logic
          return {
              'statusCode': 200,
              'body': 'Transform completed',
              'transformedFiles': ['transformed_data_001.json']
          }
    EOT
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "transform" {
  filename         = data.archive_file.transform.output_path
  function_name    = "${var.project}-${var.environment}-qb-transform"
  role             = aws_iam_role.transform.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.transform.output_base64sha256
  runtime          = "python3.12"
  timeout          = 600
  memory_size      = 1024

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      PROJECT        = var.project
      STAGING_BUCKET = var.staging_bucket_name
      DB_SECRET_ARN  = var.db_secret_arn
      RDS_ENDPOINT   = var.rds_endpoint
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-qb-transform"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.transform,
    aws_iam_role_policy_attachment.transform
  ]
}

# Lambda Function: Load
data "archive_file" "load" {
  type        = "zip"
  output_path = "${path.module}/load.zip"

  source {
    content  = <<-EOT
      def lambda_handler(event, context):
          import os
          print(f"Load Lambda - Environment: {os.environ.get('ENVIRONMENT')}")
          print(f"RDS Endpoint: {os.environ.get('RDS_ENDPOINT')}")
          print(f"Input: {event}")
          # TODO: Implement RDS load logic
          return {
              'statusCode': 200,
              'body': 'Load completed',
              'recordsLoaded': 1000
          }
    EOT
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "load" {
  filename         = data.archive_file.load.output_path
  function_name    = "${var.project}-${var.environment}-qb-load"
  role             = aws_iam_role.load.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.load.output_base64sha256
  runtime          = "python3.12"
  timeout          = 600
  memory_size      = 1024

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ENVIRONMENT    = var.environment
      PROJECT        = var.project
      STAGING_BUCKET = var.staging_bucket_name
      DB_SECRET_ARN  = var.db_secret_arn
      RDS_ENDPOINT   = var.rds_endpoint
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-qb-load"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.load,
    aws_iam_role_policy_attachment.load
  ]
}

# SNS Topic for Alerts
resource "aws_sns_topic" "etl_alerts" {
  name = "${var.project}-${var.environment}-etl-alerts"

  tags = {
    Name        = "${var.project}-${var.environment}-etl-alerts"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "etl_alerts_email" {
  topic_arn = aws_sns_topic.etl_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "${var.project}-${var.environment}-etl-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-etl-sfn-role"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "step_functions" {
  name        = "${var.project}-${var.environment}-etl-sfn-policy"
  description = "Policy for Step Functions state machine"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.extract.arn,
          aws_lambda_function.transform.arn,
          aws_lambda_function.load.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.etl_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.environment}-etl-sfn-policy"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "step_functions" {
  role       = aws_iam_role.step_functions.name
  policy_arn = aws_iam_policy.step_functions.arn
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "${var.project}-${var.environment}-etl-pipeline"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "QuickBooks ETL Pipeline: Extract -> Transform -> Load"
    StartAt = "Extract"
    States = {
      Extract = {
        Type     = "Task"
        Resource = aws_lambda_function.extract.arn
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
        Next = "Transform"
      }
      Transform = {
        Type     = "Task"
        Resource = aws_lambda_function.transform.arn
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
        Next = "Load"
      }
      Load = {
        Type     = "Task"
        Resource = aws_lambda_function.load.arn
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 30
            MaxAttempts     = 3
            BackoffRate     = 2
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "NotifyFailure"
          }
        ]
        Next = "Success"
      }
      Success = {
        Type = "Succeed"
      }
      NotifyFailure = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          "TopicArn"  = aws_sns_topic.etl_alerts.arn
          "Message.$" = "States.Format('ETL Pipeline Failed. Error: {}', $.error.Cause)"
          "Subject"   = "ETL Pipeline Failure Alert"
        }
        Next = "FailState"
      }
      FailState = {
        Type  = "Fail"
        Cause = "ETL Pipeline execution failed"
      }
    }
  })

  tags = {
    Name        = "${var.project}-${var.environment}-etl-pipeline"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.step_functions
  ]
}

# Lambda error rate alarms (one per function)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    extract   = aws_lambda_function.extract.function_name
    transform = aws_lambda_function.transform.function_name
    load      = aws_lambda_function.load.function_name
  }

  alarm_name          = "${var.project}-${var.environment}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda ${each.key} function errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.etl_alerts.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Step Functions execution failure alarm
resource "aws_cloudwatch_metric_alarm" "sfn_failures" {
  alarm_name          = "${var.project}-${var.environment}-etl-pipeline-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "ETL Step Functions pipeline execution failed"
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.etl_pipeline.arn
  }

  alarm_actions = [aws_sns_topic.etl_alerts.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

# Lambda duration alarm — warns if functions are close to timeout
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = {
    extract   = aws_lambda_function.extract.function_name
    transform = aws_lambda_function.transform.function_name
    load      = aws_lambda_function.load.function_name
  }

  alarm_name          = "${var.project}-${var.environment}-${each.key}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Maximum"
  threshold           = 480000 # 480 seconds — 80% of 600s timeout
  alarm_description   = "Lambda ${each.key} approaching timeout"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = each.value
  }

  alarm_actions = [aws_sns_topic.etl_alerts.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_dashboard" "etl" {
  dashboard_name = "${var.project}-${var.environment}-etl"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Errors"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.extract.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.transform.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.load.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Lambda Duration (ms)"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.extract.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.transform.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.load.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Step Functions Executions"
          region = var.aws_region
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.etl_pipeline.arn],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.etl_pipeline.arn]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "RDS CPU & Connections"
          region = var.aws_region
          period = 300
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      }
    ]
  })
}
