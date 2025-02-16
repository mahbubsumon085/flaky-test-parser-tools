#!/bin/bash

# Set default iteration count if not provided
DATA_FOLDER=$1
MODULE=$2
FULL_TEST_NAME=$3
ITERATIONS=${4:-5}
CODE_VERSION=${5:-"All"} # New parameter: CodeVersion
# Docker and container related variables

BASE_IMAGE_NAME="flaky_base_jdk8_new"
PROTO_IMAGE_NAME="flaky_proto_od_jdk8_new" # Image built from Dockerfile.proto
CONTAINER_NAME="container_yarn_9407"
DIR_TO_PYTHON_SCRIPT="/app/source"

# Define constants for directories

# Define base directory path
BASE_DIR="data/${DATA_FOLDER}"

# Unzip the data folder if it exists in zip format
if [ -f "${BASE_DIR}.zip" ]; then
    echo "Unzipping ${BASE_DIR}.zip..."
    unzip -o "${BASE_DIR}.zip" -d "data/" || { echo "Failed to unzip ${BASE_DIR}.zip"; exit 1; }
fi


# Define constants for directories and patch files
FLAKY_DIR="${BASE_DIR}/Flaky"
FLAKY_M2_DIR="${BASE_DIR}/Flakym2/.m2"
FLAKY_CODE_CHANGE_DIR="${BASE_DIR}/FlakyCodeChange"
FIXED_DIR="${BASE_DIR}/Fixed"
FIXED_CODE_CHANGE_DIR="${BASE_DIR}/FixedCodeChange"
FLAKY_CODE_CHANGE_PATCH="${BASE_DIR}/FlakyCodeChange.patch"
FIXED_PATCH="${BASE_DIR}/Fixed.patch"
FIXED_CODE_CHANGE_PATCH="${BASE_DIR}/FixedCodeChange.patch"
RESULT_DIR="${BASE_DIR}/result"

# Determine FIXED_M2_DIR based on the presence of Fixedm2 directory
if [ -d "${BASE_DIR}/Fixedm2" ]; then
    FIXED_M2_DIR="${BASE_DIR}/Fixedm2/.m2"
else
    FIXED_M2_DIR="${BASE_DIR}/Flakym2/.m2"
fi

# Check if Flaky folder exists and delete scripts
if [ -d "$FLAKY_DIR" ]; then
    echo "Checking for existing Python scripts in $FLAKY_DIR..."
    if [ -d "$FLAKY_DIR/python-scripts" ]; then
        echo "Deleting existing scripts directory from $FLAKY_DIR..."
        rm -rf "$FLAKY_DIR/python-scripts" || { echo "Failed to delete scripts directory";  }
    else
        echo "No scripts directory found in $FLAKY_DIR."
    fi
    echo "Copying Python scripts to $FLAKY_DIR..."
    cp -r python-scripts "$FLAKY_DIR/" || { echo "Failed to copy Python scripts"; exit 1; }
    cp statistics_generator.sh "$FLAKY_DIR/" || { echo "Failed to copy statistics_generator.sh"; exit 1; }
else
    echo "Flaky folder does not exist. Skipping scripts deletion and cloning."
    sleep 5
  #  exit 1
fi
# Function to apply patch files and create new folders
create_folder_with_patch() {
    BASE_DIR=$1
    PATCH_FILE=$2
    TARGET_DIR=$3
    
    echo "Creating folder: $TARGET_DIR using patch: $PATCH_FILE..."
    rm -rf "$TARGET_DIR"  # Remove existing directory if it exists
    cp -r "$BASE_DIR" "$TARGET_DIR" || { echo "Failed to copy $BASE_DIR to $TARGET_DIR";  }
    patch -p1 -d "$TARGET_DIR" < "$PATCH_FILE" || { echo "Failed to apply patch $PATCH_FILE to $TARGET_DIR"; }
    echo "Successfully created $TARGET_DIR."
}

# Ensure necessary directories are created
if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "FlakyCodeChange" ]]; then
    if [[ ! -d "$FLAKY_CODE_CHANGE_DIR" ]]; then
        create_folder_with_patch "$FLAKY_DIR" "$FLAKY_CODE_CHANGE_PATCH" "$FLAKY_CODE_CHANGE_DIR"
    fi
fi

if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "Fixed" ]]; then
    if [[ ! -d "$FIXED_DIR" ]]; then
        create_folder_with_patch "$FLAKY_DIR" "$FIXED_PATCH" "$FIXED_DIR"
    fi
fi

if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "FixedCodeChange" ]]; then
    if [[ ! -d "$FIXED_CODE_CHANGE_DIR" ]]; then
        create_folder_with_patch "$FLAKY_DIR" "$FIXED_CODE_CHANGE_PATCH" "$FIXED_CODE_CHANGE_DIR"
    fi
fi

# Determine which versions to process based on CodeVersion
SOURCE_DIRS=()
M2_DIRS=()

