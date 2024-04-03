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

# resource "google_compute_firewall" "firewall-sub" {
#   name    = var.firewall_name
#   network = google_compute_network.vpc_name.self_link

#   allow {
#     protocol = "tcp"
#     ports    = ["3000", "22", "5432"]
#   }

#   target_tags   = ["gcp-vm-instance-centos-new", "http-server", "https-server"]
#   source_ranges = ["0.0.0.0/0"]
# }

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

# resource "google_dns_record_set" "a" {
#   name         = var.dns_name
#   managed_zone = var.dns_zone
#   type         = "A"
#   ttl          = 60

#   rrdatas    = [google_compute_instance.default.network_interface[0].access_config[0].nat_ip]
#   depends_on = [google_compute_instance.default]
# }

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


# resource "google_compute_instance" "default" {
#   name         = "gcp-vm-instance-centos-new"
#   machine_type = "n2-standard-4"
#   zone         = "us-east4-b"

#   tags = ["http-server", "https-server", "webapp"]

#   boot_disk {
#     initialize_params {
#       image = var.packer_image_name
#       size  = 100
#       type  = "pd-balanced"
#     }
#   }

#   // Local SSD disk
#   scratch_disk {
#     interface = "NVME"
#   }

#   network_interface {
#     network    = google_compute_network.vpc_name.self_link
#     subnetwork = google_compute_subnetwork.subnet_1.self_link
#     access_config {
#       // Ephemeral IP
#     }
#   }

#   metadata = {
#     # foo = "bar"
#     dbUser = google_sql_user.db-user.name
#     dbPass = google_sql_user.db-user.password
#     dbHost = google_sql_database_instance.webapp-sql-instance.private_ip_address
#     dbName = google_sql_database.cloud-db.name
#   }

#   metadata_startup_script = file("./db.sh")
#   service_account {
#     email  = google_service_account.default.email
#     scopes = ["cloud-platform"]
#   }
# }

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
resource "google_storage_bucket" "csye-bucket-6225" {
  name     = "csye-bucket-6225-function"
  location = var.region
}

# # Upload the Cloud Function to the Bucket
resource "google_storage_bucket_object" "archive" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.csye-bucket-6225.name
  source = "./function-source.zip"
}

# # Create a Cloud Function
resource "google_cloudfunctions_function" "lambda-1" {
  name    = "lambda-1"
  region  = var.region
  runtime = "nodejs20"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.csye-bucket-6225.name
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
  cloud_function = google_cloudfunctions_function.lambda-1.name

  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.default.email}"
}

resource "google_compute_region_instance_template" "default" {
  name        = "instance-template"
  description = "Instance Template for GCP VM"

  region = "us-east4"

  machine_type = "e2-standard-2"

  tags = ["http-server", "https-server", "webapp"]

  disk {
    source_image = var.packer_image_name
    type         = "pd-balanced"
    disk_size_gb = 100
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

resource "google_compute_firewall" "firewall-template" {
  name      = "firewall-template"
  network   = google_compute_network.vpc_name.self_link
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["3000", "5432", "443"]
  }

  target_tags   = ["firewall-template"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", google_compute_global_forwarding_rule.default.ip_address]
}
resource "google_compute_region_instance_group_manager" "instance-group-manager" {
  name                      = "instance-group-manager"
  base_instance_name        = "webapp"
  region                    = var.region
  distribution_policy_zones = ["us-east4-c", "us-east4-b", "us-east4-a"]

  version {
    instance_template = google_compute_region_instance_template.default.self_link
  }
  target_size = 1

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }

  named_port {
    name = "http"
    port = 3000
  }

}

resource "google_compute_region_autoscaler" "autoscaler" {
  name   = "my-region-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.instance-group-manager.id

  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.05
    }
  }
}


resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "3000"
  }
}


resource "google_compute_managed_ssl_certificate" "default" {
  name = "test-cert"

  managed {
    domains = ["cloudwebappserver.com."]
  }
}

resource "google_compute_target_https_proxy" "default" {
  name             = "test-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_url_map" "default" {
  name        = "url-map"
  description = "Map"

  default_service = google_compute_backend_service.default.id
}

resource "google_compute_backend_service" "default" {
  name        = "backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10
  backend {
    group           = google_compute_region_instance_group_manager.instance-group-manager.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
  health_checks = [google_compute_http_health_check.default.id]
}

resource "google_compute_http_health_check" "default" {
  name               = "http-health-check"
  request_path       = "/healthz"
  port               = 3000
  check_interval_sec = 1
  timeout_sec        = 1
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "forwarding-rule"
  target     = google_compute_target_https_proxy.default.id
  port_range = 443
}

resource "google_dns_record_set" "a" {
  name         = var.dns_name
  managed_zone = var.dns_zone
  type         = "A"
  ttl          = 60

  rrdatas    = [google_compute_global_forwarding_rule.default.ip_address]
  depends_on = [google_compute_global_forwarding_rule.default]
}
