#!/bin/bash

# Check for 2 arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: ./convert_csv_to_json.sh <input_csv_file> <output_json_file>"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

python3 - <<EOF
import csv
import json
from datetime import datetime

input_file = "$INPUT_FILE"
output_file = "$OUTPUT_FILE"

# Fields by type, from your table schema:
int_fields = {
    "orig_id", "GsmSignal", "SatelliteCount", "VehicleType", "VehicleID", "Technology", "Ignition",
    "ModeDrive", "SpreadingMode", "Plow", "Gram", "Cuts1", "Cuts2", "Cuts3", "CentralBroom",
    "LeftBroom", "RightBroom", "Turbine", "RunningShaft", "LeftFlushing", "RightFlushing",
    "CentralFlushing", "Misting", "Pump", "LightOn", "ModeArrow", "RampUp", "Crash", "RevsExtension",
    "Lighthouse", "orig_topic"
}

double_fields = {
    "Longitude", "Latitude", "SpeedGps", "SpeedTach", "SpeedCan", "TachoGps", "TachoTach",
    "WidthLeft", "WidthRight", "SumSalt", "SumInert", "SumBrine", "AkuVoltage", "TempAir",
    "TempRoad", "Revs", "Fuel", "LevelPHM", "PowerVoltage"
}

timestamp_fields = {"orig_time", "CreatedTime", "GpsTime"}

def unix_to_iso(ts):
    try:
        return datetime.utcfromtimestamp(int(ts)).isoformat() + "Z"
    except:
        return None

# Count total lines for progress (excluding header)
with open(input_file, 'r') as f:
    total_lines = sum(1 for _ in f) - 1

with open(input_file, newline='') as csvfile:
    reader = csv.DictReader(csvfile)
    records = []
    processed = 0

    for row in reader:
        # Convert timestamps
        for ts_field in timestamp_fields:
            if ts_field in row and row[ts_field]:
                iso = unix_to_iso(row[ts_field])
                if iso:
                    row[ts_field] = {"\$date": iso}
                else:
                    row[ts_field] = None

        # Convert ints
        for int_field in int_fields:
            if int_field in row and row[int_field] != '':
                try:
                    row[int_field] = int(row[int_field])
                except:
                    row[int_field] = None
            else:
                row[int_field] = None

        # Convert doubles
        for double_field in double_fields:
            if double_field in row and row[double_field] != '':
                try:
                    row[double_field] = float(row[double_field])
                except:
                    row[double_field] = None
            else:
                row[double_field] = None

        # Strings are left as is (including LicensePlate, Company, etc.)

        records.append(row)

        processed += 1
        if processed % 100 == 0 or processed == total_lines:
            percent = (processed / total_lines) * 100
            print(f"Processed {processed}/{total_lines} ({percent:.1f}%)")

with open(output_file, 'w') as jsonfile:
    for record in records:
        jsonfile.write(json.dumps(record) + "\n")

print("Conversion complete. JSON written to:", output_file)
EOF
