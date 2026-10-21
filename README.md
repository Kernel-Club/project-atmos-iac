# Project Atmos — Infrastructure as Code

Terraform for the AWS infrastructure of **Project Atmos**, a weather app (React, FastAPI, MongoDB, Redis) running on Amazon EKS.

| Repository | Responsibility |
|---|---|
| [`project-atmos-dev`](https://github.com/Kernel-Club/project-atmos-dev) | Application, Docker, CI/CD |
| [`project-atmos-k8s`](https://github.com/Kernel-Club/project-atmos-k8s) | Kubernetes / Helm configuration |
| `project-atmos-iac` | AWS infrastructure (this repo) |

> **Cost.** A running cluster costs about **$0.3/hour**. Create it for short sessions and always [destroy](#destroy) it right after.

## What it creates

| Module | Resources |
|---|---|
| `bootstrap/` | S3 bucket for Terraform state (applied once, never destroyed) |
| `modules/network` | VPC, 2 public + 2 private subnets in 2 AZs, Internet Gateway, one shared NAT Gateway |
| `modules/eks` | EKS cluster, managed node group in private subnets, IAM roles, add-ons (VPC CNI, kube-proxy, CoreDNS, Pod Identity Agent, EBS CSI) |
| `modules/github-actions` | OIDC IAM roles for GitHub Actions: `dev`, `prod`, `platform` |
| `modules/secrets` | Secrets Manager secrets (OpenWeather key, generated MongoDB password) and the IAM role for External Secrets Operator |
| `modules/lb-controller` | IAM role and policy for the AWS Load Balancer Controller |

The load balancer, MongoDB volumes and everything inside Kubernetes are **not** created by Terraform — they are created from the cluster. Every `.tf` file has short comments explaining each block.

## Usage

Requirements: Terraform `~> 1.16.0`, AWS CLI v2, `kubectl`, `helm`, and an IAM user (not root) for account `155980439303`. Set credentials in the terminal only, never in files (fish: `set -gx NAME "value"`, bash/zsh: `export NAME="value"`).

**Once:** create the state bucket.

```bash
cd bootstrap && terraform init && terraform apply
```

**Every session:**

```bash
export TF_VAR_openweather_api_key="<key>"   # secret, never put it in a file
terraform init
terraform plan
terraform apply                             # about 15 minutes
aws eks update-kubeconfig --region ap-northeast-2 --name project-atmos-eks
```

Then run the `platform` workflow in `project-atmos-dev` (installs the Load Balancer Controller, External Secrets and the `dev`/`prod` namespaces) and deploy the app.

### Variables that change the cost

| Variable | Default | Note |
|---|---|---|
| `enable_nat_gateway` | `true` | `false` saves about $0.06/h, nodes then run in public subnets |
| `node_instance_type` | `t3.medium` | `t3.small` is too small for the full stack |
| `node_capacity_type` | `ON_DEMAND` | `SPOT` is about 70% cheaper but can be interrupted |
| `node_max_size` | `2` | Caps the bill |
| `cluster_version` | `1.36` | Keep it in standard support; extended support costs $0.60/h |

## Destroy

The load balancer and EBS volumes are created by Kubernetes, so **delete them first**, otherwise `destroy` can hang on the VPC and keep costing money.

```bash
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
| 2 × t3.medium | 0.10 |
| Load balancer | 0.025 |
| **Total** | **≈ 0.29** |

## GitHub Actions access (OIDC)

No AWS keys are stored in GitHub. Each role trusts only `Kernel-Club/project-atmos-dev` and only a job running in the matching GitHub Environment. Each environment holds the variable `AWS_GITHUB_ACTIONS_ROLE_ARN`; role ARNs are fixed, so the variables stay valid after every destroy.

| GitHub Environment | IAM role | Rights in Kubernetes |
|---|---|---|
| `development` | `project-atmos-github-dev` | edit, namespace `dev` |
| `production` (needs approval) | `project-atmos-github-prod` | edit, namespace `prod` |
| `platform` (needs approval) | `project-atmos-github-platform` | cluster admin |

## CI pipeline

The workflow [`iac-pipeline.yml`](.github/workflows/iac-pipeline.yml) runs on every push to `main`. It needs no AWS access and never changes the real infrastructure. If a step fails, the pipeline fails.

| Step | What it checks |
|---|---|
| `terraform fmt` | code style |
| `terraform validate` | syntax and references, for the root and `bootstrap/` |
| `tflint` | mistakes and bad practices (config: `.tflint.hcl`) |
| `trivy config` | security problems, HIGH and CRITICAL only |

Findings we accept on purpose are listed in `.trivyignore` with a reason. To run the same checks locally: `terraform fmt -check -recursive`, `tflint --recursive --config "$PWD/.tflint.hcl"`, `trivy config . --severity HIGH,CRITICAL`.

## Secrets

`project-atmos/<env>/openweather-api-key` and `project-atmos/<env>/mongodb` (`<env>` = `dev` or `prod`). External Secrets Operator reads them through Pod Identity and creates Kubernetes Secrets. Values are also kept in the Terraform state, which lives in the private, encrypted S3 bucket. Never commit keys, `.tfvars` or state files.

## Known limits

- One cluster for DEV and PROD, separated by namespaces only (cost decision).
- The Kubernetes API is public (`0.0.0.0/0`), because GitHub-hosted runners have no fixed IP. Access still requires valid AWS credentials.
- The domain uses `nip.io`: the load balancer address is known only after creation, so set the hostname in the Gateway configuration in `project-atmos-k8s` for each session.
- The full configuration has been planned (59 resources) but not applied yet; expect small fixes on the first real apply.
