variable "filename" {
  type    = list(string)
  default = ["F:\\Terraform\\test.txt", "F:\\Terraform\\test1.txt", "F:\\Terraform\\test2.txt"]
}

variable "content" {
  default = "this is a test file from terraform from variable"
}