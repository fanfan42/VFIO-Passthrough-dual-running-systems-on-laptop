#!/bin/bash
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Deisolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0-7
systemctl set-property --runtime -- system.slice AllowedCPUs=0-7
systemctl set-property --runtime -- init.scope AllowedCPUs=0-7

echo 1 > "/sys/bus/pci/devices/$GVT_PCI/$GVT_GUID/remove"
