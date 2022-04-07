#!/bin/bash
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

echo 1 | pkexec tee "/sys/bus/pci/devices/$GVT_PCI/$GVT_GUID/remove"
