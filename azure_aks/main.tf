terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.42"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "default" {
  name     = var.cluster_name
  location = var.location
}

resource "azurerm_kubernetes_cluster" "default" {
  name                = var.cluster_name
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = var.cluster_name
  kubernetes_version = var.kubernetes_version

  default_node_pool {
    name       = "default"
    min_count = var.min_nodes_count
    max_count = var.max_nodes_count
    vm_size    = var.node_type
    enable_auto_scaling = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "local_file" "kubeconfig" {
  content = azurerm_kubernetes_cluster.default.kube_config_raw
  filename = "${path.root}/../kube_config"
}
