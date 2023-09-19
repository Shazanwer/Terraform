resource "kubectl_manifest" "secret_apm" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: apm-secret
  namespace: elk
  labels:
    app: apm-server
type: Opaque
data:
  ELASTIC_PASSWORD: "MDFzeXN0ZW1z"
  KIBANA_PASSWORD: "MDFzeXN0ZW1z"
YAML
}

resource "kubectl_manifest" "configmap_apm" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: elk
  name: apm-server-config
  labels:
    app: apm-server
    name: elk
data:
  apm-server.yml: |-
    apm-server:
      host: "0.0.0.0:8200"

      rum:
        enabled: true
        event_rate.limit: 300
        event_rate.lru_size: 1000
        allow_origins: ['*']
        library_pattern: "node_modules|bower_components|~"
        exclude_from_grouping: "^/webpack"
        source_mapping.enabled: true
        source_mapping.cache.expiration: 5m
        source_mapping.index_pattern: "apm-*-sourcemap*"

      frontend:
        enabled: false

    setup.template.settings:
      index:
        number_of_shards: 1
        codec: best_compression

    output.elasticsearch:
      hosts: $${ELKSERVICE_SERVICE_HOST}:9200
      username: elastic
      password: 01systems

    setup.kibana:
      host: $${KIBANA_HOST}:$${KIBANA_PORT}
      password: 01systems
      path: $${KIBANA_PATH}
YAML
}

resource "kubectl_manifest" "service_apm" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  namespace: elk
  name: apm-server
  labels:
    app: apm-server
spec:
  type: NodePort
  ports:
  - port: 8200
    nodePort: 30020
    name: apm-server
  selector:
    app: apm-server
YAML
}

resource "kubectl_manifest" "server_apm" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: elk
  name: apm-server
  labels:
    app: apm-server
spec:
  selector:
   matchLabels:
    app: apm-server
  replicas: 1
  template:
   metadata:
    name: apm-server
    labels:
     app: apm-server
   spec:
      nodeName: k8s.worker2
      containers:
      - name: apm-server
        image: docker.elastic.co/apm/apm-server:8.9.1
        env:
        - name: ELASTICSEARCH_HOST
          value: $${ELKSERVICE_SERVICE_HOST}
        - name: ELASTICSEARCH_PORT
          value: "9200"
        - name: ELASTICSEARCH_USERNAME
          value: elastic
        - name: ELASTICSEARCH_PASSWORD
          valueFrom:
            secretKeyRef:
              name: apm-secret
              key: ELASTIC_PASSWORD
        - name: KIBANA_HOST
          value: kibana
        - name: KIBANA_PORT
          value: "5601"
        - name: KIBANA_PATH
          value: /monitoring/ui
        ports:
        - containerPort: 8200
          name: apm-server
        volumeMounts:
        - name: config
          mountPath: /usr/share/apm-server/apm-server.yml
          readOnly: true
          subPath: apm-server.yml
      volumes:
      - name: config
        configMap:
          name: apm-server-config
YAML
}