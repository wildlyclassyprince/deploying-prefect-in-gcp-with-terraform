variable "terraform_state_storage" {
  description = "Name of the GCS bucket to store the terraform state"
  type        = string
}

variable "gcp_project" {
  description = "GCP Project for the instance"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region for the instance"
  type        = string
}

variable "gcp_zone" {
  description = "GCP Zone for the instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
}

variable "boot_disk_image" {
  description = "Machine boot disk image"
  type        = string
}

variable "boot_disk_size_gb" {
  description = "Machine boot disk size in GB"
  type        = number
}

variable "subnet_cidr" {
  description = "CIDR range for subnet"
  type        = string
}

variable "environment" {
  description = "Enviroment name (stg, prd)"
  type        = string
  default     = "staging"
}

variable "enable_vpn" {
  description = "Whether to create VPN firewall rule"
  type        = bool
  default     = false
}

variable "vpn_ip" {
  description = "The IP address of the VPN"
  type        = string
  sensitive   = true
  default     = ""
}

variable "artifact_storage" {
  description = "Name of the GCS bucket for artifact storage"
  type        = string
}

variable "domain" {
  description = "Domain for the server"
  type        = string
}

variable "iap_brand" {
  description = "IAP brand for Prefect server"
  type        = string
}

variable "authorized_users" {
  description = "List of authorised users"
  type        = list(string)
}

variable "enable_load_balancer" {
  description = "Whether to create the load balancer for Prefect server"
  type        = bool
  default     = false
}

variable "load_balancer_ip_name" {
  description = "Name of the reserved IP address for the load balancer"
  type        = string
  default     = "staging-prefect-lb-ip"
}

variable "enable_iap" {
  description = "Whether to enable IAP for the Prefect server"
  type        = bool
  default     = false
}

variable "iap_client_id" {
  description = "IAP OAuth client ID"
  type        = string
  sensitive   = true
}

variable "iap_client_secret" {
  description = "IAP OAuth client secret"
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}
