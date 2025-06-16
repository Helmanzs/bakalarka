#!/bin/bash

# Check arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input_csv_file> <output_csv_file>"
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

# Validate input file
if [[ ! -f "$INPUT_FILE" ]]; then
  echo "❌ Error: Input file '$INPUT_FILE' not found."
  exit 2
fi

# Resolve full path for output file
OUTPUT_PATH="$(realpath "$OUTPUT_FILE")"

# Get total number of lines for progress tracking
TOTAL_LINES=$(wc -l < "$INPUT_FILE")

# Process with AWK and show progress
awk -v total="$TOTAL_LINES" -v output="$OUTPUT_PATH" -F',' '
BEGIN {
    OFS = ",";
    count = 0;
}
NR==1 {
    for (i = 1; i <= NF; i++) {
        if ($i == "id") idcol = i;
    }
}
{
    out = "";
    for (i = 1; i <= NF; i++) {
        if (i == idcol) continue;
        val = ($i == "" ? 0 : $i);
        out = (out == "" ? val : out OFS val);
    }
    print out;

    count++;
    if (count % 100 == 0 || count == total) {
        printf("\r🔄 Processing line %d of %d...", count, total) > "/dev/stderr";
    }
}
END {
    printf("\r✅ Processing complete.\n") > "/dev/stderr";
    printf("%d lines written to %s\n", count, output) > "/dev/stderr";
}

' "$INPUT_FILE" > "$OUTPUT_FILE"
