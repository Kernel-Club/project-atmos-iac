output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_region" {
  description = "Region of the state bucket"
  value       = var.aws_region
}

output "plan_role_arn" {
  description = "IAM role for terraform plan in GitHub Actions"
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "IAM role for terraform apply in GitHub Actions"
  value       = aws_iam_role.apply.arn
}
