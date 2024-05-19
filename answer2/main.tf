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
  region = "us-central1"
  zone = "us-central1-b"
  credentials = "love-terraform-project-f30ae0f1b12a.json"
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
  region = "us-central1"
  private_ip_google_access = true
}

resource "google_compute_firewall" "http" {
  name    = "allow-http"
  network = google_compute_network.vpc-network.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 100
}

resource "google_compute_firewall" "https" {
  name    = "allow-https"
  network = google_compute_network.vpc-network.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 100
}

resource "google_compute_instance" "us-instance" {
  project = "love-terraform-project"
  name = "us-instance"
  machine_type = "e2-medium"
  zone = "us-central1-b"
  

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size = 10
    }
  }
  
  network_interface {
    network = google_compute_network.vpc-network.name
    subnetwork = google_compute_subnetwork.asia-subnet.name
    access_config {
    //Ephemeral IP
  } 
  }

  tags = ["http-server"]
  metadata_startup_script = file("startup.sh")

 
  depends_on = [google_compute_network.vpc-network, google_compute_subnetwork.asia-subnet]

}

output "internal_ip" {
    value = google_compute_instance.us-instance.network_interface[0].network_ip
  }
output "external_ip" {
    value = google_compute_instance.us-instance.network_interface[0].access_config[0].nat_ip
  }

output "website_url" {
  value = "http://${google_compute_instance.us-instance.network_interface[0].access_config[0].nat_ip}"
}