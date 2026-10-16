output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}
# Values printed after "terraform apply". The next modules (EKS) will use them.

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "URL of the Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "kubeconfig_command" {
  description = "Command that sets up kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
# kubeconfig_command: run this command after apply and kubectl will talk to the new cluster.

output "github_actions_role_arns" {
  description = "IAM role ARN per environment for GitHub Actions"
  value       = module.github_actions.role_arns
}
# Copy these two ARNs into the GitHub workflows after apply.

output "openweather_secret_names" {
  description = "Secrets Manager names of the OpenWeather key"
  value       = module.secrets.openweather_secret_names
}

output "mongodb_secret_names" {
  description = "Secrets Manager names of the MongoDB credentials"
  value       = module.secrets.mongodb_secret_names
}

output "external_secrets_role_arn" {
  description = "IAM role of External Secrets Operator"
  value       = module.secrets.external_secrets_role_arn
}
# Names and role for the Kubernetes repository.
