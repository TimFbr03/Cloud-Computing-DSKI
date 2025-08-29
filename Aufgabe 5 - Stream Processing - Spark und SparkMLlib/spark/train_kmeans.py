from pyspark.sql import SparkSession
from pyspark.sql.functions import expr, rand, when
from pyspark.ml.feature import StringIndexer, VectorAssembler
from pyspark.ml.clustering import KMeans
from pyspark.ml import Pipeline

MODEL_PATH = "data/models/kmeans_event_value"

def main():
    spark = (SparkSession.builder
             .appName("TrainKMeans-Aufgabe5")
             .master("local[*]")
             .getOrCreate())
    spark.sparkContext.setLogLevel("WARN")

    # --- Synthetic training data (matches streaming schema) ---
    # We bias 'purchase' towards higher values to create separable clusters.
    n = 5000
    df = (spark.range(0, n)
          .withColumn("event_type", when(rand() < 0.15, "purchase")
                                   .when(rand() < 0.50, "click")
                                   .when(rand() < 0.80, "view")
                                   .otherwise("signup"))
          .withColumn("value",
                      when(expr("event_type == 'purchase'"), 50 + rand()*60)  # 50-110
                      .otherwise(rand()*60))                                  # 0-60
          .withColumn("event_id", expr("uuid()"))
          .withColumn("ts", expr("current_timestamp()"))
          .withColumn("user_id", expr("concat('user-', cast(rand()*100 as int))"))
         )

    # --- Pipeline: Index category -> assemble -> KMeans ---
    indexer = StringIndexer(inputCol="event_type", outputCol="event_type_idx", handleInvalid="keep")
    assembler = VectorAssembler(inputCols=["event_type_idx", "value"], outputCol="features")
    kmeans = KMeans(k=3, seed=42, featuresCol="features", predictionCol="cluster")

    pipeline = Pipeline(stages=[indexer, assembler, kmeans])
    model = pipeline.fit(df)

    # Save/overwrite model
    model.write().overwrite().save(MODEL_PATH)
    print(f"Saved KMeans PipelineModel to: {MODEL_PATH}")

    # Optional: small preview
    preds = model.transform(df.limit(10)).select("event_type", "value", "cluster")
    preds.show(truncate=False)

    spark.stop()

if __name__ == "__main__":
    main()
