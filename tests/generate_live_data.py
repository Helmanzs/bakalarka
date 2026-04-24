#!/usr/bin/env python3
"""
generate_live_data.py
---------------------
Generates a stream of random car-telemetry records and writes them to stdout
in the requested format.

Usage:
  python3 generate_live_data.py \
      --format  csv|json|line_protocol \
      --rows     <N>                    \
      --table    <table_name>           \
      --vehicle-ids <id1,id2,...>       \
      [--seed <int>]

Formats:
  csv            – RFC-4180 CSV with header row (for SQL databases)
  json           – one JSON object per line, GpsTime as ISO-8601 string
  line_protocol  – InfluxDB v2/v3 line protocol
"""

import argparse
import csv
import json
import random
import sys
import time
from datetime import datetime, timezone

# --------------------------------------------------------------------------- #
# Schema definition
# --------------------------------------------------------------------------- #
COMPANIES   = ["sus_uk", "sus_de", "sus_cz", "sus_pl", "sus_at"]
ORIG_TOPICS = ["telemetry/vehicle", "gps/raw", "can/data", "telematics/live"]

def rand_vehicle_ids(n=10):
    return [str(random.randint(100, 999)) for _ in range(n)]

def make_record(ts: datetime, vehicle_id: str) -> dict:
    gps_time_str = ts.strftime("%Y-%m-%dT%H:%M:%S.000000")
    return {
        "orig_id":          random.randint(1, 9_999_999),
        "orig_time":        gps_time_str,
        "orig_topic":       random.choice(ORIG_TOPICS),
        "CreatedTime":      gps_time_str,
        "GpsTime":          ts,
        "GsmSignal":        random.randint(0, 31),
        "SatelliteCount":   random.randint(0, 20),
        "LicensePlate":     f"{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}{random.randint(10,99)}{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}{random.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ')}",
        "VehicleType":      random.randint(1, 5),
        "Company":          random.choice(COMPANIES),
        "VehicleID":        vehicle_id,
        "Technology":       random.randint(0, 3),
        "Ignition":         random.randint(0, 1),
        "Longitude":        round(random.uniform(12.0, 18.5), 6),
        "Latitude":         round(random.uniform(48.5, 51.5), 6),
        "SpeedGps":         round(random.uniform(0, 130), 3),
        "SpeedTach":        round(random.uniform(0, 130), 3),
        "SpeedCan":         round(random.uniform(0, 130), 3),
        "TachoGps":         round(random.uniform(0, 130), 3),
        "TachoTach":        round(random.uniform(0, 130), 3),
        "ModeDrive":        random.randint(0, 4),
        "SpreadingMode":    random.randint(0, 3),
        "Plow":             random.randint(0, 1),
        "Gram":             random.randint(0, 500),
        "WidthLeft":        round(random.uniform(0, 3), 3),
        "WidthRight":       round(random.uniform(0, 3), 3),
        "SumSalt":          round(random.uniform(0, 10000), 4),
        "SumInert":         round(random.uniform(0, 10000), 4),
        "SumBrine":         round(random.uniform(0, 10000), 4),
        "Cuts1":            random.randint(0, 1),
        "Cuts2":            random.randint(0, 1),
        "Cuts3":            random.randint(0, 1),
        "CentralBroom":     random.randint(0, 1),
        "LeftBroom":        random.randint(0, 1),
        "RightBroom":       random.randint(0, 1),
        "Turbine":          random.randint(0, 1),
        "RunningShaft":     random.randint(0, 1),
        "LeftFlushing":     random.randint(0, 1),
        "RightFlushing":    random.randint(0, 1),
        "CentralFlushing":  random.randint(0, 1),
        "Misting":          random.randint(0, 1),
        "Pump":             random.randint(0, 1),
        "LightOn":          random.randint(0, 1),
        "ModeArrow":        random.randint(0, 5),
        "AkuVoltage":       round(random.uniform(11.0, 14.5), 3),
        "RampUp":           random.randint(0, 1),
        "Crash":            random.randint(0, 1),
        "TempAir":          round(random.uniform(-20, 40), 3),
        "TempRoad":         round(random.uniform(-20, 40), 3),
        "Revs":             round(random.uniform(0, 5000), 4),
        "RevsExtension":    random.randint(0, 1),
        "Fuel":             round(random.uniform(0, 100), 3),
        "LevelPHM":         round(random.uniform(0, 100), 3),
        "PowerVoltage":     round(random.uniform(11.0, 14.5), 3),
        "Lighthouse":       random.randint(0, 1),
    }

