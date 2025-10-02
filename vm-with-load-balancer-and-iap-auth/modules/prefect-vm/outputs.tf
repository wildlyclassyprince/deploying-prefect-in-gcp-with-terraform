output "instance_external_ip" {
  description = "External IP of the instance"
  value       = google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip
}

output "instance_internal_ip" {
  description = "Internal IP of the instance"
  value       = google_compute_instance.vm_instance.network_interface[0].network_ip
}

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = var.enable_load_balancer ? data.google_compute_global_address.prefect_lb_ip[0].address : null
}

output "prefect_url" {
  description = "URL of the Prefect UI"
  value       = var.enable_load_balancer ? "https://${var.environment}-${var.prefect_domain}" : "http://${google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip}:4200"
}

output "prefect_iap_client_id" {
  description = "IAP OAuth client ID"
  value       = var.enable_load_balancer && var.enable_iap ? var.prefect_iap_client_id : null
  sensitive   = true
}
