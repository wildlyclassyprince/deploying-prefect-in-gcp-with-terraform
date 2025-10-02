output "instance_external_ip" {
  description = "External IP of the instance"
  value       = module.prefect-vm.instance_external_ip
}

output "instance_internal_ip" {
  description = "Internal IP of the instance"
  value       = module.prefect-vm.instance_internal_ip
}


output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = module.prefect-vm.load_balancer_ip
}

output "prefect_url" {
  description = "URL of the Prefect UI"
  value       = module.prefect-vm.prefect_url
}

output "iap_client_id" {
  description = "IAP OAuth client ID"
  value       = module.prefect-vm.prefect_iap_client_id
  sensitive   = true
}
