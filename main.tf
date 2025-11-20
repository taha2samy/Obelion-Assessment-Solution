resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  bucket_name = "obelion-tf-state-${random_string.suffix.result}"
  table_name  = "obelion-tf-locks"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  # Prevent accidental deletion of this S3 bucket
  # lifecycle {
  #   prevent_destroy = true
  # }

  tags = {
    Name = "Terraform Remote State"
  }
}

resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "terraform_locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}
locals {
  backend_config_content = <<EOF
bucket         = "${aws_s3_bucket.terraform_state.id}"
key            = "global/s3/terraform.tfstate"
region         = "${aws_s3_bucket.terraform_state.region}"
dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
encrypt        = true
EOF
}
resource "local_file" "backend_config" {
  filename = "./backend.hcl"
  content  = local.backend_config_content
}
