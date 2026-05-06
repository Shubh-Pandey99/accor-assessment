# The Redemption — Infrastructure Design
*Accor APAC | ap-southeast-1 | Cloud Engineer Assessment*

## Overview

The Redemption is a hotel loyalty point deduction service handling steady baseline traffic with sudden 10x spikes during flash sales. The infrastructure runs on AWS EKS in Singapore (ap-southeast-1) across three AZs. Zero downtime is a hard requirement — a failed redemption during a flash sale is direct revenue loss, not just a latency issue.

## A. Compute & Architecture

**VPC:** 10.0.0.0/16 across three AZs. Public subnets for the ALB and NAT gateways only. Private subnets for EKS workers. Database subnets (isolated, no route to the internet) reserved for ElastiCache when the application team is ready to deploy it.

**NAT:** One NAT gateway per AZ to prevent a single-AZ failure from killing egress for the whole cluster.

**EKS:** Managed control plane, workers in private subnets. Control plane logs (API, audit, authenticator, controllerManager, scheduler) shipped to CloudWatch. API server has public access enabled for initial deployment — restrict to a VPN/corporate CIDR via `eks_public_access_cidrs` before production go-live.

**VPC Endpoints:**
- *Gateway endpoints* (no hourly charge): S3, DynamoDB — routes all S3 and DynamoDB traffic off the NAT gateway.
- *Interface endpoints* (per-AZ hourly charge justified by call volume): ECR API, ECR DKR, STS — keeps container image pulls and IRSA token requests inside the VPC.
- SQS, CloudWatch Logs, and Secrets Manager are not yet on VPC endpoints; those calls route through NAT gateways. Worth adding post-launch once traffic volume makes the cost trade-off clear.

**Nodes:** Baseline group of 3 on-demand nodes (one per AZ, always running) using `m6i.xlarge` or `m6a.xlarge` — AWS picks the cheapest available. Karpenter provisions burst capacity from spot pools when HPA creates pending pods. Spot is substantially cheaper than on-demand for the burst window, with on-demand as fallback.

## B. Scalability Strategy

The 10x spike is the core architectural challenge. We tackle this in two layers:

**Layer 1 — Pod scaling (HPA):** We run 6 baseline replicas that scale up to 60 based on CPU (60% threshold) and memory (70% threshold). The scale-up is aggressive (0-second stabilization) to immediately absorb sudden spikes, while scale-down is conservative (5-minute cooldown) to prevent flapping as traffic normalizes.

**Layer 2 — Node scaling (Karpenter):** When the HPA creates pending pods, Karpenter provisions right-sized spot nodes in roughly 60 seconds. We've configured the NodePool with a mix of instance families (`m6i`, `m6a`, `m5`, `m5a`, `c6i`, `c6a`) in large, xlarge, and 2xlarge sizes to ensure spot capacity is always found. To keep operations simple, nodes expire after 720h (30 days) to force automatic patch rotation, and Karpenter aggressively consolidates underutilised nodes after 10 minutes to cut costs between spikes.

## C. Security & Networking

**Network topology:** ALB sits in public subnets with WAFv2 attached for edge protection (rate limiting 5 000 req/IP, AWS Managed Rules for OWASP Top 10 and known bad inputs). EKS workers are in private subnets with no direct internet access. AWS API calls for ECR, DynamoDB, S3, and STS go through VPC endpoints; SQS, CloudWatch Logs, and Secrets Manager calls route through NAT.

**Pod-level IAM (IRSA):** Each pod assumes its own IAM role via OIDC federation:
- `redemption-service` — scoped to `redemption-*` DynamoDB tables, SQS queues, and Secrets Manager paths.
- `fluent-bit` — CloudWatch Logs write access for `/eks/redemption-prod/*` log groups only.
- `aws-load-balancer-controller` — EC2/ELB/WAFv2 permissions required for ALB provisioning.
- `karpenter-controller` — EC2 fleet and pricing permissions for node provisioning.

