terraform {
  required_providers {
    hyperv = {
      version = "1.0.3"
      source  = "registry.terraform.io/taliesins/hyperv"
    }
  }
}

provider "hyperv" {
  user = "sha"
  //password = ""
  host     = "sha1"
  port     = "5985"
  https    = false
  insecure = true
  use_ntlm = true
  //tls_server_name = ""
  //cacert_path     = ""
  //cert_path       = ""
  //key_path        = ""
  //script_path = "C:/Temp/terraform_%RAND%.cmd"
  timeout = "60s"
}
