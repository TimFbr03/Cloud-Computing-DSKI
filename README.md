# Cloud Computing und Big Data  
## Inhaltsverzeichnis  

1. [Aufgabe 1 - Immutable Infrastructure](#aufgabe-1---immutable-infrastructure)  
2. [Aufgabe 2 - Configuration Management und Deployment](#aufgabe-2---configuration-management-und-deployment)
3. [Aufgabe 3 - Microservice Infrastructure](#aufgabe-3---microservice-infrastructure)

## Aufgabe 1 - Immutable Infrastructure
Ziel der ersten Aufgabe ist es, eine Immutable Infrastructure bereitzustellen. 

### Wahl der Technologie
Als Technologie für das Deployment der Immutable Infrastruture wurde Terraform gewählt. Diese Technologie wurde bereits in den Vorlesungen vorgestellt.  
Weitere gründe sind:  
- Deklarative Infrastrukturautomatisierung
- Flexibel einsetzbar für viele Provider (OpenStack, AWS, Azure)
- Infrastructure as Code, wodurch Versionierung, Nachvollziehbarkeit und Automatisierung möglich werden.
- Immutable Updates durch austauschen der Ressourcen, ohne das bestehende Infrastruktur manuell verändert werden muss.

### Entwurf der Immutable-Komponenten
Bei der Immutable-Komponente handelt es sich um eine Compute-Instanz in einer **Open-Stack** umgebung.  
Diese weisst folgende merkmale der Unveränderlichkeit auf:  
- Änderungen am System erfolgen nicht innerhalb der Instanz, sondern durch Neuerstellung der gesamten Instanz mit einer neuen Konfiguration oder einem neuen Image.
- Konfigurationsänderungen an der Instanz (z. B. anderer Flavor, anderes Image) werden in den Terraform-Files hinterlegt.
- Ein Update bedeutet, dass die bestehende Ressource zerstört und anschließend durch eine neue Ressource ersetzt wird.

Dadurch entspricht die Compute-Instanz dem Immutable Prinzip, da diese Änderungen nicht "in-place" vornimmt, sondern die komplette Infrastruktur bei bedarf durch eine neue Version ersetzt.

### Implementieren mit Terraform
#### __Variablen__
Zugandaten und Parameter für die OpenStack-Verbindung werden als Variablen definiert, und müssen in einer `secrets.auto.tfvars` hinterlegt.  
Variablen welche als sensitiv markiert sind, werden von Terraform nicht in klartext in den Logs ausgegeben:

```hcl
  variable "os_user_name" {}
  variable "os_password" {
    sensitive = true
  }
  variable "os_auth_url" {}
  variable "os_tenant_id" {}
  variable "os_pub_key" {}
```

#### __Provider__
Für die Verbindung mit OpenStack wird der Provider durch die Variablen definiert und konfiguriert:
```hcl
  provider "openstack" {
    user_name   = var.os_user_name
    password    = var.os_password
    auth_url    = var.os_auth_url
    tenant_id   = var.os_tenant_id
  }
```

#### __Ressource (Immutable Komponente)__
Die Ressource ist eine Virtuelle Maschine auf einer OpenStack umgebung der DHBW Mannheim. Diese befindet sich innerhalb der OpenStack umgebung in dem Netzwerk "*DHBW*" (früher "*provider_918*").

```hcl
  resource "openstack_compute_instance_v2" "web_server" {
    name = "tfa_cloud_comp"
    image_id = "c57c2aef-f74a-4418-94ca-d3fb169162bf"
    flavor_name = "cb1.medium"
    key_pair = var.os_pub_key

      network {
          name = "DHBW"
      }
  }
```

#### __Sicherstellen der Unveränderlichkeit__
- Es dürfen keine manuellen Änderungen an der VM vorgenommen werden. 
- Änderungen erfolgen ausschließlich über **Terraform**.
- Terraform sorgt automatisch dafür, das die Infrastruktur nicht verändert, sondern ersetzt wird.
  - **Replace** (Destroy + Create)

#### __Deployment einer OpenStack Instanz__
Um die definierte Infrastruktur (hier eine OpenStack-Instanz) bereitzustellen, werden die folgenden Terraform-Kommandos in der Arbeitsumgebung ausgeführt. Jeder Befehl erfüllt dabei eine bestimmte Aufgabe im Lebenszyklus der Ressource.

**1. Initialiesen des Backends:**  
Bevor Terraform die Ressourcen verwalten kann, muss die lokale Arbeitsumgebung initialisiert werden.
Dabei lädt Terraform die im Code angegebenen Provider (hier: **OpenStack** und **local**) herunter und richtet das Backend ein.
```shell
  terraform init
```
Nach erfolgreicher Initialisierung zeigt Terraform an, dass die Provider installiert wurden und der Arbeitsbereich bereit ist.

**2. Planen der Änderung:**  
Bevor eine Änderung angewendet wird, ist es sinnvoll, aber nicht notendig diese mit `terraform plan` zu überprüfen. Dabei wird ein **Execution Plan** der geplanten Änderungen aufgezeichnet.

```shell
  terraform plan
```

- Terraform ließt die aktuelle Konfiguration und Zustand der Infrastruktur.
- Zeigt anschließend an, welche Änderungen vorgenommen würde.
  - `+ create` zeigt welche Ressourcen erstellt,
  - `~ update` welche Ressourcen ersetzt oder geändert,
  - `- destroy`welche Ressourcen gelöscht werden.
- Dies ist jedoch eine reine Vorschau, und ändert nichts an der Infrastruktur.

**3. Ausführen des Terraform Scripts**  
Mit folgendem Befehl erstellt Terraform einen Execution Plan und führt diesen aus:
```shell
  terraform apply
```
- Terraform überprüft den aktuelln zustand der OpenStack Instanz mit der aktuellen konfiguration.
- Alle geplanten änderungen werden angezeigt und müssen bestätigt werden.
  - Kann mit `--auto-approve` umgangen werden.
- Nach bestätigung oder `--auto-approve` erstellt Terraform die neue Instanz in OpenStack.

**4. Löschen der Infrastruktur**  
Wenn die Infrastruktur nicht mehr benötigt wird, kann sie mit einem einzigen Befehl wieder entfernt werden:
```shell
  terraform destoy
```
- Terraform zeigt vorab an, welche Ressourcen gelöscht werden.
- Nach Bestätigung wird die Compute-Instanz in OpenStack vollständig entfernt.  
Das sorgt für eine saubere Aufräumung und vermeidet unnötige Kosten für nicht mehr genutzte Ressourcen.

#### Imutable Update (erneutes Apply)
Wenn die konfiguration geändert wurde, z.B. durch:
- ein anderes Betriebssystem (`image_id`)
- eine größere Instanz (`flavor_name`)
- oder neue Netzwerkanbindung  

reicht es aus, folgende Befehle wieder auszuführen:
```hcl
terraform plan
terraform apply 
``` 
wobei `terraform plan`optinal ist.  
Terraform erkennt die Abweichungen und führt ein Immutable Update durch:
- Die alte Instanz wird zerstört.
- Eine neue Instanz wird mit den geänderten Parametern erstellt.
So wird sichergestellt, dass es keine inkonsistenten Zwischenzustände gibt.

*Screencast einfügen*

#### Zusammenfassung
- **Technologie:** Terraform zur bereitstellung der Instanzen aufgrund breiter Unterstützung, Verständlichkeit und Eignung für Immutable-Infrastructure.
- **Entwurf:** Eine Compute-Instanz in OpenStack als immutable Komponente.
- **Implementierung:** Terraform-Code definiert Variablen, Provider und Ressource.
- **Immutable Update:** Änderungen werden durch Neu-Erstellung der Ressource umgesetzt, nicht durch manuelles Patchen.
- **Fazit:** Das Immutable-Prinzip wird erfolgreich umgesetzt und ermöglicht eine saubere, automatisierte Infrastrukturverwaltung.

#### Alternativer Ansatz
Eine alternative zu Terraform wäre ein automatisches Deployment über Github-Actions. In dieser Technologie, wird automatisch nach festgelegten Regeln, bei neuen Versionen die Infrasteuktur automatisch re-deployed. Für unseren Anwendungsfall jedoch nicht optimal, da die OpenStack instanz der DHBW nur per VPN verbindung erreichbar.  

## Aufgabe 2 - Configuration Management und Deployment
### Erweiterung der Infrastrukturdefinition
Aufbauend auf dem ersten Kapitel, soll auf der vorhandenden Terraform OpenStack-Instanz, soll nun eine Installation und Konfiguration einer Beispielanwendung automatisiert werden.  
Für das automatische konfiguration wird **Ansible** als Konfigurationsmanagement Toll verwendet.  
- **Terraform** stellt die Infrastruktur bereit.
- **Ansible** übernimmt die Provisionierung und Deployment der Anwendung.  
  
Die zu bereitstellende Anwendung ist ein auf Docker basierter Web-Service (eine Flask API), welche aus einem Container-Image in der Github Container Registry (GHCR) gestartet wird.  
Ansible wird über eine Null-Ressource durch Terraform gestartet. 
Nachdem die Terraform-Instanz fertig installiert ist, wird das Ansible Playbook über 
```shell
  sleep 30 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml -e \"container_version=${var.container_version}\"
```  

### Ansible Playbook zur Anwendungsbereistellung
Ansible installiert über ein Playbook alle Abhängigkeiten. Diese werden in einer .yaml Datei defiert.  

Das Ansible Playbook 


## Aufgabe 3 - Microservice Infrastructure
Multi-Node Containerorchestrierung über k3s Kubernetis.  
- Deployment der Architektur über Terraform.  
- Aufsetzen der Systemvariablen über Ansible.
- k3s Containerorchestierung über Helm.
  - Netzwerkinfrastruktur durch Nginx-Ingress.

### Terraform Deployment

## Appendix - Github Actions
Docker Container werden aus dem Code über Github-Actions in das Github Container Regestry (GHCR) gepusht.
Jedes mal, wenn eine neue Version auf das Repository gepusht wird, wird die neue Version Containerisiert und auf das GHCR gepusht.