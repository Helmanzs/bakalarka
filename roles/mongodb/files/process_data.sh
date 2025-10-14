#!/bin/bash

if [ $# -lt 3 ]; then
  echo "Usage: $0 input.csv output.csv column1,column2,..."
  exit 1
fi

INPUT="$1"
OUTPUT="$2"
COLS="$3"

IFS=',' read -ra COL_NAMES <<< "$COLS"

# Read header, find indexes of columns to convert
read -r HEADER < "$INPUT"
IFS=',' read -ra HEADERS_ARR <<< "$HEADER"

declare -A COL_INDEXES

for colname in "${COL_NAMES[@]}"; do
  found=0
  for i in "${!HEADERS_ARR[@]}"; do
    if [[ "${HEADERS_ARR[$i]}" == "$colname" ]]; then
      COL_INDEXES[$colname]=$i
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "Column '$colname' not found in CSV header"
    exit 2
  fi
done

TOTAL_LINES=$(($(wc -l < "$INPUT") - 1))  # exclude header
if [[ $TOTAL_LINES -le 0 ]]; then
  echo "No data lines found in $INPUT"
  exit 3
fi

echo "$HEADER" > "$OUTPUT"

count=0
tail -n +2 "$INPUT" | while IFS=',' read -ra FIELDS; do
  for colname in "${COL_NAMES[@]}"; do
    idx=${COL_INDEXES[$colname]}
    val="${FIELDS[$idx]}"
    if [[ -n "$val" ]]; then
      epoch=$(date -d "$val" +%s 2>/dev/null)
      if [[ $? -eq 0 ]]; then
        FIELDS[$idx]=$epoch
      fi
    fi
  done
  (IFS=','; echo "${FIELDS[*]}") >> "$OUTPUT"

  # Progress
  ((count++))
  percent=$((count * 100 / TOTAL_LINES))
  echo -ne "Progress: $percent% ($count/$TOTAL_LINES) lines processed\r"
done

echo -e "\nDone!"
