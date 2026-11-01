# Project Atmos — Infrastructure as Code

Terraform for the AWS infrastructure of **Project Atmos**, a weather app (React, FastAPI, MongoDB, Redis) running on Amazon EKS.

| Repository | Responsibility |
|---|---|
| [`project-atmos-dev`](https://github.com/Kernel-Club/project-atmos-dev) | Application, Docker, CI/CD |
| [`project-atmos-k8s`](https://github.com/Kernel-Club/project-atmos-k8s) | Kubernetes / Helm configuration |
| `project-atmos-iac` | AWS infrastructure (this repo) |

> **Cost.** A running cluster costs about **$0.25/hour**. Create it for short sessions and always [destroy](#destroy) it right after.

## What it creates

| Module | Resources |
|---|---|
| `bootstrap/` | S3 bucket for Terraform state and the IAM roles of the pipeline (applied once, never destroyed) |
| `modules/network` | VPC, 2 public + 2 private subnets in 2 AZs, Internet Gateway, one shared NAT Gateway |
| `modules/eks` | EKS cluster, managed node group in private subnets, IAM roles, add-ons (VPC CNI, kube-proxy, CoreDNS, Pod Identity Agent, EBS CSI) |
| `modules/github-actions` | OIDC IAM roles for GitHub Actions: `dev`, `prod` |
| `modules/secrets` | Secrets Manager secrets (OpenWeather key, generated MongoDB password) and the IAM role for External Secrets Operator |
| `modules/lb-controller` | IAM role and policy for the AWS Load Balancer Controller |
| `modules/platform` | Inside the cluster: namespaces `dev`/`prod`, default StorageClass `gp3`, Gateway API CRDs, AWS Load Balancer Controller (Gateway API on), GatewayClass `aws-alb`, External Secrets Operator, RBAC for the deploy roles on the chart's CRDs |

`modules/platform` uses the `helm` and `kubernetes` providers. They connect to the cluster of this same stack with a token from `aws eks get-token`. Chart versions: variables `lb_controller_version`, `external_secrets_version`. The Gateway API CRDs (v1.6.0) and the GatewayClass are the local chart `modules/platform/charts/gateway-api`; its `crds/` and `templates/validating-admission-policy.yaml` are the vendored release file `standard-install.yaml`, split because `crds/` may hold only CRDs. Helm does not upgrade `crds/`: to update, split the new release file the same way, bump the chart version and run `kubectl apply --server-side -f` on the CRDs.

The app itself (`project-atmos-k8s`), its load balancer and its MongoDB volumes are **not** created by Terraform — they are created from the cluster.

## Usage

Requirements: Terraform `~> 1.16.0`, AWS CLI v2, `kubectl`, `helm`, and an IAM user (not root). Set credentials in the terminal only, never in files (fish: `set -gx NAME "value"`, bash/zsh: `export NAME="value"`).

**Once:** create the state bucket.

```bash
cd bootstrap && terraform init && terraform apply
```

**Every session:** merge to `main` and approve the `apply` job (see [CI pipeline](#ci-pipeline)). The same from a terminal:

```bash
export TF_VAR_openweather_api_key="<key>"   # secret, never put it in a file
export TF_VAR_cluster_admin_arns='["arn:aws:iam::<account id>:user/<your user>"]'   # kubectl access
terraform init \
  -backend-config="bucket=<project>-tfstate-<account id>" \
  -backend-config="region=<region>"
terraform plan
terraform apply                             # about 15 minutes
aws eks update-kubeconfig --region ap-northeast-2 --name project-atmos-eks
```

After `apply` the cluster is ready for the app: deploy it with the CD workflow of `project-atmos-k8s`.

### Variables that change the cost

| Variable | Default | Note |
|---|---|---|
| `enable_nat_gateway` | `true` | `false` saves about $0.06/h, nodes then run in public subnets |
| `node_instance_type` | `t8i.small` | The account is on the AWS Free plan, only free-tier types start |
| `node_capacity_type` | `ON_DEMAND` | `SPOT` is about 70% cheaper but can be interrupted |
| `node_max_size` | `2` | Caps the bill |
| `cluster_version` | `1.36` | Keep it in standard support; extended support costs $0.60/h |

## Destroy

The load balancer and EBS volumes are created by Kubernetes, so **delete them first**, otherwise `destroy` can hang on the VPC and keep costing money. Do it while the Load Balancer Controller is still running: `terraform destroy` removes it, and then nobody deletes the ALB.

```bash
helm uninstall atmos -n dev; helm uninstall atmos -n prod
kubectl delete gateway,ingress --all -A
kubectl delete svc --all -A --field-selector spec.type=LoadBalancer
kubectl delete pvc --all -A
terraform destroy
```

Then check that each command returns an empty list:

```bash
aws eks list-clusters --region ap-northeast-2
aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[].LoadBalancerArn'
aws ec2 describe-nat-gateways --region ap-northeast-2 --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --region ap-northeast-2 --query 'Addresses[].PublicIp'
aws ec2 describe-volumes --region ap-northeast-2 --filters Name=status,Values=available --query 'Volumes[].VolumeId'
```

The AWS Budget only sends warnings, it does not stop anything. Check **Billing** the next day.

## Approximate cost (`ap-northeast-2`, verify in the AWS Pricing Calculator)

| Resource | $/hour |
|---|---:|
| EKS control plane | 0.10 |
| NAT Gateway | 0.06 |
| 2 × t8i.small | ≈ 0.05 |
| Load balancer | 0.025 |
| **Total** | **≈ 0.24** |

## GitHub Actions access (OIDC)

No AWS keys are stored in GitHub. Each role trusts only `Kernel-Club/project-atmos-k8s` and only a job running in the matching GitHub Environment. Each environment holds the variable `AWS_GITHUB_ACTIONS_ROLE_ARN`; role ARNs are fixed, so the variables stay valid after every destroy.

| GitHub Environment | IAM role | Rights in Kubernetes |
|---|---|---|
| `development` | `project-atmos-github-dev` | edit, namespace `dev` |
| `production` (needs approval) | `project-atmos-github-prod` | edit, namespace `prod` |

Both roles are in the Kubernetes group `deployers`; `modules/platform` gives it the chart's CRDs (ExternalSecret, Gateway, ...) in its namespace. Nothing outside this repository has cluster admin.

## CI pipeline

[`iac-pipeline.yml`](.github/workflows/iac-pipeline.yml) runs Terraform on the GitHub runner.

| Event | Jobs |
|---|---|
| pull request | `checks` → `plan` (posted as a PR comment and in the run Summary) |
| push to `main` | `checks` → `plan` → `apply` (waits for a manual approval) |

`checks`: `terraform fmt`, `terraform validate` (root and `bootstrap/`), `tflint`, `trivy config` (HIGH and CRITICAL; accepted findings are in `.trivyignore`).

`apply` runs the exact plan that `plan` showed. The plan file is encrypted before it is uploaded, because the repository is public. If the state changed in between, Terraform refuses and changes nothing.

### Setup (GitHub)

| Where | Name | Value |
|---|---|---|
| Organization variable | `AWS_ACCOUNT_ID`, `AWS_REGION`, `PROJECT_NAME` | account, region, project name |
| Organization secret | `OPENWEATHER_API_KEY` | OpenWeather key |
| Repository variable | `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN` | `arn:aws:iam::<account>:role/<project>-iac-plan` and `-iac-apply` |
| Repository secret | `PLAN_ENCRYPTION_KEY` | `openssl rand -base64 32` |
| Environment | `infrastructure` | required reviewers, branch `main` only |

No AWS keys are stored: the jobs log in with OIDC. The two roles are created once from `bootstrap/` (`terraform apply`) and are never destroyed.

| Role | Who can use it | Rights |
|---|---|---|
| `<project>-iac-plan` | pull requests and `main` of this repository | read only (writes only the state lock file); in the cluster `AmazonEKSAdminViewPolicy`, because plan reads Helm releases |
| `<project>-iac-apply` | only a job in the `infrastructure` environment, after approval | AdministratorAccess; cluster admin as the cluster creator |

A running cluster costs about $0.25/hour, so reject the approval when you do not want it now. Destroy is manual (see [Destroy](#destroy)).

## Secrets

`project-atmos/<env>/openweather-api-key` and `project-atmos/<env>/mongodb` (`<env>` = `dev` or `prod`). External Secrets Operator reads them through Pod Identity and creates Kubernetes Secrets. Values are also kept in the Terraform state, which lives in the private, encrypted S3 bucket. Never commit keys, `.tfvars` or state files.

## Known limits

- One cluster for DEV and PROD, separated by namespaces only (cost decision).
- The Kubernetes API is public (`0.0.0.0/0`), because GitHub-hosted runners have no fixed IP. Access still requires valid AWS credentials.
- HTTP only: there is no domain, so the app is reached by the load balancer address.
- The cluster creator gets admin rights. When the pipeline creates the cluster, that is the apply role, not your IAM user, so `kubectl` from your laptop needs an extra EKS access entry for your user. The other way round: if you create the cluster from your laptop, the pipeline's apply role has no cluster rights and cannot manage `modules/platform`. Create the cluster from the pipeline.
