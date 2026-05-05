# Production values

aws_region         = "ap-southeast-1"
environment        = "production"
cluster_name       = "redemption-prod"
cluster_version    = "1.29"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

# baseline (on-demand)
baseline_node_instance_types = ["m6i.xlarge", "m6a.xlarge"]
baseline_node_desired        = 3
baseline_node_min            = 3
baseline_node_max            = 6

# Replace with your actual VPN/office CIDR before applying
eks_public_access_cidrs = ["203.0.113.0/32"]


log_retention_days = 90

# Set after first deploy. Retrieve with:
# aws elbv2 describe-load-balancers \
#   --query 'LoadBalancers[?LoadBalancerName==`redemption-prod-alb`].LoadBalancerArn' \
#   --output text | sed 's|.*loadbalancer/||'
# Then re-apply: terraform apply -target=module.monitoring
alb_arn_suffix = "app/redemption-prod-alb/REPLACE_AFTER_DEPLOY"

additional_tags = {
  BusinessUnit = "loyalty-program"
  Compliance   = "pci-dss"
  DataClass    = "confidential"
}
