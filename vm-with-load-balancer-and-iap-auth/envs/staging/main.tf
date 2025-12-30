module "prefect-vm" {
  source = "../../modules/prefect-vm"

  # State bucket
  terraform_state_storage = var.terraform_state_storage

  # Instance
  instance_name     = var.instance_name
  boot_disk_size_gb = var.boot_disk_size_gb
  boot_disk_image   = var.boot_disk_image
  machine_type      = var.machine_type

  # Mounted filesystem
  artifact_storage = var.artifact_storage

  # Network
  subnet_cidr = var.subnet_cidr
  enable_vpn  = var.enable_vpn
  vpn_ip      = var.vpn_ip

  # Load balancer
  load_balancer_ip_name = var.load_balancer_ip_name
  domain                = var.domain
  iap_brand             = var.iap_brand
  authorized_users      = var.authorized_users
  enable_load_balancer  = var.enable_load_balancer
  enable_iap            = var.enable_iap
  iap_client_id         = var.iap_client_id
  iap_client_secret     = var.iap_client_secret

  # Location
  gcp_zone    = var.gcp_zone
  gcp_region  = var.gcp_region
  gcp_project = var.gcp_project

  # Environment
  environment = var.environment

  # Database
  database_password = var.database_password

}

resource "local_file" "default" {
  file_permission = "0644"
  filename        = "${path.module}/backend.tf"

  content = <<-EOT
        terraform {
            backend "gcs" {
                bucket = "${var.terraform_state_storage}"
                prefix = "terraform/state/${var.environment}"
            }
        }
    EOT
}
