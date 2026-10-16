# ---------------------------------------------------------------------------
# BOOTSTRAP: creates the S3 bucket that stores the Terraform state.
#
# What is "state"? Terraform writes a file that remembers which AWS resources
# it created. Without it, Terraform would not know what to update or destroy.
#
# Why a separate "bootstrap" folder? The main project keeps its state IN this
# bucket, so the bucket must exist BEFORE the main project. We create it once
# here and we never destroy it. The bucket costs almost nothing.
# ---------------------------------------------------------------------------

# A "data" block only READS information. It does not create anything.
# Here we ask AWS: "Which account am I using?"
data "aws_caller_identity" "current" {}

locals {
  # S3 bucket names must be unique in the whole world.
  # Adding the account ID makes our name unique.
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# The bucket itself.
resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # Safety lock: if someone runs "terraform destroy" here, Terraform refuses.
  # Losing this bucket would mean losing track of all our infrastructure.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning keeps old copies of the state file.
# If the state gets damaged, we can go back to a previous version.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption: the state file can contain sensitive data, so we encrypt it.
# AES256 is free (it uses a key managed by S3, no KMS charges).
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block ALL public access. The state must never be readable from the internet.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule: delete OLD versions of the state after 30 days.
# This keeps the bucket small, so it stays almost free.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # Versioning must be turned on before this rule is created.
  depends_on = [aws_s3_bucket_versioning.tfstate]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    # An empty filter means "apply to every object in the bucket".
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Only allow encrypted connections (HTTPS) to the bucket.
# This policy DENIES any request that does not use HTTPS.
resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id

  # The public access block must exist first, otherwise AWS may reject changes.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
