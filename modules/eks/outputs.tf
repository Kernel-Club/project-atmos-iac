output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "URL of the Kubernetes API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "node_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.node.arn
}
# Values that the EKS module gives back to the project root.
# The next modules (IAM for GitHub Actions, secrets) will use the cluster name.
