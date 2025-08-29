#!/bin/bash
# data-ingestion.sh
# Vereinfachtes Script zum Laden von Datensätzen in den Hadoop Data Lake

echo "=== Data Lake Ingestion Script ==="
echo "Loading datasets into Hadoop HDFS..."

# Variablen
NAMESPACE="hadoop-cluster"
NAMENODE_POD="deployment/hadoop-namenode"
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
    
    # Warten bis NameNode bereit ist
    echo "Waiting for NameNode to be ready..."
    kubectl wait --for=condition=ready pod -l app=hadoop-namenode -n $NAMESPACE --timeout=300s
    
    echo "Cluster status: OK"
}

# HDFS Verzeichnisstruktur erstellen
create_hdfs_structure() {
    echo "Creating HDFS directory structure..."
    
    # Basis-Verzeichnisse erstellen
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/project_tasks || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/research_activities || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $DATASETS_PATH/schemas || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/raw || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/processed || true
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -mkdir -p $HDFS_BASE_PATH/archive || true
    
    echo "HDFS directory structure created successfully"
}

# Datensätze in HDFS laden (vereinfacht)
load_datasets() {
    echo "Loading datasets into HDFS..."
    
    # Prüfen ob Sample-Daten existieren
    if [ ! -f "/tmp/sample-data/avro_dataset1_project_tasks.json" ]; then
        echo "ERROR: Sample data files not found!"
        return 1
    fi
    
    # Temporären Pod für Datenübertragung erstellen
    kubectl create configmap data-transfer \
        --from-file=/tmp/sample-data/avro_dataset1_project_tasks.json \
        --from-file=/tmp/sample-data/avro_dataset2_research_activities.json \
        --from-file=/tmp/sample-data/avro_schema_tasks.json \
        -n $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Warten bis ConfigMap erstellt ist
    sleep 5
    
    # Daten direkt über kubectl exec kopieren
    echo "Copying project tasks dataset..."
    kubectl run data-loader --rm -i --image=apache/hadoop:3 --restart=Never -n $NAMESPACE \
        --overrides='{
          "spec": {
            "volumes": [
              {"name": "data-volume", "configMap": {"name": "data-transfer"}},
              {"name": "hadoop-config", "configMap": {"name": "hadoop-config"}}
            ],
            "containers": [{
              "name": "data-loader",
              "image": "apache/hadoop:3",
              "command": ["/bin/bash", "-c"],
              "args": ["cp /data/* /tmp/ && /opt/hadoop/bin/hdfs dfs -put /tmp/avro_dataset1_project_tasks.json '$DATASETS_PATH/project_tasks/' && /opt/hadoop/bin/hdfs dfs -put /tmp/avro_dataset2_research_activities.json '$DATASETS_PATH/research_activities/' && /opt/hadoop/bin/hdfs dfs -put /tmp/avro_schema_tasks.json '$DATASETS_PATH/schemas/' && echo 'Data loading completed'"],
              "volumeMounts": [
                {"name": "data-volume", "mountPath": "/data"},
                {"name": "hadoop-config", "mountPath": "/opt/hadoop/etc/hadoop"}
              ]
            }]
          }
        }'
    
    # Cleanup
    kubectl delete configmap data-transfer -n $NAMESPACE || true
    
    echo "Datasets loaded successfully"
}

# Datenintegrität prüfen
verify_data_integrity() {
    echo "Verifying data integrity..."
    
    # Dateien auflisten
    echo "Files in HDFS:"
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $DATASETS_PATH || echo "Could not list files"
    
    # HDFS Status prüfen
    echo "HDFS Status:"
    kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfsadmin -report || echo "Could not get HDFS report"
}

# Hauptausführung
main() {
    echo "Starting simplified data ingestion process..."
    
    check_cluster_status
    create_hdfs_structure
    load_datasets
    verify_data_integrity
    
    echo ""
    echo "=== Data Ingestion Complete ==="
    echo "Your datasets should now be available in HDFS:"
    echo "- Project Tasks: $DATASETS_PATH/project_tasks/"
    echo "- Research Activities: $DATASETS_PATH/research_activities/"
    echo "- Schema: $DATASETS_PATH/schemas/"
    echo ""
    echo "To verify the data:"
    echo "kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $DATASETS_PATH"
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
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $HDFS_BASE_PATH || echo "No data found"
        exit 0
        ;;
    --list)
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -ls -R $HDFS_BASE_PATH || echo "No data found"
        exit 0
        ;;
    --cleanup)
        echo "Cleaning up datasets..."
        kubectl exec -n $NAMESPACE $NAMENODE_POD -- /opt/hadoop/bin/hdfs dfs -rm -r $HDFS_BASE_PATH || echo "Nothing to clean"
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