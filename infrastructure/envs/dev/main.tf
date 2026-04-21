locals {
  gce_vm_types = {
    llama = {
      image_id = local.gce_image_llama_id
      count    = var.gce_llama_count
    }
  }
  ec2_vm_types = {
    llama = {
      image_id = data.aws_ami.llama.id
      count    = var.ec2_llama_count
    }
  }
}

module "gce_base" {
  source = "../../modules/gce-simple"

  name_prefix = "llama"

  machine_type = var.gcp_machine_type
  zone         = var.gcp_zone

  image_id  = local.gce_vm_types.llama.image_id
  count_vms = local.gce_vm_types.llama.count

  labels = {
    vm_type = "llama"
    env     = "dev"
  }

  tags = [
    "https-server"
  ]
}

module "ec2_base" {
  source = "../../modules/ec2-simple"

  name_prefix = "llama"

  instance_type = var.aws_instance_type

  image_id  = local.ec2_vm_types.llama.image_id
  count_vms = local.ec2_vm_types.llama.count

  labels = {
    vm_type = "llama"
    env     = "dev"
  }

  eip_allocation_id = var.ec2_eip_allocation_id
}
