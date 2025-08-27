# Cloud Computing und Big Data

## Inhaltsverzeichnis

1. [Aufgabe 1 - Immutable Infrastructure](#aufgabe-1---immutable-infrastructure)
2. [Aufgabe 2 - Configuration Management und Deployment](#aufgabe-2---configuration-management-und-deployment)
3. [Aufgabe 3 - Microservice Infrastructure](#aufgabe-3---microservice-infrastructure)
4. [Aufgabe 4 - Data Lake / Big Data-Processing](#aufgabe-4---data-lake--big-data-processing)
5. [Aufgabe 5 - Big Data-Stream Processing](#aufgabe-5---big-data-stream-processing)

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

#### **Variablen**

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

#### **Provider**

Für die Verbindung mit OpenStack wird der Provider durch die Variablen definiert und konfiguriert:

```hcl
provider "openstack" {
  user_name   = var.os_user_name
  password    = var.os_password
  auth_url    = var.os_auth_url
  tenant_id   = var.os_tenant_id
}
```

#### **Ressource (Immutable Komponente)**

Die Ressource ist eine Virtuelle Maschine auf einer OpenStack umgebung der DHBW Mannheim. Diese befindet sich innerhalb der OpenStack umgebung in dem Netzwerk "_DHBW_" (früher "_provider_918_").

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

#### **Sicherstellen der Unveränderlichkeit**

- Es dürfen keine manuellen Änderungen an der VM vorgenommen werden.
- Änderungen erfolgen ausschließlich über **Terraform**.
- Terraform sorgt automatisch dafür, das die Infrastruktur nicht verändert, sondern ersetzt wird.
  - **Replace** (Destroy + Create)

#### **Deployment einer OpenStack Instanz**

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

_Screencast einfügen_

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

```hcl
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
```

ausgeführt. Dabei wird gewartet, bis die Instanz vollständig vorbereitet ist, und darauf hin das Ansible Playbook ausführt. Die Ip-Adresse wird über Terraform automatisch in eine Invenory.ini Datei beschrieben.

### Ansible Playbook zur Anwendungsbereistellung

Ansible installiert über ein Playbook alle Abhängigkeiten. Diese werden in einer .yaml Datei definiert.  
Das Ansible Playbook führt folgende Aufgabe aus:

```yaml
- name: Install system dependencies (git, docker.io)
  ansible.builtin.apt:
    name: ["git", "docker.io"]
    state: present
    update_cache: yes
  notify: Ensure Docker service running

- name: Ensure Docker is running and enabled
  ansible.builtin.service:
    name: docker
    state: started
    enabled: yes

- name: Ensure docker group exists
  group:
    name: docker
    state: present

- name: Add user to docker group
  user:
    name: ubuntu
    groups: docker
    append: yes

- name: Reboot machine for docker group to take effect
  reboot:

- name: Pull Docker image from GHCR
  community.docker.docker_image:
    name: ghcr.io/timfbr03/cloud-computing-dski:{{ container_version }}
    source: pull

- name: Run Docker container with port forwarding
  community.docker.docker_container:
    name: flask-api
    image: ghcr.io/timfbr03/cloud-computing-dski:{{ container_version }}
    state: started
    restart_policy: always
    ports:
      - "80:5000"
```

- **Systemabhängigkeiten installieren:** Git und Docker werden über apt bereitgestellt.
- **Docker-Dienst starten & aktivieren:** Stellt sicher, dass Docker sofort verfügbar ist und nach Neustarts automatisch läuft.
- **Benutzerrechte anpassen:** Der Standardbenutzer ubuntu wird der docker-Gruppe hinzugefügt, damit Container ohne sudo verwaltet werden können.
- **Reboot:** Notwendig, damit die neuen Gruppenrechte wirksam werden.
- **Container-Image bereitstellen:** Das gewünschte Image wird aus GHCR gezogen.
- **Container starten:** Der Flask-Webservice wird gestartet, Ports werden gemappt (80 → 5000).

### Versionierung der Anwendung

Die Container im GHCR sind durch Tags versioniert.
Das Playbook verwendet die Variable `container_version`, welche bei dem Deployment angegeben wird. Standartmäßig wird das Image mit dem Tag `:latest` verwendet.

```yaml
ghcr.io/timfbr03/cloud-computing-dski:v1
ghcr.io/timfbr03/cloud-computing-dski:v2
ghcr.io/timfbr03/cloud-computing-dski:latest
```

Durch einfaches Ändern von container_version im Ansible-Playbook oder in den Variablen-Dateien kann eine andere Version der Anwendung ausgerollt werden.  
Dies ermöglicht:

- **Upgrade:** Wechsel von v1 → v2 durch erneutes Playbook-Run.
- **Rollback:** Wechsel zurück zu einer älteren Version (z. B. v1), falls Fehler auftreten

### Infrastruktur-Versionierung & Rollback

## Aufgabe 3 - Microservice Infrastructure

Das Ziel der dritten Aufgabe ist die Bereitstellung einer Multi-Node-Kubernetes-Infrastruktur mit containerisierten, skalierbaren Microservices und integriertem Monitoring.

### Architekturüberblick

Die implementierte Lösung besteht aus mehreren Komponenten:

- **Terraform:** Bereitstellung der OpenStack-Infrastruktur
- **Ansible:** Automatische Konfiguration und Deployment
- **k3s:** Leichtgewichtige Kubernetes-Distribution
- **Helm:** Package-Management für Kubernetes-Anwendungen
- **Nginx Ingress:** Externe Erreichbarkeit der Services
- **Prometheus/Grafana:** Monitoring und Observability

### Technologiewahl und Begründung

**k3s als Kubernetes-Distribution**  
Für die Kubernetes-Umgebung wurde k3s gewählt, eine leichtgewichtige, CNCF-zertifizierte Kubernetes-Distribution:

Vorteile:

- Minimaler Ressourcenverbrauch (ideal für Cloud-Umgebungen)
- Einfache Installation und Wartung
- Integrierter Container Runtime (containerd)
- Built-in Load Balancer und Storage Provider
- Single Binary Installation
- Automatisches TLS-Management

**Alternativen und Bewertung:**

- kubeadm: Komplexer zu installieren, höherer Overhead
- Rancher RKE: Mehr Enterprise-Features, aber höhere Komplexität
- Managed Services (EKS/GKE): Nicht verfügbar in OpenStack-Umgebung

### Infrastruktur-Deployment mit Terraform

**Multi-Node Cluster Setup**

```bash
resource "openstack_compute_instance_v2" "k3s_server" {
  name = "k3s-${random_id.cluster_id.hex}-server"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "mb1.large"
  key_pair    = "tfa_pub_key"

  network {
    name = "DHBW"
  }
}

# Kubernetes Worker Nodes
resource "openstack_compute_instance_v2" "k3s_worker" {
  count       = 2
  name  = "k3s-${random_id.cluster_id.hex}-agent-${count.index + 1}"
  image_id    = "f445d5f0-e9a6-4e09-b3c4-7e6607aea9fb"
  flavor_name = "mb1.large"
  key_pair    = "tfa_pub_key"

  network {
    name = "DHBW"
  }
}
```

**Cluster-Architektur:**

- **1x Control Plane Node:** Verwaltet die Kubernetes API, etcd, Scheduler
- **2x Worker Nodes:** Führen die Anwendungs-Pods aus
- **Automatische Inventar-Generierung:** Terraform erstellt dynamisch die Ansible-Inventory

**Automatische Provisionierung**

```bash
resource "null_resource" "ansible_provisioner" {
  depends_on = [
    openstack_compute_instance_v2.k3s_server,
    openstack_compute_instance_v2.k3s_worker,
    local_file.inventory_ini
  ]

  provisioner "local-exec" {
    command = "sleep 60 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ../ansible/inventory/inventory.ini ../ansible/deploy.yaml"
  }
}
```

### Kubernetes-Cluster Installation mit Ansible

**k3s Server Installation**
Das Ansible-Playbook installiert zuerst den k3s-Server (Control Plane):

```yaml
- name: Install k3s server
  shell: curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
  args:
    creates: /usr/local/bin/k3s
  when: "'k3s_server' in group_names"

- name: Wait for k3s server to be ready
  shell: k3s kubectl get node
  register: k3s_status
  retries: 10
  delay: 30
  until: k3s_status.rc == 0
  when: "'k3s_server' in group_names"
```

**Token-Management für Worker-Nodes**

```yaml
- name: Save node token for agents
  command: cat /var/lib/rancher/k3s/server/node-token
  register: node_token
  when: "'k3s_server' in group_names"

- name: Copy token to localhost
  copy:
    content: "{{ node_token.stdout }}"
    dest: "./node-token"
    mode: "0600"
  delegate_to: localhost
  become: no
  when: "'k3s_server' in group_names"
```

### Containerisierte Anwendung

**Microservice-Architektur**
Die Anwendung besteht aus drei containerisierten Services:

1. **Frontend (React):** Benutzeroberfläche
2. **Backend (Node.js/Express):** REST API
3. **Database (PostgreSQL):** Datenpersistierung

### Container-Images

Alle Services werden aus dem GitHub Container Registry (GHCR) deployed:

```yaml
ghcr_images:
  backend: "ghcr.io/timfbr03/cloud-computing-dski/backend:latest"
  frontend: "ghcr.io/timfbr03/cloud-computing-dski/frontend:latest"
  database: "ghcr.io/timfbr03/cloud-computing-dski/database:latest"
```

### Dockerfile-Strategien

**Frontend (Multi-Stage Build):**

```Dockerfile
# Build Stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --silent
COPY . .
RUN npm run build

# Production Stage
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
```

**Backend (Production-optimiert):**

```Dockerfile
FROM node:18-alpine
RUN apk add --no-cache make gcc g++ python3 libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production --no-optional
COPY . .
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) }).on('error', () => process.exit(1))"
CMD ["npm", "start"]
```

### Kubernetes-Konfigurationen mit Helm

**Helm Chart Struktur**

```
helm/
├── app/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── backend-deployment.yaml
│       ├── backend-service.yaml
│       ├── frontend-deployment.yaml
│       ├── frontend-service.yaml
│       ├── database-deployment.yaml
│       ├── database-service.yaml
│       └── ingress.yaml
```

### Deployment Konfiguration

**Backend-Deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: { { .Values.backend.replicas } }
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: { { .Values.backend.image } }
          ports:
            - containerPort: { { .Values.backend.containerPort } }
          env:
            - name: DATABASE_URL
              value: "postgresql://todouser:todopass@database:5432/todoapp"
```

**Service-Konfiguration**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
    - port: 80
      targetPort: 3001
      protocol: TCP
```

**Helm Values für Skalierbarkeit**

```yaml
backend:
  image: "ghcr.io/timfbr03/cloud-computing-dski/backend:latest"
  replicas: 2
  containerPort: 3001
  servicePort: 80

frontend:
  image: "ghcr.io/timfbr03/cloud-computing-dski/frontend:latest"
  replicas: 2
  containerPort: 3000
  servicePort: 80

database:
  image: "ghcr.io/timfbr03/cloud-computing-dski/database:latest"
  replicas: 1
  containerPort: 5432
  servicePort: 5432
```

### Externe Erreichbarkeit mit Nginx Ingress

**Ingress Installation**

```yaml
- name: Install Nginx Ingress Controller
  shell: |
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
  when: "'k3s_server' in group_names"
```

**Ingress-Konfiguration**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todo-ingress
  namespace: microservices
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: "" # catch-all
      http:
        paths:
          - path: /api(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: backend
                port:
                  number: 80
          - path: /(.*)
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

Routing Logik:

- `/api/*` $\rightarrow$ Backend Service (_Rest API_)
- `/*` $\rightarrow$ Frontend Service (_React SPA_)

### Versionierung und Deployment-Strategien

**Container-Versionierung**
GitHub Container Registry Tags:

```bash
ghcr.io/timfbr03/cloud-computing-dski/backend:latest
ghcr.io/timfbr03/cloud-computing-dski/backend:v1.0.0
ghcr.io/timfbr03/cloud-computing-dski/backend:v1.1.0
```

### Update- und Rollback-Strategien

**Konzept der Unveränderlichkeit**  
Im Gegensatz zu traditionellen In-Place-Updates folgt diese Infrastruktur dem **Immutable Infrastructure**-Prinzip:

- **Keine direkten Änderungen:** Bestehende Instanzen werden niemals modifiziert
- **Replace statt Update:** Jede Änderung führt zur Neuerstellung der gesamten Infrastruktur
- **Atomare Deployments:** Entweder vollständiger Erfolg oder vollständiger Rollback
- **Konsistente Umgebungen:** Eliminiert Configuration Drift und "Snowflake Servers"

**Immutable Update**  
**Phase 1** - Destroy (Alte Infratruktur entfernen)

```bash
terraform destroy --auto-approve
```

- Alle OpenStack-Instanzen werden terminiert
- Kubernetes-Cluster wird vollständig entfernt
- Keine Datenrettung - true Immutable Approach

**Phase 2** - Recreate (Neue Infrastruktur erstellen)

```bash
terraform apply --auto-approve
```

- Neue Instanzen mit aktueller Konfiguration
- Automatische Ansible-Provisionierung
- Frisches k3s-Cluster mit neuen Versionen

**Rollback Strategie**  
Git-basiertes Rollback

#### 1. **Kofigurationsstand zurücksetzen:**

```bash
# Zur letzten funktionierenden Version
git checkout HEAD~1

# Oder zu spezifischem Tag
git checkout v1.5.0
```

#### 2. **Infrastruktur neu aufsetzen**

```bash
terraform destroy --auto-approve
terraform apply --auto-approve
```

**Direkte Version-Spezifikation**

```yaml
# Explizites Rollback auf bekannte funktionierende Versionen
ghcr_images:
  backend: "ghcr.io/timfbr03/cloud-computing-dski/backend:v1.5.2" # Rollback
  frontend: "ghcr.io/timfbr03/cloud-computing-dski/frontend:v1.5.2" # Rollback
```

### Performance-Monitoring mit Prometheus und Grafana

**Monitoring-Stack Deployment**

```yaml
- name: Add Prometheus Helm repo
  shell: helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update

- name: Deploy kube-prometheus-stack
  shell: |
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --set grafana.service.type=NodePort \
      --set grafana.service.nodePort=30090 \
      --set grafana.adminPassword=admin123
```

**Prometheus-Konfiguration**
Service Discovery:

```yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    scrapeInterval: "15s"
```

**Grafana Dashboard-Zugriff**

```bash
# Grafana über NodePort erreichbar
http://<node-ip>:30090
# Login: admin / admin123
```

### Monitoring-Metriken

**Verfügbare Metriken:**

- Container CPU/Memory Usage
- Pod Restart Counts
- Network I/O
- Database Connection Pool Status

### Zusammenfassung und Bewertung

- **Multi-Node Kubernetes:** k3s-Cluster mit 1 Master + 2 Worker
  - k3s als "_lightweight_" Kubernetis Cluster
- **Containerisierung:** 3-Tier Microservice-Architektur
- **Versionierung:** GHCR mit semantischer Versionierung
- **Skalierbarkeit:** Helm-basierte Replica-Konfiguration
- **Externe Erreichbarkeit:** Nginx Ingress Controller
- **Monitoring:** Prometheus + Grafana Stack
- **Automation:** Terraform + Ansible Integration

## Aufgabe 4 - Data Lake / Big Data-Processing

Diese Lösung implementiert einen vollständigen Apache Hadoop Data Lake auf einer bestehenden Kubernetes Multi-Node-Infrastruktur. Das System basiert auf dem offiziellen Apache Hadoop Docker Image und bietet eine skalierbare, produktionsreife Data Lake-Architektur.

## Teil 1: Installation des Data Lakes

Das Setup erstellt einen vollständigen Hadoop-Cluster mit HDFS (Hadoop Distributed File System) auf Kubernetes, der als Data Lake fungiert. Der Cluster besteht aus mehreren Komponenten, die zusammenarbeiten, um ein verteiltes Speichersystem bereitzustellen.

### HDFS-Komponenten

- **NameNode:** Zentrale Metadaten-Verwaltung des Dateisystems
- **DataNode:** Verteilte Speicherknoten für die eigentlichen Daten

### YARN-Komponenten

- **ResourceManager:** Zentrale Ressourcenverwaltung für Jobs
- **NodeManager:** Lokale Ressourcenverwaltung auf jedem Knoten

Zur Installation müssen nun folgende Schritte durchgeführt werden:

#### 1. Namespace erstellen

```bash
kubectl apply -f namespace.yaml
```

#### 2. Storage konfigurieren

```bash
kubectl apply -f storage.yaml
```

#### 3. Hadoop Konfiguration

```bash
kubectl apply -f hadoop-config.yaml
```

#### 4. NameNode deployen

```bash
kubectl apply -f namenode.yaml
```

#### 5. Warten bis NameNode bereit ist

```bash
echo "Waiting for NameNode to be ready..."
kubectl wait --for=condition=ready pod -l app=hadoop-namenode -n hadoop-cluster --timeout=300s
```

#### 6. NameNode formatieren (nur beim ersten Deployment)

```bash
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- /opt/hadoop/bin/hdfs namenode -format -force
```

#### 7. DataNodes deployen

```bash
kubectl apply -f datanode.yaml
```

#### 8. ResourceManager deployen

```bash
kubectl apply -f resourcemanager.yaml
```

#### 9. NodeManager deployen

```bash
kubectl apply -f nodemanager.yaml

echo "Hadoop cluster deployment completed!"
echo "NameNode UI: http://hadoop-namenode.local"
echo "ResourceManager UI: http://hadoop-resourcemanager.local"
```

#### 10. Status prüfen

```bash
kubectl get pods -n hadoop-cluster
```

_Diese Schritte werden automatisiert durchgeführt mit Ausführung der `deploy-hadoop.sh`._

```bash
chmod +x deploy-hadoop.sh
./deploy-hadoop.sh
```

## Teil 2: Generierung der Datensätze:

Zur weiteren Verarbeitung sollen im Folgenden mehrere Datensätze nicht trivialer Größe mithilfe generativer KI erstellt werden.

Vor Generierung sollte dabei jedoch das Endziel bedacht werden, um ein sinnvolles Format zu wählen.
Im Verlauf dieser Aufgabe sollen die Datensätze im **HDFS** gespeichert und anschließend verarbeitet werden. Um BigData-Vorgänge effizient zu gestalten, werden die Datensätze als _JSON_-Dateien im _Avro-Schema_ generiert. Dies bietet eine effiziente Datenstruktur, welche eine plattformunabhängige Serialisierung und Dekompression ermöglicht und ist außerdem mit vielen Programmiersprachen kompatibel.

Als Vorlage für die zu erstellenden Datensätze dient die `init.sql` aus _Aufgabe 3_. Daraus wird ein _Avro-Schema_ erstellt:
| Name | Typ |
| ----------- | ----------- |
| title | _string_ |
| description | _string_ |
| completed | _boolean_ |
| deleted | _boolean_ |
| user*id | \_string* |

Die Generierung erfolgt mit _ClaudeAI_ und liefert zwei Datensätze:

- Datensatz 1: Projektmanagement Tasks (15 Records)
- Datensatz 2: Forschungsaktivitäten (15 Records)

## Teil 3: Data Ingestion

Um die neuen Datensätze weiterverarbeiten zu können, müssen diese zunächst in das _HDFS_ (also den Hadoop Data Lake) geladen werden.

### 3.1 Vorbereitung der Daten

Sicherstellen, dass folgende Dateien im aktuellen Verzeichnis vorhanden sind:

```bash
# Überprüfen der erforderlichen Dateien
ls -la avro_*.json
```

Erwartete Dateien:

- `avro_dataset1_project_tasks.json` - Projektmanagement Tasks
- `avro_dataset2_research_activities.json` - Forschungsaktivitäten
- `avro_schema_tasks.json` - Schema-Definition

### 3.2 Data Ingestion Script

Das `data-ingestion.sh` Script automatisiert den kompletten Ingestion-Prozess und implementiert folgende Funktionalitäten:

#### **Hauptfunktionen:**

- **Cluster-Status-Überprüfung:** Validiert Hadoop-Cluster-Verfügbarkeit
- **HDFS-Struktur-Erstellung:** Legt organisierte Verzeichnishierarchie an
- **Daten-Upload:** Überträgt Avro-Datensätze sicher ins HDFS
- **Integritätsprüfung:** Verifiziert erfolgreiche Datenübertragung
- **Metadaten-Management:** Erstellt strukturierte Dataset-Kataloge

#### **HDFS-Verzeichnisstruktur:**

```
/datalake/
├── datasets/
│   ├── project_tasks/          # Projektmanagement-Daten
│   ├── research_activities/    # Forschungsaktivitäten
│   └── schemas/               # Avro-Schema-Definitionen
├── raw/                       # Rohdaten-Bereich
├── processed/                 # Verarbeitete Daten (Spark-Output)
├── archive/                   # Archivierte Datensätze
└── metadata/                  # Dataset-Katalog und Metainformationen
```

### 3.3 Ausführung der Data Ingestion

#### **1. Script vorbereiten:**

```bash
chmod +x data-ingestion.sh
```

#### **2. Cluster-Status prüfen:**

```bash
./data-ingestion.sh --status
```

#### **3. Vollständige Ingestion durchführen:**

```bash
./data-ingestion.sh
```

**Ausgabe-Beispiel:**

```
=== Data Lake Ingestion Script ===
Loading datasets into Hadoop HDFS...
Checking Hadoop cluster status...
Cluster status: OK
Creating HDFS directory structure...
HDFS directory structure created successfully
Loading datasets into HDFS...
Datasets loaded successfully
Verifying data integrity...
Files in HDFS: [Dateiliste]
Creating dataset metadata...
Metadata created successfully

=== Data Ingestion Complete ===
Your datasets are now available in HDFS:
- Project Tasks: /datalake/datasets/project_tasks/
- Research Activities: /datalake/datasets/research_activities/
- Schema: /datalake/datasets/schemas/
- Metadata: /datalake/metadata/
```

#### **4. Ingestion-Ergebnis validieren:**

```bash
# Alle Dateien im Data Lake auflisten
./data-ingestion.sh --list

# Spezifische Dataset-Inhalte anzeigen
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- \
  /opt/hadoop/bin/hdfs dfs -cat /datalake/datasets/project_tasks/avro_dataset1_project_tasks.json | head -20
```

## Teil 4: Datenverarbeitung mit Apache Spark

Nach erfolgreicher Ingestion werden die Datensätze mit Apache Spark analysiert und verarbeitet. Diese Pipeline implementiert umfassende Business Intelligence und Data Analytics.

### 4.1 Spark-Architektur

Die Spark-Integration erfolgt über Kubernetes Jobs und umfasst:

- **Spark Application:** PySpark-Script für Datenanalyse
- **Job Orchestration:** Kubernetes Job-Controller
- **History Server:** Web-UI für Job-Monitoring und -Analyse
- **HDFS-Integration:** Direkte Integration mit dem Data Lake

### 4.2 Implementierte Analysen

#### **Project Tasks Analysis**

```python
# Completion Analysis - Erledigungsgrad
completion_stats = project_df.groupBy("completed").count()

# User Performance Analysis
user_stats = project_df.groupBy("user_id") \
    .agg(
        count("*").alias("total_tasks"),
        sum(when(col("completed") == True, 1)).alias("completed_tasks"),
        sum(when(col("deleted") == True, 1)).alias("deleted_tasks")
    ) \
    .withColumn("completion_rate", col("completed_tasks") / col("total_tasks"))

# Text Complexity Analysis
text_analysis = project_df.withColumn("description_length", length(col("description"))) \
    .withColumn("title_length", length(col("title")))
```

**Business Insights:**

- User-Performance-Metriken und Produktivitätsanalysen
- Task-Completion-Rates pro Team/Individuum
- Text-Komplexitätsanalyse für Aufgaben-Schwierigkeitsgrad

#### **Research Activities Analysis**

```python
# Technology Keyword Detection
tech_keywords = ["AI", "Machine Learning", "Quantum", "Blockchain", "IoT",
                "Cloud", "Neural", "Algorithm", "Deep Learning"]

# Automated Research Area Classification
research_classification = keyword_df.withColumn(
    "research_area",
    when(col("contains_ai") + col("contains_machine_learning") > 0, "AI/ML")
    .when(col("contains_quantum") > 0, "Quantum Computing")
    .when(col("contains_blockchain") > 0, "Blockchain")
    .otherwise("Other")
)
```

**Research Intelligence:**

- Automatische Technologie-Trend-Erkennung
- Forschungsbereich-Klassifikation (AI/ML, Quantum, Blockchain, etc.)
- Keyword-basierte Content-Analyse

#### **Cross-Dataset Analytics**

```python
# Combined Analysis across both datasets
combined_df = project_df.unionByName(research_df)

# User Cross-Analysis zwischen Project und Research
user_cross_analysis = combined_df.groupBy("user_id", "dataset_type").count() \
    .groupBy("user_id").pivot("dataset_type").sum("count")
```

**Strategic Insights:**

- Korrelationsanalyse zwischen Projekt- und Forschungsaktivitäten
- User-übergreifende Performance-Metriken
- Interdisziplinäre Aktivitätsmuster

### 4.3 Spark-Job Ausführung

#### **1. Spark-Pipeline starten:**

```bash
kubectl apply -f spark-job.yaml
```

#### **2. Job-Monitoring:**

```bash
# Job-Status überwachen
kubectl get jobs -n hadoop-cluster -w

# Live-Logs verfolgen
kubectl logs job/spark-task-processing -n hadoop-cluster -f

# Job-Details anzeigen
kubectl describe job spark-task-processing -n hadoop-cluster
```

#### **3. Spark History Server aktivieren:**

```bash
# History Server für detaillierte Analyse
kubectl port-forward -n hadoop-cluster svc/spark-history-server 18080:18080
```

Anschließend **http://localhost:18080** im Browser öffnen für:

- Detaillierte Job-Execution-Analysen
- Performance-Metriken und Ressourcenverbrauch
- Stage-by-Stage Execution-Pläne
- SQL-Query-Optimierung-Insights

### 4.4 Ergebnis-Zugriff und -Analyse

#### **Verarbeitete Daten-Struktur:**

```
/datalake/processed/
├── project_tasks_user_stats/           # User-Performance-Metriken
├── project_tasks_with_text_analysis/   # Text-Komplexitäts-Analyse
├── research_activities_classified/     # Klassifizierte Forschungsaktivitäten
├── research_area_distribution/         # Forschungsbereich-Verteilung
├── combined_tasks_research/            # Kombinierte Dataset-Analyse
└── combined_statistics/                # Übergreifende Statistiken
```

#### **Ergebnis-Zugriff:**

```bash
# Alle verarbeiteten Ergebnisse auflisten
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- \
  /opt/hadoop/bin/hdfs dfs -ls -R /datalake/processed/

# User-Performance-Statistiken anzeigen
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- \
  /opt/hadoop/bin/hdfs dfs -cat /datalake/processed/project_tasks_user_stats/part-*

# Forschungsbereich-Verteilung analysieren
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- \
  /opt/hadoop/bin/hdfs dfs -cat /datalake/processed/research_area_distribution/part-*

# Kombinierte Statistiken abrufen
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- \
  /opt/hadoop/bin/hdfs dfs -cat /datalake/processed/combined_statistics/part-*
```

## Aufgabe 5 - Big Data-Stream Processing

### Kafka-Cluster Konfiguration

#### Kafka Values Configuration

Die kafka-values.yaml definiert einen hochverfügbaren Kafka-Cluster mit automatischer Topic-Provisionierung:

```yaml
replicaCount: 3
kraft:
  enabled: true
listeners:
  client:
    protocol: PLAINTEXT
rbac:
  create: true
service:
  type: ClusterIP
provisioning:
  enabled: true
  topics:
    - name: events
      partitions: 3
      replicationFactor: 3
    - name: results
      partitions: 3
      replicationFactor: 3
```

Schlüsselmerkmale:

- 3 Kafka Broker für Hochverfügbarkeit
- Automatische Topic-Erstellung mit 3 Partitionen
- Replication Factor 3 für Datensicherheit

#### Installation

Kafka Cluster installieren

```shell
helm install kafka bitnami/kafka -n stream -f kafka-values.yaml
```

### Data Producer Implementieren

#### Producer Code (producer.py)

```python
import json, os, time, random
from kafka import KafkaProducer

bootstrap = os.getenv("KAFKA_BOOTSTRAP", "kafka.stream.svc.cluster.local:9092")
topic = os.getenv("TOPIC", "events")
producer = KafkaProducer(
    bootstrap_servers=bootstrap,
    value_serializer=lambda v: json.dumps(v).encode()
)

i = 0
while True:
    msg = {
        "id": i,
        "sensor": random.choice(["A","B","C"]),
        "value": round(random.uniform(0,100),2),
        "ts": time.time()
    }
    producer.send(topic, msg)
    i += 1
    time.sleep(0.1)
```

Features:
• IoT-Sensor Simulation: Generiert Daten von 3 verschiedenen Sensoren (A, B, C)
• JSON-Serialisierung: Strukturierte Datenübertragung
• Konfigurierbare Parameter: Über Umgebungsvariablen
• Hoher Durchsatz: 10 Nachrichten/Sekunde

#### Producer Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: producer
  namespace: stream
spec:
  replicas: 1
  selector: { matchLabels: { app: producer } }
  template:
    metadata: { labels: { app: producer } }
    spec:
      containers:
        - name: producer
          image: <euer-registry>/stream-producer:latest
          env:
            - name: KAFKA_BOOTSTRAP
              value: kafka.stream.svc.cluster.local:9092
            - name: TOPIC
              value: events
```

### Stream Processing mit PyFlink

#### Flink Job Implmentation (job.py)

```python
from pyflink.datastream import StreamExecutionEnvironment
from pyflink.common.serialization import SimpleStringSchema
from pyflink.datastream.connectors.kafka import KafkaSource, KafkaSink, KafkaRecordSerializationSchema
import json

# Execution Environment mit Parallelität konfigurieren
env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(3)  # Horizontal skalierbar

# Kafka Source konfigurieren
source = KafkaSource.builder() \
    .set_bootstrap_servers("kafka.stream.svc.cluster.local:9092") \
    .set_topics("events") \
    .set_group_id("flink-consumer") \
    .set_value_only_deserializer(SimpleStringSchema()) \
    .build()

ds = env.from_source(source, watermark_strategy=None, source_name="kafka")

# JSON Parsing
def parse(line):
    d = json.loads(line)
    return (d["sensor"], float(d["value"]))

parsed = ds.map(parse)

# Stream Processing Logic: Gleitender Durchschnitt
from pyflink.datastream.functions import ReduceFunction

class AvgReduce(ReduceFunction):
    def reduce(self, a, b):
        cnt = a[2] + b[2]
        s = a[1] + b[1]
        return (a[0], s, cnt)

avg = (parsed
       .key_by(lambda x: x[0])          # Nach Sensor gruppieren
       .map(lambda x: (x[0], x[1], 1))  # (sensor, value, count)
       .count_window(20)                # Fenster über 20 Elemente
       .reduce(AvgReduce())             # Durchschnitt berechnen
       .map(lambda x: json.dumps({      # Ergebnis formatieren
           "sensor": x[0],
           "avg": round(x[1]/x[2],2)
       })))

# Kafka Sink konfigurieren
sink = KafkaSink.builder() \
    .set_bootstrap_servers("kafka.stream.svc.cluster.local:9092") \
    .set_record_serializer(KafkaRecordSerializationSchema.builder() \
        .set_topic("results") \
        .set_value_serialization_schema(SimpleStringSchema()) \
        .build()) \
    .build()

avg.sink_to(sink)
env.execute("sensor-avg")
```

Stream Processing Features:
• Stateful Processing: Gleitender Durchschnitt über 20 Werte
• Keyed Streams: Separierte Verarbeitung pro Sensor
• Windowing: Count-basierte Fenster
• Parallelisierung: Konfigurierbare

### Horizontale Skalierbarkeit

#### Kafka-Partitionierung

Topic Details anzeigen

```shell
kubectl exec -it kafka-client -n stream -- kafka-topics.sh --describe --topic events --bootstrap-server kafka.stream.svc.cluster.local:9092
```

Ausgabe:

```bash
Topic: events   PartitionCount: 3   ReplicationFactor: 3
Partition: 0    Leader: 1    Replicas: 1,2,0
Partition: 1    Leader: 2    Replicas: 2,0,1
Partition: 2    Leader: 0    Replicas: 0,1,2
```

#### Producer Skalierung

```shell
# Mehrere Producer für höhere Last
kubectl scale deployment producer -n stream --replicas=3

# Load Balancing über Kafka-Partitionen
kubectl get pods -l app=producer -n stream
```

### Deployment und Testing

#### Vollständiges Deployment

```shell
# 1. Namespace erstellen
kubectl create namespace stream

# 2. Kafka installieren
helm install kafka bitnami/kafka -n stream -f kafka-values.yaml

# 3. Producer deployen
kubectl apply -f producer-deployment.yaml

# 4. Flink Job starten
kubectl run flink-processor --image=python:3.9 -n stream -- sleep infinity
kubectl exec -it flink-processor -n stream -- bash

# Im Pod:
pip install apache-flink kafka-python
python job.py
```

#### Pipeline Testing

Producer Test:

```shell
# Test-Producer starten
kubectl exec -it python-producer -n stream -- python producer.py
```

Consumer Test:

```shell
# Events Topic konsumieren
kubectl exec -it kafka-client -n stream -- kafka-console-consumer.sh \
  --bootstrap-server kafka.stream.svc.cluster.local:9092 \
  --topic events --from-beginning

# Results Topic konsumieren
kubectl exec -it kafka-client -n stream -- kafka-console-consumer.sh \
  --bootstrap-server kafka.stream.svc.cluster.local:9092 \
  --topic results --from-beginning
```

Erwartete Ausgabe:

```bash
Events Topic:
{"id": 0, "sensor": "A", "value": 42.5, "ts": 1692709800.123}
{"id": 1, "sensor": "B", "value": 78.1, "ts": 1692709801.456}
{"id": 2, "sensor": "C", "value": 15.3, "ts": 1692709802.789}
Results Topic:
{"sensor": "A", "avg": 45.67}
{"sensor": "B", "avg": 52.34}
{"sensor": "C", "avg": 38.91}
```

## Anhang - Github Actions

Docker Container werden aus dem Code über Github-Actions in das Github Container Regestry (GHCR) gepusht.
Jedes mal, wenn eine neue Version auf das Repository gepusht wird, wird die neue Version Containerisiert und auf das GHCR gepusht.
