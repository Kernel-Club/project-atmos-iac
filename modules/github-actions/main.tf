data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
# Reads the GitHub "identity provider" that already exists in our AWS account.
# It tells AWS: "tokens signed by GitHub can be trusted".
# We only READ it here, we do not create it (an account can have only one).

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
# One IAM role per environment (dev and prod). GitHub Actions "puts on" this role
# without any access keys (this is called OIDC).
# The "sub" condition is the lock: only a workflow that runs in the repository
# <org>/<repo> AND in the GitHub Environment (for example "production") can use the role.
# So a workflow in another repository, or a PR job, cannot deploy.
# The "production" environment can also require a manual approval in GitHub.

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
# The only AWS permission the role has: read the cluster details.
# The pipeline needs it to run "aws eks update-kubeconfig" (to find the cluster address).
# Everything inside Kubernetes is controlled separately, below.

resource "aws_eks_access_entry" "deploy" {
  for_each = var.environments

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.deploy[each.key].arn
  type          = "STANDARD"
}
# An access entry lets the IAM role log in to the Kubernetes cluster.
# By itself it gives NO rights yet, rights come from the policy below.

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
# Gives the role its rights inside Kubernetes.
# - dev and prod roles get "Edit", but ONLY inside their own namespace (dev or prod).
#   Edit means: create and update Deployments, Services, ConfigMaps, and so on.
#   It can NOT create namespaces or cluster-wide objects.
# - The platform role (namespace = null) gets "ClusterAdmin" for the whole cluster.
#   It installs the platform (load balancer controller, External Secrets, namespaces).
#   This is the most powerful role, so its GitHub Environment must need approval.
