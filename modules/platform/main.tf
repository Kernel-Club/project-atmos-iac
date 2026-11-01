# Versions are in the root versions.tf. kubectl is not a hashicorp provider, so its source is needed here;
# kubernetes is listed because provider functions need an explicit entry.
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    kubectl = {
      source = "alekc/kubectl"
    }
  }
}

locals {
  # Official release file (standard-install.yaml). Do not edit by hand, download a new one when updating:
  # https://github.com/kubernetes-sigs/gateway-api/releases/download/<version>/standard-install.yaml
  # A provider function, not a data source: it works before the cluster exists (first plan).
  gateway_api_manifests = {
    for m in provider::kubernetes::manifest_decode_multi(file("${path.module}/gateway-api-crds.yaml")) :
    "${m.kind}/${m.metadata.name}" => m
  }
}

resource "kubernetes_namespace_v1" "app" {
  for_each = var.namespaces

  metadata {
    name = each.value
  }
}

# New EKS clusters have no default StorageClass, so PVCs without a class stay Pending.
# The EBS CSI driver is an EKS add-on (modules/eks).
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

# Server-side apply: the CRDs are too big for the last-applied annotation.
resource "kubectl_manifest" "gateway_api" {
  for_each = local.gateway_api_manifests

  yaml_body         = yamlencode(each.value)
  server_side_apply = true
  wait              = true
}

# The Load Balancer Controller needs the Gateway API CRDs when it starts.
# The IAM role comes from Pod Identity (modules/lb-controller): service account name must match.
resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_version
  namespace  = var.lb_controller_service_account.namespace

  atomic  = true
  wait    = true
  timeout = 300

  set = [
    { name = "clusterName", value = var.cluster_name },
    { name = "region", value = var.region },
    { name = "vpcId", value = var.vpc_id },
    { name = "serviceAccount.name", value = var.lb_controller_service_account.name },
    { name = "controllerConfig.featureGates.ALBGatewayAPI", value = "true" },
    { name = "replicaCount", value = "1" },
  ]

  depends_on = [kubectl_manifest.gateway_api]
}

# The name must match gateway.className in project-atmos-k8s (charts/atmos/values.yaml).
resource "kubectl_manifest" "gateway_class" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata   = { name = "aws-alb" }
    spec       = { controllerName = "gateway.k8s.aws/alb" }
  })

  depends_on = [helm_release.lb_controller]
}

# The IAM role comes from Pod Identity (modules/secrets): namespace and service account must match.
# After the Load Balancer Controller: its webhook must be up before other charts create Services.
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  namespace        = var.external_secrets_service_account.namespace
  create_namespace = true

  atomic  = true
  wait    = true
  timeout = 300

  set = [
    { name = "serviceAccount.name", value = var.external_secrets_service_account.name },
  ]

  depends_on = [helm_release.lb_controller]
}

# The deploy roles only have AmazonEKSEditPolicy, which does not cover CRDs.
# Their access entries put them in this group (modules/github-actions).
resource "kubernetes_role_v1" "deployer_crds" {
  for_each = var.namespaces

  metadata {
    name      = "deployer-crds"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }

  rule {
    api_groups = ["external-secrets.io"]
    resources  = ["externalsecrets", "secretstores"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["gateway.networking.k8s.io"]
    resources  = ["gateways", "httproutes"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["gateway.k8s.aws"]
    resources  = ["loadbalancerconfigurations", "targetgroupconfigurations"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "deployer_crds" {
  for_each = var.namespaces

  metadata {
    name      = "deployer-crds"
    namespace = kubernetes_namespace_v1.app[each.key].metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deployer_crds[each.key].metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = var.deployer_group
  }
}
