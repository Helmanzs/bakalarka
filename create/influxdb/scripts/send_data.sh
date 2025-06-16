#!/bin/bash


FILE="/tmp/raltra.lp"
BATCH_SIZE=5000
DB_NAME="raltra"
HOST="http://localhost:8181"
PRECISION="nanosecond"
ACCEPT_PARTIAL="true"
NO_SYNC="false"
AUTH_HEADER="Authorization: Bearer $INFLUXDB3_AUTH_TOKEN"

python3 - <<EOF
import requests
import time

file_path = "$FILE"
batch_size = $BATCH_SIZE
url = "$HOST/api/v3/write_lp?db=$DB_NAME&precision=$PRECISION&accept_partial=$ACCEPT_PARTIAL&no_sync=$NO_SYNC"
headers = {
    "Content-Type": "text/plain"
}
auth_header = "$AUTH_HEADER"
if auth_header:
    key, value = auth_header.split(": ", 1)
    headers[key] = value

def read_batches(path, size):
    batch = []
    with open(path, "r") as f:
        for i, line in enumerate(f, 1):
            batch.append(line)
            if i % size == 0:
                yield batch
                batch = []
        if batch:
            yield batch

total_lines = sum(1 for _ in open(file_path))
print(f"Total lines to process: {total_lines}")
sent = 0

for i, batch in enumerate(read_batches(file_path, batch_size), 1):
    data = "".join(batch)
    try:
        response = requests.post(url, data=data, headers=headers)
        if response.status_code != 204:
            print(f"[!] Error in batch {i}: {response.status_code} - {response.text}")
        else:
            sent += len(batch)
            print(f"[{sent}/{total_lines}] Batch {i} uploaded successfully.")
    except Exception as e:
        print(f"[!] Exception during batch {i}: {e}")

print("✅ Upload completed.")
EOF
