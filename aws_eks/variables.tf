variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "region" {
  default = "eu-central-1"
  type = string
}

variable "cluster_name" {
  type = string
  default = "waterstream-demo"
}

variable "kubernetes_version" {
  default = "1.21"
  type    = string
}

variable "default_k8s_node_group_instance_type" {
  #1 CPU, 2 GB ram, 0.023 USD/hour as of 2022-02-15 (https://aws.amazon.com/ec2/instance-types/t2/) - enough to run CoreDNS. All the other workload goes to the Fargate.
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
  description = "Pods from these namespaces get scheduled to the Fargate instead of the default node group"
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

variable "additional_admins" {
  description = "Additional AWS users that should be able to manage the EKS cluster. Mapping in aws-auth ConfigMap is created for them with group 'system:masters'"
  #Example:
  # [{"userarn": "arn:aws:iam::111122223333:user/admin", "username": "admin"}]
  type = list(map(string))
  default = []
}
