variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "baseline_node_instance_types" { type = list(string) }
variable "baseline_node_desired" { type = number }
variable "baseline_node_min" { type = number }
variable "baseline_node_max" { type = number }

variable "eks_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the EKS public API endpoint. Set to corporate/VPN CIDR in production; private-only endpoint is the end-state target."
  default     = []

  validation {
    condition     = !contains(var.eks_public_access_cidrs, "0.0.0.0/0")
    error_message = "Do not expose the EKS API endpoint to 0.0.0.0/0. Restrict to a corporate/VPN CIDR."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 90
}

variable "alb_deployed" {
  type        = bool
  description = "Set to true after K8s manifests are applied and the ALB is provisioned. Terraform will look up the ALB by name and create CloudWatch alarms automatically."
  default     = false
}

variable "alert_email" {
  type        = string
  description = "Email address for SNS alert subscriptions."
}
