resource "kubernetes_namespace" "example" {
  metadata {
    name = "test-ns"
  }
}