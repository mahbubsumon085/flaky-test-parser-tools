#!/bin/bash

# Define variables
REPO_URL="https://github.com/mahbubsumon085/flaky-test-dataset.git"
FILE_PATH="BOOKKEEPER-709.zip"  # Path relative to the repo root
DEST_DIR="data"

echo "Creating destination directory: $DEST_DIR"
mkdir -p "$DEST_DIR"

echo "Cloning the repository sparsely (without history and unnecessary files)..."
git clone --depth 1 --filter=blob:none --sparse "$REPO_URL" repo-temp

echo "Moving into the repository directory..."
cd repo-temp || { echo "Failed to enter repo-temp directory"; exit 1; }

echo "Setting up sparse-checkout to include only the file: $FILE_PATH"
git sparse-checkout set "$FILE_PATH"

echo "Checking out the required file..."
git checkout

echo "Pulling actual content from Git LFS..."
git lfs pull

echo "Moving the file to the destination directory: $DEST_DIR"
mv "$FILE_PATH" "../$DEST_DIR/"

echo "Returning to the original directory..."
cd .. || { echo "Failed to return to original directory"; exit 1; }

echo "Cleaning up temporary repo..."
rm -rf repo-temp

echo "Download complete: $DEST_DIR/$FILE_PATH"
 curl -L -o BOOKKEEPER-709.zip https://github.com/mahbubsumon085/flaky-test-dataset/raw/master/BOOKKEEPER-709.zip
