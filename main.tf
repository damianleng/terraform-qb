module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  project     = var.project
}

module "rds" {
  source            = "./modules/rds"
  environment       = var.environment
  project           = var.project
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.database_subnet_ids
  security_group_id = module.vpc.rds_security_group_id

  instance_class        = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage     = var.environment == "prod" ? 100 : 20
  multi_az              = var.environment == "prod" ? true : false
  monitoring_interval   = var.environment == "prod" ? 30 : 60
  skip_final_snapshot   = var.environment == "dev" ? true : false
  backup_retention_days = var.environment == "prod" ? 30 : 7
}

# module "s3" {
#   source      = "./modules/s3"
#   environment = var.environment
#   project     = var.project
# }

# module "iam" {
#   source      = "./modules/iam"
#   environment = var.environment
#   project     = var.project
# }

