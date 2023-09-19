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

FLAG_FILE="/var/tmp/install-dpdk-env-once"

# Check if script has been run post-reboot
if [[ -f "$FLAG_FILE" ]] && grep -q "default_hugepagesz=1G" /proc/cmdline; then
    echo -e "${RED}This script has previously been executed and the system rebooted.${NC}"    
    exit 0
fi

echo -e "\nRunning ${YELLOW}${SCRIPT_NAME}${NC}."
echo -e "Logging install steps to ${YELLOW}$LOG_FILE${NC}."

# Default values
ONEG_HUGEPAGES=16

# Source the settings file if it exists
if [ -f "settings" ]; then
    source settings
fi

# Check the distribution from /etc/os-release
DISTRO=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
if [[ "$DISTRO" != "ubuntu" ]]; then
    echo "This script is intended only for Ubuntu systems."
    exit 1
fi

# Discover the default interface (used for routing to the default gateway)
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}')

# Create a function to generate Netplan config for an interface
generate_netplan_config() {
    local iface="$1"
    cat <<EOL
network:
  version: 2
  ethernets:
    $iface:
      dhcp4: yes
      dhcp4-overrides:
        use-routes: false
      mtu: 9000
EOL
}

for iface in $(ls /sys/class/net | grep -E 'eth[0-9]+$|en[a-z]+[0-9a-z]*'); do
    if [[ "$iface" != "$DEFAULT_IFACE" ]]; then
        log_and_run 'generate_netplan_config "$iface" > "/etc/netplan/$iface.yaml"'
        # log_and_run "netplan apply"
    fi
done
echo -e "${GREEN}Netplan${NC} configuration done."

# Install linux/kernel extra modules
if dpkg-query -W -f='${Status}' linux-modules-extra-$(uname -r) 2>/dev/null | grep -q "install ok installed"; then
    echo -e "${GREEN}Linux extra modules${NC} are already installed."
else
    echo -e "${RED}Installing Linux extra modules. It might take a few minutes. Please be patient.${NC}"
    log_and_run "sudo apt-get install -qy linux-modules-extra-$(uname -r)"
    echo -e "${GREEN}Linux extra modules${NC} installed."
fi

# Setup kernel modules for the crpd
log_and_run 'cat <<EOL | sudo tee /etc/modules-load.d/crpd.conf > /dev/null
tun 
fou 
fou6 
ipip 
ip_tunnel 
ip6_tunnel 
mpls_gso 
mpls_router 
mpls_iptunnel 
vrf 
vxlan
EOL'

echo -e "${GREEN}cRPD${NC} related modules configuration done."

# Setup vfio/vfio-pci module and options
log_and_run 'cat <<EOL | sudo tee /etc/modules-load.d/vfio.conf > /dev/null
vfio
vfio-pci
options vfio enable_unsafe_noiommu_mode=1
vfio_iommu_type1
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOL'

echo -e "${GREEN}VFIO${NC} modules configuration done."

# Setup vfio-pci extra options
log_and_run 'sudo cat <<EOF > /etc/systemd/system/vfio-extra-setup.service
[Unit]
Description=VFIO Setup Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c "modprobe vfio-pci && echo 1 > /sys/module/vfio/parameters/enable_unsafe_noiommu_mode && echo 1 > /sys/module/vfio_iommu_type1/parameters/allow_unsafe_interrupts"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

log_and_run "sudo systemctl daemon-reload"
log_and_run "sudo systemctl enable vfio-extra-setup"
log_and_run "sudo systemctl start vfio-extra-setup"
echo -e "${GREEN}VFIO ${NC}extra option setup done."

# Disable transparent huge page
log_and_run 'echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'
log_and_run 'echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null'
echo -e "${GREEN}THP${NC} disabled."

