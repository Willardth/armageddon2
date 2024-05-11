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
  credentials = "love-terraform-project-cac637d5eadc.json"
}

resource "google_compute_network" "america-vpc-network" {
  project = "love-terraform-project"
  name = "america-terraform-vpc"
  auto_create_subnetworks = false
  mtu = 1460
}

resource "google_compute_network" "asia-vpc-network" {
  project = "love-terraform-project"
  name = "asia-terraform-vpc"
  auto_create_subnetworks = false
  mtu = 1460
}

resource "google_compute_network" "europe-vpc-network" {
  project = "love-terraform-project"
  name = "europe-terraform-vpc"
  auto_create_subnetworks = false
  mtu = 1460
}


resource "google_compute_subnetwork" "subnet" {
  for_each = var.subnet_map

  project = "love-terraform-project"
  name = each.value.subnet_name
  network = each.value.network
  ip_cidr_range = each.value.ip_cidr_range
  region = each.value.region

  depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network]
}

resource "google_compute_firewall" "firewall_rules" {
  for_each = var.firewall_rule_map

  project = "love-terraform-project"
  name = each.value.firewall_rule_name
  network = each.value.network_name
  direction = "INGRESS"
  priority = 1000
  target_tags = each.value.target_tags
  allow {
    ports = each.value.ports
    protocol = each.value.protocol
    
  }
  source_ranges =  ["0.0.0.0/0"]

  depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network,]
}

resource "google_compute_instance" "instance" {
  for_each = var.instance_map

  project = "love-terraform-project"
  name = each.value.instance_name
  machine_type = "e2-micro"
  zone = each.value.zone
  tags = each.value.tags
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }
  
  network_interface {
    network = each.value.network
    subnetwork = each.value.subnet_name
    
    access_config {
    //Ephemeral IP
  } 
    }
  metadata = {
    startup-script ="#Thanks to Remo\n!/bin/bash\n# Update and install Apache2\napt update\napt install -y apache2\n\n# Start and enable Apache2\nsystemctl start apache2\nsystemctl enable apache2\n\n# GCP Metadata server base URL and header\nMETADATA_URL='http://metadata.google.internal/computeMetadata/v1'\nMETADATA_FLAVOR_HEADER='Metadata-Flavor: Google'\n\n# Use curl to fetch instance metadata\nlocal_ipv4=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/network-interfaces/0/ip')\nzone=$$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/zone')\nproject_id=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/project/project-id')\nnetwork_tags=$(curl -H '$${METADATA_FLAVOR_HEADER}' -s '$${METADATA_URL}/instance/tags')\n\n# Create a simple HTML page and include instance details\ncat <<EOF > /var/www/html/index.html\n<html><body>\n<h2>Welcome to your custom website.</h2>\n<h3>Created with a direct input startup script!</h3>\n<p><b>Instance Name:</b> $(hostname -f)</p>\n<p><b>Instance Private IP Address: </b> $local_ipv4</p>\n<p><b>Zone: </b> $zone</p>\n<p><b>Project ID:</b> $project_id</p>\n<p><b>Network Tags:</b> $network_tags</p>\n</body></html>\nEOF\n"

 }

 depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network, google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}

resource "google_compute_network_peering" "america-to-europe" {
  name         = "america-to-europe"
  network      = google_compute_network.america-vpc-network.self_link
  peer_network = google_compute_network.europe-vpc-network.self_link



  depends_on = [google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}


resource "google_compute_network_peering" "europe-to-america" {
  name         = "europe-to-america"
  network      = google_compute_network.europe-vpc-network.self_link
  peer_network = google_compute_network.america-vpc-network.self_link


  depends_on = [google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}

resource "google_compute_ha_vpn_gateway" "hq_gateway" {
  region   = "asia-northeast3"
  name     = "asia-vpn"
  network  = google_compute_network.asia-vpc-network.id
}

resource "google_compute_external_vpn_gateway" "external_gateway" {
  name            = "external-gateway"
  redundancy_type = "SINGLE_IP_INTERNALLY_REDUNDANT"
  description     = "An externally managed VPN gateway"
  interface {
    id         = 0
    ip_address = "8.8.8.8"
  }
}

resource "google_compute_router" "router1" {
  name     = "asia-vpn-router1"
  network  = google_compute_network.asia-vpc-network.id
  region   = "asia-northeast3"
  bgp {
    asn = 64514
  }
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  name                            = "hq-vpn-tunnel1"
  region                          = "asia-northeast3"
  vpn_gateway                     = google_compute_ha_vpn_gateway.hq_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = "a secret message"
  router                          = google_compute_router.router1.id
  vpn_gateway_interface           = 0
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  name                            = "hq-vpn-tunnel2"
  region                          = "asia-northeast3"
  vpn_gateway                     = google_compute_ha_vpn_gateway.hq_gateway.id
  peer_external_gateway           = google_compute_external_vpn_gateway.external_gateway.id
  peer_external_gateway_interface = 0
  shared_secret                   = "a secret message"
  router                          = " ${google_compute_router.router1.id}"
  vpn_gateway_interface           = 1
}

resource "google_compute_router_interface" "router1_interface1" {
  name       = "router1-interface1"
  router     = google_compute_router.router1.name
  region     = "asia-northeast3"
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel1.name
}

resource "google_compute_router_peer" "router1_peer1" {
  name                      = "router1-peer1"
  router                    = google_compute_router.router1.name
  region                    = "asia-northeast3"
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = 64515
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router1_interface1.name
}

resource "google_compute_router_interface" "router1_interface2" {
  name       = "router1-interface2"
  router     = google_compute_router.router1.name
  region     = "asia-northeast3"
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.tunnel2.name
}

resource "google_compute_router_peer" "router1_peer2" {
  name                      = "router1-peer2"
  router                    = google_compute_router.router1.name
  region                    = "asia-northeast3"
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = 64515
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router1_interface2.name
}