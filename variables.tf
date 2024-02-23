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

variable "address" {
  description = "Address - GCP"
  type        = string
  
}