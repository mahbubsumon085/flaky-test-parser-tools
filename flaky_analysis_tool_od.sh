#!/bin/bash

# Set default iteration count if not provided
TEST_FOLDER_NAME=$1
DATA_FOLDER=$2
MODULE=$3
PRECEDING_TEST=$4
FLAKY_TEST=$5
ITERATIONS=${6:-100} # Default to 100 iterations if not provided
CODE_VERSION=${7:-"All"} # New parameter: CodeVersion



BASE_DIR="data/${TEST_FOLDER_NAME}"
ZIP_DATA_CONTAINER="data/${DATA_FOLDER}"


# Unzip the data folder if it exists in zip format
if [ -f "${ZIP_DATA_CONTAINER}.zip" ]; then
    echo "Unzipping ${ZIP_DATA_CONTAINER}.zip into ${BASE_DIR}..."
    mkdir -p "${BASE_DIR}"
    unzip -o "${ZIP_DATA_CONTAINER}.zip" -d "${BASE_DIR}" > /dev/null || { echo "Failed to unzip ${ZIP_DATA_CONTAINER}.zip"; exit 1; }

    # Move extracted files from ${BASE_DIR}/${DATA_FOLDER} to ${BASE_DIR}, then remove the extra folder
    if [ -d "${BASE_DIR}/${DATA_FOLDER}" ]; then
        mv "${BASE_DIR}/${DATA_FOLDER}/"* "${BASE_DIR}/"
        rmdir "${BASE_DIR}/${DATA_FOLDER}"
    fi
fi

BASE_IMAGE_NAME="flaky_base_jdk8_od"
CONTAINER_NAME="container_hadoop_10207"
RESULT_DIR="${BASE_DIR}/result"

# Define constants for directories
FLAKY_DIR="${BASE_DIR}/Flaky"
FLAKY_M2_DIR="${BASE_DIR}/Flakym2/.m2"
FLAKY_CODE_CHANGE="${BASE_DIR}/FlakyCodeChange"
FIXED_DIR="${BASE_DIR}/Fixed"
FLAKY_PASSING_DIR="${BASE_DIR}/FlakyPssingOrder"
FIXED_PASSING_DIR="${BASE_DIR}/FixedPssingOrder"
FIXED_PATCH="${BASE_DIR}/Fixed.patch"

# Determine FIXED_M2_DIR based on the presence of Fixedm2 directory
if [ -d "${BASE_DIR}/Fixedm2" ]; then
    FIXED_M2_DIR="${BASE_DIR}/Fixedm2/.m2"
else
    FIXED_M2_DIR="${BASE_DIR}/Flakym2/.m2"
fi

# Check if Flaky folder exists and delete python-scripts
if [ -d "$FLAKY_DIR" ]; then
    echo "Checking for existing python-scripts in $FLAKY_DIR..."
    if [ -d "$FLAKY_DIR/python-scripts" ]; then
        echo "Deleting existing scripts directory from $FLAKY_DIR..."
        rm -rf "$FLAKY_DIR/python-scripts" || { echo "Failed to delete python-scripts directory"; exit 1; }
    else
        echo "No scripts directory found in $FLAKY_DIR."
    fi

    echo "Copying Python scripts to $FLAKY_DIR..."
    cp -r python-scripts "$FLAKY_DIR/" || { echo "Failed to copy Python scripts"; exit 1; }
    cp od_statistics_generator.sh "$FLAKY_DIR/" || { echo "Failed to copy od_statistics_generator.sh"; exit 1; }
else
    echo "Flaky folder does not exist. Skipping python-scripts deletion and cloning."
    exit 1
fi



# Function to apply patch files and create new folders
create_folder_with_patch() {
    BASE_DIR=$1
    PATCH_FILE=$2
    TARGET_DIR=$3
    
    echo "Creating folder: $TARGET_DIR using patch: $PATCH_FILE..."
    rm -rf "$TARGET_DIR"  # Remove existing directory if it exists
    echo "Creating folder: 1111"
    cp -r "$BASE_DIR" "$TARGET_DIR" || { echo "Failed to copy $BASE_DIR to $TARGET_DIR"; exit 1; }
    echo "Creating folder: 222222"
    patch -p1 -d "$TARGET_DIR" < "$PATCH_FILE" || { echo "Failed to apply patch $PATCH_FILE to $TARGET_DIR"; exit 1; }
    echo "Creating folder: 3333333"
    echo "Successfully created $TARGET_DIR."
}


