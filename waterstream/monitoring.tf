resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "${var.monitoring_namespace}${var.namespaces_suffix}"
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups     = [""]
    resources      = ["services", "pods"]
    verbs          = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    non_resource_urls = ["/metrics"]
    verbs = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata.0.name
  }
  subject {
    kind = "ServiceAccount"
    name = "default"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
  }
  subject {
    kind = "ServiceAccount"
    name = "default"
    namespace = kubernetes_namespace.waterstream.metadata.0.name
  }
}

resource "kubernetes_config_map" "etc-prometheus" {
  metadata {
    name = "etc-prometheus"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "waterstream"
      grafana_dashboard = "1"
    }
  }

  data = {
    "prometheus.yml" = file("${path.module}/resources/prometheus.yml")
  }
}

resource "kubernetes_config_map" "grafana-datasources" {
  metadata {
    name = "grafana-datasources"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "waterstream"
    }
  }

  data = {
    "prometheus.yaml" = <<EOF
{
  "apiVersion": 1,
  "datasources": [
      {
         "access":"proxy",
         "editable": false,
         "isDefault": true,
         "name": "prometheus",
         "orgId": 1,
         "type": "prometheus",
         "url": "http://prometheus.${kubernetes_namespace.monitoring.metadata.0.name}.svc:9090",
         "version": 1
      }
  ]
}
EOF
  }
}

resource "kubernetes_config_map" "grafana-dashboard-provider" {
  metadata {
    name = "grafana-dashboard-provider"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "waterstream"
    }
  }

  data = {
    "prometheus.yaml" = <<EOF
apiVersion: 1

providers:
- name: 'Dashboards'
  folder: ''
  type: file
  disableDeletion: true
  editable: true
  updateIntervalSeconds: 30
  # <bool> allow updating provisioned dashboards from the UI
  allowUiUpdates: true
  options:
    path: /var/waterstream-dashboard
EOF
  }
}


resource "kubernetes_config_map" "waterstream-dashboard" {
  metadata {
    name = "waterstream-grafana-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "waterstream"
      grafana_dashboard = "1"
    }
  }

  data = {
    "waterstream_grafana_dashboard.json" = file("${path.module}/resources/waterstream-grafana-dashboard.json")
  }
}

resource "kubernetes_deployment" "prometheus-deployment" {
  metadata {
    name = "prometheus-deployment"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "prometheus"
    }
  }
  spec {
    replicas = "1"
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          name = "prometheus"
          image = "prom/prometheus:${var.prometheus_version}"
          args = [
            "--storage.tsdb.retention.time=12h",
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus/"
          ]
          port {
            container_port = 9090
            name = "http"
          }
          resources {
            requests = {
              cpu = "300m"
              memory = "512m"
            }
            limits = {
              cpu = "1"
              memory = "2G"
            }
          }
          volume_mount {
            mount_path = "/etc/prometheus/"
            name       = "etc-prometheus"
          }
          volume_mount {
            mount_path = "/prometheus/"
            name       = "prometheus-storage"
          }
        }
        volume {
          name = "etc-prometheus"
          config_map {
            name = kubernetes_config_map.etc-prometheus.metadata.0.name
          }
        }
        volume {
          name = "prometheus-storage"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    name = "prometheus"
    labels = {
      app = "prometheus"
    }
  }
  spec {
    selector = {
      app = "prometheus"
    }
    port {
      port = 9090
      target_port = 9090
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "grafana-deployment" {
  metadata {
    name = "grafana-deployment"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
  }
  spec {
    replicas = "1"
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        name = "grafana"
        labels = {
          app = "grafana"
        }
      }
      spec {
        container {
          name = "grafana"
          image = "grafana/grafana:${var.grafana_version}"
          port {
            container_port = 3000
            name = "grafana"
          }
          resources {
            requests = {
              cpu = "250m"
              memory = "512M"
            }
            limits = {
              cpu = "1"
              memory = "1G"
            }
          }
          volume_mount {
            mount_path = "/var/lib/grafana"
            name       = "grafana-storage"
          }
          volume_mount {
            mount_path = "/etc/grafana/provisioning/datasources"
            name       = "grafana-datasources"
          }
          volume_mount {
            mount_path = "/etc/grafana/provisioning/dashboards"
            name       = "grafana-dashboard-provider"
          }
          volume_mount {
            mount_path = "/var/waterstream-dashboard"
            name       = "waterstream-dashboard"
          }
        }
        volume {
          name = "grafana-storage"
          empty_dir {}
        }
        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana-datasources.metadata.0.name
          }
        }
        volume {
          name = "grafana-dashboard-provider"
          config_map {
            name = kubernetes_config_map.grafana-dashboard-provider.metadata.0.name
          }
        }
        volume {
          name = "waterstream-dashboard"
          config_map {
            name = kubernetes_config_map.waterstream-dashboard.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "grafana" {
  metadata {
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    name = "grafana"
    labels = {
      app = "grafana"
    }
  }
  spec {
    selector = {
      app = "grafana"
    }
    port {
      port = 3000
      target_port = 3000
    }
    type = "ClusterIP"
  }
}
