variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-southeast-1" # Singapore, closest to Thailand ops
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production"], var.environment)
    error_message = "Environment must be: production."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "redemption-prod"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs for multi-AZ deployment"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

# -- Node group sizing --

variable "baseline_node_instance_types" {
  description = "Instance types for baseline (on-demand) managed node group"
  type        = list(string)
  default     = ["m6i.xlarge", "m6a.xlarge"]
}

variable "baseline_node_desired" {
  description = "Desired node count for the baseline node group"
  type        = number
  default     = 3
}

variable "baseline_node_min" {
  description = "Minimum node count for the baseline node group"
  type        = number
  default     = 3
}

variable "baseline_node_max" {
  description = "Maximum node count for the baseline node group"
  type        = number
  default     = 6
}


variable "eks_public_access_cidrs" {
  description = "CIDRs permitted to reach the EKS public API endpoint. Replace with corporate/VPN CIDR before go-live. Private-only endpoint is the production end-state."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.eks_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not expose the EKS API endpoint to 0.0.0.0/0. Set a corporate/VPN CIDR or use [] for private-only access."
  }

  validation {
    condition     = length(var.eks_public_access_cidrs) == 0 || alltrue([for cidr in var.eks_public_access_cidrs : !contains(["YOUR_VPN_CIDR/32", "203.0.113.0/32"], cidr)])
    error_message = "Set eks_public_access_cidrs to your corporate/VPN CIDR in terraform.tfvars before applying."
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 90
}

variable "alb_deployed" {
  description = "Set to true after K8s manifests are applied and the ALB is provisioned. Triggers automatic ALB lookup and CloudWatch alarm creation."
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm SNS subscriptions. The address receives a confirmation email on first apply — click the link to activate."
  type        = string
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
