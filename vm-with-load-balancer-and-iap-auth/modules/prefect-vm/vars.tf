variable "state_bucket_name" {
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

variable "vpn_ip_address" {
  description = "The IP address of the vpn"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the GCS bucket to mount"
  type        = string
}

variable "prefect_domain" {
  description = "Domain for Prefect server"
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

variable "reserved_prefect_lb_ip_name" {
  description = "Name of the reserved IP address of the loadbalancer for the Prefect server"
  type        = string
  default     = "staging-prefect-lb-ip"
}

variable "enable_iap" {
  description = "Whether to enable IAP for the Prefect server"
  type        = bool
  default     = false
}

variable "prefect_iap_client_id" {
  description = "IAP client ID for Prefect server"
  type        = string
  sensitive   = true
}

variable "prefect_iap_client_secret" {
  description = "IAP client secret for Prefect server"
  type        = string
  sensitive   = true
}

variable "prefect_postgres_password" {
  description = "Password for the Prefect PostgreSQL database"
  type        = string
  sensitive   = true
}
