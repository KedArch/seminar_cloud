variable "libvirt_host" {
  description = "Libvirt host for SSH connection (user@host)"
  type        = string
}
variable "template_qcow2" {
  description = "Libvirt qcow2 file template in default storage"
  type        = string
  default     = "debian-12-genericcloud-amd64.qcow2"