We strictly avoid using broad node-level instance profiles. If a container is ever compromised, the blast radius remains securely confined to just that service's resources.

**Network policies:** Default deny on both ingress and egress at the namespace level. Explicit allows:
- ALB public subnets → pods on port 8080
- Pods → CoreDNS in kube-system (UDP/TCP 53)
- Pods → AWS services via VPC endpoints (TCP 443)
- Pods → Redis subnet range on TCP 6379 (forward-compatibility placeholder for ElastiCache)

**KMS:** EKS secrets are encrypted at rest with a KMS key (auto-rotation enabled, 7-day deletion window). Application-level field encryption (e.g., PII in DynamoDB) would use a separate key — deferred because application code is out of scope.

**TLS:** ALB terminates TLS 1.3 (SSL policy `ELBSecurityPolicy-TLS13-1-2-2021-06`). Internal pod-to-pod communication is plaintext within the VPC — acceptable given the network policy controls.

## D. Reliability & Observability

**Handling an AZ failure:**
- `topologySpreadConstraints` with a `maxSkew: 1` ensures pods are evenly balanced across all available AZs.
- A `PodDisruptionBudget` with `minAvailable: 4` guarantees that even if we lose an entire AZ (dropping from 6 replicas to 4), the application stays up. The PDB also prevents rolling updates or Karpenter consolidation from dropping our baseline below this safe threshold.
- DynamoDB and ElastiCache (when deployed) are natively multi-AZ.

**Handling a bad deployment:**
- `maxUnavailable: 0` ensures a rolling update never terminates an old pod before its replacement passes readiness checks.
- A `preStop: sleep 15s` lifecycle hook gives the ALB 15 seconds to safely drain existing connections before the pod terminates.
- We use three distinct probes: startup (generous, allowing for slow cold starts), readiness (to gate traffic), and liveness (strictly to restart genuinely hung pods). Collapsing these into a single probe is a common anti-pattern that can cause cascading restarts under heavy load.

**Application data stores:**
- *DynamoDB* (`redemption-transactions`, PAY_PER_REQUEST billing, PITR enabled) — primary transaction store.
- *SQS* (`redemption-events`, 24h retention, 30s visibility timeout, KMS encrypted) — async event processing.
- *Secrets Manager* (`redemption/app-config`) — API keys and feature flags, auto-rotation enabled.
- *ECR* (`redemption-service`, image scan on push, KMS encrypted) — container image registry.

**Monitoring:**
- Structured JSON logs shipped to CloudWatch Logs (90-day retention) via Fluent Bit. Fluent Bit runs as a DaemonSet in the `logging` namespace, deployed as part of the standard Kustomize overlay (`kubernetes/base/logging/`). Its IRSA role is provisioned by Terraform.
- CloudWatch log groups: `/eks/redemption-prod/app/redemption` (application logs), `/aws/eks/redemption-prod/cluster` (control plane logs).
- CloudWatch alarms (activated by setting `alb_deployed = true` in `terraform.tfvars` after the ALB is live):
  - 5xx error rate > 1% for 3 consecutive minutes → SNS `critical_alerts` topic.
  - p99 latency > 500ms for 3 consecutive minutes → SNS `critical_alerts` topic.
- SNS topics: `critical_alerts` and `warning_alerts` with email subscriptions to `alert_email`.
- ALB access logs stored in an S3 bucket provisioned by Terraform.
- Post-launch: migrate to Amazon Managed Prometheus + Grafana for richer dashboards and longer-window analysis. CloudWatch is sufficient for launch and keeps operational complexity down while the team stabilises.

**SLOs:** Availability 99.95% (~4.4 hours downtime/year), p99 latency < 500ms, error rate < 0.1%.

## E. CI/CD

GitHub Actions workflow (`.github/workflows/ci-cd.yaml`) triggers on push to `main` and on pull requests.

