# Health check for Prefect server
resource "google_compute_health_check" "prefect_server_health_check" {
  count = var.enable_load_balancer ? 1 : 0
  name  = "${var.environment}-prefect-server-health-check"
  http_health_check {
    port         = 4200
    request_path = "/api/health"

  }
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# Instance group:
# This is a logical group of VM instances that can be managed as a single unit
# This is how the load balancer communicates with the instances, i.e, "which instances to send traffic to"
resource "google_compute_instance_group" "prefect_group" {
  count     = var.enable_load_balancer ? 1 : 0
  name      = "${var.environment}-prefect-group"
  instances = [google_compute_instance.vm_instance.self_link]
  zone      = var.gcp_zone

  named_port {
    name = "prefect-ui"
    port = 4200
  }

  depends_on = [google_compute_instance.vm_instance]
}

# Backend service for Prefect server with IAP
resource "google_compute_backend_service" "prefect_backend_service" {
  count         = var.enable_load_balancer ? 1 : 0
  name          = "${var.environment}-prefect-server-backend-service"
  health_checks = [google_compute_health_check.prefect_server_health_check[0].id]
  port_name     = "prefect-ui"
  protocol      = "HTTP"
  timeout_sec   = 30
  
  # Attach Cloud Armor security policy
  security_policy = google_compute_security_policy.prefect_protection[0].id

  # Enable logging for security monitoring
  log_config {
    enable      = true
    sample_rate = 1.0
  }

  backend {
    group = google_compute_instance_group.prefect_group[0].id
  }

  # Conditionally enable IAP
  dynamic "iap" {
    for_each = var.enable_iap ? [1] : []
    content {
      oauth2_client_id     = var.iap_client_id
      oauth2_client_secret = var.iap_client_secret
    }
  }
}

# URL map - "send all traffic to the Prefect backend service"
resource "google_compute_url_map" "prefect_url_map" {
  count           = var.enable_load_balancer ? 1 : 0
  name            = "${var.environment}-prefect-url-map"
  default_service = google_compute_backend_service.prefect_backend_service[0].id
}

# IAP access control for authorised users
resource "google_iap_web_backend_service_iam_member" "prefect_access" {
  for_each            = var.enable_load_balancer && var.enable_iap ? toset(var.authorized_users) : toset([])
  web_backend_service = google_compute_backend_service.prefect_backend_service[0].name
  role                = "roles/iap.httpsResourceAccessor"
  member              = "user:${each.value}"
}

resource "google_compute_target_http_proxy" "prefect_http_proxy" {
  count   = var.enable_load_balancer ? 1 : 0
  name    = "${var.environment}-prefect-http-proxy"
  url_map = google_compute_url_map.prefect_redirect_http_to_https[0].id
}

resource "google_compute_global_forwarding_rule" "prefect_http_forwarding_rule" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${var.environment}-prefect-http-forwarding-rule"
  target      = google_compute_target_http_proxy.prefect_http_proxy[0].id
  port_range  = "80"
  ip_protocol = "TCP"
  ip_address  = data.google_compute_global_address.prefect_lb_ip[0].address
}

resource "google_compute_global_forwarding_rule" "prefect_https_forwarding_rule" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "${var.environment}-prefect-https-forwarding-rule"
  target      = google_compute_target_https_proxy.prefect_https_proxy[0].id
  port_range  = "443"
  ip_protocol = "TCP"
  ip_address  = data.google_compute_global_address.prefect_lb_ip[0].address
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "prefect_ssl_certificate" {
  count = var.enable_load_balancer ? 1 : 0
  name  = "${var.environment}-prefect-ssl-certificate"
  managed {
    domains = ["${var.environment}-${var.domain}"]
  }
  lifecycle {
    create_before_destroy = true
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "prefect_https_proxy" {
  count            = var.enable_load_balancer ? 1 : 0
  name             = "${var.environment}-prefect-https-proxy"
  url_map          = google_compute_url_map.prefect_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.prefect_ssl_certificate[0].id]
}

# Redirect HTTP to HTTPS
resource "google_compute_url_map" "prefect_redirect_http_to_https" {
  count = var.enable_load_balancer ? 1 : 0
  name  = "${var.environment}-prefect-http-redirect-to-https"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Cloud Armor security policy
resource "google_compute_security_policy" "prefect_protection" {
  count = var.enable_load_balancer ? 1 : 0
  name  = "${var.environment}-prefect-protection"

  # Enable adaptive protection (ML-based DDoS detection)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  # Use Google's preconfigured WAF rules
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 10001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-v33-stable')"
      }
    }
    description = "Block local file inclusion"
  }

  rule {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "Block remote code execution"
  }

  rule {
    action   = "deny(403)"
    priority = 1003
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('protocolattack-v33-stable')"
      }
    }
    description = "Block protocol attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1007
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # Block null byte injection attacks
  rule {
    action   = "deny(403)"
    priority = 1004
    match {
      expr {
        expression = "request.path.contains('%00') || request.query.contains('%00') || request.headers['user-agent'].contains('%00')"
      }
    }
    description = "Block null byte injection attacks"
  }

  # Block excessively long URLs (potential buffer overflow or DoS)
  rule {
    action   = "deny(403)"
    priority = 1005
    match {
      expr {
        expression = "size(request.path) > 2048 || size(request.query) > 4096"
      }
    }
    description = "Block excessively long URLs"
  }

  # Rate limiting rule - prevent abuse
  rule {
    action   = "rate_based_ban"
    priority = 1006
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limit requests per IP"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 300
    }
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
}
