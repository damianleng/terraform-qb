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
├── bootstrap/                       # One-time setup — run once, never destroyed
│   ├── main.tf                      # GitHub OIDC provider + Actions IAM role
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tf                 # Local state — do NOT migrate to S3
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
    ├── lambda/                      # Lambda ETL functions + Step Functions + monitoring
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── iam/                         # IAM, CloudTrail, GuardDuty, AWS Config
        ├── main.tf
        ├── github_actions.tf        # Empty — OIDC moved to bootstrap/
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
- CloudWatch alarms: CPU > 80%, free storage < 10GB, connections > 50

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
| `{project}-{environment}-qb-logs` | ETL logs, CloudTrail logs, AWS Config snapshots |
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
- CloudWatch alarms: Lambda errors, Lambda duration approaching timeout, Step Functions failures
- CloudWatch dashboard: Lambda errors, duration, Step Functions executions, RDS CPU and connections

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
- GuardDuty detector with S3 protection and malware scanning enabled
- EventBridge rule forwarding GuardDuty findings (severity >= 4) to SNS email alert
- AWS Config recorder tracking all supported resource types
- AWS Config delivery channel writing snapshots to logs S3 bucket under `config/` prefix
- 6 AWS Config managed rules: `rds-storage-encrypted`, `rds-backup-enabled`, `s3-bucket-encrypted`, `s3-public-access-blocked`, `root-mfa-enabled`, `cloudtrail-enabled`

> GitHub Actions OIDC provider and IAM role are managed in `bootstrap/` — not here.

**Outputs:** `cloudtrail_arn`, `cloudtrail_kms_key_arn`, `access_analyzer_arn`, `mfa_group_name`, `guardduty_detector_id`, `guardduty_sns_topic_arn`, `config_recorder_name`

---

## Prerequisites — One Time Setup

Follow these steps in order the first time you set up the project in a new AWS account.

### 1. Create S3 State Buckets (manual — Terraform can't manage its own state bucket)

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

### 2. Create DynamoDB Lock Tables (manual — dev and prod are separate)

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

### 3. Run Bootstrap (creates GitHub OIDC provider and Actions IAM role)

The `bootstrap/` folder manages the GitHub Actions OIDC provider and IAM role. These resources live outside the main infrastructure so they survive `terraform destroy` cycles.

```bash
cd bootstrap/
terraform init
terraform apply
```

Note the `github_actions_role_arn` output — it should match the `role-to-assume` in `.github/workflows/terraform.yml`.

> **Important:** The `bootstrap/terraform.tfstate` file uses local state intentionally. Do not migrate it to S3. Keep it safe — if lost you will need to re-import resources manually. Add `bootstrap/terraform.tfstate` and `bootstrap/terraform.tfstate.backup` to `.gitignore`.

### 4. Add GitHub Secrets

Go to GitHub repo → Settings → Secrets and variables → Actions:
- `AWS_ACCOUNT_ID` — your AWS account ID
- `AWS_REGION` — `us-east-1`

### 5. Set Up Production Environment in GitHub

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

### 1. Bootstrap (`bootstrap/variables.tf`)

```hcl
variable "github_repo" {
  default = "client-org/client-repo"
}
```

### 2. GitHub Actions Workflow (`.github/workflows/terraform.yml`)

```yaml
# The role name stays the same, just update the account ID via GitHub secret
role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/qb-financial-warehouse-github-actions-role
```

### 3. Environment Variables (`environments/*.tfvars`)

```hcl
alert_email          = "client-email@example.com"
qb_api_secret_arn    = "arn:aws:secretsmanager:us-east-1:CLIENT_ACCOUNT_ID:secret:client-qb-api"
monthly_budget_limit = "200"
```

### 4. GitHub Secrets (Client Repo Settings)
- `AWS_ACCOUNT_ID` — client AWS account ID
- `AWS_REGION` — client AWS region

### 5. Repeat Prerequisites
Run all steps in the Prerequisites section above using the client's AWS account credentials.

### Summary of Changes

| Item | Location | Change |
|---|---|---|
| GitHub Repo | `bootstrap/variables.tf` | Update to client repo |
| AWS Account ID | GitHub Secrets | Update `AWS_ACCOUNT_ID` |
| AWS Region | GitHub Secrets, `environments/*.tfvars` | Update if different |
| Email | `environments/*.tfvars` | Update to client email |
| Budget limit | `environments/*.tfvars` | Update to client budget |
| Backend Infrastructure | AWS account | Create S3 buckets and DynamoDB tables manually |

---

## Checking for Orphaned Resources

