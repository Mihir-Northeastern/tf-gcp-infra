provider "google" {
  #   credentials = file(var.credentials)    
  project = var.project_id
  region  = var.reg
}

resource "google_compute_network" "vpc_name" {
  name                    = var.vpc_name
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
}

resource "google_compute_subnetwork" "subnet_1" {
  name          = var.subnet_1
  ip_cidr_range = "10.0.0.0/24"
  region       = var.region
  network      = google_compute_network.vpc_name.self_link
}

resource "google_compute_subnetwork" "subnet_2" {
  name          = var.subnet_2
  ip_cidr_range = "10.0.1.0/24"
  region       = var.region
  network      = google_compute_network.vpc_name.self_link
}

resource "google_compute_route" "route" {
  name                  = var.route
  network               = google_compute_network.vpc_name.self_link
  dest_range            = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
}
