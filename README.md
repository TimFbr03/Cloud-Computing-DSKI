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
    name: ['git', 'docker.io']
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
Multi-Node Containerorchestrierung über k3s Kubernetis.  
- Deployment der Architektur über Terraform.  
- Aufsetzen der Systemvariablen über Ansible.
- k3s Containerorchestierung über Helm.
  - Netzwerkinfrastruktur durch Nginx-Ingress.

### Terraform Deployment

## Appendix - Github Actions
Docker Container werden aus dem Code über Github-Actions in das Github Container Regestry (GHCR) gepusht.
Jedes mal, wenn eine neue Version auf das Repository gepusht wird, wird die neue Version Containerisiert und auf das GHCR gepusht.

## Aufgabe 5 - Stream Processing

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
•	IoT-Sensor Simulation: Generiert Daten von 3 verschiedenen Sensoren (A, B, C)
•	JSON-Serialisierung: Strukturierte Datenübertragung
•	Konfigurierbare Parameter: Über Umgebungsvariablen
•	Hoher Durchsatz: 10 Nachrichten/Sekunde

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
•	Stateful Processing: Gleitender Durchschnitt über 20 Werte
•	Keyed Streams: Separierte Verarbeitung pro Sensor
•	Windowing: Count-basierte Fenster
•	Parallelisierung: Konfigurierbare 

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