After a `terraform destroy`, run these commands to verify no resources were left behind. Any resources that still exist need to be either manually deleted or imported into Terraform state before the next `terraform apply`.

### Run All Checks

```bash
echo "=== RDS ===" && \
aws rds describe-db-instances --region us-east-1 \
  --query "DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}"

echo "=== VPC ===" && \
aws ec2 describe-vpcs --region us-east-1 \
  --filters "Name=tag:Project,Values=qb-financial-warehouse" \
  --query "Vpcs[*].{ID:VpcId,Name:Tags[?Key=='Name']|[0].Value}"

echo "=== Lambda ===" && \
aws lambda list-functions --region us-east-1 \
  --query "Functions[?starts_with(FunctionName,'qb-financial-warehouse')].FunctionName"

echo "=== S3 ===" && \
aws s3 ls | grep qb-financial-warehouse

echo "=== Step Functions ===" && \
aws stepfunctions list-state-machines --region us-east-1 \
  --query "stateMachines[?starts_with(name,'qb-financial-warehouse')].name"

echo "=== GuardDuty ===" && \
aws guardduty list-detectors --region us-east-1

echo "=== CloudTrail ===" && \
aws cloudtrail describe-trails --region us-east-1 \
  --query "trailList[?starts_with(Name,'qb-financial-warehouse')].Name"

echo "=== KMS Keys ===" && \
aws kms list-aliases --region us-east-1 \
  --query "Aliases[?starts_with(AliasName,'alias/qb-financial-warehouse')].AliasName"

echo "=== IAM Roles ===" && \
aws iam list-roles \
  --query "Roles[?starts_with(RoleName,'qb-financial-warehouse')].RoleName"
```

### Expected State After Destroy

After a successful destroy the only resources that should remain are:

| Resource | Expected | Reason |
|---|---|---|
| S3 state buckets (`*-terraform-state`) | Remain | Created manually — not managed by Terraform |
| IAM role `qb-financial-warehouse-github-actions-role` | Remains | Managed by `bootstrap/` — survives destroy intentionally |
| GuardDuty detector | Empty list | Should be fully destroyed |
| Everything else | Empty | Should be fully destroyed |

### Importing Orphaned Resources

If a resource still exists after destroy, import it before the next apply to avoid `EntityAlreadyExists` errors.

**GuardDuty detector:**
```bash
# Get detector ID
aws guardduty list-detectors --region us-east-1

terraform import 'module.iam.aws_guardduty_detector.main[0]' DETECTOR_ID
```

**AWS Config recorder:**
```bash
# Get recorder name
aws configservice describe-configuration-recorders --region us-east-1

terraform import 'module.iam.aws_config_configuration_recorder.main[0]' RECORDER_NAME
```

**AWS Config delivery channel:**
```bash
# Get delivery channel name
aws configservice describe-delivery-channels --region us-east-1

terraform import 'module.iam.aws_config_delivery_channel.main[0]' CHANNEL_NAME
```

> **Note:** Always use single quotes around resource addresses containing square brackets when running import commands in zsh — e.g. `'module.iam.aws_guardduty_detector.main[0]'` — otherwise zsh will throw `no matches found`.

### Fixing State Lock After Cancelled Run

If a GitHub Actions workflow was cancelled mid-run, the state lock may not be released. Force unlock with:

```bash
terraform force-unlock LOCK_ID
```

The lock ID is shown in the error message when you try to run plan or apply. If the lock was created by a local run, check the DynamoDB table directly:

```bash
# Dev
aws dynamodb scan --table-name qb-financial-warehouse-dev-terraform-locks --region us-east-1

# Prod
aws dynamodb scan --table-name qb-financial-warehouse-prod-terraform-locks --region us-east-1
```

---

## Requirements

- Terraform >= 1.2
- AWS Provider ~> 5.92
- AWS CLI configured with valid credentials
- Personal AWS account for testing

## Root Variables

| Variable | Description | Required |
|---|---|---|
| `environment` | Environment name (dev or prod) | Yes |
| `project` | Project name | Yes |
| `aws_region` | AWS region | No (default: us-east-1) |
| `alert_email` | Email for ETL and security alerts | Yes |
| `qb_api_secret_arn` | QuickBooks API credentials secret ARN | Yes |
| `monthly_budget_limit` | Monthly AWS spend limit in USD | No (default: 50) |

## Additional Documentation

- `CLAUDE.md` — Full project context for AI-assisted development
- `personal_testing.md` — Step-by-step guide for personal AWS testing
- `environments/dev.tfvars.example` — Dev configuration template
- `environments/prod.tfvars.example` — Prod configuration template