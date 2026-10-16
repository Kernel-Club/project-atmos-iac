# Outputs print useful values after "terraform apply".
# We will copy these values into the backend settings of the main project.

output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_region" {
  description = "Region of the state bucket"
  value       = var.aws_region
}