# --------------------------------------------------------------------------- #
# Formatters
# --------------------------------------------------------------------------- #
IOTDB_MEASUREMENTS = [
    ("orig_id", "INT64"),
    ("orig_time", "TEXT"),
    ("orig_topic", "TEXT"),
    ("CreatedTime", "TEXT"),
    ("GpsTime", "TEXT"),

    ("GsmSignal", "INT32"),
    ("SatelliteCount", "INT32"),
    ("LicensePlate", "TEXT"),
    ("VehicleType", "INT32"),
    ("Company", "TEXT"),

    ("Technology", "INT32"),
    ("Ignition", "BOOLEAN"),
    ("Longitude", "DOUBLE"),
    ("Latitude", "DOUBLE"),

    ("SpeedGps", "DOUBLE"),
    ("SpeedTach", "DOUBLE"),
    ("SpeedCan", "DOUBLE"),
    ("TachoGps", "DOUBLE"),
    ("TachoTach", "DOUBLE"),

    ("ModeDrive", "INT32"),
    ("SpreadingMode", "INT32"),
    ("Plow", "BOOLEAN"),
    ("Gram", "INT32"),

    ("WidthLeft", "DOUBLE"),
    ("WidthRight", "DOUBLE"),
    ("SumSalt", "DOUBLE"),
    ("SumInert", "DOUBLE"),
    ("SumBrine", "DOUBLE"),

    ("Cuts1", "BOOLEAN"),
    ("Cuts2", "BOOLEAN"),
    ("Cuts3", "BOOLEAN"),

    ("CentralBroom", "BOOLEAN"),
    ("LeftBroom", "BOOLEAN"),
    ("RightBroom", "BOOLEAN"),

    ("Turbine", "BOOLEAN"),
    ("RunningShaft", "BOOLEAN"),

    ("LeftFlushing", "BOOLEAN"),
    ("RightFlushing", "BOOLEAN"),
    ("CentralFlushing", "BOOLEAN"),

    ("Misting", "BOOLEAN"),
    ("Pump", "BOOLEAN"),
    ("LightOn", "BOOLEAN"),

    ("ModeArrow", "INT32"),
    ("AkuVoltage", "DOUBLE"),

    ("RampUp", "BOOLEAN"),
    ("Crash", "BOOLEAN"),

    ("TempAir", "DOUBLE"),
    ("TempRoad", "DOUBLE"),

    ("Revs", "DOUBLE"),
    ("RevsExtension", "BOOLEAN"),

    ("Fuel", "DOUBLE"),
    ("LevelPHM", "DOUBLE"),
    ("PowerVoltage", "DOUBLE"),

    ("Lighthouse", "BOOLEAN"),
]

CSV_COLS = [
    "orig_id","orig_time","orig_topic","CreatedTime","GpsTime",
    "GsmSignal","SatelliteCount","LicensePlate","VehicleType","Company",
    "VehicleID","Technology","Ignition","Longitude","Latitude",
    "SpeedGps","SpeedTach","SpeedCan","TachoGps","TachoTach",
    "ModeDrive","SpreadingMode","Plow","Gram","WidthLeft","WidthRight",
    "SumSalt","SumInert","SumBrine",
    "Cuts1","Cuts2","Cuts3","CentralBroom","LeftBroom","RightBroom",
    "Turbine","RunningShaft","LeftFlushing","RightFlushing","CentralFlushing",
    "Misting","Pump","LightOn","ModeArrow","AkuVoltage","RampUp","Crash",
    "TempAir","TempRoad","Revs","RevsExtension","Fuel","LevelPHM",
    "PowerVoltage","Lighthouse",
]

