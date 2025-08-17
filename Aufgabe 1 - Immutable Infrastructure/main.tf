# Laden der sensiblen Variablen
variable "os_user_name" {}
variable "os_password" {
  sensitive = true
}
variable "os_auth_url" {}
variable "os_tenant_id" {}
variable "os_pub_key" {}

# Initialisieren der Terraform Instans
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

# Provider to Log Into the Service
provider "openstack" {
  user_name   = var.os_user_name
  password    = var.os_password
  auth_url    = var.os_auth_url
  tenant_id   = var.os_tenant_id
}

# Dedicated ressource to deploy
resource "openstack_compute_instance_v2" "web_server" {
  name = "tfa_cloud_comp"
  image_id = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name = "cb1.medium"
  key_pair = var.os_pub_key

    network {
        name = "DHBW"
    }
}