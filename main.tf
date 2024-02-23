provider "google" {
  project = var.project_id
  region  = var.region

}

resource "google_compute_network" "vpc_name" {
  name                            = var.vpc_name
  delete_default_routes_on_create = var.delete_default_routes_on_create
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
}

resource "google_compute_subnetwork" "subnet_1" {
  name          = var.subnet_1
  ip_cidr_range = var.ip_cidr_range_1
  region        = var.region
  network       = google_compute_network.vpc_name.self_link
}

resource "google_compute_subnetwork" "subnet_2" {
  name          = var.subnet_2
  ip_cidr_range = var.ip_cidr_range_2
  region        = var.region
  network       = google_compute_network.vpc_name.self_link
}

resource "google_compute_route" "route" {
  name             = var.route
  network          = google_compute_network.vpc_name.self_link
  dest_range       = var.dest_range
  next_hop_gateway = var.next_hop_gateway
}

resource "google_compute_firewall" "firewall-sub" {
  name    = "firewall-sub"
  network = google_compute_network.vpc_name.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "3000"]
  }
  source_tags = ["webapp"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "webapp_address" {
  name = var.address
}

resource "google_service_account" "default" {
  account_id   = "default"
  display_name = "VM Instance"
}

resource "google_compute_instance" "default" {
  name         = "gcp-vm-instance-centos-new"
  machine_type = "n2-standard-2"
  zone         = "us-east1-b"

  tags = ["foo", "bar", "http-server", "https-server", "webapp"]

  boot_disk {
    initialize_params {
      image = "packer-1708651751"
      size  = 100                     
      type  = "pd-balanced"           
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "NVME"
  }

  network_interface {
    //network = "default"
    subnetwork = google_compute_subnetwork.subnet_1.name
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    foo = "bar"
  }

  metadata_startup_script = "echo hi > /test.txt"

  service_account {
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }
}
