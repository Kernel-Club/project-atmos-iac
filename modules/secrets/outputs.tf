output "openweather_secret_names" {
  description = "Secrets Manager names of the OpenWeather key, per environment"
  value       = { for env, s in aws_secretsmanager_secret.openweather : env => s.name }
}

output "mongodb_secret_names" {
  description = "Secrets Manager names of the MongoDB credentials, per environment"
  value       = { for env, s in aws_secretsmanager_secret.mongodb : env => s.name }
}

output "external_secrets_role_arn" {
  description = "IAM role used by External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}
# Names of the secrets. You will use them in the Kubernetes manifests (ExternalSecret)
# in the project-atmos-k8s repository.
