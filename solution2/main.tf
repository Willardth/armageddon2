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
    startup-script ="#Thanks to Remo\n!/bin/bash\n# Update and install Apache2\napt update\napt install -y apache2\n\n# Start and enable Apache2\nsystemctl start apache2\nsystemctl enable apache2\n\n# GCP Metadata server base URL and header\nMETADATA_URL='http://metadata.google.internal/computeMetadata/v1'\nMETADATA_FLAVOR_HEADER='Metadata-Flavor: Google'\n\n# Use curl to fetch instance metadata\nlocal_ipv4=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/network-interfaces/0/ip')\nzone=$$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/zone')\nproject_id=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/project/project-id')\nnetwork_tags=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/tags')\n\n# Create a simple HTML page and include instance details\ncat <<EOF > /var/www/html/index.html\n<html><body>\n<h2>Welcome to your custom website.</h2>\n<h3>Created with a direct input startup script!</h3>\n<p><b>Instance Name:</b> $(hostname -f)</p>\n<p><b>Instance Private IP Address: </b> $local_ipv4</p>\n<p><b>Zone: </b> $zone</p>\n<p><b>Project ID:</b> $project_id</p>\n<p><b>Network Tags:</b> $network_tags</p>\n</body></html>\nEOF\n"

 }
}

output "internal_ip" {
    value = google_compute_instance.asia-instance.network_interface[0].access_config[0].nat_ip
  }
output "external_ip" {
    value = google_compute_instance.asia-instance.network_interface[0].access_config[0].nat_ip
  }
