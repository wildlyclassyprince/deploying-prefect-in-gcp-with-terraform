# Prefect VM Module

Terraform module for deploying a Prefect server on a GCP Compute Engine VM with optional global load balancer and IAP authentication.

## Resources

This module creates the following resources:

### Compute
- `google_compute_instance.vm_instance` - VM instance running Prefect server
- `google_compute_address.static_ip_address` - Static external IP for VM

### Networking
- `google_compute_network.vpc` - Custom VPC network
- `google_compute_subnetwork.subnet` - Subnet within VPC
- `google_compute_firewall.allow_ssh` - Firewall rule for IAP SSH access
- `google_compute_firewall.allow_vpn` - Firewall rule for VPN access
- `google_compute_firewall.allow_load_balancer_backend` - Firewall rule for LB health checks (conditional)

### Load Balancer (optional)
- `google_compute_health_check.prefect_server_health_check` - HTTP health check
- `google_compute_instance_group.prefect_group` - Unmanaged instance group
- `google_compute_backend_service.prefect_backend_service` - Backend service with optional IAP
- `google_compute_url_map.prefect_url_map` - URL map for routing
- `google_compute_url_map.prefect_redirect_http_to_https` - HTTP to HTTPS redirect
- `google_compute_target_http_proxy.prefect_http_proxy` - HTTP proxy
- `google_compute_target_https_proxy.prefect_https_proxy` - HTTPS proxy
- `google_compute_managed_ssl_certificate.prefect_ssl_certificate` - Managed SSL certificate
- `google_compute_global_forwarding_rule.prefect_http_forwarding_rule` - HTTP forwarding rule
- `google_compute_global_forwarding_rule.prefect_https_forwarding_rule` - HTTPS forwarding rule

### IAM
- `google_service_account.prefect_vm_sa` - Service account for VM
- `google_iap_web_backend_service_iam_member.prefect_access` - IAP access for authorized users (conditional)

### Data Sources
- `google_compute_global_address.prefect_lb_ip` - Pre-reserved global IP address (conditional)

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| gcp_project | GCP Project for the instance | `string` | n/a | yes |
| gcp_region | GCP Region for the instance | `string` | n/a | yes |
| gcp_zone | GCP Zone for the instance | `string` | n/a | yes |
| instance_name | Name of the compute instance | `string` | n/a | yes |
| machine_type | Machine type for the instance | `string` | n/a | yes |
| boot_disk_image | Machine boot disk image | `string` | n/a | yes |
| boot_disk_size_gb | Machine boot disk size in GB | `number` | n/a | yes |
| subnet_cidr | CIDR range for subnet | `string` | n/a | yes |
| vpn_ip_address | The IP address of the VPN | `string` | n/a | yes |
| state_bucket_name | Name of the GCS bucket to store terraform state | `string` | n/a | yes |
| bucket_name | Name of the GCS bucket for Prefect storage | `string` | n/a | yes |
| prefect_postgres_password | Password for the Prefect PostgreSQL database | `string` | n/a | yes |
| environment | Environment name (staging, production) | `string` | `"staging"` | no |
| enable_load_balancer | Whether to create the load balancer for Prefect server | `bool` | `false` | no |
| reserved_prefect_lb_ip_name | Name of the reserved IP address for the load balancer | `string` | `"staging-prefect-lb-ip"` | no |
| prefect_domain | Domain for Prefect server | `string` | n/a | yes |
| enable_iap | Whether to enable IAP for the Prefect server | `bool` | `false` | no |
| iap_brand | IAP brand for Prefect server | `string` | n/a | yes |
| prefect_iap_client_id | IAP client ID for Prefect server | `string` | n/a | yes |
| prefect_iap_client_secret | IAP client secret for Prefect server | `string` | n/a | yes |
| authorized_users | List of authorized users for IAP access | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| instance_external_ip | External IP of the instance |
| instance_internal_ip | Internal IP of the instance |
| load_balancer_ip | IP address of the load balancer (if enabled) |
| prefect_url | URL to access Prefect UI |
| prefect_iap_client_id | IAP OAuth client ID (if IAP enabled) |

## Usage

```hcl
module "prefect-vm" {
  source = "../../modules/prefect-vm"

  # GCP Settings
  gcp_project = "my-gcp-project"
  gcp_region  = "us-central1"
  gcp_zone    = "us-central1-a"

  # Instance Configuration
  instance_name     = "prefect-server"
  machine_type      = "e2-medium"
  boot_disk_image   = "ubuntu-os-cloud/ubuntu-2204-lts"
  boot_disk_size_gb = 60

  # Network
  subnet_cidr    = "10.0.16.0/20"
  vpn_ip_address = "1.2.3.4"

  # Storage
  state_bucket_name = "my-terraform-state"
  bucket_name       = "my-prefect-storage"

  # Load Balancer
  enable_load_balancer        = true
  reserved_prefect_lb_ip_name = "prefect-lb-ip"
  prefect_domain              = "prefect.example.com"

  # IAP
  enable_iap                = true
  iap_brand                 = "projects/123456789/brands/123456789"
  prefect_iap_client_id     = "client-id.apps.googleusercontent.com"
  prefect_iap_client_secret = "client-secret"
  authorized_users          = ["user@example.com"]

  # Environment
  environment = "staging"

  # Secrets
  prefect_postgres_password = "secure-password"
}
```
