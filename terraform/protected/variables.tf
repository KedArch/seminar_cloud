variable "s3_endpoint" {
  description = "S3 API endpoint"
}
variable "s3_region" {
  description = "S3 region"
}
variable "s3_bucket" {
  description = "S3 bucket name"
}
variable "s3_key" {
  description = "S3 key (object)"
}
variable "s3_access_key" {
  description = "S3 access key"
}
variable "s3_secret_key" {
  description = "S3 secret key"
}
variable "libvirt_host" {
  description = "Libvirt host for SSH connection (user@host)"
  type        = string
}
variable "template_qcow2" {
  description = "Libvirt qcow2 file template in default storage"
  type        = string
  default     = "debian-12-genericcloud-amd64.qcow2"
}
