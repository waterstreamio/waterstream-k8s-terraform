###############################################################
## Kubernetes
###############################################################

variable "kubernetes_config_path" {
  type = string
  default = "../kube_config"
}

###############################################################
## Docker
###############################################################

variable "docker_server" {
  type = string
  default = "index.docker.io"
}

variable "docker_username" {
  type = string
}

variable "docker_password" {
  type = string
}

###############################################################
## Waterstream
###############################################################

variable "namespaces_suffix" {
  type = string
  default = ""
  description = "Suffix to add to all the namespaces - in case you want multiple Waterstream deployments on the same K8s cluster"
}

variable "namespace" {
  type = string
  default = "waterstream"
}

variable "waterstream_image_name" {
  type        = string
  #AWS Marketplace repository
  # default = "709825985650.dkr.ecr.us-east-1.amazonaws.com/waterstream/waterstream-kafka"
  #DockerHub repository
  default     = "simplematter/waterstream-kafka"
}

variable "waterstream_version" {
  type = string
  default = "1.4.5"
}

variable "waterstream_static_ip" {
  type = string
  default = null
}

variable "waterstream_websockets_port" {
  type = number
  default = null
}

variable "waterstream_replicas_count" {
  type        = number
  default     = 2
}

variable "waterstream_node_cpu" {
  default = "1"
  type = string
}

variable "waterstream_node_memory" {
  default = "4096M"
  type = string
}

variable "waterstream_heap_percentage" {
  default = 70
  type = number
}

variable "waterstream_centralized_consumer_listener_queue" {
  type        = number
  default     = 1024
}

variable "waterstream_centralized_consumer_client_timeout_ms" {
  type        = number
  default     = 15000
}

variable "waterstream_blocking_thread_pool_size" {
  type = number
  default = 10
}

variable "waterstream_max_queued_incoming_messages" {
  type = number
  default = 1000
}

variable "waterstream_max_in_flight_messages" {
  type = number
  default = 10
}

variable "waterstream_max_message_size_bytes" {
  type = number
  default = 100000
}



###############################################################
## Kafka topics and tuning
###############################################################

//Default topic for MQTT messages
variable "kafka_topic_default_mqtt_messages" {
  default = "mqtt_messages"
  type = string
}

//Deprecated
variable "kafka_messages_topics_patterns" {
  default = ""
  type = string
}

//In-line mapping config between (Kafka topic, Kafka key) and MQTT topic - HOCON format (see https://docs.waterstream.io/release/configGuide.html#mqtt-to-kafka-topic-key-mapping-rules-new)
variable "kafka_mqtt_mappings" {
  default = ""
  type = string
}

variable "kafka_topic_session" {
  default = "mqtt_sessions"
  type = string
}

variable "kafka_topic_retained_messages" {
  default = "mqtt_retained_messages"
  type = string
}

variable "kafka_topic_connections" {
  default = "mqtt_connections"
  type = string
}

variable "kafka_lingerMs" {
  type = number
  default = 100
}

variable "kafka_batchSize" {
  type = number
  default = 65392
}

variable "kafka_compressionType" {
  type = string
  description = "compression.type for producer. Valid values are none, gzip, snappy, lz4"
  default = "snappy"
}

variable "kafka_requestTimeoutMs" {
  type = number
  description = "request.timeout.ms for producer and consumer"
  default = 30000
}

variable "kafka_retryBackoffMs" {
  type = number
  description = "retry.backoff.ms for producer and consumer"
  default = 100
}

variable "kafka_maxBlockMs" {
  type = number
  description = "`max.block.ms` for producer"
  default = 60000
}

variable "kafka_bufferMemory" {
  type = number
  description = "`buffer.memory` for producer. Default is 32MB"
  default = 33554432
}

variable "kafka_fetchMinBytes" {
  type = number
  description = "`fetch.min.bytes` for consumer. Default is 1"
  default = 1
}

variable "kafka_fetchMaxBytes" {
  type = number
  description = "`fetch.max.bytes` for consumer. Default is 50 MB"
  default = 52428800
}

variable "kafka_fetchMaxWaitMs" {
  type = number
  description = "`fetch.max.wait.ms` for consumer. Default is 500"
  default = 500
}

variable "kafka_producerAcks" {
  type = string
  description = "`acks` for producer. Valid values are `all`, `-1`, `0`, `1`. `all` and `-1` are equivalent"
  default = "all"
}

variable "kafka_streams_replication_factor" {
  type = number
  default = 3

}


###############################################################
## Kafka cluster connection
###############################################################

variable "kafka_bootstrap_servers" {
  type = string
}

variable "kafka_sslEndpointIdentificationAlgorithm" {
  type = string
  description = "ssl.endpoint.identification.algorithm for producer and consumer"
  default = ""
}

variable "kafka_saslJaasConfig" {
  description = "sasl.jaas.config for producer and consumer"
  type = string
  default = ""
}

variable "kafka_saslMechanism" {
  type = string
  description = "`sasl.mechanism` for producer and consumer"
  default = ""
}

variable "kafka_securityProtocol" {
  type = string
  description = "security.protocol for producer and consumer"
  default = "PLAINTEXT"
}


###############################################################
## Prometheus, Grafana
###############################################################

variable "monitoring_namespace" {
  type = string
  default = "waterstream-monitoring"
}

variable "prometheus_version" {
  type = string
  default = "v2.33.1" #Latest as per 2022-02-10
}

variable "grafana_version" {
  type = string
  default = "8.3.6" #Latest stable as per 2022-02-10
}