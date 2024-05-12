variable "subnet_map" {
  type = map(object({
    subnet_name = string
    network = string
    ip_cidr_range = string
    region = string
  }))
  default = {
    america1 = {
      subnet_name = "america1-subnet"
      network = "america-terraform-vpc"
      ip_cidr_range = "172.16.7.0/24"
      region = "us-south1"
    }
    america2 = {
      subnet_name = "america2-subnet"
      network = "america-terraform-vpc"
      ip_cidr_range = "172.16.6.0/24"
      region = "us-west4"
    }
    asia = {
      subnet_name = "asia-subnet"
      network = "asia-terraform-vpc"
      ip_cidr_range = "192.168.5.0/24"
      region = "asia-northeast3"
    }
    europe = {
      subnet_name = "europe-subnet"
      network = "europe-terraform-vpc"
      ip_cidr_range = "10.155.8.0/24"
      region = "europe-west1"
    }
  }
}

variable "firewall_rule_map" {
  type = map(object({
    network_name = string
    firewall_rule_name = string
    target_tags = list(string)
    ports = list(string)
    protocol = string
    source_ranges = list(string)
  }))
  default = {
    america = {
      firewall_rule_name = "ftpsshhttp"
      network_name = "america-terraform-vpc"  
      target_tags = ["ftp-server", "ssh-server", "http-server"]
      ports = ["22", "20", "80"]
      protocol = "tcp"
      source_ranges = ["0.0.0.0/0", "35.235.240.0/20"]

    }
    asia = {
      firewall_rule_name = "rdp"
      network_name = "asia-terraform-vpc"
      target_tags = ["rdp-server"]
      ports = ["3389"]
      protocol = "tcp"
      source_ranges = ["0.0.0.0/0"]
    }
    europe = {
      firewall_rule_name = "zero"
      network_name = "europe-terraform-vpc"
      target_tags = ["zero-server"]
      ports = []
      protocol = "tcp"
      source_ranges = ["0.0.0.0/0"]
    }
  }
}

variable "instance_map" {
  type = map(object({
    instance_name = string
    zone = string
    tags = list(string)
    network = string
    subnet_name = string
  }))
  default = {
    america1 = {
      instance_name = "america1-instance"
      zone = "us-south1-a"
      tags = ["ftp-server", "ssh-server", "http-server"]
      network = "america-terraform-vpc"
      subnet_name = "america1-subnet"
    }
    america2 = {
      instance_name = "america2-instance"
      zone = "us-west4-a"
      tags = ["ftp-server", "ssh-server", "http-server"]
      network = "america-terraform-vpc"
      subnet_name = "america2-subnet"
    }
    asia = {
      instance_name = "asia-instance"
      zone = "asia-northeast3-a"
      tags = ["rdp-server"]
      network = "asia-terraform-vpc"
      subnet_name = "asia-subnet"
    }
    europe = {
      instance_name = "europe-instance"
      zone = "europe-west1-b"
      tags = ["zero-server"]
      network = "europe-terraform-vpc"
      subnet_name = "europe-subnet"
    }
  }
}
  