module "prefect-vm" {
  source = "../../modules/prefect-vm"

  # State bucket
  state_bucket_name = var.state_bucket_name

  # Instance
  instance_name     = var.instance_name
  boot_disk_size_gb = var.boot_disk_size_gb
  boot_disk_image   = var.boot_disk_image
  machine_type      = var.machine_type

  # Mounted filesystem
  bucket_name = var.bucket_name

  # Network
  subnet_cidr    = var.subnet_cidr
  enable_vpn     = var.enable_vpn
  vpn_ip_address = var.vpn_ip_address

  # Load balancer
  reserved_prefect_lb_ip_name = var.reserved_prefect_lb_ip_name
  prefect_domain              = var.prefect_domain
  iap_brand                   = var.iap_brand
  authorized_users            = var.authorized_users
  enable_load_balancer        = var.enable_load_balancer
  enable_iap                  = var.enable_iap
  prefect_iap_client_id       = var.prefect_iap_client_id
  prefect_iap_client_secret   = var.prefect_iap_client_secret

  # Location
  gcp_zone    = var.gcp_zone
  gcp_region  = var.gcp_region
  gcp_project = var.gcp_project

  # Environment
  environment = var.environment

  # Prefect postgres
  prefect_postgres_password = var.prefect_postgres_password

}

resource "local_file" "default" {
  file_permission = "0644"
  filename        = "${path.module}/backend.tf"

  content = <<-EOT
        terraform {
            backend "gcs" {
                bucket = "${var.state_bucket_name}"
                prefix = "terraform/state/${var.environment}"
            }
        }
    EOT
}
