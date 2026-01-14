resource "google_compute_firewall" "allow_ssh" {
  name        = "${var.environment}-allow-iap-ssh"
  network     = google_compute_network.vpc.name
  description = "Allow SSH access"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["${var.environment}-vm", "prefect", "ssh"]
}

resource "google_compute_firewall" "allow_vpn" {
  count       = var.enable_vpn ? 1 : 0
  name        = "${var.environment}-allow-vpn"
  network     = google_compute_network.vpc.name
  description = "Allow VPN traffic"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["${var.vpn_ip}/32"]
  target_tags   = ["${var.environment}-vm", "prefect", "vpn"]
}

resource "google_compute_firewall" "allow_load_balancer_backend" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${var.environment}-allow-load-balancer-backend"
  network     = google_compute_network.vpc.name
  description = "Allow load balancer backend traffic"

  allow {
    protocol = "tcp"
    ports    = ["4200"]
  }

  # These are GCP provided IP ranges
  source_ranges = [
    "130.211.0.0/22", # GCP Load Balancer
    "35.191.0.0/16",  # GCP Load Balancer
    "35.235.240.0/20" # GCP IAP
  ]
  target_tags = ["${var.environment}-vm", "prefect", "lb-backend"]
}

# Deny direct internet access to Prefect UI (port 4200)
# This ensures Prefect can only be accessed through the load balancer
resource "google_compute_firewall" "deny_direct_prefect_access" {
  name        = "${var.environment}-deny-direct-prefect-access"
  network     = google_compute_network.vpc.name
  description = "Block direct internet access to Prefect UI port 4200"
  priority    = 900 # Higher priority (lower number) than default allow rules

  deny {
    protocol = "tcp"
    ports    = ["4200"]
  }

  # Block from all sources except the allowed LB/IAP ranges
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.environment}-vm", "prefect"]
}
