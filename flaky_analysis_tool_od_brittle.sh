#!/bin/bash

# Usage: ./flaky_analysis_tool_od_brittle_final.sh <TestFolderName> <DataFolder> <Module> <PrecedingTest> <BrittleTest> [Iterations] [CodeVersion]

TEST_FOLDER_NAME=$1
DATA_FOLDER=$2
MODULE=$3
PRECEDING_TEST=$4
BRITTLE_TEST=$5
ITERATIONS=${6:-100}
CODE_VERSION=${7:-"All"}

BASE_DIR="data/${TEST_FOLDER_NAME}"
ZIP_DATA_CONTAINER="data/${DATA_FOLDER}"
RESULT_DIR="${BASE_DIR}/result"

FLAKY_DIR="${BASE_DIR}/Flaky"
FIXED_DIR="${BASE_DIR}/Fixed"
FLAKY_PASSING_DIR="${BASE_DIR}/FlakyPssingOrder"
FIXED_PASSING_DIR="${BASE_DIR}/FixedPssingOrder"

FLAKY_M2_DIR="${BASE_DIR}/Flakym2/.m2"
if [ -d "${BASE_DIR}/Fixedm2" ]; then
    FIXED_M2_DIR="${BASE_DIR}/Fixedm2/.m2"
else
    FIXED_M2_DIR="${BASE_DIR}/Flakym2/.m2"
fi

BASE_IMAGE_NAME="flaky_base_jdk8_od"
CONTAINER_NAME="container_od_brittle"

# Unzip if necessary
if [ -f "${ZIP_DATA_CONTAINER}.zip" ]; then
    echo "Unzipping ${ZIP_DATA_CONTAINER}.zip..."
    mkdir -p "${BASE_DIR}"
    unzip -o "${ZIP_DATA_CONTAINER}.zip" -d "${BASE_DIR}" > /dev/null || { echo "Failed to unzip"; exit 1; }
    if [ -d "${BASE_DIR}/${DATA_FOLDER}" ]; then
        mv "${BASE_DIR}/${DATA_FOLDER}/"* "${BASE_DIR}/"
        rmdir "${BASE_DIR}/${DATA_FOLDER}"
    fi
fi

# Setup Flaky dir
if [ -d "$FLAKY_DIR" ]; then
    [ -d "$FLAKY_DIR/python-scripts" ] && rm -rf "$FLAKY_DIR/python-scripts"
    cp -r python-scripts "$FLAKY_DIR/"
    cp od_statistics_generator.sh "$FLAKY_DIR/"
else
    echo "Flaky directory not found. Exiting."
    exit 1
fi

[ -d "$RESULT_DIR" ] && rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"
rm -rf "$RESULT_DIR/$MODULE"

if ! docker images | grep -q "$BASE_IMAGE_NAME"; then
    docker build -t $BASE_IMAGE_NAME -f Dockerfile.od .
fi

SOURCE_DIRS=()
M2_DIRS=()
PRECEDING_TESTS=()
BRITTLE_TESTS=()
SINGLE_TEST_MODE=()

case "$CODE_VERSION" in
    "All")
        SOURCE_DIRS=("$FLAKY_DIR" "$FIXED_DIR" "$FLAKY_PASSING_DIR" "$FIXED_PASSING_DIR")
        M2_DIRS=("$FLAKY_M2_DIR" "$FIXED_M2_DIR" "$FLAKY_M2_DIR" "$FLAKY_M2_DIR")
        PRECEDING_TESTS=("" "" "$PRECEDING_TEST" "$PRECEDING_TEST")
        BRITTLE_TESTS=("$BRITTLE_TEST" "$BRITTLE_TEST" "$BRITTLE_TEST" "$BRITTLE_TEST")
        SINGLE_TEST_MODE=("true" "true" "false" "false")
        ;;
    "Flaky")
        SOURCE_DIRS=("$FLAKY_DIR")
        M2_DIRS=("$FLAKY_M2_DIR")
        PRECEDING_TESTS=("")
        BRITTLE_TESTS=("$BRITTLE_TEST")
        SINGLE_TEST_MODE=("true")
        ;;
    "Fixed")
        SOURCE_DIRS=("$FIXED_DIR")
        M2_DIRS=("$FIXED_M2_DIR")
        PRECEDING_TESTS=("")
        BRITTLE_TESTS=("$BRITTLE_TEST")
        SINGLE_TEST_MODE=("true")
        ;;
    "FlakyPssingOrder")
        SOURCE_DIRS=("$FLAKY_PASSING_DIR")
        M2_DIRS=("$FLAKY_M2_DIR")
        PRECEDING_TESTS=("$PRECEDING_TEST")
        BRITTLE_TESTS=("$BRITTLE_TEST")
        SINGLE_TEST_MODE=("false")
        ;;
    "FixedPssingOrder")
        SOURCE_DIRS=("$FIXED_PASSING_DIR")
        M2_DIRS=("$FLAKY_M2_DIR")
        PRECEDING_TESTS=("$PRECEDING_TEST")
        BRITTLE_TESTS=("$BRITTLE_TEST")
        SINGLE_TEST_MODE=("false")
        ;;
    *)
        echo "Invalid CodeVersion specified. Use: Flaky, Fixed, FlakyPssingOrder, FixedPssingOrder"
        exit 1
        ;;
esac

for i in "${!SOURCE_DIRS[@]}"; do
    SRC_DIR="${SOURCE_DIRS[$i]}"
    M2_DIR="${M2_DIRS[$i]}"
    CUR_PRECEDING="${PRECEDING_TESTS[$i]}"
    CUR_BRITTLE="${BRITTLE_TESTS[$i]}"
    USE_SINGLE_TEST="${SINGLE_TEST_MODE[$i]}"
    DIR_NAME=$(basename "$SRC_DIR")
    RESULT_SUBDIR="$RESULT_DIR/$DIR_NAME"

    docker run -d --name $CONTAINER_NAME \
        -e MODULE="$MODULE" \
        -e PRECEDING_TEST="${USE_SINGLE_TEST:+$CUR_BRITTLE}${USE_SINGLE_TEST:+"$CUR_PRECEDING"}" \
        -e FLAKY_TEST="$CUR_BRITTLE" \
        -e ITERATIONS="$ITERATIONS" \
        $BASE_IMAGE_NAME tail -f /dev/null

    docker cp "$SRC_DIR" "$CONTAINER_NAME:/app/source"
    docker cp "$M2_DIR" "$CONTAINER_NAME:/app/m2_temp"
    docker exec $CONTAINER_NAME bash -c "mkdir -p /root/.m2 && cp -r /app/m2_temp/. /root/.m2 && rm -rf /app/m2_temp"

    docker exec -it $CONTAINER_NAME bash -c "cd /app/source && chmod +x od_statistics_generator.sh && ./od_statistics_generator.sh \"$MODULE\" \"${USE_SINGLE_TEST:+$CUR_BRITTLE}${USE_SINGLE_TEST:+"$CUR_PRECEDING"}\" \"$CUR_BRITTLE\" \"$ITERATIONS\""

    mkdir -p "$RESULT_SUBDIR"
    docker cp "$CONTAINER_NAME:/app/source/flaky-result/." "$RESULT_SUBDIR"

    docker stop $CONTAINER_NAME
    docker rm $CONTAINER_NAME

    [[ "$SRC_DIR" != "$FLAKY_DIR" ]] && rm -rf "$SRC_DIR"
done

echo "✅ Final OD Brittle script completed."
