#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input.csv> <output.lp>"
    exit 1
fi

INPUT_CSV="$1"
OUTPUT_LP="$2"
MEASUREMENT="car_telemetry"

mkdir -p "$(dirname "$OUTPUT_LP")"

# Calculate total lines and data lines (excluding header)
total_lines=$(wc -l < "$INPUT_CSV")
data_lines=$((total_lines - 1))

# Capture start time in seconds since epoch
start_time=$(date +%s)

awk -F, -v measurement="$MEASUREMENT" -v total_data_lines="$data_lines" -v start_time="$start_time" '
function escape_tag(value,   out) {
    gsub(/[,= ]/, "\\\\&", value)
    return value
}

function escape_field(value,   out) {
    gsub(/["\\]/, "\\\\&", value)
    return value
}

function to_unix_ns(datetime,   cmd, ts) {
    cmd = "date -d \"" datetime "\" +%s%N"
    cmd | getline ts
    close(cmd)
    return ts
}

function format_elapsed(seconds,   h,m,s) {
    h = int(seconds / 3600)
    m = int((seconds % 3600) / 60)
    s = int(seconds % 60)
    return sprintf("%02d:%02d:%02d", h, m, s)
}

BEGIN {
    FPAT = "([^,]*)|(\"[^\"]+\")"
    OFS = ""
    last_percent = -1
}

NR == 1 {
    for (i = 1; i <= NF; i++) {
        gsub(/^[ \t"]+|[ \t"]+$/, "", $i)  # Trim whitespace and quotes
        column_map[$i] = i
    }

    required_fields = "CreatedTime,GpsTime,LicensePlate,Company,VehicleID,Technology,VehicleType"
    n_req = split(required_fields, req)
    for (i = 1; i <= n_req; i++) {
        if (!(req[i] in column_map)) {
            print "Error: Missing required column: " req[i] > "/dev/stderr"
            exit 1
        }
    }
    next
}

{
    # Progress tracking
    current_line = NR - 1  # Adjust for header line
    if (total_data_lines > 0) {
        current_percent = int((current_line / total_data_lines) * 100)
        if (current_percent > last_percent) {
            # Calculate elapsed time in seconds
            now = systime()
            elapsed = now - start_time
            elapsed_str = format_elapsed(elapsed)

            # Print progress with elapsed time
            printf "Progress: %d%% | Elapsed Time: %s\r", current_percent, elapsed_str > "/dev/stderr"
            fflush("/dev/stderr")
            last_percent = current_percent
        }
    }

    if (!$(column_map["GpsTime"]) || !$(column_map["CreatedTime"])) next

    tags = sprintf("LicensePlate=%s,Company=%s,VehicleID=%s,Technology=%s,VehicleType=%s",
        escape_tag($(column_map["LicensePlate"])),
        escape_tag($(column_map["Company"])),
        escape_tag($(column_map["VehicleID"])),
        escape_tag($(column_map["Technology"])),
        escape_tag($(column_map["VehicleType"])))

    split("CreatedTime,GsmSignal,SatelliteCount,Longitude,Latitude,SpeedGps,SpeedTach," \
          "SpeedCan,TachoGps,TachoTach,ModeDrive,SpreadingMode,Plow,Gram,WidthLeft," \
          "WidthRight,SumSalt,SumInert,SumBrine,Cuts1,Cuts2,Cuts3,CentralBroom,LeftBroom," \
          "RightBroom,Turbine,RunningShaft,LeftFlushing,RightFlushing,CentralFlushing," \
          "Misting,Pump,LightOn,ModeArrow,AkuVoltage,RampUp,Crash,TempAir,TempRoad,Revs," \
          "RevsExtension,Fuel,LevelPHM,PowerVoltage,Lighthouse", fields, ",")

    split("GsmSignal,SatelliteCount,ModeDrive,SpreadingMode,Plow,Gram,Cuts1,Cuts2,Cuts3," \
          "CentralBroom,LeftBroom,RightBroom,Turbine,RunningShaft,LeftFlushing,RightFlushing," \
          "CentralFlushing,Misting,Pump,LightOn,ModeArrow,RampUp,Crash,RevsExtension,Lighthouse", int_fields_arr, ",")
    for (i in int_fields_arr) is_int[int_fields_arr[i]] = 1

    field_str = ""
    for (i = 1; i <= length(fields); i++) {
        f = fields[i]
        if (!(f in column_map)) continue
        val = $(column_map[f])

        if (f == "CreatedTime") {
            val = "\"" escape_field(val) "\""
        } else if (f in is_int) {
            val = val ~ /^[0-9]+$/ ? val "i" : "0i"
        } else {
            val = (val == "") ? "0" : val
        }

        if (field_str != "") field_str = field_str ","
        field_str = field_str f "=" val
    }

    ts = to_unix_ns($(column_map["GpsTime"]))
    if (!ts) next

    print measurement "," tags " " field_str " " ts
}

END {
    printf "\n" > "/dev/stderr"
}' "$INPUT_CSV" > "$OUTPUT_LP"

echo "Conversion complete. Output saved to $OUTPUT_LP"
