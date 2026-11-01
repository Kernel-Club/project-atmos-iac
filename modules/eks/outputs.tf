output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "URL of the Kubernetes API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "CA certificate of the Kubernetes API (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

# Same name, but known only when the nodes and add-ons are up.
# Charts installed with it wait for nodes, DNS and the EBS driver.
output "ready_cluster_name" {
  description = "Name of the EKS cluster, after the nodes and add-ons are ready"
  value       = aws_eks_cluster.main.name
  depends_on  = [aws_eks_addon.main]
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "node_role_arn" {
  description = "ARN of the worker node IAM role"
  value       = aws_iam_role.node.arn
}