if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "Fixed" ]]; then
    if [[ ! -d "$FIXED_DIR" ]]; then
     rm -rf "$FIXED_DIR"  # Remove the existing directory if it exists
        create_folder_with_patch "$FLAKY_DIR" "$FIXED_PATCH" "$FIXED_DIR"
    fi
fi

if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "FlakyPssingOrder" ]]; then
    if [[ ! -d "$FLAKY_PASSING_DIR" ]]; then
        echo "Creating $FLAKY_PASSING_DIR by copying from $FLAKY_DIR..."
        rm -rf "$FLAKY_PASSING_DIR"  # Remove the existing directory if it exists
        cp -r "$FLAKY_DIR" "$FLAKY_PASSING_DIR" || { echo "Failed to copy $FLAKY_DIR to $FLAKY_PASSING_DIR"; exit 1; }
        echo "Successfully created $FLAKY_PASSING_DIR by copying."
    fi
fi


if [[ "$CODE_VERSION" == "All" || "$CODE_VERSION" == "FixedPssingOrder" ]]; then
    if [[ ! -d "$FIXED_PASSING_DIR" ]]; then
     rm -rf "$FIXED_PASSING_DIR"  # Remove the existing directory if it exists
        create_folder_with_patch "$FLAKY_DIR" "$FIXED_PATCH" "$FIXED_PASSING_DIR"
    fi
fi

# Delete the result folder if it exists
if [ -d "$RESULT_DIR" ]; then
    echo "Deleting the existing result folder..."
    rm -rf "$RESULT_DIR"
fi

# Step 1: Build the base image if not present
if ! docker images | grep -q "$BASE_IMAGE_NAME"; then
    echo "Docker image $BASE_IMAGE_NAME not found. Building it using Dockerfile..."
    docker build -t $BASE_IMAGE_NAME -f Dockerfile.od .
fi



# Ensure the result directory exists and clean up any initial module folder
mkdir -p "$RESULT_DIR"
rm -rf "$RESULT_DIR/$MODULE"  # Remove any folder with the module name if it exists

# Determine which versions to process based on CodeVersion
SOURCE_DIRS=()
M2_DIRS=()
case "$CODE_VERSION" in
    "All")
        SOURCE_DIRS=("$FLAKY_DIR" "$FIXED_DIR" "$FLAKY_PASSING_DIR" "$FIXED_PASSING_DIR")
        M2_DIRS=("$FLAKY_M2_DIR" "$FIXED_M2_DIR" "$FLAKY_M2_DIR" "$FLAKY_M2_DIR")
        PRECEDING_TESTS=("$PRECEDING_TEST" "$PRECEDING_TEST" "$FLAKY_TEST" "$FLAKY_TEST")
        FLAKY_TESTS=("$FLAKY_TEST" "$FLAKY_TEST" "$PRECEDING_TEST" "$PRECEDING_TEST")
        ;;

    "FlakyPssingOrder")
        if [ -d "$FLAKY_PASSING_DIR" ]; then
            SOURCE_DIRS=("$FLAKY_PASSING_DIR")
            M2_DIRS=("$FLAKY_M2_DIR")
            PRECEDING_TESTS=("$FLAKY_TEST")
            FLAKY_TESTS=("$PRECEDING_TEST")
        else
            echo "Flaky version directory is not present. Exiting."
            exit 1
        fi
        ;;

     "FixedPssingOrder")
        if [ -d "$FIXED_PASSING_DIR" ]; then
            SOURCE_DIRS=("$FIXED_PASSING_DIR")
            M2_DIRS=("$FLAKY_M2_DIR")
            PRECEDING_TESTS=("$FLAKY_TEST")
            FLAKY_TESTS=("$PRECEDING_TEST")
        else
            echo "Flaky version directory is not present. Exiting."
            exit 1
        fi
        ;;


    "Flaky")
        if [ -d "$FLAKY_DIR" ]; then
            SOURCE_DIRS=("$FLAKY_DIR")
            M2_DIRS=("$FLAKY_M2_DIR")
            PRECEDING_TESTS=("$PRECEDING_TEST")
            FLAKY_TESTS=("$FLAKY_TEST")
        else
            echo "Flaky version directory is not present. Exiting."
            exit 1
        fi
        ;;
    "Fixed")
        if [ -d "$FIXED_DIR" ]; then
            SOURCE_DIRS=("$FIXED_DIR")
            M2_DIRS=("$FIXED_M2_DIR")
            PRECEDING_TESTS=("$PRECEDING_TEST")
            FLAKY_TESTS=("$FLAKY_TEST")
        else
            echo "Fixed version directory is not present. Exiting."
            exit 1
        fi
        ;;
    *)
        echo "Invalid CodeVersion specified. Use one of: All, Flaky, FlakyCodeChange, Fixed, FixedCodeChange."
        exit 1
        ;;
