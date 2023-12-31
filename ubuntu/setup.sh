#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPTS_DIR=./scripts

run_script() {
    $1
    exit_code=$?
    if [[ $exit_code -eq 100 ]]; then
        # Rebooting system exit code
        exit 0
    elif [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}setup: Error executing $1. Exiting setup. exit code $exit_code.${NC}"
        exit 1
    fi
}

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as${NC} ${YELLOW}root${NC}.\n"
   exit 1
fi

run_script $SCRIPTS_DIR/install-dpdk-env.sh
run_script $SCRIPTS_DIR/install-k8s.sh
run_script $SCRIPTS_DIR/install-tools.sh
run_script $SCRIPTS_DIR/load-jcnr-images.sh
run_script $SCRIPTS_DIR/create-jcnr-secrets.sh
run_script $SCRIPTS_DIR/create-label-update-values.sh

read -t 30 -p "Do you want to install JCNR with the auto-configured values.yaml file? (y/N): (You have 30 seconds to respond. Default is N): " CONFIRM
CONFIRM=${CONFIRM:-N}

if [[ "$CONFIRM" == [nN] ]]; then
    echo -e "${GREEN}Navigate to JCNR helm chart directory and edit the values.yaml file.${NC}"
else
    if helm ls -A | grep -q jcnr; then
        echo -e "${GREEN}jcnr${NC} ${RED}Helm chart has been previously installed.${NC}"
        echo -e "Not installing ${GREEN}jcnr${NC} again..."
    else
        echo -e "${GREEN}Navigate to JCNR helm chart directory and helm install jcnr.${NC}"
        cd Juniper_Cloud_Native_Router*/helmchart
        helm install jcnr .
    fi
fi
