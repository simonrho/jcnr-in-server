#!/bin/bash

# Accept port name as argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <port_name>"
    exit 1
fi

lshw -c network -businfo -quiet

echo -e '======================================================='

PORT="$1"

# Get PCI address using ethtool
PCI_ADDR=$(ethtool -i "$PORT" 2>/dev/null | grep 'bus-info' | cut -d' ' -f2)
if [ -z "$PCI_ADDR" ]; then
    echo "Error: Couldn't obtain PCI address for $PORT"
    exit 2
fi

# Determine IOMMU group
IOMMU_GROUP_PATH=$(find /sys/kernel/iommu_groups/ -name "*${PCI_ADDR}*" -type l)
if [ -z "$IOMMU_GROUP_PATH" ]; then
    echo "Error: Couldn't determine IOMMU group for $PORT"
    exit 3
fi
IOMMU_GROUP=$(echo $IOMMU_GROUP_PATH | sed -n 's|.*/iommu_groups/\([0-9]\+\)/.*|\1|p')

# Display results
echo "Port Name: $PORT"
echo "PCI Address: $PCI_ADDR"
echo "IOMMU Group: $IOMMU_GROUP"
lspci -s "$PCI_ADDR" -v

exit 0
