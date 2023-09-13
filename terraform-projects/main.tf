//resource "local_file" "count" {
//  filename = var.filename[count.index]
//  content  = var.content
//  count    = length(var.filename)
//}

resource "local_file" "foreach" {
  filename = each.value
  content  = var.content
  for_each = toset(var.filename)
}

output "test" {
  value = var.content
}