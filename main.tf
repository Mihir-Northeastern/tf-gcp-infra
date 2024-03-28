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
    ports    = ["3000", "22", "5432"]
  }

  target_tags   = ["gcp-vm-instance-centos-new", "http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
}

# resource "google_compute_firewall" "deny-ssh-to-connect" {
#   name    = var.deny-ssh-to-connect
#   project = var.project_id
#   network = google_compute_network.vpc_name.self_link

#   deny {
#     protocol = "tcp"
#     ports    = ["22"]
#   }

#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = ["gcp-vm-instance-centos-new"]
#   priority      = 1000
# }

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



# resource "google_compute_firewall" "deny-internet-connection-sql-db-instance" {
#   name    = var.deny-internet-connection-sql-db-instance
#   project = var.project_id
#   network = google_compute_network.vpc_name.self_link

#   deny {
#     protocol = "tcp"
#     ports    = ["3306"]
#   }

#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = ["db-instance"]
# }


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

resource "google_compute_firewall" "allow-port-3000" {
  name    = "allow-port-3000"
  network = google_compute_network.vpc_name.self_link

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  source_ranges = ["0.0.0.0/0"] # Adjust as needed to limit traffic source
}

# Creates a VPC Access Connector
resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  machine_type  = "e2-micro"
  region        = "us-east4"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc_name.self_link
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
    tier = "db-custom-1-3840"
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

resource "google_project_iam_binding" "cloudsql_admin_role" {
  project = var.project_id
  role    = "roles/cloudsql.admin"

  members = [
    "serviceAccount:${google_sql_database_instance.webapp-sql-instance.service_account_email_address}",
  ]
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
  special          = false
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

  rrdatas    = [google_compute_instance.default.network_interface[0].access_config[0].nat_ip]
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

# Create a Pub/Sub topic
resource "google_pubsub_topic" "verify_email" {
  name                       = "verify_email"
  message_retention_duration = "604800s"
}

# Create a Pub/Sub subscription
resource "google_pubsub_subscription" "verify_email_subscription" {
  name  = "verify_email_subscription"
  topic = google_pubsub_topic.verify_email.name
}

# Grant the Cloud Function service account access to the Pub/Sub topic
resource "google_pubsub_topic_iam_binding" "publisher_access" {
  topic = google_pubsub_topic.verify_email.name
  role  = "roles/pubsub.publisher"

  members = [
    var.service_account_log_metric
  ]
}

# Create a Bucket to store the Cloud Function
resource "google_storage_bucket" "bucket" {
  name     = "bucket-for-cloud-function-0022"
  location = var.region
}

# Upload the Cloud Function to the Bucket
resource "google_storage_bucket_object" "archive" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.bucket.name
  source = "./function-source.zip"
}

# Create a Cloud Function
resource "google_cloudfunctions_function" "lambda" {
  name    = "lambda"
  region  = var.region
  runtime = "nodejs20"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  entry_point           = "verifyEmail"
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.verify_email.name
  }

  environment_variables = {
    CLOUDSQL_INSTANCE_CONNECTION_NAME = google_sql_database_instance.webapp-sql-instance.connection_name
    DB_NAME                           = google_sql_database.cloud-db.name
    DB_USER                           = google_sql_user.db-user.name
    DB_PASSWORD                       = google_sql_user.db-user.password
    DB_HOST                           = google_sql_database_instance.webapp-sql-instance.private_ip_address
    MAILGUN_API_KEY                   = var.mailgun_api_key
    MAILGUN_DOMAIN                    = var.mailgun_domain
  }

  vpc_connector         = google_vpc_access_connector.connector.name
  service_account_email = google_service_account.default.email
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = var.project_id
  region         = var.region
  cloud_function = google_cloudfunctions_function.lambda.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
