#!/bin/bash
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Deisolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0-19
systemctl set-property --runtime -- system.slice AllowedCPUs=0-19
systemctl set-property --runtime -- init.scope AllowedCPUs=0-19

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Re-Bind GPU to Nvidia Driver
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO
virsh nodedev-reattach $VIRSH_SSD_NVME

# Avoid race condition
sleep 2

# Restart lightdm with nvidia
optimus-manager --switch hybrid --no-confirm
systemctl restart lightdm

# Comment out autologin lines in /etc/lightdm/lightdm.conf
sed -i 's/^autologin-user=your_username/#autologin-user=/' /etc/lightdm/lightdm.conf
