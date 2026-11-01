locals {
  # AmazonEKSEditPolicy does not cover CRDs (ExternalSecret, Gateway, ...).
  # modules/platform gives this group a Role for them in each namespace.
  deployer_group = "deployers"
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "deploy" {
  for_each = var.environments

  name        = "${var.project_name}-github-${each.key}"
  description = "Used by GitHub Actions to deploy to the ${each.value.namespace} namespace"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        # Lock: only this repository and this GitHub Environment can use the role.
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # GitHub sends the sub as name@id/name@id
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@${var.github_org_id}/${var.github_repo}@${var.github_repo_id}:environment:${each.value.github_environment}"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "describe_cluster" {
  for_each = var.environments

  name = "DescribeEksCluster"
  role = aws_iam_role.deploy[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = var.cluster_arn
      }
    ]
  })
}

resource "aws_eks_access_entry" "deploy" {
  for_each = var.environments

  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_role.deploy[each.key].arn
  type              = "STANDARD"
  kubernetes_groups = [local.deployer_group]
}

resource "aws_eks_access_policy_association" "deploy" {
  for_each = var.environments

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.deploy[each.key].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [each.value.namespace]
  }

  depends_on = [aws_eks_access_entry.deploy]
}
