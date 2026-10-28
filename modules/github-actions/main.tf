data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "deploy" {
  for_each = var.environments

  name        = "${var.project_name}-github-${each.key}"
  description = "Used by GitHub Actions to deploy to ${each.value.namespace != null ? "the ${each.value.namespace} namespace" : "the whole cluster"}"

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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:environment:${each.value.github_environment}"
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

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.deploy[each.key].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy" {
  for_each = var.environments

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.deploy[each.key].arn
  policy_arn    = each.value.namespace != null ? "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy" : "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type       = each.value.namespace != null ? "namespace" : "cluster"
    namespaces = each.value.namespace != null ? [each.value.namespace] : null
  }

  depends_on = [aws_eks_access_entry.deploy]
}
