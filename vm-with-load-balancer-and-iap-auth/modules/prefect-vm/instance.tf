resource "google_compute_instance" "vm_instance" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.gcp_zone

  boot_disk {
    # Non-persistent (deletes with VM)
    auto_delete = true
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      nat_ip = google_compute_address.static_ip_address.address
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tpl", {
    environment         = var.environment
    gcp_project         = var.gcp_project
    db_password_secret  = google_secret_manager_secret.prefect_db_password.secret_id
  })

  metadata = {
    bucket-name = var.artifact_storage
  }

  service_account {
    email = google_service_account.prefect_vm_sa.email
    # Use specific scopes instead of overly-permissive cloud-platform
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append",
      "https://www.googleapis.com/auth/devstorage.read_write", # For GCS artifact storage
    ]
  }

  tags = ["${var.environment}-vm", "prefect", "ssh", "vpn", "web", "lb-backend"]
}
