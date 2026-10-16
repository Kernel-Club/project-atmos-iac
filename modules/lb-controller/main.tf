resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-lb-controller-policy"
  description = "Lets the AWS Load Balancer Controller create and manage load balancers"
  policy      = file("${path.module}/iam_policy.json")
}
# The AWS Load Balancer Controller is a program inside the cluster. When we create a
# Kubernetes Gateway, it builds a real AWS load balancer for us. To do that it must
# be allowed to create load balancers, target groups, listeners and so on.
# The policy text is the official one from the AWS project (file iam_policy.json).
# Do not edit it by hand. When you update the controller, download the new version.

resource "aws_iam_role" "lb_controller" {
  name = "${var.project_name}-lb-controller-role"

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

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}
# The "badge" (role) for the controller pod, with the policy above attached.
# "pods.eks.amazonaws.com" means the role is used by pods through EKS Pod Identity.

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn
}
# Connects the role to the pod: "the service account aws-load-balancer-controller
# in kube-system may use this role". These names are the defaults of the Helm chart.
