# The Redemption — Infrastructure

AWS EKS infrastructure for Accor's hotel loyalty point deduction service.

## Structure

```
terraform/
├── modules/
│   ├── vpc/                   # Multi-AZ VPC, NAT, VPC endpoints
│   ├── eks/                   # Cluster, node groups, Karpenter IAM
│   ├── security/              # IRSA, WAF, KMS, Secrets Manager
│   └── monitoring/            # CloudWatch log groups, SNS, alarms
└── environments/
    └── production/

kubernetes/
├── base/
│   ├── app/                   # Deployment, Service, Ingress, Karpenter
│   ├── hpa/                   # HPA config
│   ├── pdb/
│   ├── network-policies/
│   └── monitoring/            # Fluent Bit DaemonSet (ships logs to CloudWatch)
└── overlays/
    ├── production/
    └── staging/

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
- EKS public endpoint restricted to configured CIDRs — set `eks_public_access_cidrs` to your VPN/office CIDR in `environments/production/terraform.tfvars` before applying. Private-only endpoint is the production end-state.

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
terraform plan -var-file=environments/production/terraform.tfvars
terraform apply -var-file=environments/production/terraform.tfvars

# kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name redemption-prod

# deploy
kustomize build kubernetes/overlays/production | kubectl apply -f -
```

## Key decisions

- **Baseline + Karpenter** — on-demand baseline nodes, Karpenter provisions spot for burst
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
