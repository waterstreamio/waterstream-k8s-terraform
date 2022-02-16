provider "google" {
  credentials = file("account.json")
  project = var.project
  region = var.region
}

# Use a random suffix to prevent overlap in network names
resource "random_string" "suffix" {
  length = 4
  special = false
  upper = false
}

resource "google_compute_network" "net" {
  name = "${var.cluster_name}-network-${random_string.suffix.result}"
}

resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork-${random_string.suffix.result}"
  network = google_compute_network.net.self_link
  ip_cidr_range = var.vpc_cidr_block
  region = var.region
}

resource "google_container_cluster" "cluster" {
  timeouts {
    delete = "120m"
  }

  name = var.cluster_name
  location = var.region
  min_master_version = var.k8s_version

  enable_autopilot = true

  ip_allocation_policy { }


  network = google_compute_network.net.name
  subnetwork = google_compute_subnetwork.subnet.name

}


# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {
}

data "template_file" "kubeconfig" {
  template = file("${path.module}/kubeconfig-template.yaml")
  vars = {
    cluster_ca = google_container_cluster.cluster.master_auth[0].cluster_ca_certificate
    endpoint = "https://${google_container_cluster.cluster.endpoint}"
    cluster_name = google_container_cluster.cluster.name
    cluster_token = data.google_client_config.default.access_token
  }
}

resource "local_file" "kubeconfig_out" {
  content  = "${data.template_file.kubeconfig.rendered}"
  filename = "${path.module}/../kube_config"
}



