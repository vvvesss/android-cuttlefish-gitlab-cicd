# terraform/main.tf - CORRECT NETWORK CONFIGURATION
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default = "globalinfratech"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default = "europe-west1-c"
}

variable "network" {
  description = "Network name"
  type        = string
  default = "cryptoapis"
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
  region  = var.region
  zone    = var.zone
}

# Use the VM subnet for Cuttlefish instances
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
    network    = "projects/${var.project_id}/global/networks/${var.network}"
    subnetwork = "projects/${var.project_id}/regions/${var.region}/subnetworks/belgium-europe-west-vm"
    access_config {
      # Ephemeral public IP
    }
  }
  
  metadata_startup_script = file("${path.module}/cuttlefish-startup.sh")
  tags = ["cuttlefish", "android-ci", "allow-adb"]
  
  lifecycle {
    create_before_destroy = true
  }
}

# Instance group manager
resource "google_compute_instance_group_manager" "cuttlefish_group" {
  name               = "cuttlefish-group"
  base_instance_name = "cuttlefish"
  zone               = var.zone
  
  version {
    instance_template = google_compute_instance_template.cuttlefish_template.id
  }
  
  target_size = 0
}

# Firewall rule for ADB access
resource "google_compute_firewall" "allow_adb" {
  name    = "allow-adb-cuttlefish"
  network = "projects/${var.project_id}/global/networks/${var.network}"
  
  allow {
    protocol = "tcp"
    ports    = ["6520", "6444"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-adb"]
  
  priority = 1000
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

output "network_info" {
  description = "Network configuration used"
  value = {
    network    = var.network
    subnetwork = "belgium-europe-west-vm"
    region     = var.region
    zone       = var.zone
  }
}