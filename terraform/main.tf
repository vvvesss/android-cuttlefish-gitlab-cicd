# terraform/main.tf - Enhanced Cuttlefish Infrastructure
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

# Configure the Google Cloud Provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
  zone    = var.zone
}

# Service account for Cuttlefish instances
resource "google_service_account" "cuttlefish_sa" {
  account_id   = "cuttlefish-ci"
  display_name = "Cuttlefish CI Service Account"
  description  = "Service account for Cuttlefish instances"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "cuttlefish_compute_user" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.cuttlefish_sa.email}"
}

# Startup script for Cuttlefish instances
resource "google_compute_instance_template" "cuttlefish_template" {
  name_prefix  = "cuttlefish-template-"
  description  = "Template for Cuttlefish Android testing instances"
  machine_type = "n1-standard-4"
  
  # Use Ubuntu 20.04 LTS for better Cuttlefish compatibility
  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231213"
    boot         = true
    disk_size_gb = 50
    auto_delete  = true
    disk_type    = "pd-ssd"
  }
  
  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }
  
  # Startup script to install and configure Cuttlefish
  metadata_startup_script = file("${path.module}/cuttlefish-startup.sh")
  
  service_account {
    email  = google_service_account.cuttlefish_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  tags = ["cuttlefish", "android-ci", "allow-adb"]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Managed instance group for auto-scaling
resource "google_compute_instance_group_manager" "cuttlefish_group" {
  name               = "cuttlefish-group"
  base_instance_name = "cuttlefish"
  zone               = var.zone
  
  version {
    instance_template = google_compute_instance_template.cuttlefish_template.id
  }
  
  target_size = 0  # Start with 0, scale up during CI
  
  # Auto-healing
  auto_healing_policies {
    health_check      = google_compute_health_check.cuttlefish_health.id
    initial_delay_sec = 300
  }
  
  # Update policy
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }
}

# Health check for auto-healing
resource "google_compute_health_check" "cuttlefish_health" {
  name                = "cuttlefish-health-check"
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 3
  
  tcp_health_check {
    port = "6520"  # ADB port
  }
}

# Firewall rule to allow ADB connections
resource "google_compute_firewall" "allow_adb" {
  name    = "allow-adb-cuttlefish"
  network = "default"
  
  allow {
    protocol = "tcp"
    ports    = ["6520", "6444"]  # ADB and VNC ports
  }
  
  source_ranges = ["0.0.0.0/0"]  # In production, restrict this
  target_tags   = ["allow-adb"]
}

# Outputs
output "instance_template_name" {
  description = "Name of the Cuttlefish instance template"
  value       = google_compute_instance_template.cuttlefish_template.name
}

output "instance_group_name" {
  description = "Name of the Cuttlefish instance group"
  value       = google_compute_instance_group_manager.cuttlefish_group.name
}

output "service_account_email" {
  description = "Email of the Cuttlefish service account"
  value       = google_service_account.cuttlefish_sa.email
}