esac

# Loop through each source and m2 directory
for i in "${!SOURCE_DIRS[@]}"; do
    SRC_DIR="${SOURCE_DIRS[$i]}"
    M2_DIR="${M2_DIRS[$i]}"
    CURRENT_PRECEDING_TEST="${PRECEDING_TESTS[$i]}"
    CURRENT_FLAKY_TEST="${FLAKY_TESTS[$i]}"

    # Extract a clean directory name from SRC_DIR to use for the result folder
    DIR_NAME=$(basename "$SRC_DIR")
    FLAKY_RESULT_DIR="$RESULT_DIR/$DIR_NAME"

    # Step 3: Run the container in detached mode with necessary environment variables
    echo "Starting the container in detached mode for source $SRC_DIR and m2 $M2_DIR..."
    docker run -d --name $CONTAINER_NAME \
        -e MODULE="$MODULE" \
        -e PRECEDING_TEST="$CURRENT_PRECEDING_TEST" \
        -e FLAKY_TEST="$CURRENT_FLAKY_TEST" \
        -e ITERATIONS="$ITERATIONS" \
        $BASE_IMAGE_NAME tail -f /dev/null

    # Step 4: Copy the source and m2 directories from the host to the container
    echo "Copying $SRC_DIR and $M2_DIR into the container..."
    docker cp "$SRC_DIR" "$CONTAINER_NAME:/app/source"
    docker cp "$M2_DIR" "$CONTAINER_NAME:/app/m2_temp"
    docker exec $CONTAINER_NAME /bin/bash -c "mkdir -p /root/.m2 && cp -r /app/m2_temp/. /root/.m2 && rm -rf /app/m2_temp"

    # Step 5: Run the OD statistics generator script inside the container
    echo "Executing the od_statistics_generator.sh script inside the container..."

    docker exec -it $CONTAINER_NAME /bin/bash -c "cd /app/source && chmod +x od_statistics_generator.sh && ./od_statistics_generator.sh \"$MODULE\" \"$CURRENT_PRECEDING_TEST\" \"$CURRENT_FLAKY_TEST\" \"$ITERATIONS\""

    # Step 6: Copy the flaky-result folder's content from the container to the host and rename it
    echo "Preparing to copy flaky-result folder content from container to host for $SRC_DIR..."
    mkdir -p "$FLAKY_RESULT_DIR"
    docker cp "$CONTAINER_NAME:/app/source/flaky-result/." "$FLAKY_RESULT_DIR"
    
    echo "flaky-result folder content successfully copied to '$FLAKY_RESULT_DIR' in the 'result' directory."

    # Step 7: Stop and remove the container before the next iteration
    echo "Cleaning up: stopping and removing the container..."
    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME

       # Step 8: Delete the folder if it is not Flaky
    if [[ "$SRC_DIR" != "$FLAKY_DIR" ]]; then
        echo "Deleting the folder: $SRC_DIR..."
        rm -rf "$SRC_DIR"
    else
        echo "Skipping deletion for Flaky folder."
    fi
done

echo "Process completed for all sources."
