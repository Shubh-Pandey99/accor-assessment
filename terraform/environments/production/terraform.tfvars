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


log_retention_days = 90

additional_tags = {
  BusinessUnit = "loyalty-program"
  Compliance   = "pci-dss"
  DataClass    = "confidential"
}
