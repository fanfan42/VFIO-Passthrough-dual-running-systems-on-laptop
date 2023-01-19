#!/bin/bash
# Helpful to read output when debugging
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Isolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0,4
systemctl set-property --runtime -- system.slice AllowedCPUs=0,4
systemctl set-property --runtime -- init.scope AllowedCPUs=0,4

echo "$GVT_GUID" > "/sys/bus/pci/devices/$GVT_PCI/mdev_supported_types/$MDEV_TYPE/create"

