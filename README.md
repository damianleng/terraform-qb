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

### RDS Security
- **KMS Encryption**: Customer-managed key for storage encryption with automatic rotation
- **Secrets Manager**: Auto-generated password stored securely
- **Enhanced Monitoring**: OS-level metrics sent to CloudWatch
- **Performance Insights**: Enabled for performance analysis
- **Deletion Protection**: Enabled on prod, disabled on dev
- **Backup Strategy**: Automated daily backups with 7-day retention (dev) or 30-day (prod)

### Module Outputs
- `db_instance_id` - RDS instance ID
- `db_instance_endpoint` - Connection endpoint
- `db_instance_address` - Database address
- `db_instance_port` - Database port
- `db_name` - Database name
- `db_username` - Master username (sensitive)
- `db_password_secret_arn` - Secrets Manager ARN for password
- `rds_kms_key_arn` - ARN of the KMS key used for RDS encryption
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

### S3 Security
- **KMS Encryption**: Customer-managed key for all buckets with automatic rotation
- **Bucket Policies**: Deny unencrypted uploads and insecure transport (HTTPS only)
- **Public Access**: Completely blocked on all buckets
- **Versioning**: Enabled for data recovery
- **Bucket Keys**: Enabled to reduce KMS API calls and costs
- **Server Logging**: Access logs sent to dedicated logs bucket
- **Lifecycle Management**: Automatic archival to Glacier after 90 days, expiration after 2555 days (SOX compliance)

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

## IAM Module

### What It Creates
- **KMS Key for CloudTrail** - Customer-managed key with automatic rotation for encrypting API logs
- **CloudTrail** - Multi-region API logging with log file validation enabled
- **S3 Bucket Policy** - Allows CloudTrail to write encrypted logs, denies unencrypted transport
- **IAM Password Policy** - Enforces strong passwords across all IAM users
- **IAM Access Analyzer** - Scans account for external resource access
- **MFA Enforcement Policy** - Denies all actions without MFA (except MFA setup)

### Password Policy Requirements
- Minimum 14 characters
- Requires uppercase, lowercase, numbers, and symbols
- 90-day expiration
- 24-key reuse prevention
- Users can change their own password

### CloudTrail Configuration
- Multi-region trail captures all API calls
- Log file validation enabled for integrity checking
- Logs encrypted with customer-managed KMS key
- Stored in S3 with HTTPS-only access

### Module Inputs
| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| environment | string | (required) | Environment name (dev/prod) |
| project | string | (required) | Project name |
| cloudtrail_s3_bucket_name | string | (required) | S3 bucket for CloudTrail logs |
| enable_access_analyzer | bool | true | Enable IAM Access Analyzer |
| password_min_length | number | 14 | Minimum password length |
| password_require_symbols | bool | true | Require symbols in password |
| password_require_numbers | bool | true | Require numbers in password |
| password_require_uppercase | bool | true | Require uppercase in password |
| password_require_lowercase | bool | true | Require lowercase in password |
| password_max_age | number | 90 | Password expiration in days |

### Module Outputs
- `cloudtrail_arn` - CloudTrail ARN
- `cloudtrail_kms_key_arn` - KMS key ARN for CloudTrail encryption
- `access_analyzer_arn` - IAM Access Analyzer ARN

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


## GitHub Actions CI/CD Pipeline

### Workflow Overview
The project includes automated CI/CD with GitHub Actions for dev and prod deployments.

**Workflow Triggers:**
- Push to `main` branch - Runs all jobs (check, plan dev, apply dev, plan prod, apply prod)
- Pull request to `main` - Runs check and plan jobs only (no apply)
- Feature branches - No workflow triggers

**Jobs:**
1. `terraform-check` - Format validation and syntax check
2. `terraform-plan-dev` - Plans dev changes, posts to PR comment
3. `terraform-apply-dev` - Auto-applies dev on main push
4. `terraform-plan-prod` - Plans prod changes after dev apply
5. `terraform-apply-prod` - Requires manual approval before applying prod

