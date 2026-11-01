# First start: demo for the mentor

Goal: show the full IaC flow: pull request, plan, approval, apply, destroy.
Time: about 40 minutes. Cost: about $0.3 per hour while the cluster runs.

## Before the demo

1. Check the AWS Budget and Billing. Cluster must not be running.
2. Log in: `aws login` (check: `aws sts get-caller-identity` shows user `streetflow`).
3. Check GitHub (repo `project-atmos-iac`):
   - Variables: `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`.
   - Organization variable `EKS_ADMIN_ARNS` (your user, for `kubectl`).
   - Secrets: `PLAN_ENCRYPTION_KEY`, `OPENWEATHER_API_KEY`.
   - Environment `infrastructure`: both reviewers, branch `main` only.
4. Check GitHub (repo `project-atmos-k8s`): environments `development`, `production`, `platform`, each with `AWS_GITHUB_ACTIONS_ROLE_ARN`. Organization variable `DOCKERHUB_NAMESPACE`.
5. Open in tabs: GitHub Actions page, AWS console (region `ap-northeast-2`), this file.

## Part 1: show the plan (pull request)

1. Create a branch and make a small change:
   ```bash
   git switch -c demo/change
   # change something small, for example a tag or a description
   git commit -am "demo change"
   git push -u origin demo/change
   ```
2. Open a pull request into `main`.
3. Show the checks: fmt, validate, tflint, trivy.
4. Show the plan comment in the pull request. Explain: plan is read-only, nothing is created.

## Part 2: apply with approval

1. Merge the pull request.
2. Open Actions. The jobs `checks` and `plan` run on their own.
3. Job `apply` stops and waits. Click **Review deployments**, select `infrastructure`, approve.
4. Wait about 15 minutes. Explain: only this environment can use the admin role.

## Part 3: use the cluster

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name project-atmos-eks
kubectl get nodes
```

Then, in `project-atmos-k8s`: run the `Platform` workflow once (Actions -> Platform -> Run workflow, approve), then the `CD` workflow (or push to `develop` in `project-atmos-dev`).
Open the app at the load balancer address from the `CD` run Summary.

## Part 4: destroy (always!)

```bash
kubectl delete gateway,ingress --all -A
kubectl delete svc --all -A --field-selector spec.type=LoadBalancer
kubectl delete pvc --all -A
terraform init -backend-config="bucket=<project>-tfstate-<account id>" -backend-config="region=<region>"
terraform destroy
```

Check that each list is empty:

```bash
aws eks list-clusters --region ap-northeast-2
aws elbv2 describe-load-balancers --region ap-northeast-2 --query 'LoadBalancers[].LoadBalancerArn'
aws ec2 describe-nat-gateways --region ap-northeast-2 --filter Name=state,Values=available,pending --query 'NatGateways[].NatGatewayId'
aws ec2 describe-addresses --region ap-northeast-2 --query 'Addresses[].PublicIp'
aws ec2 describe-volumes --region ap-northeast-2 --filters Name=status,Values=available --query 'Volumes[].VolumeId'
```

Check Billing the next day.
