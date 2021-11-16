#!/bin/bash
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio-pci
modprobe -r vfio_iommu_type1
modprobe -r vfio
modprobe -r vfio_virqfd

# Re-Bind GPU to Nvidia Driver
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO
virsh nodedev-reattach $VIRSH_USB
virsh nodedev-reattach $VIRSH_SERIAL_BUS

# Rebind VT consoles
#echo 1 > /sys/class/vtconsole/vtcon0/bind
#echo 1 > /sys/class/vtconsole/vtcon1/bind

# Bind EFI-Framebuffer
#nvidia-xconfig --query-gpu-info > /dev/null 2>&1
#echo "efi-framebuffer.0" > /sys/bus/platform/drivers/efi-framebuffer/bind

# Load all Nvidia drivers
#modprobe nvidia_drm
#modprobe nvidia_modeset
#modprobe drm_kms_helper
#modprobe drm
#modprobe nvidia_uvm
#modprobe nvidia
#sleep 10
#modprobe nouveau
#echo 1 > /sys/bus/pci/devices/0000\:01\:00.0/remove
#echo 1 > /sys/bus/pci/devices/0000\:01\:00.1/remove
#echo 1 > /sys/bus/pci/devices/0000\:01\:00.2/remove 
#echo 1 > /sys/bus/pci/devices/0000\:01\:00.3/remove 
#echo 1 > /sys/bus/pci/rescan

# Restart Display Manager
#systemctl start lightdm.service

