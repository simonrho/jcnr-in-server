#!/bin/bash

# Define log file and colors
SCRIPT_NAME=$(basename "$0")
LOG_FILE="${SCRIPT_NAME%.*}.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

cat /dev/null > $LOG_FILE

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

# Default values
JCNR_LICENSE_KEY=""
JCNR_ROOT_PASSWORD=""

# Source the settings file if it exists
if [ -f "settings" ]; then
    source settings
fi


ROOT_PW_FILE="jcnr-root-password.txt"
LICENSE_FILE="jcnr-license.txt"

echo -e "\nRunning ${YELLOW}${SCRIPT_NAME}${NC}"

# Notify the user about the default files
echo -e "This script will attempt to obtain the license key and root password in the following order:"
echo -e "1. From variables in the ${GREEN}settings.sh${NC} file: ${GREEN}JCNR_LICENSE_KEY${NC} and ${GREEN}JCNR_ROOT_PASSWORD${NC}."
echo -e "2. From the default files if present:"
echo -e "   License File: ${GREEN}${LICENSE_FILE}${NC}"
echo -e "   Root Password File: ${GREEN}${ROOT_PW_FILE}${NC}"
echo -e "3. If neither of the above sources are found, you will be prompted for input."
echo -e "---------------------------------------"

# Function to silently get contents from file or write user input to an output file
get_input_or_prompt_to_file() {
    local prompt=$1
    local file=$2
    local outfile=$3
    local default_message=$4

    if [[ -f $file ]]; then
        echo -e "Reading $default_message from ${GREEN}$file${NC}."
        cp "$file" "$outfile"
    else
        read -sp "$prompt: " content
        echo "$content" > "$outfile"
    fi
}

# Function to get multi-line input until a delimiter (END) is detected, and write it to an output file
get_multiline_input_or_prompt_to_file() {
    local prompt=$1
    local file=$2
    local outfile=$3
    local default_message=$4

    if [[ -f $file ]]; then
        echo -e "Reading $default_message from ${GREEN}$file${NC}."
        cp "$file" "$outfile"
    else
        echo -e "$prompt (Type ${GREEN}'END'${NC} on a new line to finish):"
        local multi_line=""
        while IFS= read -r line; do
            [[ "$line" == "END" ]] && break
            multi_line="${multi_line}${line}"$'\n'
        done
        echo "$multi_line" > "$outfile"
    fi
}

# Function to build secrets YAML
build_secrets() {
    OUTPUT_FILE=./jcnr-secrets.yaml
    ROOT_PASSWORD_FILE=$1
    JCNR_LICENSE_FILE=$2

    # Get the base64 encoded values
    ENCODED_ROOT_PASSWORD=$(base64 -w 0 ${ROOT_PASSWORD_FILE})
    ENCODED_JCNR_LICENSE=$(base64 -w 0 ${JCNR_LICENSE_FILE})

    # Template string with replaced placeholders
    OUTPUT_STRING=$(cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: jcnr
---
apiVersion: v1
kind: Secret
metadata:
  name: jcnr-secrets
  namespace: jcnr
data:
  root-password: ${ENCODED_ROOT_PASSWORD}
  crpd-license: |
    ${ENCODED_JCNR_LICENSE}
EOF
    )

    # Writing the template to the output file
    echo "${OUTPUT_STRING}" > ${OUTPUT_FILE}
}


# Check if the JCNR_ROOT_PASSWORD and JCNR_LICENSE_KEY are set.
# If not, use the default files (if they exist) or prompt the user.
if [[ -z $JCNR_ROOT_PASSWORD ]]; then
    get_input_or_prompt_to_file "Enter root password" "${ROOT_PW_FILE}" "tmp-root-password.txt" "root password"
else
    echo -e "Reading root password from ${GREEN}settings file${NC}."
    echo "$JCNR_ROOT_PASSWORD" > "tmp-root-password.txt"
fi

if [[ -z $JCNR_LICENSE_KEY ]]; then
    get_multiline_input_or_prompt_to_file "Enter license key" "${LICENSE_FILE}" "tmp-license.txt" "license key"
else
    echo -e "Reading license key from ${GREEN}settings file${NC}."
    echo "$JCNR_LICENSE_KEY" > "tmp-license.txt"
fi

# Build jcnr-secrets.yaml file
echo -e "Creating ${GREEN}jcnr-secrets.yaml${NC} file."
build_secrets tmp-root-password.txt tmp-license.txt

# Cleanup temporary files
rm tmp-root-password.txt tmp-license.txt

# Apply JCNR secrets and namespace
echo -e "Applying JCNR ${GREEN}secrets${NC} and ${GREEN}namespace${NC}."
kubectl apply -f jcnr-secrets.yaml
if [ $? -ne 0 ]; then
    echo -e "${RED}Error applying jcnr-secrets.yaml. Exiting.${NC}"
    exit 1
fi

