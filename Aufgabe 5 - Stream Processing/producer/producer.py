import json, os, time, random
from kafka import KafkaProducer

bootstrap = os.getenv("KAFKA_BOOTSTRAP", "kafka.stream.svc.cluster.local:9092")
topic = os.getenv("TOPIC", "events")
producer = KafkaProducer(bootstrap_servers=bootstrap, value_serializer=lambda v: json.dumps(v).encode())

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
