# tf-gcp-infra

## Install Terraform

1. Download Terraform: Go to Terraform's official download page : https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli and download the appropriate package for your OS.
   
2. Install Terraform

3. Verify Version of Terraform
````
terraform -v
````
If Terraform is correctly installed, you should see the Terraform version number.

## Basic Terraform Commmands

1. Initialize a Terraform working directory:

````
terraform init
````
This command prepares your working directory for other commands.

2. Create an execution plan:

````
terraform plan
````
Terraform performs a dry run to show you what actions it will take to change your infrastructure to match the configuration.

3. Apply the changes required to reach the desired state of the configuration:

````
terraform apply
````
This command applies the changes described by terraform plan.

4. Destroy Terraform-managed infrastructure:
   
````
terraform destroy
````
This command removes all the infrastructure that Terraform manages.

## Variables file .tfvars

````
project_id              = "your-project-id"
vpc_name                = "your-vpc-name"
region                  = "region-selected by you"
auto_create_subnetworks = "boolean values"
routing_mode            = "regional"
subnet_1                = "your-subnet-name"
subnet_2                = "your-subnet-name"
route                   = "route-vpc"
````
