# ---------------------------------------------------------------------------
# 1. IAM role for the EKS control plane
# ---------------------------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}
# An IAM role is like a "badge" a service can wear to get permissions.
# This one says: "the EKS service is allowed to use this role".

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
# Gives the role the permissions EKS needs to manage the cluster
# (for example to create network interfaces). This policy is made and kept up to date by AWS.

# ---------------------------------------------------------------------------
# 2. The EKS cluster (the Kubernetes control plane)
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidrs
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}
# The cluster is the "brain" of Kubernetes. AWS runs it for us. It costs $0.10 per hour.
# - authentication_mode "API": we give people access with EKS "access entries"
#   (simple, no aws-auth ConfigMap).
# - bootstrap_cluster_creator_admin_permissions: the user who runs terraform
#   becomes cluster admin, so you can use kubectl right away.
# - endpoint_public_access: the Kubernetes API can be reached from the internet,
#   so GitHub Actions and your laptop can deploy. Only the IP ranges in
#   public_access_cidrs are allowed. Private access is also on, for the nodes.
# - depends_on: wait until the role has its policy before creating the cluster.

# ---------------------------------------------------------------------------
# 3. IAM role for the worker nodes
# ---------------------------------------------------------------------------

resource "aws_iam_role" "node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}
# The worker nodes are EC2 servers, so this role says: "EC2 is allowed to use this role".

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}
# Three AWS policies for the nodes:
# - AmazonEKSWorkerNodePolicy: lets a node join the cluster.
# - AmazonEKS_CNI_Policy: lets the network plugin give IP addresses to pods.
# - AmazonEC2ContainerRegistryReadOnly: lets nodes pull the EKS add-on images from AWS.
# "for_each" creates one attachment for every policy in the list.

# ---------------------------------------------------------------------------
# 4. The worker nodes (managed node group)
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-workers"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = [var.node_instance_type]
  capacity_type  = var.node_capacity_type

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
# The node group is the set of EC2 servers where our pods (frontend, backend,
# MongoDB, Redis...) really run. AWS creates, joins and replaces them for us.
# - ami_type: the server operating system (Amazon Linux 2023, made for EKS).
# - capacity_type: ON_DEMAND = normal price; SPOT = much cheaper but AWS can take it back.
# - scaling_config: how many nodes we want (desired) and the allowed range.
# - update_config: when updating, replace only one node at a time.

# ---------------------------------------------------------------------------
# 5. IAM role for the EBS CSI driver (storage for MongoDB)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  name = "${var.project_name}-ebs-csi-role"

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

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
# The EBS CSI driver is a pod that creates and attaches EBS disks.
# MongoDB needs a disk to keep its data. This role lets that pod manage EBS disks.
# "pods.eks.amazonaws.com" means: the role is for pods, using EKS Pod Identity.

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}
# Connects the role to the pod. Meaning: "the service account ebs-csi-controller-sa
# in the namespace kube-system may use this IAM role". No access keys are needed.

# ---------------------------------------------------------------------------
# 6. EKS add-ons (small programs AWS installs and updates for us)
# ---------------------------------------------------------------------------

resource "aws_eks_addon" "main" {
  for_each = toset([
    "vpc-cni",
    "kube-proxy",
    "coredns",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
  ])

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_pod_identity_association.ebs_csi,
  ]
}
# The five add-ons:
# - vpc-cni: pod networking (gives each pod an IP address from our subnets).
# - kube-proxy: routes traffic to the right pod inside the cluster.
# - coredns: DNS inside the cluster (so "backend" resolves to an address).
# - eks-pod-identity-agent: lets pods use IAM roles (used by the EBS driver and later secrets).
# - aws-ebs-csi-driver: creates EBS disks for MongoDB.
# We do not pin versions, so AWS picks the default version for our Kubernetes version.
# depends_on: add-ons are pods, so the nodes must exist first.
