resource "kubernetes_pod" "nginx" {
  metadata {
    name      = "nginx-test"
    namespace = "test-ns"
    labels = {
      name = "test"
    }
  }
  spec {
    container {
      image = "nginx"
      name  = "nginx"
    }
  }
}