#!/bin/sh

# usage check
if [ $# -ne 2 ]; then
  echo "Usage: $0 <input_csv_file> <output_csv_file>" >&2
  exit 1
fi

INPUT="$1"
OUTPUT="$2"
STORAGE_GROUP="root.car_telemetry"

# make sure output dir exists
mkdir -p "$(dirname "$OUTPUT")"

# run the embedded Python
python3 - "$INPUT" "$OUTPUT" "$STORAGE_GROUP" << 'PYCODE'
import sys, csv

# parse args
_, infile, outfile, sg = sys.argv

# count total data rows (minus header)
with open(infile, 'r', newline='') as f:
    total = sum(1 for _ in f) - 1
if total < 1:
    print(f"No data rows found in {infile}", file=sys.stderr)
    sys.exit(1)

# process CSV
with open(infile, 'r', newline='') as fin, \
     open(outfile, 'w', newline='') as fout:

    reader = csv.reader(fin)
    header = next(reader)
    header = [h.rstrip('\r') for h in header]

    # find indices
    try:
        orig_i    = header.index('orig_id')
        gpstime_i = header.index('GpsTime')
    except ValueError as e:
        print("ERROR: Required header not found:", str(e), file=sys.stderr)
        sys.exit(1)

    # build and write new header
    out_cols = ['Time'] + [
        f"{sg}.{col}" 
        for i, col in enumerate(header)
        if i not in (orig_i, gpstime_i)
    ]
    writer = csv.writer(fout)
    writer.writerow(out_cols)

    # process rows with progress
    for count, row in enumerate(reader, start=1):
        print(f"\rProgress: {count}/{total}", end='', file=sys.stderr)
        sys.stderr.flush()

        # format timestamp
        t = row[gpstime_i].replace(' ', 'T') + '+02:00'
        out_row = [t]

        # write other values
        for i, v in enumerate(row):
            if i in (orig_i, gpstime_i):
                continue
            out_row.append(v)
        writer.writerow(out_row)

# final newline and summary
print(file=sys.stderr)
print(f"Done: wrote {total} rows to {outfile}", file=sys.stderr)
PYCODE
