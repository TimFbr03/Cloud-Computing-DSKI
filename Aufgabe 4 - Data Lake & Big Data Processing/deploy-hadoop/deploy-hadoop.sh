# deploy-hadoop.sh

echo "Deploying Hadoop Cluster on Kubernetes..."

# Namespace erstellen
kubectl apply -f namespace.yaml

# Storage konfigurieren
kubectl apply -f storage.yaml

# Hadoop Konfiguration
kubectl apply -f hadoop-config.yaml

# NameNode deployen
kubectl apply -f namenode.yaml

# Warten bis NameNode bereit ist
echo "Waiting for NameNode to be ready..."
kubectl wait --for=condition=ready pod -l app=hadoop-namenode -n hadoop-cluster --timeout=300s

# NameNode formatieren (nur beim ersten Deployment)
kubectl exec -n hadoop-cluster deployment/hadoop-namenode -- /opt/hadoop/bin/hdfs namenode -format -force

# DataNodes deployen
kubectl apply -f datanode.yaml

# ResourceManager deployen
kubectl apply -f resourcemanager.yaml

# NodeManager deployen
kubectl apply -f nodemanager.yaml

echo "Hadoop cluster deployment completed!"
echo "NameNode UI: http://hadoop-namenode.local"
echo "ResourceManager UI: http://hadoop-resourcemanager.local"

# Status prüfen
kubectl get pods -n hadoop-cluster