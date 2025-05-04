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
      source = "dmacvicar/libvirt"
      version = ">= 0.6.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu+ssh://${var.libvirt_host}/system?sshauth=privkey"
}

locals {
  cloud_init_pool = "cloud-init"
  cloud_init_configs = {
    for env, vm in var.vms : env => {
      cloud_init = {
        for name, config in vm : name => [
          for id in range(coalesce(lookup(config, "count"), 1)) : templatefile("${path.module}/cloud-init/cloud_init.cfg", {
            hostname = "${env}-${name}-${id}"
            username = var.vm_user
            password_hash = var.vm_user_pass_hash
            auth_keys = var.vm_user_auth_keys
          })
        ]
      }
      meta_data = {
        for name, config in vm : name => [
          for id in range(coalesce(lookup(config, "count"), 1)) : templatefile("${path.module}/cloud-init/meta-data", {
            hostname = "${env}-${name}-${id}"
          })
        ]
      }
    }
  }
}

resource "libvirt_pool" "cloud_init_pool" {
  name = local.cloud_init_pool
  type = "dir"
}

resource "libvirt_network" "default" {
  name = "default"
}

resource "libvirt_pool" "storages" {
  for_each = toset(var.storages)
  name = each.key
  type = "dir"
}

resource "libvirt_network" "networks" {
  for_each = var.networks
  name = each.key
  addresses = ["${each.value}"]
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = {
    for env, vm in var.vms : env => {
      for name, config in vm : name => {
        for id in range(coalesce(lookup(config, "count"), 1)) : "${env}-${name}-${id}" => {
          env = env
          name = name
          id = id
        }
      }
    }
  }

  name = "${each.key}-${each.value.vm.key}-${each.value.id}-init.iso"
  user_data = local.cloud_init_configs[each.value.env].cloud_init[each.value.name][each.value.id]
  meta_data = local.cloud_init_configs[each.value.env].meta_data[each.value.name][each.value.id]
  pool = local.cloud_init_pool
}

resource "libvirt_volume" "main-qcow2" {
  for_each = {
    for env, vm in var.vms : env => {
      for name, config in vm : name => {
        for id in range(coalesce(lookup(config, "count"), 1)) : "${env}-${name}-${id}" => {
          env = env
          name = name
          id = id
        }
      }
    }
  }
  name = "${each.value.env}-${each.value.name}-${each.value.id}.qcow2"
  pool = "default"
  base_volume_id = var.libvirt_qcow2_template_path
  format = "qcow2"
}

resource "libvirt_volume" "qcow2" {
  for_each = {
    for env, vm in var.vms : env => {
      for name, config in vm : name => {
        for id in range(coalesce(lookup(config, "count"), 1)) : id => {
          for storage_index, storage in coalesce(config.storage,{}) : "${env}-${name}-${id}-${storage.storage_name}" => {
            env = env
            name = name
            id = id
            storage = storage
          }
        }
      }
    }
  }

  name = "${each.value.env}-${each.value.name}-${each.value.id}-${each.value.storage.storage_name}.qcow2"
  pool = lookup(each.value.storage, "pool_name", "default")
  format = "qcow2"
  size = lookup(each.value.storage, "size", 5) * 1024 * 1024 * 1024
}

resource "libvirt_domain" "domains" {
  for_each = {
    for env, vm in var.vms : env => {
      for name, config in vm : name => {
        for id in range(coalesce(lookup(config, "count"), 1)) : id => {
            env = env
            name = name
            id = id
            config = config
        }
      }
    }
  }

  name = "${each.value.env}-${each.value.name}-${each.value.id}"
  vcpu = lookup(each.value.config, "vcpus", 2)
  memory = lookup(each.value.config, "ram", 2048)
  cloudinit = libvirt_cloudinit_disk.init["${each.value.env}-${each.value.name}-${each.value.id}-init.iso"].id

  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }

  disk {
    volume_id = libvirt_volume.qcow2["${each.value.env}-${each.value.name}-${each.value.id}"].id
  }

  dynamic "disk" {
    for_each = toset(each.value.config.storage)
    content {
      volume_id = libvirt_volume.qcow2["${each.value.env}-${each.value.name}-${each.value.id}-${disk.storage.storage_name}"].id
    }
  }

  graphics {
    type = "vnc"
  }

  network_interface {
    network_name = "default"
    wait_for_lease = true
  }

  dynamic "network_interface" {
    for_each = each.value.config.networks
    content {
      network_name = lookup(network_interface.value, "name", "default")
    }
  }
}

resource "local_file" "ansible_inventory_file" {
  content = templatefile("${path.module}/inventory_file.yml.tftpl",
    {
      jump_host = var.libvirt_host
      username = var.vm_user

      vm_inventory = {
        for env, vm in var.vms : env => {
          for name, config in vm : name => {
            for id in range(coalesce(lookup(config, "count"), 1)) : "${env}-${name}-${id}" => {
              name = "${env}-${name}-${id}"
              ip = lookup(config.networks[0], "ip", null)
            }
          }
        }
      }
    }
  )
  filename = "../../ansible/inventory/main.yml"
}

