//resource "kubernetes_manifest" "some_manifest" {
//  manifest = yamldecode(file(".//elk.yaml"))
//}

resource "kubectl_manifest" "namespace" {
  yaml_body = <<YAML
kind: Namespace
apiVersion: v1
metadata:
  name: elk
  labels:
    name: elk
YAML
}

resource "kubectl_manifest" "service_logstash" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: elksvclogstash
  namespace: elk
  labels:
    name: elk
spec:
  type: NodePort
  selector:
    name: elk-logstash
  ports:    
    - port: 5044
      nodePort: 30014
      name: logstash
      targetPort: 5044
      protocol: TCP

YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "service_elasticsearch" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: elksvcelasticsearch
  namespace: elk
  labels:
    name: elk
spec:
  type: NodePort
  selector:
    name: elk-elasticsearch
  ports:
    - port: 9200
      nodePort: 30011
      name: elasticsearch      

YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "service_kibana" {
  yaml_body = <<YAML
apiVersion: v1
kind: Service
metadata:
  name: elksvckibana
  namespace: elk
  labels:
    name: elk
spec:
  type: NodePort
  selector:
    name: elk-kibana
  ports:
    - port: 5601
      nodePort: 30013
      name: kibana
    - port: 8080
      nodePort: 30012
      name: http

YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "configmap_elasticsearchconfig" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: elasticsearchconfig
  namespace: elk
  labels:
    name: elk
data:
  elasticsearch.yml: |-
    cluster.name: k8s-elk-cluster  
    network.host: 0.0.0.0 
    http.host: 0.0.0.0
    #network.host: 127.0.0.1   
    #discovery.seed_hosts: ["127.0.0.1"]
    xpack.ml.enabled: false
    xpack.license.self_generated.type: basic
    xpack.security.enabled: true    
    xpack.security.http.ssl.enabled: false
    logger.org.elasticsearch.discovery: DEBUG
    ingest.geoip.downloader.enabled: false
YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "configmap_kibanaconfig" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: kibanaconfig
  namespace: elk
  labels:
    name: elk
data:
  kibana.yml: |-
    server.name: kibana
    server.host: 0.0.0.0    
    elasticsearch.hosts: ["http://elksvcelasticsearch:9200"]
    elasticsearch.username: kibana_system
    elasticsearch.password: 01systems
    elasticsearch.requestTimeout: 40000
    xpack.actions.allowedHosts: ["*"]
    xpack.actions.enabledActionTypes: ["*"]
    xpack.monitoring.ui.container.elasticsearch.enabled: false
    xpack.reporting.roles.enabled: false      
    xpack.security.enabled: true     
    xpack.encryptedSavedObjects.encryptionKey: d4537d34978e9f99f76be5458628b2a6
    xpack.reporting.encryptionKey: a6d49011ac7693698c79c98fa9c52c1f
    xpack.security.encryptionKey: 6510ead44d8338e1b6a10c6c748a0021    
    xpack.fleet.enabled: true
    xpack.fleet.agents.enabled: true
    #xpack.fleet.agents.elasticsearch.hosts: ["http://elksvcelasticsearch:9200"]
    #xpack.fleet.agents.fleet_server.hosts: ["http://elksvcelasticsearch:9200"]    
    #xpack.fleet.registryUrl: "http://package-registry.corp.net:8080"
    #xpack.fleet.packages:
    #- name: kubernetes
    #  version: latest
    #xpack.fleet.agentPolicies:
    #- name: Default Fleet Server on ECK policy
    #  is_default_fleet_server: true
    #  package_policies:
    #  - package:
    #      name: fleet_server
    #    name: fleet_server-1
    #- name: Default Elastic Agent on ECK policy
    #  is_default: true
    #  unenroll_timeout: 900
    #  package_policies:
    #  - package:
    #      name: system
    #    name: system-1
    #  - package:
    #      name: kubernetes
    #    name: kubernetes-1
    server.publicBaseUrl: "http://10.100.2.12:30013"
    
YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "configmap_logstashconfig" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstashconfig
  namespace: elk
  labels:
    name: elk
data:
  logstash.yml: |-
    http.host: "0.0.0.0"
    xpack.monitoring.elasticsearch.hosts: "http://elksvcelasticsearch:9200"
    xpack.monitoring.enabled: true        
    xpack.monitoring.elasticsearch.username: elastic
    xpack.monitoring.elasticsearch.password: 01systems
    path.config: "/usr/share/logstash/pipeline/logstash.conf"
  logstash.conf: |-
    input {
      beats {
        port => 5044        
      }
    }

    output {  
      stdout { codec => rubydebug }    
      elasticsearch {
        hosts => ["http://elksvcelasticsearch:9200"]
        user => "elastic"
        password => "01systems"
        index => "%%{[@metadata][beat]}-%%{[@metadata][version]}"        
        ilm_enabled => true
        ilm_rollover_alias => "%%{[@metadata][beat]}-%%{[@metadata][version]}"        
        ilm_policy => "7-days"
      }
    }
YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "configmap_filebeatconfig" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeatconfig
  namespace: elk
  labels:
    name: elk
data:
  filebeat.yml: |-
    filebeat.inputs:
    - type: container
      paths:
        - /var/log/containers/*.log 
      processors:
        - add_kubernetes_metadata: 
            host: $${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"  

    output.logstash:
      hosts: ["$${ELKSVCLOGSTASH_SERVICE_HOST}:5044"]
      enabled: true
      username: kibana_system
      password: 01systems
      loadbalance: false
      index: filebeat
YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "elk_secret" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: elk-secret
  namespace: elk
  labels:
    name: elk
type: Opaque
data:
  ELASTIC_PASSWORD: "MDFzeXN0ZW1z"
  KIBANA_PASSWORD: "MDFzeXN0ZW1z"
YAML
  depends_on = [
    kubectl_manifest.namespace
  ]
}

resource "kubectl_manifest" "elasticsearch" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment

metadata:
  name: elasticsearch
  namespace: elk
  labels:
    name: elk
  
spec:
  replicas: 1
  selector:
    matchLabels:
      name: elk-elasticsearch
  template:
    metadata:
      labels:
        name: elk-elasticsearch
    spec:
      restartPolicy: Always
      nodeName: k8s.worker1
      containers:
        - name: elasticsearchcont
          image: "docker.elastic.co/elasticsearch/elasticsearch:8.9.1"          
          resources:
            limits:
              memory: 2000Mi    
              cpu: 1    
            requests:
              memory: 2000Mi
              cpu: 1          
          env:
            - name: discovery.type
              value: single-node
            - name: ELASTIC_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: elk-secret
                  key: ELASTIC_PASSWORD
            - name: KIBANA_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: elk-secret
                  key: KIBANA_PASSWORD
            - name: LS_JAVA_OPTS
              value: "-Xmx512m -Xms512m"
            - name: MY_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          ports:
            - containerPort: 9200
              name: elasticsearch          
          volumeMounts:
            - name: datastorage
              mountPath: "/usr/share/elasticsearch/data"
            - name: esconfig
              mountPath: "/usr/share/elasticsearch/config/elasticsearch.yml"
              readOnly: true
              subPath: elasticsearch.yml
          readinessProbe:
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 25
            exec:
              command:
                - bash
                - -c
                #- curl http://elksvcelasticsearch:9200 | grep -q 'missing authentication credentials'
                #- curl -u \"elastic:$${ELASTIC_PASSWORD}\" http://localhost:9200 | grep -q '^{'
                - 'curl -s -X POST -H "Content-Type: application/json" -u "elastic:$${ELASTIC_PASSWORD}" http://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"$${KIBANA_PASSWORD}\"}" -v | grep -q "^{}"'
      volumes:
        - name: esconfig
          configMap:
            name: elasticsearchconfig
        - name: datastorage
          emptyDir: {}
            #medium: "3000Mi"

YAML
  depends_on = [
    kubectl_manifest.elk_secret,
    kubectl_manifest.configmap_elasticsearchconfig
  ]

}

resource "kubectl_manifest" "kibana" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment

metadata:
  name: kibana
  namespace: elk
  labels:
    name: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      name: elk-kibana
  template:
    metadata:
      labels:
        name: elk-kibana
    spec:
      restartPolicy: Always
      nodeName: k8s-apm
      initContainers:
       - name: wait-for-elasticsearch
         image: appropriate/curl:latest
         command: ['sh', '-c', 'until curl -s http://elksvcelasticsearch:9200; do echo waiting for elasticsearch pod; sleep 2; done;']
      containers:
        - name: kibanacont
          resources:
            limits:
              memory: 3000Mi    
              cpu: 2    
            requests:
              memory: 3000Mi
              cpu: 2
          image: "docker.elastic.co/kibana/kibana:8.9.1"
          volumeMounts:
            - name: kibconfig
              mountPath: "/usr/share/kibana/config/kibana.yml"
              readOnly: true
              subPath: kibana.yml
          env:
            - name: ELASTICSEARCH_USERNAME
              value: kibana_system
            - name: ELASTICSEARCH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: elk-secret
                  key: KIBANA_PASSWORD
            - name: SERVERNAME
              value: kibana
            - name: ELASTICSEARCH_HOSTS
              value: http://elksvcelasticsearch:9200
          ports:
            - containerPort: 5601
          readinessProbe:
            initialDelaySeconds: 60
            periodSeconds: 15
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 25
            exec:
              command:
                - bash
                - -c
                - curl http://elksvcelasticsearch:9200 | grep -q 'missing authentication credentials'
                #- 'curl -s -X POST -H "Content-Type: application/json" -u "elastic:$${ELASTIC_PASSWORD}" http://$${MY_POD_IP}:9200/_security/user/kibana_system/_password -d "{\"password\":\"$${KIBANA_PASSWORD}\"}" -v | grep -q "^{}"'
      volumes:
      - name: kibconfig
        configMap:
            name: kibanaconfig
            items:
              - key: kibana.yml
                path: kibana.yml
YAML
  depends_on = [
    kubectl_manifest.configmap_kibanaconfig
  ]
}

resource "kubectl_manifest" "logstash" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment

metadata:
  name: logstash
  namespace: elk
  labels:
    name: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      name: elk-logstash
  template:
    metadata:
      labels:
        name: elk-logstash
    spec:
      restartPolicy: Always
      nodeName: k8s-apm
      initContainers:
       - name: wait-for-elasticsearch
         image: appropriate/curl:latest
         command: ['sh', '-c', 'until curl -s http://elksvcelasticsearch:9200; do echo waiting for elasticsearch pod; sleep 2; done;']
      containers:
        - name: logstashcont
          resources:
            limits:
              memory: 2000Mi    
              cpu: 1    
            requests:
              memory: 2000Mi
              cpu: 1
          image: "docker.elastic.co/logstash/logstash:8.9.1"
          #env:
          #  - name: ELASTICSEARCH_HOSTS
          #    value: http://elksvcelasticsearch:9200
          volumeMounts:
            - name: lspipeline
              mountPath: "/usr/share/logstash/pipeline/logstash.conf"
              readOnly: true
              subPath: logstash.conf
            - name: lsconfig
              mountPath: "/usr/share/logstash/config/logstash.yml"
              readOnly: true
              subPath: logstash.yml
          ports:
            - containerPort: 5044
          readinessProbe:
            initialDelaySeconds: 100
            periodSeconds: 15
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - bash
                - -c
                - curl http://elksvcelasticsearch:9200 | grep -q 'missing authentication credentials'
      volumes:
        - name: lsconfig
          configMap:
            name: logstashconfig
            items:
              - key: logstash.yml
                path: logstash.yml
        - name: lspipeline
          configMap:
            name: logstashconfig
            items:
              - key: logstash.conf
                path: logstash.conf
YAML
  depends_on = [
    kubectl_manifest.configmap_logstashconfig
  ]
}

resource "kubectl_manifest" "filebeat" {
  yaml_body = <<YAML
apiVersion: apps/v1
kind: DaemonSet

metadata:
  name: filebeat
  namespace: elk
  labels:
    name: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      name: elk-filebeat
  template:
    metadata:
      labels:
        name: elk-filebeat
    spec:
      restartPolicy: Always
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                - key: k8s
                  operator: In
                  values:
                    - worker
      initContainers:
       - name: wait-for-elasticsearch
         image: appropriate/curl:latest
         command: ['sh', '-c', 'until curl -s http://elksvcelasticsearch:9200; do echo waiting for elasticsearch pod; sleep 2; done;']
      containers:
        - name: filebeatcont
          resources:
            limits:
              memory: "1000Mi"
          image: "docker.elastic.co/beats/filebeat:8.9.1"
          #user: root
          env:
            - name: strict.perms
              value: "false"
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          resources:
            limits:
              memory: 2000Mi    
              cpu: 1    
            requests:
              memory: 2000Mi
              cpu: 1 
          volumeMounts:
            - name: fbconfig
              mountPath: "/usr/share/filebeat/filebeat.yml"
              readOnly: true
              subPath: filebeat.yml
            - name: filebeatdata
              mountPath: /usr/share/filebeat/data
            - name: varlogcontainers
              mountPath: /var/log/containers
              readOnly: true
            - name: varlog
              mountPath: /var/log
              readOnly: true          
          readinessProbe:
            initialDelaySeconds: 100
            periodSeconds: 15
            timeoutSeconds: 3
            successThreshold: 1
            failureThreshold: 5
            exec:
              command:
                - bash
                - -c
                - curl http://elksvcelasticsearch:9200 | grep -q 'missing authentication credentials'
      volumes:
        - name: fbconfig
          configMap:
            name: filebeatconfig
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
        - name: varlog
          hostPath:
            path: /var/log        
        - name: filebeatdata
          emptyDir:
            medium: ""

# k create clusterrole filebeat-cr --verb="*" --resource=nodes,deployments,pods,namespaces,replicasets,jobs -n elk
# k create clusterrolebinding filebeat-crb --clusterrole=filebeat-cr --serviceaccount=elk:default -n elk

YAML

  depends_on = [
    kubectl_manifest.configmap_filebeatconfig
  ]
}