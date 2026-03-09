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
  deletion_protection   = var.environment == "prod" ? true : false
}

module "s3" {
  source        = "./modules/s3"
  environment   = var.environment
  project       = var.project
  force_destroy = false
}

module "lambda" {
  source                   = "./modules/lambda"
  environment              = var.environment
  project                  = var.project
  subnet_ids               = module.vpc.private_subnet_ids
  lambda_security_group_id = module.vpc.lambda_security_group_id
  staging_bucket_arn       = module.s3.staging_bucket_arn
  staging_bucket_name      = module.s3.staging_bucket_name
  logs_bucket_arn          = module.s3.logs_bucket_arn
  db_secret_arn            = module.rds.db_password_secret_arn
  rds_endpoint             = module.rds.db_instance_endpoint
  alert_email              = var.alert_email
  qb_api_secret_arn        = var.qb_api_secret_arn
}


module "iam" {
  source                    = "./modules/iam"
  environment               = var.environment
  project                   = var.project
  cloudtrail_s3_bucket_name = module.s3.logs_bucket_name
}