# terraform/main.tf - WORKING SIMPLIFIED VERSION
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

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

# Simple instance template (uses default compute service account)
resource "google_compute_instance_template" "cuttlefish_template" {
  name_prefix  = "cuttlefish-template-"
  machine_type = "n1-standard-4"
  
  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231213"
    boot         = true
    disk_size_gb = 50
    auto_delete  = true
  }
  
  network_interface {
    network = "default"
    access_config {}
  }
  
  metadata_startup_script = file("${path.module}/cuttlefish-startup.sh")
  tags = ["cuttlefish", "android-ci", "allow-adb"]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Simple instance group (no health checks initially)
resource "google_compute_instance_group_manager" "cuttlefish_group" {
  name               = "cuttlefish-group"
  base_instance_name = "cuttlefish"
  zone               = var.zone
  
  version {
    instance_template = google_compute_instance_template.cuttlefish_template.id
  }
  
  target_size = 0
}

# Basic firewall rule
resource "google_compute_firewall" "allow_adb" {
  name    = "allow-adb-cuttlefish"
  network = "default"
  
  allow {
    protocol = "tcp"
    ports    = ["6520", "6444"]
  }
  
  source_ranges = ["0.0.0.0/0"]
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
