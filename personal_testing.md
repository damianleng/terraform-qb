# Personal AWS Testing Guide

This guide walks through deploying the QuickBooks Financial Data Warehouse infrastructure to your personal AWS account for development testing.

## Prerequisites

- AWS CLI configured with credentials (`aws configure`)
- Terraform >= 1.2 installed
- Personal AWS account with admin access

## Step-by-Step Deployment

### 1. Update Configuration Files

**Edit `dev.tfvars`:**
```bash
# Replace with your actual email address
alert_email = "your-email@example.com"
```

The `qb_api_secret_arn` placeholder will work for initial deployment. You'll create the real secret later.

### 2. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and initializes the working directory.

### 3. First Deployment (VPC, RDS, S3, Lambda, DynamoDB)

```bash
terraform plan -var-file="dev.tfvars"
```

Review the plan. You should see:
- VPC with subnets, NAT gateway, security groups
- RDS PostgreSQL instance
- 4 S3 buckets with KMS encryption
- 3 Lambda functions with IAM roles
- Step Functions state machine
- SNS topic with email subscription
- DynamoDB table for state locking

```bash
terraform apply -var-file="dev.tfvars"
```

Type `yes` to confirm.

**Expected duration:** 10-15 minutes (RDS takes the longest)

### 4. Confirm SNS Email Subscription

After deployment, check your email for an SNS subscription confirmation from AWS. Click the confirmation link.

### 5. Create QuickBooks API Secret (Optional)

The Lambda functions reference a QuickBooks API secret. To create a real one:

```bash
aws secretsmanager create-secret \
  --name qb-financial-warehouse-dev-qb-api-credentials \
  --description "QuickBooks OAuth credentials for dev" \
  --secret-string '{"client_id":"placeholder","client_secret":"placeholder","refresh_token":"placeholder"}' \
  --region us-east-1
```

Get the ARN:
```bash
aws secretsmanager describe-secret \
  --secret-id qb-financial-warehouse-dev-qb-api-credentials \
  --region us-east-1 --query ARN --output text
```

Update `dev.tfvars` with the real ARN and run `terraform apply -var-file="dev.tfvars"` again.

### 6. Enable Remote State (Optional but Recommended)

After successful first deployment, enable S3 backend for remote state storage:

**Edit `terraform.tf`:**
Uncomment the backend block:
```hcl
backend "s3" {
  bucket         = "qb-financial-warehouse-dev-qb-terraform-state"
  key            = "terraform.tfstate"
  region         = "us-east-1"
  dynamodb_table = "qb-financial-warehouse-terraform-locks"
  encrypt        = true
}
```

**Migrate state:**
```bash
terraform init -migrate-state
```

Type `yes` to copy local state to S3.

Your state is now stored remotely with locking enabled.

## Testing the ETL Pipeline

### Invoke Step Functions Manually

```bash
aws stepfunctions start-execution \
  --state-machine-arn $(terraform output -raw state_machine_arn) \
  --input '{}' \
  --region us-east-1
```

Check execution in AWS Console → Step Functions → State machines

### View Lambda Logs

```bash
aws logs tail /aws/lambda/qb-financial-warehouse-dev-qb-extract --follow
```

## Values to Replace Later

| Placeholder | Location | Real Value Source |
|-------------|----------|-------------------|
| `qb_api_secret_arn` | `dev.tfvars` | Create secret in Secrets Manager with real QuickBooks OAuth credentials |
| `alert_email` | `dev.tfvars` | Your actual email address |

## Clean Teardown

To destroy all resources:

```bash
terraform destroy -var-file="dev.tfvars"
```

Type `yes` to confirm.

**Important notes:**
- S3 buckets will be deleted (force_destroy = true in dev)
- RDS will skip final snapshot (skip_final_snapshot = true in dev)
- DynamoDB table will be deleted
- If using remote state, your state file remains in S3 after destroy

To delete the state bucket manually:
```bash
aws s3 rm s3://qb-financial-warehouse-dev-qb-terraform-state --recursive
aws s3 rb s3://qb-financial-warehouse-dev-qb-terraform-state
```

## Troubleshooting

### Lambda can't connect to RDS
- Check security groups: Lambda SG should be allowed in RDS SG
- Verify Lambda is in private subnets with NAT gateway access
- Check RDS endpoint in Lambda environment variables

### SNS email not received
- Check spam folder
- Verify email in `dev.tfvars` is correct
- Check SNS topic subscriptions in AWS Console

### Terraform state locked
If a previous apply failed and left a lock:
```bash
terraform force-unlock <LOCK_ID>
```

### Cost Estimate (Dev Environment)
- NAT Gateway: ~$32/month
- RDS db.t3.micro: ~$15/month
- S3 storage: <$1/month (minimal data)
- Lambda: Free tier covers testing
- **Total: ~$50/month**

Stop NAT gateway when not testing to save costs (requires infrastructure changes).
