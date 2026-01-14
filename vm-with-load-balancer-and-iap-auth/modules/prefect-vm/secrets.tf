# Secret Manager secret for PostgreSQL database password
resource "google_secret_manager_secret" "prefect_db_password" {
  secret_id = "${var.environment}-prefect-db-password"

  replication {
    auto {}
  }

  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Store the password value in the secret
resource "google_secret_manager_secret_version" "prefect_db_password_version" {
  secret      = google_secret_manager_secret.prefect_db_password.id
  secret_data = var.database_password
}
