# QB Financial Data Warehouse — Terraform Infrastructure

## Overview

This project manages AWS infrastructure for the QuickBooks Financial Data Warehouse using Terraform with a modular approach. It supports two environments (dev and prod) with automated CI/CD via GitHub Actions.

## Project Structure

```
.
├── main.tf                          # Root module — calls child modules
├── variables.tf                     # Root-level input variables
├── outputs.tf                       # Root-level outputs
├── terraform.tf                     # Provider and version configuration
├── .gitignore                       # Git ignore rules
├── environments/
│   ├── dev.tfvars                   # Dev environment variables (gitignored)
│   ├── dev.tfvars.example           # Dev template
│   ├── prod.tfvars                  # Prod environment variables (gitignored)
│   └── prod.tfvars.example          # Prod template
├── .github/
│   └── workflows/
│       ├── terraform.yml            # CI/CD pipeline
│       └── terraform-destroy.yml   # Manual destroy workflow
└── modules/
    ├── vpc/                         # VPC, subnets, security groups
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/                         # PostgreSQL RDS instance
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── s3/                          # S3 buckets with KMS encryption
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── lambda/                      # Lambda ETL functions + Step Functions
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── iam/                         # IAM, CloudTrail, GitHub OIDC role
        ├── main.tf
        ├── github_actions.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Modules

### VPC Module

**What it creates:**
- VPC: `10.0.0.0/16` with DNS support enabled
- Public subnets: `10.0.0.0/24`, `10.0.1.0/24` across 2 AZs
- Private subnets: `10.0.2.0/24`, `10.0.3.0/24` across 2 AZs
- Database subnets: `10.0.4.0/24`, `10.0.5.0/24` across 2 AZs (fully isolated)
- Internet Gateway, NAT Gateway, route tables
- Lambda security group (outbound to internet)
- RDS security group (inbound from Lambda only, outbound VPC-only)

**Outputs:** `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids`, `database_subnet_ids`, `internet_gateway_id`, `nat_gateway_id`, `lambda_security_group_id`, `rds_security_group_id`

---

### RDS Module

**What it creates:**
- PostgreSQL 16 RDS instance
- Customer-managed KMS key for storage encryption with automatic rotation
- Secrets Manager secret storing credentials as JSON (username, password, host, port, dbname)
- DB subnet group, parameter group, enhanced monitoring IAM role
- Performance Insights enabled

**Environment-specific config:**

| Setting | Dev | Prod |
|---|---|---|
| Instance Class | db.t3.micro | db.t3.medium |
| Storage | 20GB (autoscale to 100GB) | 100GB (autoscale to 100GB) |
| Multi-AZ | false | true |
| Monitoring Interval | 60s | 30s |
| Backup Retention | 7 days | 90 days |
| Deletion Protection | false | true |
| Final Snapshot | Skipped | Taken |

**Outputs:** `db_instance_id`, `db_instance_endpoint`, `db_instance_address`, `db_instance_port`, `db_name`, `db_username`, `db_password_secret_arn`, `rds_kms_key_arn`

---

### S3 Module

**What it creates:**

| Bucket | Purpose |
|---|---|
| `{project}-{environment}-qb-staging` | Raw QuickBooks data landing zone before RDS load |
| `{project}-{environment}-qb-logs` | ETL Lambda execution logs (long-term audit trail) |
| `{project}-{environment}-qb-terraform-state` | Terraform remote state storage |
| `{project}-{environment}-qb-analytics-backups` | Pyplan dashboard backups |

All buckets have:
- KMS CMK encryption with bucket keys enabled (reduces API costs)
- Versioning enabled
- All public access blocked
- Bucket policies enforcing KMS encryption and HTTPS only
- Lifecycle: Glacier after 90 days, expire after 2555 days (7 years, SOX compliance)
- Server access logging to logs bucket (logs bucket does not log itself)

**Outputs:** `staging_bucket_arn`, `staging_bucket_name`, `logs_bucket_arn`, `logs_bucket_name`, `terraform_state_bucket_arn`, `terraform_state_bucket_name`, `analytics_backups_bucket_arn`, `analytics_backups_bucket_name`, `kms_key_arn`

---

### Lambda Module

**What it creates:**
- 3 Lambda functions (Python 3.12, 1024MB, 600s timeout, deployed in private subnets)
- 3 IAM execution roles with least privilege policies
- 3 CloudWatch log groups (90-day retention)
- Step Functions state machine: Extract → Transform → Load
- SNS topic for ETL failure alerts with email subscription

**ETL Pipeline:**

```
Extract (QB API → S3 staging)
     ↓ retry 3x, 30s interval, backoff 2
Transform (S3 staging → clean data)
     ↓ retry 3x, 30s interval, backoff 2
Load (S3 staging → RDS PostgreSQL)
     ↓ on any failure
NotifyFailure (SNS alert with error details)
     ↓
