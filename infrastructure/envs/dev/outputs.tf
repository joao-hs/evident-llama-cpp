output "ec2_public_ips" {
  value = module.ec2_base.instance_IPv4s
}

output "gce_public_ips" {
  value = module.gce_base.instance_IPv4s
}

output "ec2_instance_ids" {
  value = module.ec2_base.instance_ids
}

output "debug" {
  value = {
    "ec2_image_base_id" : local.ec2_image_llama_id,
    "gce_image_llama_id" : local.gce_image_llama_id,
  }
}
