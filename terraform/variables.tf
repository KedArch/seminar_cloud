variable "s3_endpoint" {
  description = "S3 API endpoint"
  type        = string
}

variable "s3_region" {
  description = "S3 region"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket name"
  type        = string
}

variable "s3_key" {
  description = "S3 key (object)"
  type        = string
}

variable "s3_access_key" {
  description = "S3 access key"
  type        = string
}

variable "s3_secret_key" {
  description = "S3 secret key"
  type        = string
}

variable "libvirt_host" {
  description = "Libvirt host for SSH connection (user@host)"
  type        = string
}

variable "libvirt_qcow2_template_path" {
  description = "Libvirt .qcow2 template file path"
  type        = string
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

variable "networks" {
  description = "Map of additional networks to be created where key is network name and value is network address with mask"
  type = map(string)
  default = {}
}

variable "storages" {
  description = "List of additional storage pools"
  type = list(string)
  default = []
}

variable "vms" {
  description = "Map of VM configurations with named types as keys"
  type = map(map(object({
    count    = optional(number)
    vcpus    = optional(number)
    ram      = optional(number)
    networks = optional(list(object({
      name = string # must be declared in "networks"
      ip   = string # must match network
    })))
    storage  = optional(list(object({
      pool_name    = string # must be declared in "storages"
      storage_name = string
      size         = number # it is multiplied by 1024^3
    })))
  })))
}