FailState
```

**IAM roles:**

| Role | Permissions |
|---|---|
| qb-extract-role | Secrets Manager read (QB API + DB), S3 write to staging, CloudWatch logs, VPC networking |
| qb-transform-role | S3 read/write staging, CloudWatch logs, VPC networking |
| qb-load-role | S3 read staging, Secrets Manager read (DB), CloudWatch logs, VPC networking |
| etl-sfn-role | Lambda invoke (all 3), SNS publish, CloudWatch log delivery |

**Outputs:** `extract_function_arn`, `transform_function_arn`, `load_function_arn`, `extract_role_arn`, `transform_role_arn`, `load_role_arn`, `state_machine_arn`, `sns_topic_arn`

---

### IAM Module

**What it creates:**
- Account password policy (14 char min, 90-day expiry, 24-key reuse prevention)
- MFA enforcement policy (denies all actions without MFA except MFA setup)
- IAM group with MFA policy attached
- CloudTrail (multi-region, log file validation, KMS encrypted)
- KMS key for CloudTrail logs
- IAM Access Analyzer (account-level)
- GitHub Actions OIDC provider and IAM role for CI/CD authentication

**Outputs:** `cloudtrail_arn`, `cloudtrail_kms_key_arn`, `access_analyzer_arn`, `github_actions_role_arn`

---

## Prerequisites — Manual Setup (One Time Only)

These resources must be created manually before running `terraform init` because Terraform needs them to store state.

### 1. Create S3 State Buckets

```bash
# Dev state bucket
aws s3api create-bucket \
  --bucket qb-financial-warehouse-dev-qb-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket qb-financial-warehouse-dev-qb-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket qb-financial-warehouse-dev-qb-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Prod state bucket
aws s3api create-bucket \
  --bucket qb-financial-warehouse-prod-qb-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket qb-financial-warehouse-prod-qb-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket qb-financial-warehouse-prod-qb-terraform-state \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

### 2. Create Separate DynamoDB Lock Tables

Dev and prod use separate lock tables to prevent conflicts when running simultaneously.

```bash
# Dev lock table
aws dynamodb create-table \
  --table-name qb-financial-warehouse-dev-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Prod lock table
aws dynamodb create-table \
  --table-name qb-financial-warehouse-prod-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Create GitHub OIDC Provider (if not already exists)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region us-east-1
```

If it already exists you'll get an `EntityAlreadyExists` error — that's fine, import it into Terraform state instead:

```bash
terraform import module.iam.aws_iam_openid_connect_provider.github \
  arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### 4. Bootstrap IAM Module (OIDC Role)

The GitHub Actions OIDC role must exist before the pipeline can authenticate. Bootstrap it locally once:

```bash
terraform apply -var-file="environments/dev.tfvars" -target=module.iam
```

### 5. Add GitHub Secrets

Go to GitHub repo → Settings → Secrets and variables → Actions:
- `AWS_ACCOUNT_ID` — your AWS account ID
- `AWS_REGION` — `us-east-1`

### 6. Set Up Production Environment in GitHub

Go to GitHub repo → Settings → Environments → New environment:
- Name: `production`
- Enable **Required reviewers** and add yourself
- Save

---

## Usage

### Initialize Terraform

```bash
# Dev
terraform init \
  -backend-config="bucket=qb-financial-warehouse-dev-qb-terraform-state" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=qb-financial-warehouse-dev-terraform-locks" \
  -backend-config="encrypt=true"

# Prod
terraform init \
  -backend-config="bucket=qb-financial-warehouse-prod-qb-terraform-state" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=qb-financial-warehouse-prod-terraform-locks" \
  -backend-config="encrypt=true"
```

### Plan and Apply

```bash
terraform plan -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/dev.tfvars"
```

### Switch Between Environments Locally

```bash
terraform init -reconfigure \
  -backend-config="bucket=qb-financial-warehouse-prod-qb-terraform-state" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=qb-financial-warehouse-prod-terraform-locks" \
  -backend-config="encrypt=true"
```

---

## Destroying Infrastructure

### Important — Disable RDS Deletion Protection Before Destroying Prod

Prod RDS has deletion protection enabled. You must disable it first or destroy will fail:

```bash
aws rds modify-db-instance \
  --db-instance-identifier qb-financial-warehouse-prod-postgres \
  --no-deletion-protection \
  --apply-immediately \
  --region us-east-1
```

Wait 2 minutes then verify:

```bash
aws rds describe-db-instances \
  --db-instance-identifier qb-financial-warehouse-prod-postgres \
  --region us-east-1 \
  --query "DBInstances[*].{ID:DBInstanceIdentifier,DeletionProtection:DeletionProtection}"
```

### Destroy Dev

```bash
terraform init -reconfigure \
  -backend-config="bucket=qb-financial-warehouse-dev-qb-terraform-state" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=qb-financial-warehouse-dev-terraform-locks" \
  -backend-config="encrypt=true"

