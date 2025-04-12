terraform {
  backend "s3" {
    endpoints = {
      s3 = "${var.s3_endpoint}"
    }
    region = "${var.s3_region}"
    bucket = "${var.s3_bucket}"
    key = "${var.s3_key}"
    access_key = "${var.s3_access_key}"
    secret_key = "${var.s3_secret_key}"
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
  }
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.6.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_host}/system?sshauth=privkey"
}

resource "libvirt_volume" "template" {
  name   = "${var.template_qcow2}"
  pool   = "default"
  format = "qcow2"

  lifecycle {
    prevent_destroy = true
  }
}

