terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.28.0"
    }
  }
}

provider "google" {
  # Configuration options

  project = "love-terraform-project"
  region = "asia-southeast1"
  zone = "asia-southeast1-b"
  credentials = "love-terraform-project-cac637d5eadc.json"
}

resource "google_compute_network" "vpc-network" {
  
  project = "love-terraform-project"
  name = "terraform-vpc-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "asia-subnet" {
  project = "love-terraform-project"
  name = "terraform-vpc-subnet"
  network = google_compute_network.vpc-network.name
  ip_cidr_range = "10.244.0.0/24"
  region = "asia-southeast1"
}

resource "google_compute_firewall" "http-rule" {
  name = "http-rule"
  network = google_compute_network.vpc-network.name
  direction = "INGRESS"
  priority = 1000
  target_tags = ["http-server"]
  allow {
    ports= ["80"]
    protocol = "tcp"
  }
  source_ranges =  ["0.0.0.0/0"]
}

resource "google_compute_instance" "asia-instance" {
  project = "love-terraform-project"
  name = "asia-instance"
  machine_type = "e2-micro"
  zone = "asia-southeast1-b"
  tags = ["http-server"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  
  network_interface {
    network = google_compute_network.vpc-network.name
    subnetwork = google_compute_subnetwork.asia-subnet.name
    
    access_config {
    //Ephemeral IP
  } 
    }
  metadata = {
    startup-script = file("${path.module}/remo-script.sh")

 }
}

output "internal_ip" {
    value = google_compute_instance.asia-instance.network_interface[0].access_config[0].nat_ip
  }
output "external_ip" {
    value = google_compute_instance.asia-instance.network_interface[0].access_config[0].nat_ip
  }
