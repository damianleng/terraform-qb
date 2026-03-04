# Infrastructure as Code - Terraform Project

## Overview
This project manages AWS infrastructure using Terraform with a modular approach for the qb-financial-warehouse project.

## Project Structure
```
.
├── main.tf              # Root module - calls child modules
├── variables.tf         # Root-level input variables
├── output.tf           # Root-level outputs
├── terraform.tf        # Provider and version configuration
├── .gitignore          # Git ignore rules for Terraform
└── modules/
    ├── vpc/            # VPC module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── output.tf
    ├── rds/            # RDS module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── output.tf
    ├── s3/             # S3 module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── lambda/         # Lambda & Step Functions module
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## VPC Module

### What It Creates
- **VPC**: 10.0.0.0/16 CIDR block with DNS support enabled
- **Public Subnets**: 2 subnets (10.0.0.0/24, 10.0.1.0/24) across 2 AZs
- **Private Subnets**: 2 subnets (10.0.2.0/24, 10.0.3.0/24) across 2 AZs
- **Database Subnets**: 2 subnets (10.0.4.0/24, 10.0.5.0/24) across 2 AZs
- **Internet Gateway**: For public subnet internet access
- **NAT Gateway**: Single NAT with EIP for private subnet outbound traffic
- **Route Tables**: Separate route tables for public and private subnets with proper associations
- **Security Groups**: Lambda SG (outbound to internet) and RDS SG (inbound from Lambda only, outbound VPC-only)

### Module Inputs
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | (required) | Environment name (dev/prod) |
| project | string | (required) | Project name |
| vpc_cidr | string | 10.0.0.0/16 | VPC CIDR block |
| enable_nat_gateway | bool | true | Enable/disable NAT Gateway |

### Module Outputs
- `vpc_id` - VPC ID
- `vpc_cidr` - VPC CIDR block
- `public_subnet_ids` - List of public subnet IDs
- `private_subnet_ids` - List of private subnet IDs
- `database_subnet_ids` - List of database subnet IDs
- `internet_gateway_id` - Internet Gateway ID
- `nat_gateway_id` - NAT Gateway ID (null if disabled)
- `lambda_security_group_id` - Lambda security group ID
- `rds_security_group_id` - RDS security group ID

## RDS Module

### What It Creates
- **PostgreSQL 16 Database**: Managed RDS instance
- **Secrets Manager**: Auto-generated password storage
- **DB Subnet Group**: Spans database subnets across AZs
- **Parameter Group**: Custom PostgreSQL settings with connection logging
- **IAM Role**: For enhanced monitoring
- **Encryption**: All storage encrypted at rest
- **Backups**: Automated daily backups with 7-day retention
- **Monitoring**: Enhanced monitoring and Performance Insights enabled

### Environment-Specific Configuration
| Setting | Dev | Prod |
|---------|-----|------|
| Instance Class | db.t3.micro | db.t3.medium |
| Storage | 20GB (autoscale to 100GB) | 100GB (autoscale to 100GB) |
| Availability | Single-AZ | Multi-AZ |
| Monitoring Interval | 60 seconds | 30 seconds |
| Final Snapshot | Skipped | Taken on deletion |

### Module Inputs
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | (required) | Environment name (dev/prod) |
| project | string | (required) | Project name |
| vpc_id | string | (required) | VPC ID |
| subnet_ids | list(string) | (required) | Database subnet IDs |
| security_group_id | string | (required) | RDS security group ID |
| instance_class | string | db.t3.micro | RDS instance class |
| allocated_storage | number | 20 | Initial storage in GB |
| max_allocated_storage | number | 100 | Max storage for autoscaling |
| postgres_version | string | 16 | PostgreSQL version |
| db_name | string | qb_financial | Initial database name |
| db_username | string | dbadmin | Master username |
| backup_retention_days | number | 7 | Backup retention period |
| multi_az | bool | false | Enable Multi-AZ |
| monitoring_interval | number | 60 | Enhanced monitoring interval |
| backup_window | string | 03:00-04:00 | Backup window (UTC) |
| maintenance_window | string | sun:04:00-sun:05:00 | Maintenance window (UTC) |
| deletion_protection | bool | true | Enable deletion protection |
| skip_final_snapshot | bool | false | Skip final snapshot on deletion |

### Module Outputs
- `db_instance_id` - RDS instance ID
- `db_instance_endpoint` - Connection endpoint
- `db_instance_address` - Database address
- `db_instance_port` - Database port
- `db_name` - Database name
- `db_username` - Master username (sensitive)
- `db_password_secret_arn` - Secrets Manager ARN for password

## S3 Module

### What It Creates
- **4 S3 Buckets**:
  - `{project}-{environment}-qb-staging` - QuickBooks raw data staging
  - `{project}-{environment}-qb-logs` - ETL Lambda execution logs
  - `{project}-{environment}-qb-terraform-state` - Terraform remote state
  - `{project}-{environment}-qb-analytics-backups` - Pyplan dashboard backups
- **KMS CMK**: Customer-managed key for S3 encryption with automatic key rotation
- **Versioning**: Enabled on all buckets
- **Encryption**: SSE-KMS with bucket keys enabled (reduces KMS API costs)
- **Public Access**: Completely blocked on all buckets
- **Logging**: Server access logs sent to logs bucket
- **Lifecycle Policy**: Transition to Glacier after 90 days, expire after 2555 days (7 years for SOX compliance)

### Module Inputs
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | (required) | Environment name (dev/prod) |
| project | string | (required) | Project name |
| force_destroy | bool | false | Allow bucket deletion even if not empty |

### Module Outputs
- `staging_bucket_arn` - Staging bucket ARN
- `staging_bucket_name` - Staging bucket name
- `logs_bucket_arn` - Logs bucket ARN
- `logs_bucket_name` - Logs bucket name
- `terraform_state_bucket_arn` - Terraform state bucket ARN
- `terraform_state_bucket_name` - Terraform state bucket name
- `analytics_backups_bucket_arn` - Analytics backups bucket ARN
- `analytics_backups_bucket_name` - Analytics backups bucket name
- `kms_key_arn` - KMS key ARN for S3 encryption

## Lambda Module

### What It Creates
- **3 Lambda Functions**:
  - `{project}-{environment}-qb-extract` - Extracts data from QuickBooks API to S3 staging
  - `{project}-{environment}-qb-transform` - Transforms and cleans data in S3
  - `{project}-{environment}-qb-load` - Loads transformed data into RDS PostgreSQL
- **3 IAM Roles**: Separate execution roles with least privilege policies
- **3 CloudWatch Log Groups**: 90-day retention for Lambda execution logs
- **Step Functions State Machine**: Orchestrates Extract → Transform → Load pipeline
- **SNS Topic**: Email alerts for pipeline failures
- **Step Functions IAM Role**: Permissions to invoke Lambdas and publish to SNS

### Lambda Configuration
| Setting | Value |
|---------|-------|
| Runtime | Python 3.12 |
| Timeout | 600 seconds |
| Memory | 1024 MB |
| VPC | Deployed in private subnets |
| Environment Variables | ENVIRONMENT, PROJECT, STAGING_BUCKET, DB_SECRET_ARN, RDS_ENDPOINT |

### IAM Roles & Permissions
| Role | Permissions |
|------|-------------|
| qb-extract-role | Secrets Manager read (QB API + DB), S3 write to staging, CloudWatch logs, VPC networking |
| qb-transform-role | S3 read/write to staging, CloudWatch logs, VPC networking |
| qb-load-role | S3 read from staging, Secrets Manager read (DB), CloudWatch logs, VPC networking |
| etl-sfn-role | Lambda invoke (all 3 functions), SNS publish, CloudWatch logs |

### Step Functions Pipeline
- **Flow**: Extract → Transform → Load (sequential)
- **Retry Logic**: 3 attempts, 30 second interval, backoff rate 2
- **Error Handling**: On failure, sends SNS alert with error details and moves to Fail state
- **State Passing**: Output of each step passed as input to next step

### Module Inputs
| Variable | Type | Description |
|----------|------|-------------|
| environment | string | Environment name (dev/prod) |
| project | string | Project name |
| subnet_ids | list(string) | Private subnet IDs for Lambda |
| lambda_security_group_id | string | Security group ID for Lambda |
| staging_bucket_arn | string | Staging bucket ARN |
| staging_bucket_name | string | Staging bucket name |
| logs_bucket_arn | string | Logs bucket ARN |
| db_secret_arn | string | RDS password secret ARN |
| rds_endpoint | string | RDS instance endpoint |
| alert_email | string | Email for ETL failure alerts |
| qb_api_secret_arn | string | QuickBooks API credentials secret ARN |

### Module Outputs
- `extract_function_arn` - Extract Lambda ARN
- `transform_function_arn` - Transform Lambda ARN
- `load_function_arn` - Load Lambda ARN
- `extract_role_arn` - Extract IAM role ARN
- `transform_role_arn` - Transform IAM role ARN
- `load_role_arn` - Load IAM role ARN
- `state_machine_arn` - Step Functions state machine ARN
- `sns_topic_arn` - SNS topic ARN

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
terraform plan -var-file="environments/dev.tfvars"
```

### Apply Configuration
```bash
terraform apply -var-file="environments/dev.tfvars"
```

### Destroy Infrastructure
```bash
terraform destroy -var-file="environments/dev.tfvars"
```

### Check AWS Profile
```bash
aws sts get-caller-identity
echo $AWS_PROFILE
```

## Variables

### Root Variables
- `environment` - Environment name (required)
- `aws_region` - AWS region (default: us-east-1)
- `project` - Project name (default: qb-financial-warehouse)
- `alert_email` - Email address for ETL failure alerts (required)
- `qb_api_secret_arn` - QuickBooks API credentials secret ARN (required)

### Configuration Files
- `environments/dev.tfvars` - Development environment variables
- `environments/prod.tfvars` - Production environment variables (when ready)

## Requirements
- Terraform >= 1.2
- AWS Provider ~> 5.92
- AWS CLI configured with valid credentials
- Personal AWS account for testing

## Additional Documentation
- `personal_testing.md` - Step-by-step guide for personal AWS testing
- `environments/dev.tfvars` - Development configuration with placeholder values

## Additional Documentation
- `personal_testing.md` - Step-by-step guide for personal AWS testing
- `environments/dev.tfvars` - Development configuration with placeholder values
