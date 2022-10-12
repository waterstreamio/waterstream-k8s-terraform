variable "kubernetes_version" {
  default = "1.24.6"
  type = string
}

variable "min_nodes_count" {
  default = 1
  type = number
}

variable "max_nodes_count" {
  default = 5
  type = number
}

variable "node_type" {
  #See https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/#ddv4-series for complete machine types list
  default = "Standard_DS2_v2" #2 core, 7GB RAM, 0.114 USD/hour - 2022-02-09
  type = string
}

variable "cluster_name" {
  default = "waterstream-demo"
  type = string
}

variable "location" {
  default = "West Europe"
  type = string
}

