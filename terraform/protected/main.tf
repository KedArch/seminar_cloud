terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.6.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_host}/system"
}

resource "libvirt_volume" "template" {
  name   = "${var.template_qcow2}"
  pool   = "default"
  format = "qcow2"

  lifecycle {
    prevent_destroy = true
  }
}

