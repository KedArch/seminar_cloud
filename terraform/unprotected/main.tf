terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.6.0"
    }
  }
}

data "terraform_remote_state" "protected" {
  backend = "local"

  config = {
    path = "../protected/terraform.tfstate"
  }
}

provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_host}/system?sshauth=privkey"
}

locals {
  control_cloud_init_configs = {
    for vm in var.control_vms : vm => templatefile("${path.module}/cloud-init/cloud_init.cfg", {
      hostname      = vm
      username      = var.vm_user
      password_hash = var.vm_user_pass_hash
      auth_keys     = var.vm_user_auth_keys
    })
  }

  control_meta_data_configs = {
    for vm in var.control_vms : vm => templatefile("${path.module}/cloud-init/meta-data", {
      hostname      = vm
    })
  }

  worker_cloud_init_configs = {
    for vm in var.worker_vms : vm => templatefile("${path.module}/cloud-init/cloud_init.cfg", {
      hostname      = vm
      username      = var.vm_user
      password_hash = var.vm_user_pass_hash
      auth_keys     = var.vm_user_auth_keys
    })
  }

  worker_meta_data_configs = {
    for vm in var.worker_vms : vm => templatefile("${path.module}/cloud-init/meta-data", {
      hostname      = vm
    })
  }
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = toset(concat(var.control_vms, var.worker_vms))

  name      = "${each.key}-init.iso"
  user_data = contains(var.control_vms, each.key) ? local.control_cloud_init_configs[each.key] : local.worker_cloud_init_configs[each.key]
  meta_data = contains(var.control_vms, each.key) ? local.control_meta_data_configs[each.key] : local.worker_meta_data_configs[each.key]
  pool      = "default"
}

resource "libvirt_volume" "qcow2" {
  for_each = toset(concat(var.control_vms, var.worker_vms))

  name          = "${each.key}.qcow2"
  pool          = "default"
  base_volume_id = data.terraform_remote_state.protected.outputs.template_id
  format        = "qcow2"
}

resource "libvirt_domain" "control" {
  for_each = toset(var.control_vms)

  name     = each.key
  vcpu     = 2
  memory   = 2048
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  disk {
    volume_id = libvirt_volume.qcow2[each.key].id
  }

  graphics {
    type = "vnc"
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }
}

resource "libvirt_domain" "worker" {
  for_each = toset(var.worker_vms)

  name     = each.key
  vcpu     = 2
  memory   = 2048
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  disk {
    volume_id = libvirt_volume.qcow2[each.key].id
  }

  graphics {
    type = "vnc"
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }
}

locals {
  control_addrs = {
    for control in var.control_vms :
    control => try(libvirt_domain.control[control].network_interface[0].addresses[0], "0.0.0.0")
  }

  worker_addrs = {
    for worker in var.worker_vms :
    worker => try(libvirt_domain.worker[worker].network_interface[0].addresses[0], "0.0.0.0")
  }
}

resource "local_file" "ansible_inventory_file" {
  content = templatefile("${path.module}/inventory_file.yml.tftpl",
    {
      control_addrs = local.control_addrs
      worker_addrs = local.worker_addrs
      jump_host = var.libvirt_host
      username = var.vm_user
    }
  )
  filename = "../../ansible/inventory/main.yml"
}

