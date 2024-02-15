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

variable "auto_create_subnetworks" {
  description = "Auto Create Subnetworks - GCP"
  type        = bool
}

variable "routing_mode" {
  description = "Routing Mode - GCP"
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

variable "route" {
  description = "Router - GCP"
  type        = string
}