# data-ingestion.sh
# Script zum Laden von Datensätzen in den Hadoop Data Lake

echo "=== Data Lake Ingestion Script ==="
echo "Loading datasets into Hadoop HDFS..."

# Variablen
NAMESPACE="hadoop-cluster"
NAMENODE_POD="deployment/hadoop-namenode"
LOCAL_DATA_PATH="/data"
HDFS_BASE_PATH="/datalake"
DATASETS_PATH="$HDFS_BASE_PATH/datasets"

# Funktion zur Überprüfung des Cluster-Status
check_cluster_status() {
    echo "Checking Hadoop cluster status..."
    
    # Prüfen ob NameNode läuft
    kubectl get pods -n $NAMESPACE -l app=hadoop-namenode
    if [ $? -ne 0 ]; then
        echo "ERROR: NameNode is not running!"
        exit 1
    fi
    
    # HDFS Status prüfen
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfsadmin -safemode get
    
    echo "Cluster status: OK"
}

# HDFS Verzeichnisstruktur erstellen
create_hdfs_structure() {
    echo "Creating HDFS directory structure..."
    
    # Basis-Verzeichnisse erstellen
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/project_tasks
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/research_activities
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/schemas
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/raw
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/processed
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/archive
    
    echo "HDFS directory structure created successfully"
}

# Datensätze in HDFS laden
load_datasets() {
    echo "Loading datasets into HDFS..."
    
    # Temporäres Volume für Datenübertragung erstellen
    kubectl create configmap data-transfer \
        --from-file=avro_dataset1_project_tasks.json \
        --from-file=avro_dataset2_research_activities.json \
        --from-file=avro_schema_tasks.json \
        -n $NAMESPACE
    
    # Temporären Pod für Datenübertragung erstellen
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: data-transfer-pod
  namespace: $NAMESPACE
spec:
  containers:
  - name: hadoop-client
    image: apache/hadoop:3
    command: ["/bin/sleep", "3600"]
    volumeMounts:
    - name: data-volume
      mountPath: /data
    - name: hadoop-config
      mountPath: /opt/hadoop/etc/hadoop
  volumes:
  - name: data-volume
    configMap:
      name: data-transfer
  - name: hadoop-config
    configMap:
      name: hadoop-config
  restartPolicy: Never
EOF
    
    # Warten bis Pod bereit ist
    echo "Waiting for data transfer pod to be ready..."
    kubectl wait --for=condition=ready pod/data-transfer-pod -n $NAMESPACE --timeout=120s
    
    # Daten in HDFS kopieren
    echo "Copying project tasks dataset..."
    kubectl exec -n $NAMESPACE data-transfer-pod -- /opt/hadoop/bin/hdfs dfs -put /data/avro_dataset1_project_tasks.json $DATASETS_PATH/project_tasks/
    
    echo "Copying research activities dataset..."
    kubectl exec -n $NAMESPACE data-transfer-pod -- /opt/hadoop/bin/hdfs dfs -put /data/avro_dataset2_research_activities.json $DATASETS_PATH/research_activities/
    
    echo "Copying schema definition..."
    kubectl exec -n $NAMESPACE data-transfer-pod -- /opt/hadoop/bin/hdfs dfs -put /data/avro_schema_tasks.json $DATASETS_PATH/schemas/
    
    # Cleanup
    kubectl delete pod data-transfer-pod -n $NAMESPACE
    kubectl delete configmap data-transfer -n $NAMESPACE
    
    echo "Datasets loaded successfully"
}

# Datenintegrität prüfen
verify_data_integrity() {
    echo "Verifying data integrity..."
    
    # Dateien auflisten
    echo "Files in HDFS:"
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $DATASETS_PATH
    
    # Dateigrößen prüfen
    echo "File sizes:"
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -du -h $DATASETS_PATH
    
    # Replikation prüfen
    echo "Replication status:"
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs fsck $DATASETS_PATH -files -blocks -locations
}

# Metadaten erstellen
create_metadata() {
    echo "Creating dataset metadata..."
    
    # Metadata als JSON erstellen
    cat <<EOF > dataset_metadata.json
{
  "datasets": [
    {
      "name": "project_tasks",
      "path": "$DATASETS_PATH/project_tasks/avro_dataset1_project_tasks.json",
      "format": "avro_json",
      "schema_path": "$DATASETS_PATH/schemas/avro_schema_tasks.json",
      "record_count": 15,
      "created_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "description": "Project management tasks with completion status"
    },
    {
      "name": "research_activities", 
      "path": "$DATASETS_PATH/research_activities/avro_dataset2_research_activities.json",
      "format": "avro_json",
      "schema_path": "$DATASETS_PATH/schemas/avro_schema_tasks.json",
      "record_count": 15,
      "created_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "description": "Research and development activities"
    }
  ],
  "data_lake_info": {
    "hdfs_cluster": "$NAMESPACE",
    "base_path": "$HDFS_BASE_PATH",
    "ingestion_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "total_datasets": 2
  }
}
EOF

    # Metadata in HDFS speichern
    kubectl create configmap metadata --from-file=dataset_metadata.json -n $NAMESPACE
    kubectl run metadata-loader --rm -i --image=apache/hadoop:3 --restart=Never -n $NAMESPACE \
        --overrides='{"spec":{"volumes":[{"name":"metadata","configMap":{"name":"metadata"}},{"name":"hadoop-config","configMap":{"name":"hadoop-config"}}],"containers":[{"name":"metadata-loader","image":"apache/hadoop:3","command":["/bin/bash","-c","cp /metadata/dataset_metadata.json /tmp/ && /opt/hadoop/bin/hdfs dfs -put /tmp/dataset_metadata.json '$HDFS_BASE_PATH/metadata/'"],"volumeMounts":[{"name":"metadata","mountPath":"/metadata"},{"name":"hadoop-config","mountPath":"/opt/hadoop/etc/hadoop"}]}]}}'
    
    kubectl delete configmap metadata -n $NAMESPACE
    rm dataset_metadata.json
    
    echo "Metadata created successfully"
}

# Hauptausführung
main() {
    echo "Starting data ingestion process..."
    
    check_cluster_status
    create_hdfs_structure
    load_datasets
    verify_data_integrity
    create_metadata
    
    echo ""
    echo "=== Data Ingestion Complete ==="
    echo "Your datasets are now available in HDFS:"
    echo "- Project Tasks: $DATASETS_PATH/project_tasks/"
    echo "- Research Activities: $DATASETS_PATH/research_activities/"
    echo "- Schema: $DATASETS_PATH/schemas/"
    echo "- Metadata: $HDFS_BASE_PATH/metadata/"
    echo ""
    echo "To access the data:"
    echo "kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -cat $DATASETS_PATH/project_tasks/avro_dataset1_project_tasks.json"
}

# Hilfefunktionen
show_help() {
    echo "Usage: $0 [OPTION]"
    echo "Load datasets into Hadoop Data Lake"
    echo ""
    echo "Options:"
    echo "  --help          Show this help"
    echo "  --status        Show current HDFS status"
    echo "  --list          List files in data lake"
    echo "  --cleanup       Remove all datasets from HDFS"
}

# Kommandozeilenargumente verarbeiten
case "${1:-}" in
    --help)
        show_help
        exit 0
        ;;
    --status)
        check_cluster_status
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $HDFS_BASE_PATH
        exit 0
        ;;
    --list)
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $HDFS_BASE_PATH
        exit 0
        ;;
    --cleanup)
        echo "Cleaning up datasets..."
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -rm -r $HDFS_BASE_PATH
        echo "Cleanup complete"
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        show_help
        exit 1
        ;;
esac