resource "aws_instance" "this" {
  count         = var.count_vms
  ami           = var.image_id
  instance_type = var.instance_type

  subnet_id = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [
    aws_security_group.this.id
  ]
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
  }

  cpu_options {
    amd_sev_snp = "enabled"
  }

  tags = merge(var.labels, {
    Name = "${var.name_prefix}-${count.index}"
  })
}

resource "aws_eip_association" "llama-cpp" {
  instance_id   = aws_instance.this[0].id # TODO (hardcoded to the first instance)
  allocation_id = var.eip_allocation_id
}
