output "instance_IPv4s" {
  value = [for i in aws_instance.this : i.public_ip]
}
output "instance_ids" {
  value = [for i in aws_instance.this : i.id]
}
