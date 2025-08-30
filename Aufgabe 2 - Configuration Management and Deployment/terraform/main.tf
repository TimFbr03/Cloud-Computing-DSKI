# Laden der sensiblen Variablen
variable "os_user_name" {}
variable "os_password" {
  sensitive = true
}
variable "os_auth_url" {}
variable "os_tenant_id" {}
variable "os_pub_key" {}

variable "container_version" {
  description = "Version of the Docker container to deploy"
  type        = string
  default = "latest"
}

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
  name = "tfa-cloud-comp-${timestamp()}"
  image_id = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name = "cb1.medium"
  key_pair = "tfa_pub_key"

    network {
        name = "DHBW"
    }
}


resource "local_file" "inventory_ini" {
  content = <<EOF
[openstack]
${openstack_compute_instance_v2.web_server.network.0.fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

  filename = "../ansible/inventory/inventory.ini"
}

resource "null_resource" "ansible_provisioner" {
  depends_on = [
    openstack_compute_instance_v2.web_server,
    local_file.inventory_ini
  ]

  provisioner "local-exec" {
    command = "sleep 30 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml -e \"container_version=${var.container_version}\""
  }

  triggers = {
    instance_id = openstack_compute_instance_v2.web_server.id
    ip_address  = openstack_compute_instance_v2.web_server.network.0.fixed_ip_v4
    container_version = var.container_version
  }
}