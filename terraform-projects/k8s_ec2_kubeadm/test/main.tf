resource "local_file" "name" {
	filename = each.value 
	for_each = toset(var.name)
	content = "test"
}
