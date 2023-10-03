#!/bin/bash

# Define log file and colors
SCRIPT_NAME=$(basename "$0")
LOG_FILE="${SCRIPT_NAME%.*}.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define log function
log_and_run() {
    echo -ne "${YELLOW}Running: ${NC}" >> $LOG_FILE
    echo "$@" >> $LOG_FILE
    eval "$@" >> $LOG_FILE 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error:${NC} $@"
        echo -e "${RED}Error encountered. Check $LOG_FILE for details.${NC}"
        exit 1
    fi
}

# Clear the log file
cat /dev/null > $LOG_FILE
echo -e "\nRunning ${YELLOW}${SCRIPT_NAME}${NC}."

# Get the tar file from the argument or search for the default in the current directory
TAR_FILE="${1:-$(ls Juniper_Cloud_Native_Router*gz | sort -V | tail -1)}"

# Check if the tar file exists
if [[ ! -f "$TAR_FILE" ]]; then
    echo -e "${RED}Error:$NC File $TAR_FILE does not exist." | tee -a $LOG_FILE
    echo "Please provide the path to the .tgz file as an argument or place it in the current directory." | tee -a $LOG_FILE
    exit 1
fi

echo -e "Found tar file: ${GREEN}${TAR_FILE}${NC}." | tee -a $LOG_FILE

# Extract the tar file to a temporary directory
JCNR_DIR="./"
echo -e "Extracting the file: ${GREEN}${TAR_FILE}${NC}." | tee -a $LOG_FILE
log_and_run "tar zxvf \"$TAR_FILE\" --overwrite -C \"$JCNR_DIR\""

# Find the Docker image file in the extracted contents
IMAGE_PATH=$(find "$JCNR_DIR" -name "jcnr-images.tar.gz" -type f | head -n 1)

# Check if the Docker image file was found
if [[ -z "$IMAGE_PATH" ]]; then
    echo -e "${RED}Error:${NC} Docker image file jcnr-images.tar.gz not found in the tar archive." | tee -a $LOG_FILE
    rm -rf "$JCNR_DIR"  # Clean up the temporary directory
    exit 2
fi

echo -e "Found Docker image file: ${GREEN}${IMAGE_PATH}${NC}." | tee -a $LOG_FILE

# Load the Docker image
echo -e "Loading Docker image: ${GREEN}${IMAGE_PATH}${NC}." | tee -a $LOG_FILE
log_and_run "docker load -i \"$IMAGE_PATH\""

echo -e "${GREEN}Docker image loaded successfully!${NC}" | tee -a $LOG_FILE
