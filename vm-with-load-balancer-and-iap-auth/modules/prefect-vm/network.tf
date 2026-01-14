resource "google_compute_network" "vpc" {
  name                    = "${var.instance_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.instance_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.vpc.id

  # Enable Private Google Access so VMs can reach GCP APIs without public IPs
  private_ip_google_access = true
}

resource "google_compute_address" "static_ip_address" {
  name   = "${var.instance_name}-static-ip-address"
  region = var.gcp_region
}

data "google_compute_global_address" "prefect_lb_ip" {
  count = var.enable_load_balancer ? 1 : 0
  name  = var.load_balancer_ip_name
}
