# Cloud Computing und Big Data  
## Inhaltsverzeichnis  

1. [Aufgabe 1 - Immutable Infrastructure](#aufgabe-1---immutable-infrastructure)  
2. [Aufgabe 2 - Configuration Management und Deployment](#aufgabe-2---configuration-management-und-deployment)

## Aufgabe 1 - Immutable Infrastructure
Das Ziel dieser Aufgabe ist es, eine Immutable Infrastructure zu erstellen.  
Die Wahl der Technoligie fällt dabei auf Terraform.  

**Ziel:** Eine Webserver Instanz auf Open-Stack, welche bei Änderungen der Architektur wie Updates nicht abgeändert, sonder ersetzt wird.  
Dafür wird für jede neue Version die Infrastruktur neu aufgesetzt und in einer neuen Instanz Deployed.   

**Architektur:**
```h
provider "openstack" {
  user_name   = var.os_user_name
  password    = var.os_password
  auth_url    = var.os_auth_url
  tenant_id   = var.os_tenant_id
}
```
Über den Provider mit den Login Informationen zugriff auf die Open-Stack umgebung erhalten.

```h
resource "openstack_compute_instance_v2" "web_server" {
  name = "tfa_cloud_comp"
  image_id = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
  flavor_name = "cb1.medium"
  key_pair = var.os_pub_key

    network {
        name = "provider_912"
    }
}
```
Deployment einer VM.  
```image_id``` definiert das Betriebssystem der VM - in diesem Fall __Ubunutu 24.04__  
```flavor_name``` bescreibt die Ressourcen. Die VM hat 2 VCPUs, 2 GB RAM, und 10 GB Speicher.


**Deployment:**
```
terraform init  
terraform apply
```

**Delete:**
```
terraform destroy
```
<hr>

## Aufgabe 2 - Configuration Management und Deployment
Es sollen Apllikationen auf dieser Immutable Infrastructure deployed werden. Dafür werden Docker-Contaienr über Ansible auf der Instanz Deployed. 
Hinzufügen einer automatischen Installation aller Systeme und anforderungen per Playbook auf der Open-Stack Infrastruktur.  
Das Deployment soll weiterhin nur über Terraform erfolgen.  
  
Automatisches Deployment mit ```null_resource```  

```h
resource "null_resource" "ansible" {
  triggers = {
    instance_ip = aws_instance.web.public_ip
  }

  provisioner "local-exec" {
    command = <<EOT
echo "[web]" > inventory.ini
echo "${aws_instance.web.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/my-key.pem" >> inventory.ini
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini ansible/playbook.yml
EOT
  }
}
```