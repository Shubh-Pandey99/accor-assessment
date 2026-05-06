# The Redemption — Infrastructure

AWS EKS infrastructure for Accor's hotel loyalty point deduction service.

## Structure

```
terraform/
├── modules/
│   ├── vpc/                   # Multi-AZ VPC, NAT, VPC endpoints
│   ├── eks/                   # Cluster, node groups, Karpenter IAM, monitoring
│   └── security/              # IRSA, WAF, KMS, Secrets Manager
├── terraform.tfvars           # Environment configuration

kubernetes/
├── base/
│   ├── app/                   # Deployment, Service, Ingress, ConfigMap
│   ├── hpa/                   # HPA config
│   ├── pdb/
│   ├── network-policies/
│   └── monitoring/            # Fluent Bit ServiceAccount (ships logs to CloudWatch)
└── overlays/
    └── production/

.github/workflows/             # CI/CD
docs/                          # Design document
diagrams/                      # Architecture diagram (SVG)
```

## Architecture Diagram

Architecture diagram: [`diagrams/architecture.svg`](diagrams/architecture.svg) — open directly in the browser or any SVG viewer.

## Known Gaps

Things that aren't done or aren't in scope for this assessment:

- Application code is not included — infra only.
- Redis/ElastiCache is intentionally not provisioned in this assessment. The NetworkPolicy Redis egress rule and DB-tier subnet scaffolding are forward-compatibility placeholders for a future caching layer — not a broken implementation.
- ElastiCache endpoint injection into K8s ConfigMap is not implemented (needs External Secrets Operator or init container pattern).
- Canary deploy is a rolling update with `maxUnavailable: 0` — request-level traffic splitting (Argo Rollouts) is deferred post-launch.
- Custom HPA metrics (RPS via Prometheus Adapter) are deferred — CPU + memory HPA is sufficient until real traffic data is available.
- EKS public endpoint restricted to configured CIDRs — set `eks_public_access_cidrs` to your VPN/office CIDR in `terraform/terraform.tfvars` before applying. Private-only endpoint is the production end-state.
- **CloudWatch alarms require two Terraform applies.** The ALB ARN suffix (`alb_arn_suffix`) is only known after the ALB is created by the Load Balancer Controller (post-`kubectl apply`). Workflow: (1) `terraform apply` → deploy K8s manifests → ALB provisioned; (2) retrieve suffix with `aws elbv2 describe-load-balancers --query 'LoadBalancers[?LoadBalancerName==\`redemption-prod-alb\`].LoadBalancerArn' --output text | sed 's|.*loadbalancer/||'`; (3) set `alb_arn_suffix` in `terraform.tfvars`; (4) `terraform apply -target=module.monitoring`. Until step 4, CloudWatch alarms stay in `INSUFFICIENT_DATA`.
- **Karpenter spot interruption handling** — Karpenter supports an SQS-based interruption queue (EventBridge routes EC2 spot interruption/rebalance events → SQS → Karpenter for proactive draining). Not provisioned in this assessment; Karpenter's default 2-minute IMDS warning path handles spot reclamation. Add the queue + EventBridge rules + `spec.interruptionQueueName` in EC2NodeClass as a Day-2 operational improvement.
- **Interface VPC endpoints for SQS, CloudWatch Logs, Secrets Manager** — not provisioned; those calls route through the NAT gateways. The endpoints add a fixed per-AZ hourly charge; at low traffic volume the savings on NAT data processing don't offset that fixed cost. Worth adding post-launch once traffic volume makes the trade-off clear.

See [docs/design-document.md](docs/design-document.md) for full context on these.

## Prerequisites

- AWS CLI v2
- Terraform >= 1.6
- kubectl >= 1.29
- kustomize >= 5.0
- docker

## Getting started

```bash
# infra
cd terraform
terraform init
terraform plan
terraform apply

# kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name redemption-prod

# Bootstrap: AWS Load Balancer Controller (required for ALB Ingress to work)
# The IRSA role is provisioned by Terraform. Run once after first `terraform apply`.
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=redemption-prod \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$(terraform output -raw alb_controller_role_arn)"
# Note: Helm is used for one-time bootstrap (same pattern as Karpenter).
# The controller itself is not managed via Terraform to keep state lean.

# Bootstrap: Karpenter (required for burst node autoscaling)
# See docs/design-document.md for full Karpenter bootstrap instructions.

# deploy
kustomize build kubernetes/overlays/production | kubectl apply -f -
```

## Key decisions

- **Baseline + Karpenter** — on-demand baseline nodes, Karpenter provisions spot for burst. Note: baseline nodes carry a `role=baseline` label but **no taint**, so burst pods can land on on-demand capacity if Karpenter hasn't scaled yet. Add `role=baseline:NoSchedule` taint to the managed node group and a matching toleration to the Deployment for strict cost isolation in production.
- **HPA + Karpenter** — pod-level and node-level autoscaling
- **Private subnets + VPC endpoints** — workloads never exposed to public internet
- **IRSA** — pod-level IAM, no long-lived credentials
- **CI/CD**: GitHub Actions validates Terraform and K8s manifests on PR, deploys to EKS on merge to main. See `.github/workflows/ci-cd.yaml`.

## SLOs

- Availability: 99.95%
- P99 latency: < 500ms
- Error rate: < 0.1%

See [docs/design-document.md](docs/design-document.md) for full design rationale.

---

> **Note:** This is infrastructure code for a Cloud Engineer take-home assessment. Some environment-specific values (account IDs, secrets) are placeholder values.
