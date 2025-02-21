#!/bin/bash

# Variables
MODULE="$1"   # Pass the module name as the first argument
TEST="$2"     # Pass the test name as the second argument
rounds="$3"
CSV_FILE="rounds-test-results.csv"

# BASE_DIR=$(pwd)
# LOG_DIR="$BASE_DIR/LOGRESULTS/FlakyVersionCode"


# echo "Maven repository directory is set to: $MAVEN_OPTS"
# echo "M2 directory : $M2_DIR"

# echo $MODULE
# echo $TEST

# Prepare Maven repository
# mkdir -p ~/.m2/repository
# cp -r $M2_DIR/* ~/.m2/repository

# cd $FLAKY_DIR

# Clean and build the project
mvn clean install -DskipTests -pl "$MODULE" -am

# Run NonDex and capture output
OUTPUT=$(mvn -pl "$MODULE" edu.illinois:nondex-maven-plugin:2.1.1:nondex -DnondexRuns=$rounds -Dtest="$TEST" 2>&1 | tee /dev/tty)

# Extract the NonDexExecid and nondexSeed
EXEC_IDS=$(echo "$OUTPUT" | grep "nondexExecid=" | sed -E 's/.*nondexExecid=([^\ ]+).*/\1/')
SEEDS=$(echo "$OUTPUT" | grep "nondexSeed=" | sed -E 's/.*nondexSeed=([^\ ]+).*/\1/')

# Initialize CSV header
echo "Iteration,Execution ID,Seed,XML File,Total Tests,Total Success,Total Failures,Total Errors,Total Skipped,Total Time" > "$CSV_FILE"

total_success_count=0
total_failure_count=0

# Save Execution IDs and Seeds to output.txt
if [ -n "$EXEC_IDS" ] && [ -n "$SEEDS" ]; then
    echo "Extracted NonDex Execution IDs and Seeds:"
    paste -d',' <(echo "$EXEC_IDS") <(echo "$SEEDS") > output.txt
    awk '!seen[$0]++ && $0 !~ /^clean_/' output.txt > filtered_output.txt
else
    echo "Error: Execution IDs or Seeds not found."
    exit 1
fi

iteration=1
CLASS_NAME="${TEST%%#*}" # Extract the part of TEST before the `#`

# Process Execution IDs and Seeds from output.txt
while IFS=',' read -r line seed; do
    if [[ -n "$line" ]]; then
        echo "Processing NonDex Execution ID: $line and Seed: $seed"
        NDEX_DIR="${MODULE}/.nondex/${line}"
        TXT_FILE="${NDEX_DIR}/${CLASS_NAME}.txt"
        xml_file="${NDEX_DIR}/TEST-${CLASS_NAME}.xml"

        if [[ -f "$TXT_FILE" && -f "$xml_file" ]]; then
            mkdir -p "flaky-result/testlog/$iteration"
            cp "$TXT_FILE" "flaky-result/testlog/$iteration/mvn-test-$iteration.log"

            # Parse test results from the XML file
            total_tests=$(xmllint --xpath 'string(//testsuite/@tests)' "$xml_file")
            total_failures=$(xmllint --xpath 'string(//testsuite/@failures)' "$xml_file")
            total_errors=$(xmllint --xpath 'string(//testsuite/@errors)' "$xml_file")
            total_skipped=$(xmllint --xpath 'string(//testsuite/@skipped)' "$xml_file")
            total_time=$(xmllint --xpath 'string(//testsuite/@time)' "$xml_file")

            # Calculate success and failure counts
            total_success=$((total_tests - total_failures - total_errors - total_skipped))
            total_failure=$((total_failures + total_errors))

            # Update global counts
            total_success_count=$((total_success_count + total_success))
            total_failure_count=$((total_failure_count + total_failure))

            # Write results to CSV
            echo "$iteration,$line,$seed,$xml_file,$total_tests,$total_success,$total_failures,$total_errors,$total_skipped,$total_time" >> "$CSV_FILE"
        else
            echo "Error: File $TXT_FILE or $xml_file not found!"
        fi

        # Increment iteration
        ((iteration++))
    fi
done < filtered_output.txt

# Output global results
echo "Total Successes: $total_success_count"
echo "Total Failures: $total_failure_count"

# Move the CSV file to the log directory
mv $CSV_FILE "flaky-result"