case "$CODE_VERSION" in
    "All")
        SOURCE_DIRS=("$FLAKY_DIR" "$FLAKY_CODE_CHANGE_DIR" "$FIXED_DIR" "$FIXED_CODE_CHANGE_DIR")
        M2_DIRS=("$FLAKY_M2_DIR" "$FLAKY_M2_DIR" "$FIXED_M2_DIR" "$FIXED_M2_DIR")
        ;;
    "Flaky")
        SOURCE_DIRS=("$FLAKY_DIR")
        M2_DIRS=("$FLAKY_M2_DIR")
        ;;
    "FlakyCodeChange")
        SOURCE_DIRS=("$FLAKY_CODE_CHANGE_DIR")
        M2_DIRS=("$FLAKY_M2_DIR")
        ;;
    "Fixed")
        SOURCE_DIRS=("$FIXED_DIR")
        M2_DIRS=("$FIXED_M2_DIR")
        ;;
    "FixedCodeChange")
        SOURCE_DIRS=("$FIXED_CODE_CHANGE_DIR")
        M2_DIRS=("$FIXED_M2_DIR")
        ;;
    *)
        echo "Invalid CodeVersion specified. Use one of: All, Flaky, FlakyCodeChange, Fixed, FixedCodeChange."
        sleep 5

     #   exit 1
        ;;
esac


# Delete the result folder if it exists
if [ -d "$RESULT_DIR" ]; then
    echo "Deleting the existing result folder..."
    rm -rf "$RESULT_DIR"
fi
# Ensure the result directory exists and clean up any initial module folder
mkdir -p "$RESULT_DIR"
rm -rf "$RESULT_DIR/$MODULE"  # Remove any folder with the module name if it exists

# Step 1: Build the Docker image
# Step 1: Build the base image if not present
if ! docker images | grep -q "$BASE_IMAGE_NAME"; then
    echo "Docker image $BASE_IMAGE_NAME not found. Building it using Dockerfile..."
    docker build -t $BASE_IMAGE_NAME -f Dockerfile .
fi

# Step 2: Build the proto image if not present
if ! docker images | grep -q "$PROTO_IMAGE_NAME"; then
    echo "Docker image $PROTO_IMAGE_NAME not found. Building it using Dockerfile.proto..."
    docker build -t $PROTO_IMAGE_NAME -f Dockerfile.proto .
fi

# Process each source and `.m2` directory
for i in "${!SOURCE_DIRS[@]}"; do
    SRC_DIR="${SOURCE_DIRS[$i]}"
    M2_DIR="${M2_DIRS[$i]}"
    DIR_NAME=$(basename "$SRC_DIR")
    FLAKY_RESULT_DIR="$RESULT_DIR/$DIR_NAME"

    # Step 2: Run the container
    echo "Starting the container for source: $SRC_DIR and m2: $M2_DIR..."
    docker run -d --name $CONTAINER_NAME \
        -e MODULE="$MODULE" \
        -e DIR_TO_PYTHON_SCRIPT="$DIR_TO_PYTHON_SCRIPT" \
        -e FULL_TEST_NAME="$FULL_TEST_NAME" \
        -e ITERATIONS="$ITERATIONS" \
        $PROTO_IMAGE_NAME tail -f /dev/null


    # Step 3: Copy the source and `.m2` directories into the container
    echo "Copying $SRC_DIR and $M2_DIR into the container..."
    docker cp "$SRC_DIR" "$CONTAINER_NAME:/app/source"
    docker cp "$M2_DIR" "$CONTAINER_NAME:/app/m2_temp"
    docker exec $CONTAINER_NAME /bin/bash -c "mkdir -p /root/.m2 && cp -r /app/m2_temp/. /root/.m2 && rm -rf /app/m2_temp"

    # Step 4: Run the statistics generator script inside the container
    echo "Running the statistics generator script..."
    docker exec -it $CONTAINER_NAME /bin/bash -c "cd /app/source && chmod +x statistics_generator.sh && ./statistics_generator.sh \"$MODULE\" \"$DIR_TO_PYTHON_SCRIPT\" \"$FULL_TEST_NAME\" \"$ITERATIONS\""

    # Step 5: Copy results back to the host
    echo "Copying results from container to $FLAKY_RESULT_DIR..."
    mkdir -p "$FLAKY_RESULT_DIR"
    docker cp "$CONTAINER_NAME:/app/source/flaky-result/." "$FLAKY_RESULT_DIR"
    
       # Step 6: Copy the `.m2` directory back from the container
    echo "Copying .m2 directory from container to $M2_RESULT_DIR..."

    docker cp "$CONTAINER_NAME:/root/.m2/." "$FLAKY_RESULT_DIR"

    # Step 6: Stop and remove the container
    echo "Stopping and removing the container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME

    # Step 7: Delete the folder if it is not Flaky
    if [[ "$SRC_DIR" != "$FLAKY_DIR" ]]; then
        echo "Deleting the folder: $SRC_DIR..."
        rm -rf "$SRC_DIR"
    else
        echo "Skipping deletion for Flaky folder."
    fi
done

echo "Process completed for all sources."
