variable "elk_config" {
  type = map(any)
  default = {
    "index" = ""

  }
}