### Authentication
- Uses GitHub OIDC provider for AWS authentication (no static keys)
- IAM role: `qb-financial-warehouse-github-actions-role`
- Restricted to specific GitHub repo and branch

### Required GitHub Secrets
- `AWS_ACCOUNT_ID` - AWS account ID
- `AWS_REGION` - AWS region (default: us-east-1)

### Required GitHub Environment
- `production` - Manual approval required before prod apply

## Migrating to Client Repository

When deploying to a client's GitHub repo and AWS account, update these locations:

### 1. GitHub Actions Workflow (`.github/workflows/terraform.yml`)
```yaml
# Update AWS account ID in role-to-assume
role-to-assume: arn:aws:iam::CLIENT_ACCOUNT_ID:role/qb-financial-warehouse-github-actions-role

# Update AWS region if different
aws-region: us-east-1  # or client's region

# Update S3 bucket names for backend
-backend-config="bucket=qb-financial-warehouse-dev-qb-terraform-state"
-backend-config="bucket=qb-financial-warehouse-prod-qb-terraform-state"

# Update DynamoDB table name if different
-backend-config="dynamodb_table=qb-financial-warehouse-terraform-locks"
```

### 2. IAM Module (`modules/iam/github_actions.tf`)
```hcl
# Update GitHub repo
variable "github_repo" {
  default = "client-org/client-repo"  # Change to client repo
}

# Update GitHub branch if not main
variable "github_branch" {
  default = "main"  # or client's branch
}

# Update AWS account ID in trust policy
grantee_principal = "arn:aws:iam::CLIENT_ACCOUNT_ID:user/cloud-admin-damian"
```

### 3. Environment Variables (`environments/dev.tfvars`, `environments/prod.tfvars`)
```hcl
alert_email       = "client-email@example.com"
qb_api_secret_arn = "arn:aws:secretsmanager:us-east-1:CLIENT_ACCOUNT_ID:secret:client-qb-api"
github_repo       = "client-org/client-repo"
github_branch     = "main"  # or client's branch
```

### 4. GitHub Actions Secrets (Repository Settings)
- `AWS_ACCOUNT_ID` - Set to client's AWS account ID
- `AWS_REGION` - Set to client's AWS region

### 5. AWS Manual Setup (Client Account)
Create these resources manually in the client's AWS account:

```bash
# Create dev state bucket
aws s3 mb s3://qb-financial-warehouse-dev-qb-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket qb-financial-warehouse-dev-qb-terraform-state --versioning-configuration Status=Enabled --region us-east-1

# Create prod state bucket
aws s3 mb s3://qb-financial-warehouse-prod-qb-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket qb-financial-warehouse-prod-qb-terraform-state --versioning-configuration Status=Enabled --region us-east-1

# Create DynamoDB lock table (shared between dev and prod)
aws dynamodb create-table \
  --table-name qb-financial-warehouse-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 6. GitHub OIDC Provider (Client Account)
If not already configured, create the OIDC provider:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1
```

### 7. IAM Role for GitHub Actions (Client Account)
The role `qb-financial-warehouse-github-actions-role` is created by Terraform. Ensure it exists and has proper trust policy for the client's GitHub repo.

### Summary of Changes
| Item | Location | Change |
|------|----------|--------|
| AWS Account ID | `.github/workflows/terraform.yml`, `modules/iam/github_actions.tf` | Update to client account |
| AWS Region | `.github/workflows/terraform.yml`, `environments/*.tfvars` | Update if different |
| GitHub Repo | `modules/iam/github_actions.tf`, `environments/*.tfvars` | Update to client repo |
| GitHub Branch | `modules/iam/github_actions.tf`, `environments/*.tfvars` | Update if not main |
| Email | `environments/*.tfvars` | Update to client email |
| Secrets | GitHub repo settings | Update AWS_ACCOUNT_ID and AWS_REGION |
| Backend Infrastructure | AWS account | Create S3 buckets and DynamoDB table |

All other code remains unchanged.