def to_csv(records, include_header=True):
    writer = csv.DictWriter(
        sys.stdout, fieldnames=CSV_COLS,
        extrasaction="ignore", lineterminator="\n"
    )
    if include_header:
        writer.writeheader()
    for r in records:
        writer.writerow(r)

def to_json(records):
    for r in records:
        r_copy = r.copy()

        ts: datetime = r_copy["GpsTime"]
        r_copy["GpsTime"] = {
            "$date": ts.replace(tzinfo=timezone.utc)
                         .isoformat()
                         .replace("+00:00", "Z")
        }

        print(json.dumps(r_copy))

def _lp_escape_tag(v):
    return str(v).replace(",", r"\,").replace("=", r"\=").replace(" ", r"\ ")

def _lp_escape_field_str(v):
    return '"' + str(v).replace('"', r'\"') + '"'

def to_line_protocol(records, table):
    TAG_FIELDS    = {"VehicleID", "Company", "LicensePlate", "VehicleType", "Technology"}
    STRING_FIELDS = {"orig_topic", "orig_time", "CreatedTime", "GpsTime"}
    INT_FIELDS    = {
        "orig_id","GsmSignal","SatelliteCount",
        "Ignition","ModeDrive","SpreadingMode","Plow","Gram",
        "Cuts1","Cuts2","Cuts3","CentralBroom","LeftBroom","RightBroom",
        "Turbine","RunningShaft","LeftFlushing","RightFlushing","CentralFlushing",
        "Misting","Pump","LightOn","ModeArrow","RampUp","Crash",
        "RevsExtension","Lighthouse",
    }

    for r in records:
        tags = ",".join(
            f"{_lp_escape_tag(k)}={_lp_escape_tag(r[k])}"
            for k in sorted(TAG_FIELDS) if k in r
        )
        field_parts = []
        for k, v in r.items():
            if k in TAG_FIELDS or k == "GpsTime":
                continue
            if k in STRING_FIELDS:
                field_parts.append(f"{k}={_lp_escape_field_str(v)}")
            elif k in INT_FIELDS:
                field_parts.append(f"{k}={int(v)}i")
            else:
                field_parts.append(f"{k}={float(v)}")
        fields = ",".join(field_parts)

        dt = r["GpsTime"]
        ts_ns = int(dt.timestamp() * 1_000_000_000)

        print(f"{table},{tags} {fields} {ts_ns}")

def to_iotdb(records, device_prefix):
    import json

    measurements = [m[0] for m in IOTDB_MEASUREMENTS]
    data_types   = [m[1] for m in IOTDB_MEASUREMENTS]

    devices = {}
    for r in records:
        vid = r["VehicleID"]
        device_id = f"{device_prefix}.vehicle_{vid}"
        devices.setdefault(device_id, []).append(r)

    for device_id, dev_records in devices.items():
        timestamps = []
        values = [[] for _ in measurements]

        for r in dev_records:
            dt = r["GpsTime"]
            timestamps.append(int(dt.timestamp() * 1000))

            for i, (field, dtype) in enumerate(IOTDB_MEASUREMENTS):
                v = r.get(field)
                if v is None:
                    values[i].append(None)
                    continue
                if dtype == "BOOLEAN":
                    values[i].append(bool(v))
                elif dtype == "INT32":
                    values[i].append(int(v))
                elif dtype == "INT64":
                    values[i].append(int(v))
                elif dtype in ("DOUBLE", "FLOAT"):
                    values[i].append(float(v))
                else: 
                    values[i].append(str(v))

        payload = {
            "deviceId": device_id,
            "timestamps": timestamps,
            "measurements": measurements,
            "dataTypes": data_types,
            "values": values,
            "isAligned": False
        }
        print(json.dumps(payload))

