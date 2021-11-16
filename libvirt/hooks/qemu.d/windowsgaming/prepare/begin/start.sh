#!/bin/bash
# Helpful to read output when debugging
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

# Stop display manager
#systemctl stop lightdm.service

# Unbind VTconsoles
#echo 0 > /sys/class/vtconsole/vtcon0/bind
#echo 0 > /sys/class/vtconsole/vtcon1/bind

# Unbind EFI-Framebuffer
#echo efi-framebuffer.0 > /sys/bus/platform/drivers/efi-framebuffer/unbind

# Avoid a Race condition
#sleep 5

# Unload all Nvidia drivers
#modprobe -r nvidia_drm
#modprobe -r nvidia_modeset
#modprobe -r nvidia_uvm
#modprobe -r nvidia

# Unbind the GPU from display driver
virsh nodedev-detach $VIRSH_GPU_VIDEO
virsh nodedev-detach $VIRSH_GPU_AUDIO
virsh nodedev-detach $VIRSH_USB
virsh nodedev-detach $VIRSH_SERIAL_BUS

# Load VFIO Kernel Module  
modprobe vfio-pci
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_virqfd