terraform destroy -var-file="environments/dev.tfvars"
```

### Destroy Prod

```bash
terraform init -reconfigure \
  -backend-config="bucket=qb-financial-warehouse-prod-qb-terraform-state" \
  -backend-config="key=terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=qb-financial-warehouse-prod-terraform-locks" \
  -backend-config="encrypt=true"

terraform destroy -var-file="environments/prod.tfvars"
```

### Notes on Destroy
- Always destroy dev before prod to avoid DynamoDB lock conflicts
- If destroy fails due to RDS timing, rerun `terraform destroy` — it picks up where it left off
- Lambda ENIs can take 20-40 minutes to release after destroy — wait before manually cleaning up VPC resources
- If you get an orphaned lock error, force unlock: `terraform force-unlock LOCK_ID`

---

## CI/CD Pipeline

### Workflow Overview

**Triggers:**
- Push to `main` — runs all jobs (check, plan dev, apply dev, plan prod, apply prod)
- Pull request to `main` — runs check and plan only (no apply)

**Jobs:**

```
terraform-check (fmt + validate)
     ↓
terraform-plan-dev (posts plan to PR comment)
     ↓
terraform-apply-dev (auto on merge to main)
     ↓
terraform-plan-prod (auto after dev apply)
     ↓
⏸ Manual approval required (production environment)
     ↓
terraform-apply-prod
```

### Authentication
- GitHub OIDC — no static AWS credentials stored anywhere
- IAM role: `qb-financial-warehouse-github-actions-role`
- Restricted to repo `damianleng/terraform-qb` on `main` branch only

### Manual Destroy via GitHub Actions
Go to Actions → Terraform Destroy → Run workflow:
- Select environment (`dev` or `prod`)
- Type `DESTROY` to confirm
- Click Run

---

## Migrating to Client Repository

When deploying to a client's AWS account and GitHub repo, update these locations:

### 1. GitHub Actions Workflow (`.github/workflows/terraform.yml`)

```yaml
# Update AWS account ID
role-to-assume: arn:aws:iam::CLIENT_ACCOUNT_ID:role/qb-financial-warehouse-github-actions-role

# Update backend bucket names
-backend-config="bucket=qb-financial-warehouse-dev-qb-terraform-state"
-backend-config="bucket=qb-financial-warehouse-prod-qb-terraform-state"

# Dev jobs
-backend-config="dynamodb_table=qb-financial-warehouse-dev-terraform-locks"

# Prod jobs
-backend-config="dynamodb_table=qb-financial-warehouse-prod-terraform-locks"
```

### 2. IAM Module (`modules/iam/github_actions.tf`)

```hcl
variable "github_repo" {
  default = "client-org/client-repo"
}

variable "github_branch" {
  default = "main"
}
```

### 3. Environment Variables (`environments/*.tfvars`)

```hcl
alert_email       = "client-email@example.com"
qb_api_secret_arn = "arn:aws:secretsmanager:us-east-1:CLIENT_ACCOUNT_ID:secret:client-qb-api"
github_repo       = "client-org/client-repo"
```

### 4. GitHub Secrets (Client Repo Settings)
- `AWS_ACCOUNT_ID` — client AWS account ID
- `AWS_REGION` — client AWS region

### 5. Repeat Manual Setup Steps
Run all steps in the Prerequisites section above using the client's AWS account credentials.

### Summary of Changes

| Item | Location | Change |
|---|---|---|
| AWS Account ID | `.github/workflows/terraform.yml`, `modules/iam/github_actions.tf` | Update to client account |
| AWS Region | `.github/workflows/terraform.yml`, `environments/*.tfvars` | Update if different |
| GitHub Repo | `modules/iam/github_actions.tf`, `environments/*.tfvars` | Update to client repo |
| Email | `environments/*.tfvars` | Update to client email |
| GitHub Secrets | GitHub repo settings | Update `AWS_ACCOUNT_ID` and `AWS_REGION` |
| Backend Infrastructure | AWS account | Create S3 buckets and DynamoDB tables |

---

## Requirements

- Terraform >= 1.2
- AWS Provider ~> 5.0
- AWS CLI configured with valid credentials
- Personal AWS account for testing

## Root Variables

| Variable | Description | Required |
|---|---|---|
| `environment` | Environment name (dev or prod) | Yes |
| `project` | Project name | Yes |
| `aws_region` | AWS region | No (default: us-east-1) |
| `alert_email` | Email for ETL failure alerts | Yes |
| `qb_api_secret_arn` | QuickBooks API credentials secret ARN | Yes |

## Additional Documentation

- `personal_testing.md` — Step-by-step guide for personal AWS testing
- `environments/dev.tfvars.example` — Dev configuration template
- `environments/prod.tfvars.example` — Prod configuration template