variable "project_id" {
  description = "Project Id - GCP"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name - GCP"
  type        = string
}

variable "region" {
  description = "Region - GCP"
  type        = string
}

variable "delete_default_routes_on_create" {
  description = "Delete Default Routes On Create - GCP"
  type        = bool
}

variable "auto_create_subnetworks" {
  description = "Auto Create Subnetworks - GCP"
  type        = bool
}

variable "routing_mode" {
  description = "Routing Mode - GCP"
  type        = string
}

variable "dest_range" {
  description = "Destination Range - GCP"
  type        = string
}
variable "subnet_1" {
  description = "Subnet 1 - GCP"
  type        = string
}

variable "subnet_2" {
  description = "Subnet  2 - GCP"
  type        = string
}

variable "ip_cidr_range_1" {
  description = "IP CIDR Range 1 webapp- GCP"
  type        = string
}

variable "ip_cidr_range_2" {
  description = "IP CIDR Range 2 db- GCP"
  type        = string
}
variable "route" {
  description = "Router - GCP"
  type        = string
}

variable "next_hop_gateway" {
  description = "Next Hop Gateway - GCP"
  type        = string
}

variable "private_ip_google_access" {
  description = "Private IP Google Access - GCP"
  type        = bool
}

variable "firewall_name" {
  description = "Firewall Name - GCP"
  type        = string
}

variable "firewall_sql_name" {
  description = "Firewall SQL Name - GCP"
  type        = string
}

variable "deny-ssh-to-connect" {
  description = "Deny SSH To Connect - GCP"
  type        = string
}

variable "deny-internet-connection-sql-db-instance" {
  description = "Deny Internet Connection SQL DB Instance - GCP"
  type        = string
}

variable "db-name" {
  description = "DB Name - GCP"
  type        = string
}

variable "db-user" {
  description = "DB User - GCP"
  type        = string

}

variable "packer_image_name" {
  description = "value of packer image name"
  type        = string
}

variable "dns_name" {
  description = "DNS Name - GCP"
  type        = string
}

variable "dns_zone" {
  description = "DNS Zone - GCP"
  type        = string
}

variable "service_account_log_metric" {
  description = "Service Account Log Metric - GCP"
  type        = string
}

variable "mailgun_api_key" {
  description = "Mailgun API Key - GCP"
  type        = string
}

variable "mailgun_domain" {
  description = "Mailgun Domain - GCP"
  type        = string
}

variable "service_account_function" {
  description = "Service Account Function - GCP"
  type        = string
}