#!/bin/bash

# Define log file and colors
SCRIPT_NAME=$(basename "$0")
LOG_FILE="${SCRIPT_NAME%.*}.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

echo -e "\nRunning ${YELLOW}${SCRIPT_NAME}${NC}"
echo -e "Logging install steps to ${YELLOW}$LOG_FILE${NC}"

install_common() {
  # Install kubectl
  if ! command -v kubectl &> /dev/null; then
    echo -e "Installing ${GREEN}kubectl${NC}..."
    log_and_run "sudo curl -sLO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    log_and_run "sudo chmod +x ./kubectl"
    log_and_run "sudo mv ./kubectl /usr/local/bin/kubectl"
  else
    echo -e "${YELLOW}kubectl${NC} is already installed."
  fi

  # Install Helm
  if ! command -v helm &> /dev/null; then
    echo -e "Installing ${GREEN}Helm${NC}..."
    log_and_run "sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
    log_and_run "sudo chmod 700 get_helm.sh"
    log_and_run "sudo ./get_helm.sh"
  else
    echo -e "${YELLOW}Helm${NC} is already installed."
  fi

  # Install k9s for Linux
  LATEST_K9S_TAG=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
  if ! command -v k9s &> /dev/null; then
    echo -e "Installing ${GREEN}k9s${NC}..."
    K9S_RELEASE_URL="https://github.com/derailed/k9s/releases/download/${LATEST_K9S_TAG}/k9s_Linux_amd64.tar.gz"
    log_and_run "curl -sL ${K9S_RELEASE_URL} | tar xvz -C /tmp/"
    log_and_run "sudo mv /tmp/k9s /usr/local/bin/"
    log_and_run "rm -rf /tmp/k9s*"
  else
    echo -e "${YELLOW}k9s${NC} is already at the latest version."
  fi
}

# macOS specific installations
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${GREEN}Detected macOS, installing tools...${NC}"
  log_and_run "brew install kubectl helm k9s"
elif command -v apt-get > /dev/null; then
  log_and_run "sudo apt-get update -qq"
  log_and_run "sudo apt-get install jq unzip -y -qq"
  install_common
elif command -v yum > /dev/null; then
  log_and_run "sudo yum update -y -q"
  log_and_run "sudo yum install jq -y -q"
  install_common
else
  echo -e "${RED}No known package manager found.${NC}"
  exit 1
fi

echo -e "${GREEN}All required tools are installed.${NC}"