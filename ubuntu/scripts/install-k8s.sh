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


echo -e "\nRunning ${YELLOW}${SCRIPT_NAME}${NC}."
echo -e "Logging install steps to ${YELLOW}$LOG_FILE${NC}."

# Default values
K8S_VERSION="latest"

# Source the settings file if it exists
if [ -f "settings" ]; then
    source settings
fi

log_and_run sudo apt-get update -y
log_and_run sudo apt-get install -y jq unzip socat

echo -e "Installing ${GREEN}Docker${NC}..."
log_and_run sudo apt-get install -y apt-transport-https curl software-properties-common
log_and_run "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg"

log_and_run sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
log_and_run sudo apt-get update -y
log_and_run sudo apt-get install -y docker-ce
log_and_run sudo usermod -aG docker ${USER}


echo -e "Installing ${GREEN}cri-dockerd${NC}..."
UBUNTU_CODENAME=$(lsb_release -cs)
if [ -z "$UBUNTU_CODENAME" ]; then
    echo "Failed to detect the Ubuntu codename!"
    exit 1
fi
# Fetch the release URL matching the detected codename
LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest | jq -r ".assets[] | select(.name | test(\"$UBUNTU_CODENAME.*amd64.deb\")) | .browser_download_url")
if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "Failed to fetch the release for $UBUNTU_CODENAME!"
    exit 1
fi
FILENAME=$(basename "$LATEST_RELEASE_URL")
log_and_run sudo wget -q "$LATEST_RELEASE_URL"
log_and_run sudo dpkg -i "$FILENAME"
log_and_run sudo rm "$FILENAME"


echo -e "Installing ${GREEN}crictl${NC}..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/cri-tools/releases/latest | jq -r ".tag_name")
URL="https://github.com/kubernetes-sigs/cri-tools/releases/download/${LATEST_VERSION}/crictl-${LATEST_VERSION}-linux-amd64.tar.gz"
log_and_run "sudo curl -sL $URL | sudo tar zx -C /usr/local/bin"

echo -e "Installing ${GREEN}CNI plugins${NC}..."
log_and_run sudo mkdir -p /etc/cni/net.d
log_and_run sudo mkdir -p /opt/cni/bin
LATEST_VERSION=$(curl --silent "https://api.github.com/repos/containernetworking/plugins/releases/latest" | jq -r .tag_name)
log_and_run sudo wget -q https://github.com/containernetworking/plugins/releases/download/${LATEST_VERSION}/cni-plugins-linux-amd64-${LATEST_VERSION}.tgz
log_and_run sudo tar -xf cni-plugins-linux-amd64-${LATEST_VERSION}.tgz -C /opt/cni/bin/
log_and_run sudo rm cni-plugins-linux-amd64-${LATEST_VERSION}.tgz 

echo -e "Installing ${GREEN}minikube${NC}... k8s version: ${GREEN}${K8S_VERSION}${NC}"
log_and_run apt-get install conntrack -y
log_and_run sudo modprobe bridge
log_and_run sudo modprobe br_netfilter
if [[ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]]; then
    log_and_run "echo 1 | sudo tee /proc/sys/net/bridge/bridge-nf-call-iptables"
fi
log_and_run curl -sLo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
log_and_run chmod +x minikube
log_and_run sudo mv minikube /usr/local/bin/
log_and_run "sudo minikube start --driver=none --cni=${K8S_CNI} --kubernetes-version=${K8S_VERSION}"

echo -e "Create ${GREEN}/usr/local/bin/kubectl${NC} soft-link..."
log_and_run sudo ln -f -s ~/.minikube/cache/linux/amd64/v*/kubectl /usr/local/bin/kubectl

echo -e "Installing ${GREEN}multus cni${NC}..."
log_and_run sudo kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset.yml

echo -e "${GREEN}Installation completed. Check $LOG_FILE for detailed logs.${NC}"
