import json, time, random, uuid
from datetime import datetime, timezone
from confluent_kafka import Producer

BOOTSTRAP = "localhost:19092,localhost:29092,localhost:39092"
TOPIC = "events"

EVENT_TYPES = ["click", "view", "purchase", "signup"]
USERS = [f"user-{i}" for i in range(1, 101)]

def now_iso():
    return datetime.now(tz=timezone.utc).isoformat()

def make_event():
    return {
        "event_id": str(uuid.uuid4()),
        "ts": now_iso(),
        "user_id": random.choice(USERS),
        "event_type": random.choice(EVENT_TYPES),
        "value": round(random.random() * 100, 2)
    }

def delivery(err, msg):
    if err is not None:
        print(f"Delivery failed: {err}")

def main(rate_per_sec: int = 20):
    p = Producer({"bootstrap.servers": BOOTSTRAP, "linger.ms": 20, "retries": 10})
    print(f"Producing ~{rate_per_sec} msgs/sec to topic '{TOPIC}' (Ctrl+C to stop)")
    try:
        while True:
            start = time.time()
            for _ in range(rate_per_sec):
                evt = make_event()
                p.produce(TOPIC, json.dumps(evt).encode("utf-8"), callback=delivery)
            p.poll(0)
            elapsed = time.time() - start
            time.sleep(max(0, 1.0 - elapsed))
    except KeyboardInterrupt:
        print("\\nStopping.")
    finally:
        p.flush()

if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--rps", type=int, default=20, help="messages per second")
    args = ap.parse_args()
    main(args.rps)
