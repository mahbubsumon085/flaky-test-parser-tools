chmod +x single_runner.sh
./single_runner.sh BOOKKEEPER-709

# Parameter:  issue_id(the zip file name that contains the necessary data for flaky test)

# chmod +x testresult.sh
#./testresult.sh
find . -name "pom.xml" | while read -r file; do
            sed -i 's|2.7.0-SNAPSHOT|2.7.0|g' "$file"
   done
