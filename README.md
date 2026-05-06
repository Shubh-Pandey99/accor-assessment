# The Redemption — Infrastructure

AWS EKS infrastructure for Accor's hotel loyalty point deduction service.

## Structure

```
terraform/
├── modules/
│   ├── vpc/                   # Multi-AZ VPC, NAT, VPC endpoints (S3, ECR, STS, DynamoDB)
│   ├── eks/                   # Cluster, node groups, Karpenter IAM, CloudWatch monitoring
│   └── security/              # IRSA roles, WAF, KMS, Secrets Manager, ECR, DynamoDB, SQS
├── main.tf                    # Module orchestration
├── outputs.tf                 # Key outputs (cluster, IRSA ARNs, ECR URL, WAF ARN)
├── variables.tf               # Input variable definitions
├── terraform.tfvars           # Environment configuration
└── versions.tf                # Provider and backend config (S3 + DynamoDB lock)

kubernetes/
├── base/
│   ├── app/                   # Deployment, Service, Ingress, ConfigMap, ServiceAccount
│   ├── hpa/                   # HPA (6–60 replicas, CPU 60% / memory 70%)
│   ├── pdb/                   # PodDisruptionBudget (minAvailable: 4)
│   ├── network-policies/      # Default-deny + explicit ALB/DNS/AWS/Redis allows
│   └── logging/               # Fluent Bit DaemonSet + ServiceAccount + ConfigMap (CRI parser, ships to CloudWatch)
└── overlays/
    └── production/            # Image pin, resource upgrades, IRSA ARN injection, Karpenter NodePool

.github/workflows/ci-cd.yaml  # Validate (always) + Deploy (conditional on AWS credentials)
docs/                          # Design document
diagrams/                      # Architecture diagram (SVG)
```

## Architecture Diagram

Architecture diagram: [`diagrams/architecture.svg`](diagrams/architecture.svg) — open directly in the browser or any SVG viewer.

## Design & Architecture

For a deep dive into the architecture, scaling strategy, security controls, and a list of known gaps (like deferred ElastiCache provisioning or the two-step apply for CloudWatch alarms), please refer to the [Design Document](docs/design-document.md).

## Prerequisites

- AWS CLI v2
- Terraform >= 1.6
- kubectl >= 1.29
- kustomize >= 5.0
- docker

## Getting started

```bash
# 1. Provision infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region ap-southeast-1 --name redemption-prod

# 3. Bootstrap: AWS Load Balancer Controller (required for ALB Ingress)
#    IRSA role is provisioned by Terraform. Run once after first terraform apply.
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=redemption-prod \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$(terraform output -raw alb_controller_role_arn)"

# 4. Bootstrap: Karpenter (required for burst node autoscaling)
#    See docs/design-document.md for full Karpenter bootstrap steps.

# 5. Inject account-specific ARNs and deploy all manifests
#    The production overlay patches IRSA ARNs and the SQS queue URL automatically.
#    Replace ACCOUNT_ID / CERT_ID / WAF_ID placeholders first (or let CI/CD do it).
kustomize build kubernetes/overlays/production | kubectl apply -f -

# 6. Enable CloudWatch alarms (after ALB is live)
#    Set alb_deployed = true in terraform.tfvars, then:
terraform apply
```



---

> **Note:** This is infrastructure code for a Cloud Engineer take-home assessment. Account IDs, certificate ARNs, and WAF IDs are placeholder values that must be substituted before deployment.
