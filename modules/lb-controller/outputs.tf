output "role_arn" {
  description = "IAM role of the AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}
