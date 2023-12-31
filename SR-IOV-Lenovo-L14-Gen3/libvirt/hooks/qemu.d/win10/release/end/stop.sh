#!/bin/bash
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Delete VF
echo 0 > "/sys/bus/pci/devices/$SRIOV_PCI/sriov_numvfs"

systemctl start clamav-daemon

# Deisolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
systemctl set-property --runtime -- init.scope AllowedCPUs=0-11

