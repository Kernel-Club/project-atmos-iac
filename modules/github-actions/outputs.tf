output "role_arns" {
  description = "IAM role ARN for each environment, to put into the GitHub workflows"
  value       = { for name, role in aws_iam_role.deploy : name => role.arn }
}