def to_questdb(records, table):
    TAG_FIELDS = {"VehicleID", "Company", "LicensePlate", "VehicleType", "Technology"}
    BOOL_FIELDS = {
        "Ignition","Plow","Cuts1","Cuts2","Cuts3",
        "CentralBroom","LeftBroom","RightBroom",
        "Turbine","RunningShaft","LeftFlushing","RightFlushing",
        "CentralFlushing","Misting","Pump","LightOn",
        "RampUp","Crash","RevsExtension","Lighthouse"
    }
    TIMESTAMP_FIELDS = {"CreatedTime", "orig_time"}

    for r in records:
        tags = ",".join(
            f"{k}={str(r[k]).replace(' ', '\\ ')}"
            for k in TAG_FIELDS if k in r
        )

        fields = []
        for k, v in r.items():
            if k in TAG_FIELDS or k == "GpsTime":
                continue

            if k in TIMESTAMP_FIELDS:
                # Convert ISO-8601 string to UTC epoch microseconds for QuestDB ILP
                dt = datetime.fromisoformat(v).replace(tzinfo=timezone.utc)
                ts_us = int(dt.timestamp() * 1_000_000)
                fields.append(f"{k}={ts_us}t")
            elif k in BOOL_FIELDS:
                fields.append(f"{k}={'true' if v else 'false'}")
            elif isinstance(v, str):
                fields.append(f'{k}="{v}"')
            elif isinstance(v, int):
                fields.append(f"{k}={v}i")
            else:
                fields.append(f"{k}={float(v)}")

        ts_ns = int(r["GpsTime"].timestamp() * 1_000_000_000)

        print(f"{table},{tags} {','.join(fields)} {ts_ns}")

# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--format",       default="csv",
                    choices=["csv", "json", "line_protocol", "iotdb", "questdb"])
    ap.add_argument("--rows",         type=int,   default=100)
    ap.add_argument("--table",        default="car_telemetry")
    ap.add_argument("--vehicle-ids",  default="",
                    help="Comma-separated list of VehicleIDs to use")
    ap.add_argument("--seed",         type=int,   default=None)
    ap.add_argument("--ts-start",     default=None,
                    help="ISO-8601 start timestamp (default: now)")
    ap.add_argument("--ts-step-ms",   type=int,   default=1000,
                    help="Milliseconds between successive row timestamps")
    ap.add_argument("--no-header", action="store_true",
                help="Do not output CSV header row")
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    vehicle_ids = (
        [v.strip() for v in args.vehicle_ids.split(",") if v.strip()]
        if args.vehicle_ids else rand_vehicle_ids(5)
    )

    if args.ts_start:
        ts_str = args.ts_start.replace('Z', '+00:00')
        base_ts = datetime.fromisoformat(ts_str)
    else:
        base_ts = datetime.now(tz=timezone.utc)

    records = []
    for i in range(args.rows):
        ts = base_ts.replace(
            microsecond=0,
            second=0,
            minute=0,
        )
        # advance time per row
        offset_sec = (i * args.ts_step_ms) // 1000
        offset_us  = ((i * args.ts_step_ms) % 1000) * 1000
        from datetime import timedelta
        ts = base_ts + timedelta(seconds=offset_sec, microseconds=offset_us)

        vid = vehicle_ids[i % len(vehicle_ids)]
        records.append(make_record(ts, vid))

    if args.format == "csv":
        to_csv(records, include_header=not args.no_header)
    elif args.format == "json":
        to_json(records)
    elif args.format == "line_protocol":
        to_line_protocol(records, args.table)
    elif args.format == "iotdb":
        to_iotdb(records, args.table)
    elif args.format == "questdb":
        to_questdb(records, args.table)
if __name__ == "__main__":
    main()