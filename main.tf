provider "google" {
  project = var.project_id
  region  = var.region

}

resource "google_compute_network" "vpc_name" {
  name                            = var.vpc_name
  provider                        = google-beta
  project                         = var.project_id
  delete_default_routes_on_create = var.delete_default_routes_on_create
  auto_create_subnetworks         = var.auto_create_subnetworks
  routing_mode                    = var.routing_mode
}

resource "google_compute_subnetwork" "subnet_1" {
  name                     = var.subnet_1
  ip_cidr_range            = var.ip_cidr_range_1
  region                   = var.region
  network                  = google_compute_network.vpc_name.self_link
  private_ip_google_access = var.private_ip_google_access
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
  name    = var.firewall_name
  network = google_compute_network.vpc_name.self_link

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  target_tags   = ["gcp-vm-instance-centos-new", "http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "deny-ssh-to-connect" {
  name    = var.deny-ssh-to-connect
  project = var.project_id
  network = google_compute_network.vpc_name.self_link

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gcp-vm-instance-centos-new"]
  priority      = 1000
}

resource "google_compute_firewall" "allow-sql" {
  name    = var.firewall_sql_name
  project = var.project_id
  network = google_compute_network.vpc_name.self_link

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["10.0.1.0/24"]
  priority      = 1000
  direction     = "INGRESS"
}

resource "google_compute_firewall" "deny-internet-connection-sql-db-instance" {
  name    = var.deny-internet-connection-sql-db-instance
  project = var.project_id
  network = google_compute_network.vpc_name.self_link

  deny {
    protocol = "tcp"
    ports    = ["3306"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["db-instance"]
}


# Create a private IP
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "private-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.vpc_name.self_link
}

# Create a private connection
resource "google_service_networking_connection" "private_connection" {
  network                 = google_compute_network.vpc_name.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

resource "google_sql_database_instance" "webapp-sql-instance" {
  provider            = google-beta
  project             = var.project_id
  name                = "webapp-sql-instance"
  region              = "us-east4"
  database_version    = "POSTGRES_15"
  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc_name.self_link
      enable_private_path_for_google_cloud_services = true
    }

    disk_type         = "PD_SSD"
    disk_size         = 100
    availability_type = "REGIONAL"
  }
}

resource "google_sql_database" "cloud-db" {
  name            = var.db-name
  instance        = google_sql_database_instance.webapp-sql-instance.name
  deletion_policy = "ABANDON"
}

resource "google_sql_user" "db-user" {
  name     = var.db-user
  instance = google_sql_database_instance.webapp-sql-instance.name
  password = random_password.db-password.result
}
resource "random_password" "db-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "google_service_account" "default" {
  account_id   = "default"
  display_name = "VM Instance"
}

resource "google_dns_record_set" "a" {
  name         = var.dns_name
  managed_zone = var.dns_zone
  type         = "A"
  ttl          = 60

  rrdatas = [google_compute_instance.default.network_interface[0].access_config[0].nat_ip]
  depends_on = [google_compute_instance.default]
}

resource "google_project_iam_binding" "logging_admin_binding" {
  project = var.project_id
  role    = "roles/logging.admin"

  members = [
    var.service_account_log_metric,
  ]
}

resource "google_project_iam_binding" "monitoring_metric_writer_binding" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    var.service_account_log_metric,
  ]
}


resource "google_compute_instance" "default" {
  name         = "gcp-vm-instance-centos-new"
  machine_type = "n2-standard-4"
  zone         = "us-east4-b"

  tags = ["http-server", "https-server", "webapp"]

  boot_disk {
    initialize_params {
      image = var.packer_image_name
      size  = 100
      type  = "pd-balanced"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "NVME"
  }

  network_interface {
    network    = google_compute_network.vpc_name.self_link
    subnetwork = google_compute_subnetwork.subnet_1.self_link
    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    # foo = "bar"
    dbUser = google_sql_user.db-user.name
    dbPass = google_sql_user.db-user.password
    dbHost = google_sql_database_instance.webapp-sql-instance.private_ip_address
    dbName = google_sql_database.cloud-db.name
  }

  metadata_startup_script = file("./db.sh")
  service_account {
    email  = google_service_account.default.email
    scopes = ["cloud-platform"]
  }

  

}