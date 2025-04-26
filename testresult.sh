#!/bin/bash

# Paths
DATA_DIR="./data"
CSV_FILE="./summary_output.csv"

# Delete old CSV if exists
if [ -f "$CSV_FILE" ]; then
    rm "$CSV_FILE"
fi

# Create new CSV and write header
echo "folder_name,flaky_passes,flaky_failures,flaky_errors,flaky_total,fixed_passes,fixed_failures,fixed_errors,fixed_total,flaky_has_failures" > "$CSV_FILE"

# Process each folder in data
echo "Processing folders inside $DATA_DIR..."
for folder in "$DATA_DIR"/*; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")

        result_dir="$folder/result"
        if [ ! -d "$result_dir" ]; then
            echo "⚠️ Skipping $folder_name (no result folder)"
            continue
        fi

        # Function to parse a summary.txt file
        parse_summary() {
            local summary_file="$1"
            local passes=0 failures=0 errors=0
            if [ -f "$summary_file" ]; then
                passes=$(grep -i '^Passes:' "$summary_file" | awk -F': ' '{print $2}' || echo 0)
                failures=$(grep -i '^Failures:' "$summary_file" | awk -F': ' '{print $2}' || echo 0)
                errors=$(grep -i '^Errors:' "$summary_file" | awk -F': ' '{print $2}' || echo 0)
            fi
            echo "$passes $failures $errors"
        }

        # Parse flaky summary
        flaky_summary_file="$result_dir/Flaky/summary.txt"
        read flaky_passes flaky_failures flaky_errors < <(parse_summary "$flaky_summary_file")
        flaky_total=$((flaky_passes + flaky_failures + flaky_errors))

        # Parse fixed summary
        fixed_summary_file="$result_dir/Fixed/summary.txt"
        read fixed_passes fixed_failures fixed_errors < <(parse_summary "$fixed_summary_file")
        fixed_total=$((fixed_passes + fixed_failures + fixed_errors))

        # Determine flaky_has_failures
        if [ "$flaky_failures" -gt 0 ]; then
            flaky_has_failures="true"
        else
            flaky_has_failures="false"
        fi

        # Write to CSV
        echo "$folder_name,$flaky_passes,$flaky_failures,$flaky_errors,$flaky_total,$fixed_passes,$fixed_failures,$fixed_errors,$fixed_total,$flaky_has_failures" >> "$CSV_FILE"
    fi

done

echo "✅ CSV generated: $CSV_FILE"

