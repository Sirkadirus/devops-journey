data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_s3_backups" {
  name               = "ec2-s3-backups-role-tf"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Project = "devops-journey-fase8"
  }
}

data "aws_iam_policy_document" "s3_backups" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.backups.arn]
  }

  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.backups.arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_backups" {
  name   = "S3-backups-policy-tf"
  role   = aws_iam_role.ec2_s3_backups.id
  policy = data.aws_iam_policy_document.s3_backups.json
}

resource "aws_iam_instance_profile" "ec2_s3_backups" {
  name = "ec2-s3-backups-profile-tf"
  role = aws_iam_role.ec2_s3_backups.name
}