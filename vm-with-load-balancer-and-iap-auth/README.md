# VM with Load Balancer and IAP

This directory contains the Terraform module and environment configurations for deploying Prefect with optional load balancing and IAP authentication.

## Directory Structure

```
vm-with-load-balancer-and-iap-auth/
├── modules/prefect-vm/        # Reusable Terraform module
│   ├── instance.tf           # VM compute resource
│   ├── network.tf            # VPC, subnets, static IPs
│   ├── loadbalancer.tf       # Global LB, SSL, IAP (conditional)
│   ├── firewall.tf           # Security rules
│   ├── iam.tf                # Service accounts
│   ├── startup.sh.tpl        # VM initialization script
│   ├── vars.tf               # Module input variables
│   └── outputs.tf            # Module outputs
│
└── envs/
    └── staging/              # Example environment
        ├── main.tf          # Instantiates prefect-vm module
        ├── providers.tf     # GCP provider config
        ├── vars.tf          # Environment variables
        ├── outputs.tf       # Environment outputs
        └── terraform.tfvars # Variable values (gitignored)
```

## Module Architecture

### Conditional Resources Pattern

The module uses feature flags to conditionally create resources:

```hcl
resource "google_compute_health_check" "prefect_server_health_check" {
  count = var.enable_load_balancer ? 1 : 0
  # ...
}
```

When `enable_load_balancer = false`, no LB resources are created. When referencing conditional resources, use index `[0]`:

```hcl
health_checks = [google_compute_health_check.prefect_server_health_check[0].id]
```

### IAP Configuration

IAP is conditionally added to the backend service using dynamic blocks:

```hcl
dynamic "iap" {
  for_each = var.enable_iap ? [1] : []
  content {
    oauth2_client_id     = var.prefect_iap_client_id
    oauth2_client_secret = var.prefect_iap_client_secret
  }
}
```

IAM bindings are created for each authorized user:

```hcl
resource "google_iap_web_backend_service_iam_member" "prefect_access" {
  for_each = var.enable_load_balancer && var.enable_iap ? toset(var.authorized_users) : toset([])
  # ...
}
```

### Startup Script Templating

`startup.sh.tpl` uses Terraform's `templatefile()` function for variable interpolation:

```hcl
metadata_startup_script = templatefile("${path.module}/startup.sh.tpl", {
  environment               = var.environment
  prefect_postgres_password = var.prefect_postgres_password
})
```

Variables in the template: `${prefect_postgres_password}`

### State Backend Generation

Each environment dynamically generates its own `backend.tf`:

```hcl
resource "local_file" "default" {
  filename = "${path.module}/backend.tf"
  content  = <<-EOT
    terraform {
      backend "gcs" {
        bucket = "${var.state_bucket_name}"
        prefix = "terraform/state/${var.environment}"
      }
    }
  EOT
}
```

This allows multiple environments to coexist in the same GCP project with isolated state.

## Creating New Environments

To add a new environment (e.g., production):

```bash
# Copy staging as template
cp -r envs/staging envs/production

# Update terraform.tfvars
cd envs/production
vi terraform.tfvars  # Change environment = "production", instance_name, etc.

# Create production-specific GCP resources
gcloud compute addresses create production-prefect-lb-ip --global --ip-version IPV4

# Initialize and deploy
terraform init
terraform apply
```

## Key Differences from Top-Level README

- **Module Implementation Details**: Shows conditional resource patterns, dynamic blocks, and templating
- **Code Examples**: Actual Terraform code snippets from the module
- **Architecture Patterns**: Explains the technical implementation choices
- **Multi-Environment Strategy**: Details on how environments are isolated

For deployment instructions and usage, see the [top-level README](../../README.md).
