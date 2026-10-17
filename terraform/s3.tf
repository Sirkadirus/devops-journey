resource "aws_s3_bucket" "backups" {
  bucket        = var.backups_bucket_name
  force_destroy = true # solo laboratorio: permite que destroy vacie el bucket

  tags = {
    Name    = "devops-journey-backups-tf"
    Project = "devops-journey-fase8"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}