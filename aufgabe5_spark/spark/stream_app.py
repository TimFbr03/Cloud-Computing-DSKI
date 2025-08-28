from pyspark.sql import SparkSession
from pyspark.ml import PipelineModel
from pyspark.sql.functions import from_json, col, window, count, avg, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

KAFKA_SERVERS = "localhost:19092,localhost:29092,localhost:39092"
TOPIC = "events"
GROUP_ID = "spark-streaming-demo"

CHECKPOINT_DIR = "data/checkpoints/agg"
OUTPUT_DIR = "data/out/agg-parquet"

schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("ts", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("value", DoubleType(), True),
])

spark = (SparkSession.builder
         .appName("Aufgabe5-StructuredStreaming")
         # For local dev use all cores; on a cluster remove this
         .master("local[*]")
         .config("spark.sql.shuffle.partitions", "6")
         .config("spark.default.parallelism", "6")
         .getOrCreate())

spark.sparkContext.setLogLevel("WARN")

# Source: Kafka
df_raw = (spark.readStream
          .format("kafka")
          .option("kafka.bootstrap.servers", KAFKA_SERVERS)
          .option("subscribe", TOPIC)
          .option("startingOffsets", "latest")
          .option("failOnDataLoss", "false")
          .load())


# Parse JSON
df_parsed = (df_raw
             .selectExpr("CAST(value AS STRING) AS json_str")
             .select(from_json(col("json_str"), schema).alias("data"))
             .select(
                 col("data.event_id"),
                 to_timestamp(col("data.ts")).alias("ts"),
                 col("data.user_id"),
                 col("data.event_type"),
                 col("data.value"),
             )
             .withWatermark("ts", "2 minutes")
            )

# Simple windowed aggregations (per event type, 1-minute tumbling window)
agg = (df_parsed
       .groupBy(window(col("ts"), "1 minute"), col("event_type"))
       .agg(
           count("*").alias("events"),
           avg("value").alias("avg_value")
       )
       .select(
           col("window.start").alias("window_start"),
           col("window.end").alias("window_end"),
           col("event_type"),
           col("events"),
           col("avg_value")
       ))

# Console sink for quick verification
query_console = (agg.writeStream
                 .outputMode("update")
                 .format("console")
                 .option("truncate", "false")
                 .option("numRows", "50")
                 .start())

# Durable sink (Parquet) to simulate writing results back to a Data Lake
query_parquet = (agg.writeStream
                 .outputMode("append")
                 .format("parquet")
                 .option("path", OUTPUT_DIR)
                 .option("checkpointLocation", CHECKPOINT_DIR)
                 .start())

print("Streaming started. Press Ctrl+C to stop.")


# --- MLlib scoring (optional but integrated) ---
MODEL_PATH = "data/models/kmeans_event_value"
try:
    model = PipelineModel.load(MODEL_PATH)
    print(f"Loaded MLlib PipelineModel from {MODEL_PATH}")
except Exception as e:
    model = None
    print(f"[INFO] No ML model loaded from {MODEL_PATH}. Run './scripts/train_model.sh' to create one. Details: {e}")

def score_batch(batch_df, batch_id):
    if model is None:
        return
    preds = model.transform(batch_df)
    (preds
        .select("ts", "event_type", "value", "user_id", "event_id", "cluster")
        .write.mode("append").parquet("data/out/ml-preds"))
    print(f"[ML] Wrote predictions for batch {batch_id}")

ml_query = (df_parsed.writeStream
            .foreachBatch(score_batch)
            .start())

spark.streams.awaitAnyTermination()

