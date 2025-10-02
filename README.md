# GCP Terraform Infrastructure

A collection of Terraform infrastructure-as-code projects for architecting and deploying production-ready infrastructure on Google Cloud Platform.

## Projects

### [vm-with-load-balancer-and-iap-auth](./vm-with-load-balancer-and-iap-auth)

**Prefect Server Deployment on GCP**

Terraform module for deploying a Prefect workflow orchestration server on GCP with enterprise-grade features:

- **Compute**: VM running Prefect server with PostgreSQL backend
- **Load Balancer**: Optional global HTTP(S) load balancer with managed SSL certificates
- **Security**: Optional Identity-Aware Proxy (IAP) for zero-trust authentication
- **Networking**: Custom VPC with firewall rules for IAP and VPN access
- **Reliability**: Systemd service management with automatic restarts and health checks

**Use Case**: Production-ready Prefect deployment with optional public access via load balancer and IAP authentication.

[View Documentation →](./vm-with-load-balancer-and-iap-auth/README.md)

## Repository Structure

```
.
├── vm-with-load-balancer-and-iap-auth/
│   ├── modules/
│   │   └── prefect-vm/        # Reusable Terraform module
│   ├── envs/
│   │   └── staging/           # Environment-specific configuration
│   └── README.md              # Detailed project documentation
└── README.md                  # This file
```

## Getting Started

Each project contains:
- **Reusable Terraform modules** - Production-ready infrastructure components
- **Environment configurations** - Example staging/production setups
- **Comprehensive documentation** - Setup instructions and architecture details
- **Example configurations** - `.tfvars.example` files with all required variables

## Prerequisites

General requirements for working with these projects:

- Terraform >= 1.0
- Google Cloud SDK (`gcloud`)
- Active GCP project with appropriate APIs enabled
- GCS bucket for Terraform state storage

## Contributing

Each project is self-contained and can be used independently. Refer to individual project READMEs for specific requirements and deployment instructions.
