output "role_arns" {
  description = "IAM role ARN for each environment, to put into the GitHub workflows"
  value       = { for name, role in aws_iam_role.deploy : name => role.arn }
}
# The role ARNs. You will paste them into the GitHub Actions workflows
# (in the application repository) so they know which role to use.
