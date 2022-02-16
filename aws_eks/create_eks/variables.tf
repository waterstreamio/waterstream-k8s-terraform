variable "cluster_name" {
  type = string
  default = "waterstream-demo"
}

variable "kubernetes_version" {
  default = "1.21"
  type    = string
}

variable "default_k8s_node_group_instance_type" {
  default = "t2.small"
  type    = string
}

#At least one node in the default node group needed to run CoreDNS services
variable "default_k8s_node_group_min_size" {
  default = 1
  type = number
}

variable "default_k8s_node_group_max_size" {
  default = 3
  type = number
}

variable "fargate_namespaces" {
  type = list(string)
  default = ["default", "waterstream", "waterstream-kafka"]
}

variable "vpc_name" {
  default = "waterstream-vpc"
  type = string
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}
