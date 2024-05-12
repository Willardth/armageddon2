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

# Creating VPC Networks
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

# Creating subnets for each network
resource "google_compute_subnetwork" "subnet" {
  for_each = var.subnet_map

  project = "love-terraform-project"
  name = each.value.subnet_name
  network = each.value.network
  ip_cidr_range = each.value.ip_cidr_range
  region = each.value.region

  depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network]
}

# Creating firewall rules for each network through tags targeting instance
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
  source_ranges = each.value.source_ranges

  depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network,]
}

# Creating instances
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
    startup-script = file("${path.module}/remo-script.sh")

 }

 depends_on = [google_compute_network.america-vpc-network, google_compute_network.asia-vpc-network, google_compute_network.europe-vpc-network, google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}

# Network Peering between America and Europe
resource "google_compute_network_peering" "america-to-europe" {
  name = "america-to-europe"
  network = google_compute_network.america-vpc-network.self_link
  peer_network = google_compute_network.europe-vpc-network.self_link



  depends_on = [google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}


resource "google_compute_network_peering" "europe-to-america" {
  name = "europe-to-america"
  network = google_compute_network.europe-vpc-network.self_link
  peer_network = google_compute_network.america-vpc-network.self_link


  depends_on = [google_compute_subnetwork.subnet, google_compute_firewall.firewall_rules]
}

# Asia VPN Gateway
resource "google_compute_vpn_gateway" "asia_gateway" {
  name = "asia-vpn"
  region = "asia-northeast3"
  network = google_compute_network.asia-vpc-network.id
}

# Europe VPN Gateway
resource "google_compute_vpn_gateway" "hq_gateway" {
  name = "europe-vpn"
  region = "europe-west1"
  network = google_compute_network.europe-vpc-network.id
  }

# External Static IP addresses for VPN
resource "google_compute_address" "asia_external_ip" {
  name = "asia-vpn-external-ip"
  region = "asia-northeast3"
}

resource "google_compute_address" "europe_external_ip" {
  name = "europe-vpn-external-ip"
  region = "europe-west1"
}

# VPN Tunnel from Asia to HQ
data "google_secret_manager_secret_version" "vpn_secret" {
  secret = "vpn-shared-secret"
  version = "latest"
}

resource "google_compute_vpn_tunnel" "tunnel1" {
  name = "hq-vpn-tunnel1"
  region = "asia-northeast3"
  vpn_gateway = google_compute_vpn_gateway.asia_gateway.id
  peer_ip = google_compute_address.europe_external_ip.address
  shared_secret = data.google_secret_manager_secret_version.vpn_secret.secret_data
  ike_version = 2
  
  local_traffic_selector = ["192.168.5.0/24"]
  remote_traffic_selector = ["10.155.8.0/24"]

  depends_on = [google_compute_forwarding_rule.asia_esp, google_compute_forwarding_rule.asia_udp500, google_compute_forwarding_rule.asia_udp4500]
}

# Route for Asia to HQ
resource "google_compute_route" "asia_to_hq" {
  name     = "asia-to-hq-route"
  network  = google_compute_network.asia-vpc-network.id
  dest_range = "10.155.8.0/24"
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.id
  priority = 1000
}

# Forwarding Rules for Asia VPN
resource "google_compute_forwarding_rule" "asia_esp" {
  name = "asia-esp"
  region = "asia-northeast3"
  ip_protocol = "ESP"
  ip_address = google_compute_address.asia_external_ip.address
  target = google_compute_vpn_gateway.asia_gateway.self_link
}

resource "google_compute_forwarding_rule" "asia_udp500" {
  name = "asia-udp500"
  region = "asia-northeast3"
  ip_protocol = "UDP"
  port_range = "500"
  ip_address = google_compute_address.asia_external_ip.address
  target = google_compute_vpn_gateway.asia_gateway.self_link
}

resource "google_compute_forwarding_rule" "asia_udp4500" {
  name = "asia-udp4500"
  region = "asia-northeast3"
  ip_protocol = "UDP"
  port_range = "4500"
  ip_address = google_compute_address.asia_external_ip.address
  target = google_compute_vpn_gateway.asia_gateway.self_link
}   

# Tunnel from HQ to Asia
resource "google_compute_vpn_tunnel" "tunnel2" {
  name = "hq-vpn-tunnel2"
  region = "europe-west1"
  target_vpn_gateway = google_compute_vpn_gateway.hq_gateway.id
  peer_ip = google_compute_address.asia_external_ip.address
  shared_secret = data.google_secret_manager_secret_version.vpn_secret.secret_data
  ike_version = 2

  local_traffic_selector = ["10.155.8.0/24"]
  remote_traffic_selector = ["192.168.5.0/24"]

  depends_on = [google_compute_forwarding_rule.europe_esp, google_compute_forwarding_rule.europe_udp500, google_compute_forwarding_rule.europe_udp4500]
}

# Route for HQ to Asia
resource "google_compute_route" "hq_to_asia_route" {
  depends_on = [google_compute_vpn_tunnel.tunnel2]
  name = "hq-to-asia-route"
  network = google_compute_network.europe-vpc-network.id
  dest_range = "192.168.5.0/24"
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel2.id
}

# Forwarding Rules for HQ VPN
resource "google_compute_forwarding_rule" "europe_esp" {
  name = "europe-esp"
  region = "europe-west1"
  ip_protocol = "ESP"
  ip_address = google_compute_address.europe_external_ip.address
  target = google_compute_vpn_gateway.hq_gateway.self_link
}

resource "google_compute_forwarding_rule" "europe_udp500" {
  name = "europe-udp500"
  region = "europe-west1"
  ip_protocol = "UDP"
  port_range = "500"
  ip_address = google_compute_address.europe_external_ip.address
  target = google_compute_vpn_gateway.hq_gateway.self_link
}

resource "google_compute_forwarding_rule" "europe_udp4500" {
  name = "europe-udp4500"
  region = "europe-west1"
  ip_protocol = "UDP"
  port_range = "4500"
  ip_address = google_compute_address.europe_external_ip.address
  target = google_compute_vpn_gateway.hq_gateway.self_link
}