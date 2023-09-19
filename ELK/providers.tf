terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.17"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
  }
}

provider "kubernetes" {
  config_path = ".\\admin.conf"
}

provider "kubectl" {
  config_path = ".\\admin.conf"
}
