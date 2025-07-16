# Variables
variable "os_user_name" {}
variable "os_password" { sensitive = true }
variable "os_auth_url" {}
variable "os_tenant_id" {}
variable "os_pub_key" {}

# Terraform initialization
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

# OpenStack Provider
provider "openstack" {
  user_name = var.os_user_name
  password  = var.os_password
  auth_url  = var.os_auth_url
  tenant_id = var.os_tenant_id
}

resource "random_id" "cluster_id" {
  byte_length = 4
}

# Key pair (optional if not managed here)
# resource "openstack_compute_keypair_v2" "keypair" {
#   name       = "tfa_pub_key"
#   public_key = var.os_pub_key
# }

# Kubernetes Master
resource "openstack_compute_instance_v2" "k8s_master" {
  name = "k3s-${random_id.cluster_id.hex}-master"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "cb1.medium"
  key_pair    = "tfa_pub_key"

  network {
    name = "provider_912"
  }
}

# Kubernetes Worker Nodes
resource "openstack_compute_instance_v2" "k8s_worker" {
  count       = 2
  name  = "k3s-${random_id.cluster_id.hex}-worker-${count.index + 1}"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "cb1.medium"
  key_pair    = "tfa_pub_key"

  network {
    name = "provider_912"
  }
}

# Inventory file for Ansible
resource "local_file" "inventory_ini" {
  content = <<EOF
[k3s_master]
${openstack_compute_instance_v2.k8s_master.network.0.fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k3s_worker]
%{ for worker in openstack_compute_instance_v2.k8s_worker ~}
${worker.network.0.fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
%{ endfor ~}
EOF

  filename = "../ansible/inventory/inventory.ini"
}

resource "null_resource" "ansible_provisioner" {
  depends_on = [
    openstack_compute_instance_v2.k8s_master,
    openstack_compute_instance_v2.k8s_worker,
    local_file.inventory_ini
  ]

  provisioner "local-exec" {
    command = "sleep 45 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml"
  }

  triggers = {
    master_id  = openstack_compute_instance_v2.k8s_master.id
    master_ip  = openstack_compute_instance_v2.k8s_master.network.0.fixed_ip_v4
    worker_ips = join(",", [for w in openstack_compute_instance_v2.k8s_worker : w.network.0.fixed_ip_v4])
  }
}