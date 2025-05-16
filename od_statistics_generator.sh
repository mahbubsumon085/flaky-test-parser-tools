#!/bin/bash

# Assign parameters
module=$1
precedingtest=$2
flakytest=$3
iterations=${4:-100}

MVNOPTIONS="-Ddependency-check.skip=true -Dgpg.skip=true -DfailIfNoTests=false -Dskip.installnodenpm -Dskip.npm -Dskip.yarn -Dlicense.skip -Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dmdep.analyze.skip -Dpgpverify.skip -Dxml.skip -Dcobertura.skip=true -Dfindbugs.skip=true"

echo "Parameters: module=$module, precedingtest=$precedingtest, flakytest=$flakytest, iterations=$iterations"

# Build step
mvn clean install -DskipTests -pl "$module" -am $MVNOPTIONS || { echo "❌ Maven install failed"; exit 1; }

pass_count=0
fail_count=0
error_count=0

for ((i=0; i<iterations; i++)); do
    find . -name "TEST-*.xml" -delete
    set -x
    mvn -pl "$module" test -Dsurefire.runOrder=testorder -Dtest="$precedingtest,$flakytest" $MVNOPTIONS |& tee mvn-test-$i.log
    set +x

    # Parse class and method
    formatted_flakytest="${flakytest//#/.}"
    test_class=$(echo "$formatted_flakytest" | rev | cut -d'.' -f2- | rev)
    test_method=$(echo "$formatted_flakytest" | awk -F. '{print $NF}')

    echo "Looking for test: class='$test_class', method='$test_method'"

    f=""
    while IFS= read -r file; do
        echo "Checking file: '$file'"
        if grep -Pq "<testcase[^>]*\bclassname=\"$test_class\"[^>]*\bname=\"$test_method\"" "$file" || \
           grep -Pq "<testcase[^>]*\bname=\"$test_method\"[^>]*\bclassname=\"$test_class\"" "$file"; then
            echo "✔ Found in: $file"
            f="$file"
            break
        fi
    done < <(find . -name "TEST-*.xml" -not -path "*target/surefire-reports/junitreports/*")

    if [[ -n "$f" && -f "$f" ]]; then
        echo "✓ Using: $f"
        python python-scripts/parse_surefire_report.py "$f" "$i" "$flakytest" >> rounds-test-results1.csv
    else
        echo "✗ ERROR: Could not find test XML for $flakytest"
    fi

    mkdir -p "flaky-result/testlog"
    mkdir -p "flaky-result/surefire-reports"

    mv mvn-test-$i.log "flaky-result/testlog"

    for xmlf in $(find . -name "TEST-*.xml" -not -path "*target/surefire-reports/*"); do 
        mv "$xmlf" "flaky-result/testlog"
    done

    cp -r "$module/target/surefire-reports" "flaky-result/surefire-reports/reports-$i"
done

# Filter for flakytest only
formatted_flakytest="${flakytest//#/.}"
awk -v dependent="$formatted_flakytest" -F, '$1 ~ dependent { print $0 }' rounds-test-results1.csv > rounds-test-results.tmp

if [[ -s rounds-test-results.tmp ]]; then
    mv rounds-test-results.tmp rounds-test-results.csv
else
    echo "⚠️ No matching rows found for dependent test: $formatted_flakytest"
    rm -f rounds-test-results.tmp
fi

# Count summary
while IFS=',' read -r col1 col2 col3 col4 col5; do
    if [[ $col2 == "pass" ]]; then
        ((pass_count++))
    elif [[ $col2 == "failure" ]]; then
        ((fail_count++))
    elif [[ $col2 == "error" ]]; then
        ((error_count++))
    fi
done < rounds-test-results.csv


# Output the counts
echo "Summary:"
echo "Passes: $pass_count"
echo "Failures: $fail_count"
echo "Errors: $error_count"
total_rounds=$((  fail_count + error_count))
echo "Total Rounds: $total_rounds"
# Output the counts and log to a summary file
summary_file="flaky-result/summary.txt"
{
    echo "Summary:"
    echo "Passes: $pass_count"
    echo "Failures: $fail_count"
    echo "Errors: $error_count"
} > "$summary_file"



# Move the CSV file to the log directory
mv $CSV_FILE "flaky-result"
echo "$total_rounds"

