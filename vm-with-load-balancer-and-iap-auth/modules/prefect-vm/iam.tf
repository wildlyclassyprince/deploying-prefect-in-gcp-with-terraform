resource "google_service_account" "prefect_vm_sa" {
  account_id   = "${var.environment}-prefect-vm-sa"
  display_name = "${title(var.environment)} Prefect VM Service Account"
  description  = "Service account for ${title(var.environment)} Prefect VM"
}
