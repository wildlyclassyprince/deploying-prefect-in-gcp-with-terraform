resource "google_service_account" "prefect_vm_sa" {
  account_id   = "${var.environment}-prefect-vm-sa"
  display_name = "${title(var.environment)} Prefect VM Service Account"
  description  = "Service account for ${title(var.environment)} Prefect VM"
}

# Grant Cloud Logging permissions
resource "google_project_iam_member" "prefect_vm_logging" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.prefect_vm_sa.email}"
}

# Grant Cloud Monitoring permissions
resource "google_project_iam_member" "prefect_vm_monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.prefect_vm_sa.email}"
}

# Grant Cloud Trace permissions (for distributed tracing)
resource "google_project_iam_member" "prefect_vm_trace" {
  project = var.gcp_project
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.prefect_vm_sa.email}"
}
