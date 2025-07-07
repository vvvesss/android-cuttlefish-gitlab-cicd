#What more?
#Service Account resource
#Health check resource
#Maybe firewall rules
resource "google_compute_instance_template" "cuttlefish_template" {
  name_prefix  = "cuttlefish-template-"
  machine_type = "n1-standard-4"
  
  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
    boot         = true
    disk_size_gb = 50
  }
  
  network_interface {
    network = "default"
    access_config {}
  }
  
  metadata_startup_script = file("scripts/cuttlefish-setup.sh")
  
  service_account {
    email  = google_service_account.cuttlefish_sa.email
    scopes = ["cloud-platform"]
  }
  
  tags = ["cuttlefish", "android-testing"]
}

resource "google_compute_instance_group_manager" "cuttlefish_group" {
  name               = "cuttlefish-group"
  base_instance_name = "cuttlefish"
  zone               = "europe-west1-b"
  
  version {
    instance_template = google_compute_instance_template.cuttlefish_template.id
  }
  
  target_size = 0  # Scale up/down via CI
  
  auto_healing_policies {
    health_check      = google_compute_health_check.cuttlefish_health.id
    initial_delay_sec = 300
  }
}