# check if 1G huge page is available
log_and_run 'grep -q pdpe1gb /proc/cpuinfo || (echo "Error: CPU lacks 1G huge pages support." && exit 1)'
log_and_run "echo $ONEG_HUGEPAGES | sudo tee /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages > /dev/null"
log_and_run 'echo 0 | sudo tee /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages > /dev/null'
# unmount 2M huge page if needed
if sudo mountpoint -q /mnt/huge; then
    echo "Unmounting 2M Huge Pages..."
    log_and_run 'sudo umount /mnt/huge'
fi

# Setup bridge and bridge netfilter setup
log_and_run "sudo echo bridge | sudo tee -a /etc/modules"
log_and_run "sudo echo br_netfilter | sudo tee -a /etc/modules"
echo -e "${GREEN}bridge${NC} and ${GREEN}br_netfilter${NC} module setup complete."

# Setup 1G huge page
log_and_run sudo mkdir -p /mnt/huge1G
log_and_run sudo mount -t hugetlbfs -o pagesize=1G none /mnt/huge1G
log_and_run 'grep -q "/mnt/huge1G" /etc/fstab || (echo "hugetlbfs /mnt/huge1G hugetlbfs pagesize=1G 0 0" | sudo tee -a /etc/fstab > /dev/null)'
echo -e "${GREEN}Huge Pages${NC} setup complete."

# Disable swap
if grep -q swap /etc/fstab; then
    log_and_run sudo swapoff -a
    log_and_run sudo cp /etc/fstab /etc/fstab.bak
    log_and_run "sudo sed -i '/swap/s/^/#/' /etc/fstab"
    echo -e "Swap lines in ${GREEN}/etc/fstab${NC} have been commented out."
fi

# Update Grub
update_grub() {
    # The main config file and the directory containing other config files
    MAIN_GRUB="/etc/default/grub"
    GRUB_DIR="/etc/default/grub.d"

    # String to check for in the config files
    SEARCH_STRING="default_hugepagesz=1G hugepagesz=1G hugepages=${ONEG_HUGEPAGES} intel_iommu=on iommu=pt"

    # Find all files in grub.d containing GRUB_CMDLINE_LINUX_DEFAULT and pick the last one (by alphanumeric order)
    OVERRIDE_FILE=$(grep -l "GRUB_CMDLINE_LINUX_DEFAULT" $GRUB_DIR/* | sort | tail -n 1)

    # If no override files contain GRUB_CMDLINE_LINUX_DEFAULT, we'll modify the main file
    if [[ -z "$OVERRIDE_FILE" ]]; then
        OVERRIDE_FILE=$MAIN_GRUB
    fi

    # Now check if the chosen file contains our desired string, and if not, modify it
    if ! grep -q "$SEARCH_STRING" "$OVERRIDE_FILE"; then
        echo -e "1G HugePages count: ${GREEN}$ONEG_HUGEPAGES${NC}"
        echo -e "grub file updated: ${GREEN}${OVERRIDE_FILE}${NC}"
        cmd="sudo sed -i -r 's/^(GRUB_CMDLINE_LINUX_DEFAULT=)\"(.*)\"/\\1\"\\2 $SEARCH_STRING\"/' $OVERRIDE_FILE"
        log_and_run "$cmd"

        # Update GRUB after making the change
        log_and_run "sudo update-grub"
    fi
}

update_grub
echo -e "${GREEN}GRUB${NC} updated."
echo -e "${GREEN}Installation completed. Check $LOG_FILE for detailed logs.${NC}"

# Reboot prompt
read -t 30 -p "Reboot now? (y/N): (You have 30 seconds to respond. Default is Y): " CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ "$CONFIRM" == [yY] || "$CONFIRM" == [yY][eE][sS] ]]; then
    # Mark that the system will be rebooted by creating a flag file
    log_and_run sudo touch "$FLAG_FILE"
    log_and_run echo "Initiating reboot..."
    log_and_run sudo reboot
    exit 100
else
    log_and_run sudo touch "$FLAG_FILE"
    log_and_run echo "Reboot cancelled."
    exit 1
fi
