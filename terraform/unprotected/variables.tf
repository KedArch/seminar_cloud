variable "libvirt_host" {
  description = "Libvirt host for SSH connection (user@host)"
  type        = string
}

variable "control_vms" {
  description = "List of control VM names"
  type        = list(string)
}

variable "worker_vms" {
  description = "List of worker VM names"
  type        = list(string)
}

variable "vm_user" {
  description = "Username for VM user"
  type        = string
  default     = "deploy"
}

variable "vm_user_pass_hash" {
  description = "Password hash for VM user (mkpasswd)"
  type        = string
}

variable "vm_user_auth_keys" {
  description = "List of VM user SSH authorized keys"
  type        = list(string)
}
