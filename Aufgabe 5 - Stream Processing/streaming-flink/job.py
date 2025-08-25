from pyflink.datastream import StreamExecutionEnvironment
from pyflink.common.serialization import SimpleStringSchema
from pyflink.datastream.connectors.kafka import KafkaSource, KafkaSink, KafkaRecordSerializationSchema
import json

env = StreamExecutionEnvironment.get_execution_environment()
env.set_parallelism(3)

source = KafkaSource.builder() \
    .set_bootstrap_servers("kafka.stream.svc.cluster.local:9092") \
    .set_topics("events") \
    .set_group_id("flink-consumer") \
    .set_value_only_deserializer(SimpleStringSchema()) \
    .build()

ds = env.from_source(source, watermark_strategy=None, source_name="kafka")

def parse(line):
    d = json.loads(line)
    return (d["sensor"], float(d["value"]))

parsed = ds.map(parse)

# einfacher gleitender Durchschnitt über 20 Elemente pro Sensor
from pyflink.datastream.functions import ReduceFunction
class AvgReduce(ReduceFunction):
    def reduce(self, a, b):
        cnt = a[2] + b[2]
        s = a[1] + b[1]
        return (a[0], s, cnt)

avg = (parsed
       .key_by(lambda x: x[0])
       .map(lambda x: (x[0], x[1], 1))
       .count_window(20)
       .reduce(AvgReduce())
       .map(lambda x: json.dumps({"sensor": x[0], "avg": round(x[1]/x[2],2)})))

sink = KafkaSink.builder() \
    .set_bootstrap_servers("kafka.stream.svc.cluster.local:9092") \
    .set_record_serializer(KafkaRecordSerializationSchema.builder() \
        .set_topic("results") \
        .set_value_serialization_schema(SimpleStringSchema()) \
        .build()) \
    .build()

avg.sink_to(sink)
env.execute("sensor-avg")
