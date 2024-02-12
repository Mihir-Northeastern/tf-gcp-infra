provider "google" {
#   credentials = file(var.credentials)    
  project     = var.project_id
  region      = var.region
}

resource "google_compute_network" "vpc_name" {
  name                    = var.vpc_name
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
}