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

# Source the settings file if it exists
if [ -f "settings" ]; then
    source settings
fi

# Find the values.yaml file
VALUES_FILE=$(find . -type f -name 'values.yaml' -path './Juniper_Cloud_Native_Router_*/helmchart/values.yaml' | sort -V | tail -1)

if [[ -z "$VALUES_FILE" ]]; then
    echo -e "${RED}Couldn't find values.yaml under Juniper_Cloud_Native_Router_*/helmchart/${NC}"
    exit 1
fi

# Backup the original values.yaml
cp "$VALUES_FILE" "${VALUES_FILE}.bak"

# Get the default ethernet interface
DEFAULT_ETH=$(ip route | grep default | awk '{print $5}')

is_physical_interface() {
    local interface="$1"
    if [[ -d "/sys/class/net/$interface/device" ]]; then
        return 0
    else
        return 1
    fi
}


if [[ -z "$JCNR_FABRIC_INTERFACES" ]]; then
    ETH_INTERFACES=()
    for intf in $(ls /sys/class/net/); do
        if is_physical_interface "$intf" && [ "$intf" != "$DEFAULT_ETH" ]; then
            ETH_INTERFACES+=("$intf")
        fi
    done
else
    IFS=' ' read -ra ETH_INTERFACES <<< "$JCNR_FABRIC_INTERFACES"
fi

if [ ${#ETH_INTERFACES[@]} -eq 0 ]; then
    echo -e "${RED}No ethernet interfaces found. Please check your system.${NC}"
    exit 1
fi

# # Update restoreInterfaces value using perl
# perl -i -pe 'BEGIN{undef $/;} s/(jcnr-vrouter:[\s\S]*?restoreInterfaces: )false/\1true/' "$VALUES_FILE"

# Check JCNR_LABEL
if [[ -z "$JCNR_LABEL" ]]; then
    # Read user input or set default
    read -t 30 -p "Enter label in format key=value (You have 30 seconds to respond. Default is key1=jcnr): " LABEL_INPUT
    JCNR_LABEL=${LABEL_INPUT:-key1=jcnr}
fi

# Extract key and value
KEY="${JCNR_LABEL%=*}"
VALUE="${JCNR_LABEL#*=}"


# Add label to worker nodes
NODE_NAME=$(kubectl get nodes -o json | jq -r .items[0].metadata.name)
echo -e "Adding label ${GREEN}${KEY}=${VALUE}${NC} to the node ${GREEN}${NODE_NAME}${NC}."
kubectl label node ${NODE_NAME} "$KEY=$VALUE" --overwrite


# Append comments, nodeAffinity config, and ethernet interfaces to values.yaml
awk -v key="$KEY" -v value="$VALUE" -v interfaces="${ETH_INTERFACES[*]}" '
BEGIN {
    nodeAffinityAdded = 0
    fabricInterfaceAdded = 0
    insideGlobal = 0
}

/^[ \t]*global:/ {
    insideGlobal = 1
    print
    next
}

/^[ \t]*fabricInterface:/ && !fabricInterfaceAdded {
    print "  fabricInterface:"
    print "  # --- Begin script added configuration for interfaces ---"
    split(interfaces, intfs, " ")
    for (i in intfs) {
        print "    - " intfs[i]
    }
    print "  # --- End script added configuration for interfaces ---"
    fabricInterfaceAdded = 1
    next
}

/^[ \t]*nodeAffinity:/ && !nodeAffinityAdded {
    nodeAffinityAdded = 1
    print "  nodeAffinity:"
    print "  # --- Begin script added configuration for nodeAffinity ---"
    print "    - key: " key
    print "      operator: In"
    print "      values:"
    print "      - " value
    print "  # --- End script added configuration for nodeAffinity ---"
    next
}

/^[^ \t]/ && insideGlobal { 
    insideGlobal = 0
    if (!fabricInterfaceAdded) {
        print "  fabricInterface:"
        print "  # --- Begin script added configuration for interfaces ---"
        split(interfaces, intfs, " ")
        for (i in intfs) {
            print "    - " intfs[i]
        }
        print "  # --- End script added configuration for interfaces ---"
        fabricInterfaceAdded = 1
    }
    if (!nodeAffinityAdded) {
        print "  nodeAffinity:"
        print "  # --- Begin script added configuration for nodeAffinity ---"
        print "    - key: " key
        print "      operator: In"
        print "      values:"
        print "      - " value
        print "  # --- End script added configuration for nodeAffinity ---"
        nodeAffinityAdded = 1
    }
}

{
    print
}
' "$VALUES_FILE" > "${VALUES_FILE}.tmp" && mv "${VALUES_FILE}.tmp" "$VALUES_FILE"


# Update YAML file based on shell variable values - mtu, cpu_core_mask, vrouter_dpdk_uio_driver, restoreInterfaces
sed -i "s/^\(\s*mtu:\s*\).*$/\1\"$JCNR_MTU\"/" $VALUES_FILE
sed -i "s/^\(\s*restoreInterfaces:\s*\).*$/\1$JCNR_RESTORE_INTERFACES/" $VALUES_FILE
sed -i "s/^\(\s*cpu_core_mask:\s*\).*$/\1\"$JCNR_CPU_CORE_MASK\"/" $VALUES_FILE
sed -i "s/^\(\s*vrouter_dpdk_uio_driver:\s*\).*$/\1\"$JCNR_VROUTER_DPDK_UIO_DRIVER\"/" $VALUES_FILE

# Summary of changes
echo -e "Updates made to ${GREEN}$VALUES_FILE${NC}:"
echo -e " 1. Added ${GREEN}nodeAffinity${NC} with key-value pair: ${GREEN}$KEY=$VALUE${NC}."
echo -e " 2. Added ${GREEN}fabricInterface${NC}: ${YELLOW}${ETH_INTERFACES[@]}${NC}."
echo -e " 3. Updated ${GREEN}mtu${NC} to ${GREEN}${JCNR_MTU}${NC}."
echo -e " 4. Updated ${GREEN}restoreInterfaces${NC} to ${GREEN}$JCNR_RESTORE_INTERFACES${NC}."
echo -e " 5. Updated ${GREEN}cpu_core_mask${NC} to ${GREEN}$JCNR_CPU_CORE_MASK${NC}."
echo -e " 6. Updated ${GREEN}vrouter_dpdk_uio_driver${NC} to ${GREEN}$JCNR_VROUTER_DPDK_UIO_DRIVER${NC}."

# Note
echo ""
echo -e "Note: Please double-check that the ${GREEN}'fabricInterface'${NC} entries and other configurations in the ${GREEN}'values.yaml'${NC} file match your intentions."
echo -e "A backup of the original file is saved as ${GREEN}${VALUES_FILE}.bak${NC}."
echo ""


