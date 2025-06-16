#!/bin/bash

# Check for input arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_csv_file> <output_txt_file>"
    exit 1
fi

csv_file="$1"
output_file="$2"
temp_file=$(mktemp)

# Validate input file
if [ ! -f "$csv_file" ]; then
    echo "Error: Input file $csv_file not found!"
    exit 1
fi

# Get total lines for progress tracking (excluding header)
total_lines=$(($(wc -l < "$csv_file") - 1))
current_line=0

# Process the CSV with AWK
awk -F ',' -v total="$total_lines" '
BEGIN {
    # Metrics to extract
    split("GsmSignal,SatelliteCount,SpeedGps,SpeedTach,SpeedCan,TachoGps,TachoTach,Fuel,TempAir,TempRoad,Revs,PowerVoltage,LevelPHM,WidthLeft,WidthRight,SumSalt,SumInert,SumBrine,Plow,Gram,ModeDrive,SpreadingMode,CentralBroom,LeftBroom,RightBroom,Turbine,RunningShaft,LeftFlushing,RightFlushing,CentralFlushing,Misting,Pump,LightOn,ModeArrow,AkuVoltage,RampUp,Crash,Cuts1,Cuts2,Cuts3", metrics, ",")
    split("VehicleID,LicensePlate,Company,VehicleType,Technology,Ignition,ModeDrive", tag_fields, ",")

    OFS = " "
}
NR == 1 {
    for (i = 1; i <= NF; i++) {
        col[$i] = i
    }
    next
}
NR > 1 {
    current_line++
    if (total > 0 && current_line % 1000 == 0) {
        printf("\rProcessing line %d of %d", current_line, total) > "/dev/stderr"
    }

    # Convert GpsTime to Unix timestamp
    split($(col["GpsTime"]), datetime, /[T.:-]/)
    timestamp = mktime(datetime[1] " " datetime[2] " " datetime[3] " " datetime[4] " " datetime[5] " " datetime[6])
    if (timestamp == 0) next

    # Prepare tags
    tags = ""
    for (i = 1; i <= length(tag_fields); i++) {
        field = tag_fields[i]
        value = $(col[field])
        gsub(/ /, "_", value)
        tags = tags field "=" value " "
    }

    # Prepare each metric line
    for (i = 1; i <= length(metrics); i++) {
        metric = metrics[i]
        val = $(col[metric])
        if (val == "" || val == "NULL") val = "0"
        key = metric "|" timestamp "|" tags
        data[key] = val  # Overwrite with latest
    }
}
END {
    for (k in data) {
        split(k, parts, "|")
        printf("raltra.%s %d %s %s\n", parts[1], parts[2], data[k], parts[3])
    }
    print "" > "/dev/stderr"
}
' "$csv_file" > "$temp_file"

# Sort by timestamp (2nd field) and write to output
sort -n -k2 "$temp_file" > "$output_file"
rm "$temp_file"

echo "Done. Data written to $output_file"
