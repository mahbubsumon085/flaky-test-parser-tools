# Project Test Automation and Statistics Generator

This repository primarily contains Python and Bash scripts for parsing and generating statistics for flaky unit tests across multiple iterations. It supports various flaky test types, including order-dependent (OD), time-dependent (TD), implementation-dependent (ID), and more.  

The scripts are adapted from the [Azure Tools repository](https://github.com/winglam/azure-tools) to extend functionality for diverse flaky test scenarios and provide enhanced automation and analysis.

## Prerequisites

- **Docker**: Ensure Docker is installed and running on your system to enable containerized execution of the analysis.
- **Linux (Tested on Version 22)**: The analysis has been tested on Linux 22 and is recommended for optimal performance.  
- **Mac Compatibility**: The setup should be compatible with macOS as well. If you encounter any issues on macOS, please let us know.

### `Run the Rcript`

To execute the tool, run the `runner.sh` script. It will start the tool based on `test_config.csv` and flaky test present inside the `data` folder. You can download more test data from our shared data directory and update the `test_config.csv` file accordingly to work with more data set.

## `Input`

The input data is stored in the data folder, which contains zipped files. Our automated script processes these zip files to generate results. The following are the key input data folders and files used during the execution of the flaky test analysis:

- **`Flaky`**:  
  Contains the source code that includes the flaky test. 

- **`Fixed.patch`**:  
  A patch file used to generate the fixed version of the source code from the `Flaky` folder.

- **`FixedCodeChange.patch`**:  
  A patch file used to generate the fixed version with additional code changes from the `Flaky` folder.

- **`FlakyCodeChange.patch`**:  
  A patch file used to generate the flaky version with additional code changes from the `Flaky` folder. 

- **`Flakym2`**:  
  A directory used to store the `.m2` repository for maven dependencies during test execution. This ensures that the containerized environment can access required dependencies efficiently without re-downloading them for each run.

- **`Fixedm2`**:  
  A directory used to store the `.m2` repository for maven dependencies specific to the fixed version. If the dependencies for the fixed version are the same as those in `Flakym2`, this directory will not be present in the data directory, as `Flakym2` can handle Maven execution requirements.

## Output
After executing the script, the following outputs will be generated and stored as the `result` directory inside the corresponding `data` folder on the host machine. The results are organized into subdirectories based on the version codes: `Flaky`, `FlakyCodeChange`, `Fixed`, `FixedPassingOrder`, `FlakyPassingOrder`, and `FixedCodeChange`.

- **surefire-reports**:  
  Maven-generated reports containing detailed test execution logs. These include information about passed, failed, and errored test cases, along with stack traces and other debugging details.

- **rounds-test-results.csv**:  
  A CSV file summarizing the outcomes of all test iterations. It provides whether the test passes, failures, or has errors.

- **testlog**:  
  Log file capturing the output from each iteration as it appears in the terminal during test execution.

- **summary.txt**:  
  A text file summarizing key test metrics, such as total iterations, passes, failures, and errors.


## Important Folders and Files

The following are the key files for test analysis and in generating statistics:

- **`python-scripts/parse_surefire_report.py`**:  
  A python script that processes Maven Surefire XML reports to extract detailed test case results. It parses the report to identify the status of each test case (pass, failure, or error), along with execution time, and outputs the results in a structured format for further analysis.

- **`statistics_generator.sh (For timining dependent flaky test)`**:  
  A Bash script designed to automate the process of running a specified test iteratively, analyzing results, and generating comprehensive statistics for timing dependent flaky tests. The script is used by `flaky_analysis_tool_td.sh` and `flaky_analysis_tool_td_proto.sh`. It performs: 
  - Builds the project with Maven while skipping tests and unnecessary checks.
  - Executes the test for a given number of iterations (default: 100) and logs results for each run.
  - Uses the `parse_surefire_report.py` script to extract and format test results from Surefire XML reports.
  - Organizes logs and test result files into structured directories (`flaky-result`).
  - Calculates and summarizes the counts of test passes, failures, and errors in a summary file.
  - Saves the results in `rounds-test-results.csv` and outputs a summary to `flaky-result/summary.txt`.
  - To run timing dependent `SlowBookieTest#testSlowBookie` test in the `bookkeeper-server` module with 100 iterations for statistics_generator.sh run in your source code directory.

  ```bash
    chmod +x statistics_generator.sh
    ./statistics_generator.sh bookkeeper-server scripts org.apache.bookkeeper.client.SlowBookieTest#testSlowBookie 100
  ```

- **`od_statistics_generator.sh (For order-dependent flaky tests)`**:  
  A Bash script designed to analyze and generate statistics for order-dependent flaky tests by running a flaky test along with its preceding test in a specific order for multiple iterations. The script is used by `flaky_analysis_tool_od.sh`. It performs: 
  - Builds the Maven project with necessary options while skipping unnecessary checks.
  - Executes the specified tests (`precedingtest` and `flakytest`) in the desired order for a given number of iterations (default: 100).
  - Uses the `parse_surefire_report.py` script to process Surefire XML reports and extract detailed results for the flaky test.
  - Organizes logs, test results, and summaries into structured directories (`flaky-result`).
  - Outputs a summary of test passes, failures, and errors to `flaky-result/summary.txt`.

  - To run order dependent flaky test `testGetServerSideGroups`  that depends on running earler `testLogin` from class `TestUserGroupInformation` in the `hadoop-common-project/hadoop-common` module with 100 iterations for statistics_generator.sh run in your source code directory.

    ```bash
      chmod +x od_statistics_generator.sh
      ./od_statistics_generator.sh hadoop-common-project/hadoop-common org.apache.hadoop.security.TestUserGroupInformation#testGetServerSideGroups org.apache.hadoop.security.TestUserGroupInformation#testLogin 100
    ```
- **`Dockerfile`**:  
  A configuration file for building the Docker image used in flaky test analysis. It sets up a Java 8 and Maven environment, installs required dependencies (e.g., Python, BeautifulSoup, lxml), and defines a default command to run the `statistics_generator.sh` script, wwhich is available int the script repository. 

- **`Dockerfile.proto`**:  

  This `Dockerfile.proto` sets up a custom Docker image to add extended protobuf 2.5.0 dependency for hadoop project. It extends `flaky_base_jdk8` (Please see `flaky_analysis_tool.sh`) image based on `Dockerfile`.

- **`Dockerfile.id`**:  

   A configuration file for building the Docker image used in flaky test analysis for id-related flaky test to run with nondex plugin. It sets up a Java 11 and Maven environment, installs required dependencies (e.g., xmllint), and to run the `id_statistics_generator.sh` script, which is available int the script repository. 

- **`Dockerfilej.dk8id`**:  

  A configuration file for building the Docker image used in flaky test analysis for id-related flaky test to run with nondex plugin. It sets up a Java 8 and Maven environment, installs required dependencies (e.g., xmllint), and to run the `id_jdk8_statistics_generator.sh` script, which is available int the script repository. 

- **`Dockerfile.od`**:  

  A configuration file for building the Docker image used in flaky test analysis for od-related flaky test to run with custom surefire. It sets up a Java 8 and Maven environment with [custom surefire](https://github.com/TestingResearchIllinois/maven-surefire), installs required dependencies (e.g., Python, BeautifulSoup, lxml), and to run the `od_statistics_generator.sh` script, which is available int the script repository. 

- **`Dockerfile.odproto`**:  

   This `Dockerfile.odproto` sets up a custom Docker image to add extended protobuf 2.5.0 dependency for hadoop project. It extends `flaky_base_jdk8_od` (Please see `flaky_analysis_tool_od_proto`) image based on `Dockerfile.od`. 



- **`flaky_analysis_tool_td.sh`**:  
  A comprehensive script designed to execute and manage the analysis of a single timing dependent flaky test across various code versions within a Docker container:
  - Parameters for `flaky_analysis_tool_td.sh`
   - **`moduleName`**:  
     The relative path of the module from the root directory.  
     Example: `bookkeeper-server`.

     - **`fullQualifiedTest`**:  
     The fully qualified name of the test method.  
     Example: `org.apache.bookkeeper.client.SlowBookieTest#testSlowBookie`.

   - **`iteration`**:  
       The number of test iterations to run. Default is `100`, but you can adjust this based on your requirements. 

   - **`version_code (Optional)`**:  
      Specifies the code version to analyze. If you don't send any version code, then it will run for All. Allowed values include:
      - `All`
      - `Flaky`
      - `FlakyCodeChange`
      - `Fixed`
      - `FixedCodeChange`.
  - To run:
  ```bash
    chmod +x flaky_analysis_tool_td.sh
    ./flaky_analysis_tool_td.sh BOOKKEEPER-709 bookkeeper-server org.apache.bookkeeper.client.SlowBookieTest#testSlowBookie 100 All
 
  ```

- **`flaky_analysis_tool_td_proto.sh`**:  
  Its functionality is identical to `flaky_analysis_tool_td.sh`, but it also manages additional dependencies related to Protobuf using an extended Dockerfile, `Dockerfile.proto`

  - To run:
  ```bash
    chmod +x flaky_analysis_tool_td_proto.sh
    ./flaky_analysis_tool_td_proto.sh YARN-9405 hadoop-yarn-project/hadoop-yarn/hadoop-yarn-applications/hadoop-yarn-services/hadoop-yarn-services-core org.apache.hadoop.yarn.service.TestYarnNativeServices#testExpressUpgrade 100  All
 
  ```

- **`flaky_analysis_tool_od_proto.sh`**:  
  A comprehensive script designed to execute and manage the analysis of a single order-dependent flaky test across various code versions within a Docker container.

  -  Parameters for `flaky_analysis_tool_od_proto.sh`
  - **`moduleName`**:  
    The relative path of the module from the root directory.  
    Example: `bookkeeper-server`.

  - **`PRECEDING_TEST`**:  
    The fully qualified name of the test that must execute before the order-dependent flaky test to cause it to fail.

  - **`FLAKY_TEST`**:  
    The fully qualified name of the test that will execute as flaky if `PRECEDING_TEST` runs earlier.

  - **`iteration`**:  
    The number of test iterations to run. Default is `100`, but you can adjust this based on your requirements. 

  - **`version_code (Optional)`**:  
     Specifies the code version to analyze. If no version code is provided, it will execute for all versions. Allowed values include:  
    - `All`
    - `Flaky`:
    - `FixedPassingOrder`: Runs the tests on the fixed version of the code while reversing the test order.  
    - `Fixed`
    - `FlakyPassingOrder`: Runs the tests on the flaky version of the code while reversing the test order.  

   - To run:
  ```bash
    chmod +x flaky_analysis_tool_od.sh
    ./flaky_analysis_tool_od.sh HADOOP-10207 hadoop-common-project/hadoop-common org.apache.hadoop.security.   TestUserGroupInformation#testGetServerSideGroups org.apache.hadoop.security.TestUserGroupInformation#testLogin 100 All
 
  ```   

- **`test_config.csv`**:  
  This CSV files contains the meta data to run the tools, mainly used by `runner.sh`. It contains test type, test folder name inside `data` folder (mainly issue id), module, preceding_test (for od only), flaky_test, iterations, config (`All`, `Flaky`, `FixedPassingOrder`, `Fixed`, `FlakyPassingOrder`, `FlakyCodeChange`, `FixedCodeChange`)  
 
- **`runner.sh`**:   
 It works as wrapper to run appropriate flaky analysis tools based on the data it received from `test_config.csv`. It reads test configurations from the CSV file and runs the appropriate analysis tool based on the test type and module.


## To contribute for more test type

To add more test type like ID, Timezone or more, create corresponing statistics generator like `statistics_generator.sh` and flaky analysis tools like `flaky_analysis_tool_td.sh`. Also you might need extended docker file. Add corresponing test type in `test_config.csv` file and add corresponding changes in `runner.sh`. 
