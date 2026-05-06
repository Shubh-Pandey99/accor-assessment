# Production values

aws_region         = "ap-southeast-1"
environment        = "production"
cluster_name       = "redemption-prod"
cluster_version    = "1.31"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]

# baseline (on-demand)
baseline_node_instance_types = ["m6i.xlarge", "m6a.xlarge"]
baseline_node_desired        = 3
baseline_node_min            = 3
baseline_node_max            = 6

# eks_public_access_cidrs = ["YOUR_CORP_VPN_CIDR/32"]
# Set to your corporate/VPN CIDR before applying. See README for instructions.


log_retention_days = 90

# SNS alert subscriptions — AWS sends a confirmation email on first apply; click the link.
alert_email = "oncall@example.com"

# Set after first deploy.
alb_deployed = false

additional_tags = {
  BusinessUnit = "loyalty-program"
  Compliance   = "internal"
  DataClass    = "confidential"
}
