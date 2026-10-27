import os
import time

from kafka import KafkaProducer


if __name__ == '__main__':
    producer = KafkaProducer(
        bootstrap_servers='localhost:9092',
        value_serializer=lambda v: v.encode('utf-8')
    )

    file_path = os.path.expanduser(
        '~/Data/alice_in_wonderland.txt'
    )

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            producer.send('stream_text', line.strip())
            print(f"Sent: {line.strip()[:50]}...")
            time.sleep(1)

    producer.flush()
    producer.close()
    print("Done sending all lines.")