**Validate job (always runs, no AWS credentials needed):**
- `terraform validate` and `terraform fmt -check` (init with `-backend=false` to avoid state access).
- `kustomize build` lint on the production overlay.
- Grep check for unresolved placeholder tokens (`ACCOUNT_ID`, `CERT_ID`, `WAF_ID`).

**Deploy job (conditional on `AWS_DEPLOY_ROLE_ARN` secret):**
- Authenticates to AWS via OIDC (no long-lived credentials stored in GitHub).
- Builds and pushes the container image to ECR (`$ECR_REPO:$SHA`).
- Substitutes account-specific values (account ID, certificate ARN, WAF ARN) into manifests via `sed`.
- Verifies no placeholder tokens remain post-substitution.
- Deploys via `kubectl apply` and waits for rollout status.

The deploy job is skipped by default in this assessment repository (AWS OIDC and ECR secrets not populated). Set `AWS_DEPLOY_ROLE_ARN` as a GitHub environment secret to activate live deployments.

## F. Operations

**Reducing Day-2 operational toil:**
- Setting Karpenter's `expireAfter: 720h` means nodes are automatically rotated every 30 days, eliminating the need for manual OS patching windows.
- The CI pipeline runs `terraform plan` on every PR, acting as an automated guardrail against configuration drift.
- CloudWatch alarms are configured to fire only on business-meaningful signals (like user-facing 5xx errors or high latency) rather than noisy infrastructure metrics like high CPU on individual pods.

**Team delegation (1 Senior + 2 Juniors, ~3–4 weeks):**
- **Senior:** VPC, EKS cluster, IAM/IRSA, Karpenter setup, WAF, security review of all manifests before go-live.
- **Junior 1:** Kubernetes manifests (Deployment, HPA, PDB, network policies), production environment validation, rolling update testing.
- **Junior 2:** Monitoring setup (CloudWatch log groups, SNS, alarms), runbook authoring, load testing with k6 or Locust to validate the 10x spike scenario.

The senior owns anything touching IAM or network topology — mistakes there are hard to recover from. The juniors own the K8s layer where mistakes are visible quickly and rollback is a single command.

## Infrastructure Cost Strategy

To keep infrastructure costs highly efficient, we reserve on-demand instances strictly for our predictable baseline traffic. When a massive flash-sale hits, Karpenter aggressively provisions much cheaper spot instances to absorb the burst. We also use Gateway VPC endpoints (for S3 and DynamoDB) to eliminate NAT data-processing fees entirely on high-volume paths. Interface endpoints (for ECR and STS) carry a fixed hourly cost, but the call volume justifies their presence. Conversely, we deferred endpoints for SQS, CloudWatch, and Secrets Manager until their traffic volume grows enough to offset their fixed AZ costs.

## Known Gaps

- **Application code not included** — infrastructure only, per assessment scope.
- **Prometheus / Grafana** — CloudWatch used initially; migrate to AMP/AMG post-launch.
- **Canary deployments** — Currently rolling updates (`maxUnavailable: 0`); Argo Rollouts planned for request-level traffic shifting post-launch.
- **ElastiCache Redis** — Database-tier subnet scaffolding and network policy egress rule are in place; cluster provisioning deferred until the application requires it.
- **ECR lifecycle policy** — Retain last 30 images; deferred to post-launch hygiene once image cadence is known.
- **Karpenter spot interruption queue** — SQS-based interruption handling (EventBridge → SQS → Karpenter proactive drain) not provisioned; Karpenter's default 2-minute IMDS warning path handles reclamation. Add as Day-2 improvement.
- **Interface VPC endpoints for SQS, CloudWatch Logs, Secrets Manager** — not provisioned; calls route through NAT. Add post-launch.
- **CloudWatch alarms require two applies** — ALB is provisioned by the Load Balancer Controller (not Terraform). Set `alb_deployed = true` after the ALB is live and re-apply.
