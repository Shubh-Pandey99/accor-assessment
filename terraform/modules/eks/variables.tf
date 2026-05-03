variable "cluster_name" { type = string }
variable "cluster_version" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "baseline_node_instance_types" { type = list(string) }
variable "baseline_node_desired" { type = number }
variable "baseline_node_min" { type = number }
variable "baseline_node_max" { type = number }

variable "tags" {
  type    = map(string)
  default = {}
}
