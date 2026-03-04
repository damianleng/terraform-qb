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
└── modules/
    ├── vpc/            # VPC module
    │   ├── main.tf
    │   ├── variables.tf
    │   └── output.tf
    └── rds/            # RDS module
        ├── main.tf
        ├── variables.tf
        └── output.tf
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

## Usage

### Initialize Terraform
```bash
terraform init
```

### Plan Changes
```bash
terraform plan -var="environment=dev"
```

### Apply Configuration
```bash
terraform apply -var="environment=dev"
```

### Destroy Infrastructure
```bash
terraform destroy -var="environment=dev"
```

## Variables

### Root Variables
- `environment` - Environment name (required)
- `aws_region` - AWS region (default: us-east-1)
- `project` - Project name (default: qb-financial-warehouse)

## Requirements
- Terraform >= 1.2
- AWS Provider ~> 5.92
