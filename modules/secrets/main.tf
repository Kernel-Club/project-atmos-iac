data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_secretsmanager_secret" "openweather" {
  for_each = var.environments

  name        = "${var.project_name}/${each.key}/openweather-api-key"
  description = "OpenWeather API key for the ${each.key} environment"
  # 0 = delete at once on destroy, otherwise the name stays locked and the next apply fails.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "openweather" {
  for_each = var.environments

  secret_id     = aws_secretsmanager_secret.openweather[each.key].id
  secret_string = var.openweather_api_key
}

resource "random_password" "mongodb" {
  for_each = var.environments

  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "mongodb" {
  for_each = var.environments

  name                    = "${var.project_name}/${each.key}/mongodb"
  description             = "MongoDB credentials for the ${each.key} environment"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mongodb" {
  for_each = var.environments

  secret_id = aws_secretsmanager_secret.mongodb[each.key].id
  secret_string = jsonencode({
    username = "atmos"
    password = random_password.mongodb[each.key].result
  })

  lifecycle {
    # Do not overwrite a rotated password.
    ignore_changes = [secret_string]
  }
}

resource "aws_iam_role" "external_secrets" {
  name = "${var.project_name}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "ReadProjectSecrets"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}
