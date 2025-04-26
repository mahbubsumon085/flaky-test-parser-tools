#!/bin/bash

CSV_FILE="test_config.csv"
ISSUE_ID_FILTER="$1"

# Ensure an issue_id is provided
if [[ -z "$ISSUE_ID_FILTER" ]]; then
    echo "Usage: $0 <issue_id>"
    exit 1
fi

# Ensure the CSV file exists and is not empty
if [[ ! -s "$CSV_FILE" ]]; then
    echo "Error: CSV file is missing or empty!"
    exit 1
fi

# Read the file into an array to avoid subshell issues
echo "Reading CSV file..."
mapfile -t csv_lines < <(tail -n +2 "$CSV_FILE")  # Skip the header
echo "CSV Lines Read: ${#csv_lines[@]}"

for line in "${csv_lines[@]}"; do
    IFS=, read -r test_type issue_id zip module preceding_test flaky_test iterations config <<< "$line"

    # Process only if issue_id matches the filter
    if [[ "$issue_id" != "$ISSUE_ID_FILTER" ]]; then
        continue
    fi

    echo "Processing: test_type=$test_type, issue_id=$issue_id, zip = $zip module=$module, preceding_test=$preceding_test, flaky_test=$flaky_test, iterations=$iterations, config=$config"

    # Determine script based on test type and project
    if [[ "$test_type" == "od" ]]; then
        if [[ "$module" =~ ^hadoop ]]; then
            script_name="flaky_analysis_tool_od_proto.sh"
        else
             script_name="flaky_analysis_tool_od.sh"
        fi
        chmod +x "$script_name"
        bash "$script_name" "$issue_id"  "$zip" "$module" "$preceding_test" "$flaky_test" "$iterations" "$config"

    elif [[ "$test_type" == "td" ]]; then
        if [[ "$module" =~ ^hadoop ]]; then
            script_name="flaky_analysis_tool_td_proto.sh"
        else
            script_name="flaky_analysis_tool_td.sh"
        fi
        chmod +x "$script_name"
        bash "$script_name" "$issue_id" "$zip" "$module" "$flaky_test" "$iterations" "$config"
        
    elif [[ "$test_type" == "id" ]]; then
        if [[ "$module" =~ ^hadoop ]]; then
            script_name="flaky_analysis_tool_id.sh"
        elif [[ "$module" =~ ^hdfs-connector ]]; then
            script_name="flaky_analysis_tooljdk8_id.sh"
        else
            script_name="flaky_analysis_tool_id.sh"
        fi
        chmod +x "$script_name"
        bash "$script_name" "$issue_id" "$zip" "$module" "$flaky_test" "$iterations" "$config"
    else
        if [[ "$module" =~ ^hadoop ]]; then
            script_name="flaky_analysis_tool.sh"
        else
            script_name="flaky_analysis_tool.sh"
        fi
        chmod +x "$script_name"
        bash "$script_name" "$issue_id" "$zip" "$module" "$flaky_test" "$iterations" "$config"
    fi

    # Exit after processing the first matching issue
    break
done