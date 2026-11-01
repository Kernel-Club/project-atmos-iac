output "role_arn" {
  description = "IAM role of the AWS Load Balancer Controller"
  value       = aws_iam_role.lb_controller.arn
}

output "service_account" {
  description = "Namespace and service account that get the IAM role"
  value = {
    namespace = aws_eks_pod_identity_association.lb_controller.namespace
    name      = aws_eks_pod_identity_association.lb_controller.service_account
  }
}
