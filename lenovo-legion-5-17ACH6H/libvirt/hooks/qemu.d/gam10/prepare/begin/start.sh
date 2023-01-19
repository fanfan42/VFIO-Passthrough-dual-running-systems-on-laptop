#!/bin/bash
# Helpful to read output when debugging
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

lsmod | grep nvidia
CHECK=$?

# Isolate host
# Mostly if kernel ACS patching 
systemctl set-property --runtime -- user.slice AllowedCPUs=0,1
systemctl set-property --runtime -- system.slice AllowedCPUs=0,1
systemctl set-property --runtime -- init.scope AllowedCPUs=0,1

# Uncomment autologin lines in /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user=/autologin-user=your_username/' /etc/lightdm/lightdm.conf

# Stop display manager
if [ $CHECK -ne 1 ] ; then
	optimus-manager --switch integrated --no-confirm
	systemctl stop lightdm.service
	rmmod nvidia_uvm nvidia_drm nvidia_modeset nvidia
	echo "1" > /sys/bus/pci/rescan
	virsh nodedev-detach $VIRSH_GPU_VIDEO
	virsh nodedev-detach $VIRSH_GPU_AUDIO
	modprobe vfio vfio_pci vfio_iommu_type1
	systemctl start lightdm.service
else
	echo "1" > /sys/bus/pci/rescan
	virsh nodedev-detach $VIRSH_GPU_VIDEO
	virsh nodedev-detach $VIRSH_GPU_AUDIO
	modprobe vfio vfio_pci vfio_iommu_type1
fi
