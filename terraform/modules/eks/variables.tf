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
  default     = ["YOUR_VPN_CIDR/32"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
