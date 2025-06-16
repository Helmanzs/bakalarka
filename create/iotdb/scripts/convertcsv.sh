#!/bin/bash

# Transform CSV for IoTDB with device paths
# Usage: ./transform_csv.sh input.csv

if [ $# -eq 0 ]; then
    echo "Error: No input file specified"
    echo "Usage: $0 input.csv"
    exit 1
fi

INPUT="$1"
OUTPUT="${INPUT%.*}_transformed.csv"

python3 - <<EOF
import csv
import sys

input_file = "$INPUT"
output_file = "$OUTPUT"

try:
    with open(input_file, 'r') as infile, open(output_file, 'w', newline='') as outfile:
        reader = csv.reader(infile)
        writer = csv.writer(outfile)
        
        # Process header
        header = next(reader)
        new_header = ["Time", "device"] + [col.split(".")[-1] for col in header[1:]]
        writer.writerow(new_header)
        
        # Process rows
        for row in reader:
            if len(row) < 10:  # Skip incomplete rows
                continue
                
            # Create device path from Company + VehicleID
            company = row[8].replace(" ", "_").lower()
            vehicle_id = row[9]
            device = f"root.{company}.vehicle_{vehicle_id}"
            
            # Build new row with device path
            new_row = [row[0], device] + row[1:]
            writer.writerow(new_row)
            
    print(f"Success: Transformed CSV saved to {output_file}")
    print("Import to IoTDB using:")
    print(f"  import-csv.sh -f {output_file} -u root -pw root -t Time -d device --aligned")

except Exception as e:
    print(f"Error: {str(e)}")
    sys.exit(1)
EOF