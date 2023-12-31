#!/bin/bash
# Helpful to read output when debugging
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Instantiate VFS
echo "${SRIOV_NUM_VFS}" > "/sys/bus/pci/devices/$SRIOV_PCI/sriov_numvfs"

# Detach new PCI created
virsh nodedev-detach pci_0000_00_02_1

# Isolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0-1,4-5
systemctl set-property --runtime -- system.slice AllowedCPUs=0-1,4-5
systemctl set-property --runtime -- init.scope AllowedCPUs=0-1,4-5

