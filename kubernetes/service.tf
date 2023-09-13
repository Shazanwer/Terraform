resource "kubernetes_service" "nginx" {

  metadata {
    name      = "nginx-example-svc"
    namespace = "test-ns"
  }
  spec {
    selector = {
      name = "test"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}