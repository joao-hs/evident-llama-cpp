variable "aws_region" {
  type        = string
  description = "AWS region; AMD SEV-SNP only available in \"eu-west-1\" (Ireland, Europe) and \"us-east-2\" (Ohio, US)"
  default     = "eu-west-1"
}

variable "aws_instance_type" {
  description = "Choose from `aws ec2 describe-instance-types --filters Name=processor-info.supported-features,Values=amd-sev-snp --query 'InstanceTypes[*].[InstanceType]' --output text | sort`"
  type        = string
  default     = "c6a.large"
}

variable "ec2_image_llama_id" {
  description = "AMI ID of llama VM image type"
  type        = string
}

variable "ec2_image_llama_version_file" {
  description = "Relative path to file containing the version suffix of the target image, ex: 1.2.3"
  type        = string
  default     = null
}

variable "ec2_llama_count" {
  description = "Number of VMs to launch of type llama on EC2"
  type        = number
  default     = 1
}

variable "ec2_eip_allocation_id" {
  description = "EIP allocation ID to associate with the instance"
  type        = string
}

locals {
  ec2_image_llama_id = var.ec2_image_llama_version_file == null ? var.ec2_image_llama_id : "${var.ec2_image_llama_id}-${trimspace(file("${path.module}/${var.ec2_image_llama_version_file}"))}"
}

data "aws_ami" "llama" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [local.ec2_image_llama_id]
  }
}

variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  # according to gcp_zone
  type        = string
  description = "Optional GCP region. If null, it will be derived from the zone."
  default     = null
}

variable "gcp_zone" {
  description = "Choose from https://cloud.google.com/confidential-computing/confidential-vm/docs/supported-configurations#supported-zones"
  type        = string
  default     = "europe-west3-a"
}

locals {
  # If gcp_region is provided, use it.
  # Otherwise, strip the last two characters from the zone (e.g., 'us-central1-a' becomes 'us-central1')
  gcp_region = var.gcp_region != null ? var.gcp_region : join("-", slice(split("-", var.gcp_zone), 0, 2))
}

variable "gcp_machine_type" {
  description = "Choose from https://cloud.google.com/compute/docs/general-purpose-machines#n2d_machine_types"
  type        = string
  default     = "n2d-standard-2"
}

variable "gce_image_llama_id" {
  description = "ID of llama VM image type"
  type        = string
}

variable "gce_image_llama_version_file" {
  description = "Relative path to file containing the version suffix of the target image, ex: 1.2.3"
  type        = string
  default     = null
}

locals {
  _gce_raw_image_version    = trimspace(file("${path.module}/${var.gce_image_llama_version_file}"))
  _gce_format_image_version = replace(local._gce_raw_image_version, ".", "-")
  gce_image_llama_id        = var.gce_image_llama_version_file != null ? "${var.gce_image_llama_id}-${local._gce_format_image_version}" : var.gce_image_llama_id
}

variable "gce_llama_count" {
  description = "Number of VMs to launch of type llama on GCE"
  type        = number
  default     = 1
}
