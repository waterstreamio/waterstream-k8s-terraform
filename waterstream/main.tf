provider "kubernetes" {
  config_path    = var.kubernetes_config_path
}

resource "kubernetes_namespace" "waterstream" {
  metadata {
    name = "${var.namespace}${var.namespaces_suffix}"
  }
}

resource "kubernetes_secret" "dockerhub-download" {
  metadata {
    name = "dockerhub-download"
    namespace = kubernetes_namespace.waterstream.metadata.0.name
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.docker_server) = {
          auth = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}

resource "kubernetes_config_map" "etc_waterstream" {
  metadata {
    name = "etc-waterstream"
    namespace = kubernetes_namespace.waterstream.metadata.0.name
    labels = {
      app = "waterstream"
    }
  }

  data = {
    "waterstream.license" = file("${path.module}/waterstream.license")
    "logback.xml" = file("${path.module}/resources/logback.xml")
    "ssl_key" = var.waterstream_ssl_key_inline
    "ssl_cert" = var.waterstream_ssl_cert_inline
    "jwt_key" = var.waterstream_jwt_verification_key
    "users.properties" = var.waterstream_authentication_plain_users_content
    "authorization_rules.csv" = var.waterstream_authorization_rules
  }
}

resource "random_string" "kafka_streams_app_server_shared_token" {
  length = 8
  special = false
  upper = false
}


resource "kubernetes_deployment" "waterstream" {
  depends_on = [kubernetes_config_map.etc_waterstream]
  lifecycle {
    replace_triggered_by = [kubernetes_config_map.etc_waterstream]
  }

  metadata {
    name = "waterstream"
    namespace = kubernetes_namespace.waterstream.metadata.0.name
    labels = {
      app = "waterstream"
    }
  }
  spec {
    replicas = var.waterstream_replicas_count
    strategy {
      type = "RollingUpdate"
    }

    selector {
      match_labels = {
        app = "waterstream"
      }
    }

    template {
      metadata {
        labels = {
          app = "waterstream"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/path" = "/metrics"
          "prometheus.io/port" = "1884"
        }
      }
      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_labels = {
                  app = "waterstream"
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
        image_pull_secrets {
          name = kubernetes_secret.dockerhub-download.metadata.0.name
        }
        volume {
          name = "etc-waterstream"
          config_map {
            name = kubernetes_config_map.etc_waterstream.metadata.0.name
          }
        }
        container {
          name = "waterstream"
          image = "${var.waterstream_image_name}:${var.waterstream_version}"
          image_pull_policy = "Always"
          resources {
            requests = {
              cpu = var.waterstream_node_cpu
              memory = var.waterstream_node_memory
            }
          }
          port {
            container_port = 1882
            name = "streams-app"
          }
          port {
            container_port = 1883
            name = "mqtt"
          }
          port {
            container_port = 1884
            name = "metrics"
          }
          dynamic "port" {
            for_each = var.waterstream_websockets_port == null ? [] : ["1"]
            content {
              container_port = tostring(var.waterstream_websockets_port)
              name           = "mqttws"
            }
          }
          volume_mount {
            mount_path = "/etc/waterstream"
            name       = "etc-waterstream"
            read_only  = true
          }
          liveness_probe {
            initial_delay_seconds = 20
            period_seconds = 20
            success_threshold = 1
            failure_threshold = 3
            http_get {
              path = "/health"
              port = "1884"
            }
          }
          startup_probe {
            initial_delay_seconds = 20
            period_seconds = 20
            success_threshold = 1
            failure_threshold = 3
            http_get {
              path = "/health"
              port = "1884"
            }
          }
          env {
            name = "KAFKA_BOOTSTRAP_SERVERS"
            value = var.kafka_bootstrap_servers
          }
          env {
            name = "KAFKA_SASL_JAAS_CONFIG"
            value = var.kafka_saslJaasConfig
          }
          env {
            name = "KAFKA_SSL_ENDPOINT_IDENTIFICATION_ALGORITHM"
            value = var.kafka_sslEndpointIdentificationAlgorithm
          }
          env {
            name = "KAFKA_SASL_MECHANISM"
            value = var.kafka_saslMechanism
          }
          env {
            name = "KAFKA_SECURITY_PROTOCOL"
            value = var.kafka_securityProtocol
          }
          env {
            name = "KAFKA_REQUEST_TIMEOUT_MS"
            value = tostring(var.kafka_requestTimeoutMs)
          }
          env {
            name = "KAFKA_RETRY_BACKOFF_MS"
            value = tostring(var.kafka_retryBackoffMs)
          }
          env {
            name = "KAFKA_PRODUCER_LINGER_MS"
            value = tostring(var.kafka_lingerMs)
          }
          env {
            name = "KAFKA_BATCH_SIZE"
            value = tostring(var.kafka_batchSize)
          }
          env {
            name = "KAFKA_COMPRESSION_TYPE"
            value = var.kafka_compressionType
          }
          env {
            name = "KAFKA_FETCH_MIN_BYTES"
            value = tostring(var.kafka_fetchMinBytes)
          }
          env {
            name = "KAFKA_FETCH_MAX_BYTES"
            value = tostring(var.kafka_fetchMaxBytes)
          }
          env {
            name = "KAFKA_TRANSACTIONAL_ID"
            value = ""
          }
          env {
            name = "SESSION_TOPIC"
            value = var.kafka_topic_session
          }
          env {
            name = "RETAINED_MESSAGES_TOPIC"
            value = var.kafka_topic_retained_messages
          }
          env {
            name = "CONNECTION_TOPIC"
            value = var.kafka_topic_connections
          }
          env {
            name = "KAFKA_MESSAGES_DEFAULT_TOPIC"
            value = var.kafka_topic_default_mqtt_messages
          }
          env {
            name = "KAFKA_MQTT_MAPPINGS"
            value = var.kafka_mqtt_mappings
          }
          env {
            //Deprecated
            name = "KAFKA_MESSAGES_TOPICS_PATTERNS"
            value = var.kafka_messages_topics_patterns
          }
          env {
            name = "CENTRALIZED_CONSUMER_LISTENER_QUEUE"
            value = tostring(var.waterstream_centralized_consumer_listener_queue)
          }
          env {
            name = "CENTRALIZED_CONSUMER_CLIENT_TIMEOUT_MS"
            value = tostring(var.waterstream_centralized_consumer_client_timeout_ms)
          }
          env {
            name = "KAFKA_STREAMS_REPLICATION_FACTOR"
            value = tostring(var.kafka_streams_replication_factor)
          }
          env {
            name = "KAFKA_STREAMS_APP_SERVER_HOST"
            value_from {
              field_ref {
                field_path = "status.podIP"
              }
            }
          }
          env {
            name = "KAFKA_STREAMS_APP_SERVER_PORT"
            value = "1882"
          }
          env {
            name = "KAFKA_STREAMS_APP_SERVER_SHARED_TOKEN"
            value = random_string.kafka_streams_app_server_shared_token.result
          }
          env {
            name = "KAFKA_STREAMS_PROPAGATION_UNDECISIVE_TIMEOUT_MS"
            value = "5000"
          }
          dynamic "env" {
            for_each = var.waterstream_websockets_port == null ? [] : ["1"]
            content {
              name  = "MQTT_WS_PORT"
              value = var.waterstream_websockets_port
            }
          }
          env {
            name = "MQTT_BLOCKING_THREAD_POOL_SIZE"
            value = tostring(var.waterstream_blocking_thread_pool_size)
          }
          env {
            name = "MAX_QUEUED_INCOMMING_MESSAGES"
            value = tostring(var.waterstream_max_queued_incoming_messages)
          }
          env {
            name = "MQTT_MAX_IN_FLIGHT_MESSAGES"
            value = tostring(var.waterstream_max_in_flight_messages)
          }
          env {
            name = "MONITORING_INCLUDE_JAVA_METRICS"
            value = "true"
          }
          env {
            name = "MONITORING_EXTENDED_METRICS"
            value = "false"
          }
          env {
            name = "MQTT_MAX_MESSAGE_SIZE"
            value = var.waterstream_max_message_size_bytes
          }
          env {
            name = "WATERSTREAM_JAVA_OPTS"
            value = "-XX:InitialRAMPercentage=${var.waterstream_heap_percentage} -XX:MaxRAMPercentage=${var.waterstream_heap_percentage}"
          }
          env {
            name = "WATERSTREAM_LICENSE_LOCATION"
            value = "/etc/waterstream/waterstream.license"
          }
          env {
            name = "WATERSTREAM_LOGBACK_CONFIG"
            value = "/etc/waterstream/logback.xml"
          }
          env {
            name = "KAFKA_MQTT_MAPPINGS"
            value = var.kafka_mqtt_mappings
          }
          env {
            name = "SSL_ENABLED"
            value = tostring(var.waterstream_ssl_enabled)
          }
          env {
            name = "SSL_KEY_PATH"
            value = "/etc/waterstream/ssl_key"
          }
          env {
            name = "SSL_CERT_PATH"
            value = "/etc/waterstream/ssl_cert"
          }
          env {
            name = "AUTHENTICATION_REQUIRED"
            value = var.waterstream_authentication_required
          }
          env {
            name = "AUTHENTICATION_METHOD_JWT_ENABLED"
            value = tostring(coalesce(var.waterstream_authentication_method_jwt_enabled, var.waterstream_authentication_required))
          }
          env {
            name = "JWT_AUDIENCE"
            value = var.waterstream_jwt_audience
          }
          env {
            name = "JWT_VERIFICATION_KEY_ALGORITHM"
            value = var.waterstream_jwt_verification_key_algorithm
          }
          env {
            name = "JWT_VERIFICATION_KEY_PATH"
            value = "/etc/waterstream/jwt_key"
          }
          env {
            name = "JWT_SUBJECT_USERNAME_EXTRACTION_REGEX"
            value = var.waterstream_jwt_subject_username_extraction_regex
          }
          env {
            name = "JWT_GROUPS_CLAIM_NAME"
            value = var.waterstream_jwt_groups_claim_name
          }
          env {
            name = "AUTHENTICATION_METHOD_PLAIN_USERS_FILE_ENABLED"
            value = tostring(var.waterstream_authentication_method_plain_enabled)
          }
          env {
            name = "USERS_FILE_PATH"
            value = "/etc/waterstream/users.properties"
          }
          env {
            name = "AUTHORIZATION_RULES_PATH"
            value = "/etc/waterstream/authorization_rules.csv"
          }
          env {
            name = "AUTHORIZATION_PUBLISH_DEFAULT_OUTCOME"
            value = "DENY"
          }
          env {
            name = "AUTHORIZATION_SUBSCRIBE_DEFAULT_OUTCOME"
            value = "DENY"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "waterstream" {
  metadata {
    namespace = kubernetes_namespace.waterstream.metadata.0.name
    name = "waterstream-mqtt"
    labels = {
      app = "waterstream"
    }
    annotations = {
      "service.beta.kubernetes.io/azure-dns-label-name": var.namespace
    }
  }
  spec {
    load_balancer_ip = var.waterstream_static_ip
    selector = {
      app = "waterstream"
    }
    port {
      name = "mqtt"
      port = 1883
      target_port = 1883
    }
    dynamic "port" {
      for_each = var.waterstream_websockets_port == null ? [] : ["1"]
      content {
        name        = "mqttws"
        port        = var.waterstream_websockets_port
        target_port = var.waterstream_websockets_port
      }
    }
    external_traffic_policy = "Cluster"
    type = "LoadBalancer"
  }
}

output "waterstream-mqtt-load-balancer-hostname" {
  value = kubernetes_service.waterstream.status.0.load_balancer.0.ingress.0.hostname
}

output "waterstream-mqtt-load-balancer-ip" {
  value = kubernetes_service.waterstream.status.0.load_balancer.0.ingress.0.ip
}


##TODO delete after debug
#output "waterstream-mqtt-status" {
#  value = kubernetes_service.waterstream.status
#}
#
##TODO delete after debug
#output "waterstream-mqtt-load-balancer" {
#  value = kubernetes_service.waterstream.status.0.load_balancer
#}