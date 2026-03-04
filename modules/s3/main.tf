resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project}-${var.environment}-s3-kms"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# Staging bucket
resource "aws_s3_bucket" "staging" {
  bucket        = "${var.project}-${var.environment}-qb-staging"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project}-${var.environment}-qb-staging"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "staging" {
  bucket = aws_s3_bucket.staging.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "staging-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

# Logs bucket
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project}-${var.environment}-qb-logs"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project}-${var.environment}-qb-logs"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

# Terraform state bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "${var.project}-${var.environment}-qb-terraform-state"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project}-${var.environment}-qb-terraform-state"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "terraform-state-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "archive-only"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# Analytics backups bucket
resource "aws_s3_bucket" "analytics_backups" {
  bucket        = "${var.project}-${var.environment}-qb-analytics-backups"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project}-${var.environment}-qb-analytics-backups"
    Environment = var.environment
    Project     = var.project
  }
}

resource "aws_s3_bucket_versioning" "analytics_backups" {
  bucket = aws_s3_bucket.analytics_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics_backups" {
  bucket = aws_s3_bucket.analytics_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "analytics_backups" {
  bucket = aws_s3_bucket.analytics_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "analytics_backups" {
  bucket = aws_s3_bucket.analytics_backups.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "analytics-backups-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "analytics_backups" {
  bucket = aws_s3_bucket.analytics_backups.id

  rule {
    id     = "archive-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}
