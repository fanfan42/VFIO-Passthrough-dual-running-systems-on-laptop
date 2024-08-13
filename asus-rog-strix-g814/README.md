# Asus ROG Strix G18 G814
## Introduction
This work is based on my previous configuration on Lenovo Legion 5. I only use Nvidia driver because, when on Linux, I use some emulation tools which prefer Nvidia driver. Also, I didn't verify if Nouveau is compatible with Nvidia RTX 40xx. When I bought this laptop, it was delivered with no OS, 16GB of RAM and a single NVMe PCI drive. In order to make this installation working, you will need, at least, a second NVMe drive installed in the laptop. This laptop has a single 16GB RAM card installed, consider buying another one so you can use the dual-channel. For better performance, I reinstalled a dual-boot system so I can passthrough a full drive with Windows 11 to the VM. Also, it allows me to boot Windows and install updates for BIOS/firmware updates that fwupd still doesn't manage on Linux. And last point, I found a workaround working on Lenovo Legion 5 for Nvidia RTX 3060. With Nvidia RTX 4080, you can directly load Nvidia driver for more screens attached to the laptop at start. Personnaly, I prefer my old workaround because, most of the time, I only need the default screen attached to my iGPU (Intel Xe), I really appreciate not consuming too much energy when I don't need it.

### **Table Of Contents**
- [**Installing Windows 11 on second NVMe drive**](#installing-windows-11-on-second-nvme-drive)
- [**Enable IOMMU and install required packages**](#enable-iommu-and-install-required-packages)
- [**Configure optimus-manager and blacklist modules**](#configure-optimus-manager-and-blacklist-modules)
- [**Setup Guest OS**](#setup-guest-os)
- [**Install Windows**](#install-windows)
- [**Attaching PCI devices**](#attaching-pci-devices)
- [**Libvirt Hook Helper**](#libvirt-hook-helper)
- [**Config Libvirt Hooks**](#config-libvirt-hooks)
- [**Start/Stop Libvirt Hooks**](#startstop-libvirt-hooks)
- [**Keyboard/Mouse Passthrough**](#keyboardmouse-passthrough)
- [**Video card driver virtualisation detection**](#video-card-driver-virtualisation-detection)
- [**CPU Pinning**](#cpu-pinning)
- [**Hyper-V Enlightenments**](#hyper-v-enlightenments)
- [**Disable Memballoon**](#disable-memballoon)
- [**Only laptop with Nvidia card Tuning**](#only-laptop-with-nvidia-card-tuning)
- [**Hugepages**](#hugepages)
- [**CPU Governor**](#cpu-governor)
- [**Optimize Windows**](#optimize-windows)
- [**Install looking-glass**](#install-looking-glass)

### **Installing Windows 11 on second NVMe drive**
Also possible with Windows 10, but didn't test it. I won't explain all the steps, you have plenty of tutorials for helping you install a LiveUSB and configure Windows.

What you have to verify :

* Secboot is disabled in your BIOS before installing Windows 11 (Pro, in my case). Manjaro still doesn't use this s*** and we need a functioning dual-boot system
* Download [virtio](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) in the VM and install it after Windows installation
* Download and install Nvidia Driver
* (Optional) Make all Windows updates needed

Note : Yes, Windows 11 is normally only available with secboot activated. [Rufus](https://rufus.ie/en/) can help you go through this problem with the original Windows 11 ISO

### **Enable IOMMU and install required packages**
```sh
sudo pacman -S --needed qemu-base libvirt edk2-ovmf virt-manager dnsmasq ebtables vim linuxxx-nvidia optimus-manager qemu-hw-usb-host
```
You can replace iptables with iptables-nft if asked. linuxxx-nvidia refers to your kernel version, ex: linux610-nvidia.

WARNING : At this time, qemu 9.0 is available but there are some warnings because of ***topoext*** deprecated in this version. Please install manjaro-downgrade and execute :
```sh
sudo downgrade qemu-base qemu-common qemu-img qemu-system-x86-firmware qemu-system-x86 qemu-hw-usb-host
```
And select version 8.2 for all these packages. I will update this how-to later in the future.

Add yourself in all these groups :
```sh
sudo groupadd autologin
sudo usermod -aG libvirt,autologin,plugdev,kvm,input,disk $(whoami)
```

Enable IOMMU support by setting the kernel parameter for Intel CPU.

| /etc/default/grub                                                              |
|--------------------------------------------------------------------------------|
| `GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=on iommu=pt iomem=relaxed ..."`   |

Generate grub.cfg
```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Before rebooting, execute these steps :
```sh
sudo systemctl enable libvirtd
sudo virsh net-start default
sudo virsh net-autostart default
sudo systemctl enable optimus-manager
```

When rebooting, go in the BIOS configuration, for the graphics/MUX configuration, apply ***Dynamic*** setting. Ensure that ***Intel VT-d*** is also enabled.

After rebooting, check that the groups are valid.
```sh
for g in `find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V`; do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

Example output: 
```
IOMMU Group 16:
	01:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD104M [GeForce RTX 4080 Max-Q / Mobile] [10de:27e0] (rev a1)
	01:00.1 Audio device [0403]: NVIDIA Corporation AD104 High Definition Audio Controller [10de:22bc] (rev a1)
```

### **Configure optimus-manager and blacklist modules**
In /usr/share/optimus-manager.conf (The conf is reset each time optimus-manager is updated) :
```sh
[optimus]
...
pci_remove=yes
...
startup_mode=integrated
...
auto_logout=no
```

In /etc/modprobe.d/blacklist.conf :
```sh
blacklist nouveau
blacklist nvidia-drm
blacklist nvidia-modeset
blacklist nvidia_uvm
blacklist nvidia_wmi_ec_backlight
blacklist nvidia
```

This step is only if, like me, you dont want to have nvidia loaded at boot. If you prefer having nvidia loaded, change ***startup_mode*** to "hybrid" in optimus-manager.conf and don't edit blacklist.conf in modprobe.d. I don't guarantee that this step-by-step will work until the end so please adapt to your choices.

Another reboot will be necessary (sorry, not sorry ^^).

### **Setup Guest OS**

Don't ask me why, but when I tried a "manual install" with libvirt-manager, passing directly the NVMe Windows drive, it never worked. I had no HDMI output besides having Passthrough GPU and NVMe working. I had an error which was like "Find Image based on IP ... (No PDB)" which may reference to grub2 or OVMF problems but still can't get the exact cause. I still have to make a manual install of a VM on img (RAW) file for the first steps. In this step, don't bother installing every updates, just verify that Nvidia driver is correctly installed in case the GPU passthrough not working properly and install virtio Fedora package on Windows in step [**Installing Windows 11 on second NVMe drive**](#installing-windows-11-on-second-nvme-drive)

Create your storage volume with the ***raw*** format. Select ***Customize before install*** on Final Step. 

| In Overview                                                                |
|:---------------------------------------------------------------------------|
| set **Chipset** to **Q35**                                                 |
| set **Firmware** to **UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd** |

WARNING: Click on "Apply" each time you switch panels in virt-manager

| In CPUs                                                |
|:-------------------------------------------------------|
| set **CPU model** to **host-passthrough**              |
| set **CPU Topology** with 1 socket, 16 cores, 1 thread |

| In Sata                        |
|:-------------------------------|
| set **Disk Bus** to **virtio** |

| In NIC                             |
|:-----------------------------------|
| set **Device Model** to **virtio** |

| In Add Hardware                                            |
|:-----------------------------------------------------------|
| select **CDROM** and point to `/path/to/virtio-driver.iso` |

### **Install Windows**

Windows can't detect the ***virtio disk***, so you need to ***Load Driver*** and select `virtio-iso/amd64/win11` when prompted.

Windows can't connect to the internet, we will activate internet later in this tutorial.

Note : it's Windows 11, it asks you to connect with a Microsoft account. If you only want a local account, please follow this tutorial when needed in the install process : [tomshardware](https://www.tomshardware.com/how-to/install-windows-11-without-microsoft-account) can help you go through this problem with the original Windows 11

### **Attaching PCI devices**

The devices you want to passthrough.

| In Add PCI Host Device                         |
|:-----------------------------------------------|
| *PCI Host devices for your GPU and NVMe drive* |

| In Add USB Host Device  |
|:------------------------|
| *Add whatever you want* |

| Remove                                       |
|:---------------------------------------------|
| `Video Bochs`                                |
| `Tablet`                                     |
| `Video VNC`                                  |
| `RAW disk previously created at 1st install` |

In boot priority, select you NVME drive as 1st

### **Libvirt Hook Helper**

Libvirt hooks automate the process of running specific tasks during VM state change.

More documentation on [The Passthrough Post](https://passthroughpo.st/simple-per-vm-libvirt-hooks-with-the-vfio-tools-hook-helper/) website.

<details>
  <summary><b>Create Libvirt Hook Helper</b></summary>

```sh
mkdir /etc/libvirt/hooks
vim /etc/libvirt/hooks/qemu
chmod +x /etc/libvirt/hooks/qemu
```

  <table>
  <tr>
  <th>
  /etc/libvirt/hooks/qemu
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash
#
# Author: Sebastiaan Meijer (sebastiaan@passthroughpo.st)
# https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"
MISC="${@:4}"

BASEDIR="$(dirname $0)"

HOOKPATH="$BASEDIR/qemu.d/$GUEST_NAME/$HOOK_NAME/$STATE_NAME"

set -e # If a script exits with an error, we should as well.

# check if it's a non-empty executable file
if [ -f "$HOOKPATH" ] && [ -s "$HOOKPATH"] && [ -x "$HOOKPATH" ]; then
    eval \"$HOOKPATH\" "$@"
elif [ -d "$HOOKPATH" ]; then
    while read file; do
        # check for null string
        if [ ! -z "$file" ]; then
          eval \"$file\" "$@"
        fi
    done <<< "$(find -L "$HOOKPATH" -maxdepth 1 -type f -executable -print;)"
fi
```

  </td>
  </tr>
  </table>
</details>

### **Config Libvirt Hooks**

This configuration file allows you to create variables that can be read by the scripts below.

```sh
vim /etc/libvirt/hooks/kvm.conf
```

<table>
<tr>
<th>
/etc/libvirt/hooks/kvm.conf
</th>
</tr>

<tr>
<td>

```conf
# CONFIG
VM_MEMORY=16384

# VIRSH
VIRSH_GPU_VIDEO=pci_0000_01_00_0
VIRSH_GPU_AUDIO=pci_0000_01_00_1
VIRSH_SSD_NVME=pci_0000_6c_00_0
```

</td>
</tr>
</table>

`VM_MEMORY` in MiB is the memory allocated tho the guest.

Make sure to substitute the correct bus addresses for the devices you'd like to passthrough to your VM.
Just in case it's still unclear, you get the virsh PCI device IDs from the [**Enable IOMMU and install required packages**](#enable-iommu-and-install-required-packages).
Translate the address for each device as follows: IOMMU `Group 1 01:00.0 ...` --> `VIRSH_...=pci_0000_01_00_0`.

### **Start/Stop Libvirt Hooks**

This command will set the variable KVM_NAME so you can execute the rest of the commands without changing the name of the VM.

```sh
KVM_NAME="YOUR_VM_NAME"
```

**If the scripts are not working, use the scripts as template and write your own.**

My hardware for this scripts is:
- *13th Gen Intel(R) Core(TM) i7-13650HX*
- *NVIDIA Corporation AD104M [GeForce RTX 4080 Max-Q / Mobile]*

<details>
  <summary><b>Create Start Script</b></summary>

```sh
mkdir -p /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/start.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/start.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/prepare/begin/start.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash
# Helpful to read output when debugging
set -x

# Load variables
source "/etc/libvirt/hooks/kvm.conf"

lsmod | grep nvidia
CHECK=$?

# Isolate host
# Mostly if kernel ACS patching 
systemctl set-property --runtime -- user.slice AllowedCPUs=0-1,12-13
systemctl set-property --runtime -- system.slice AllowedCPUs=0-1,12-13
systemctl set-property --runtime -- init.scope AllowedCPUs=0-1,12-13

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
	virsh nodedev-detach $VIRSH_SSD_NVME
	modprobe vfio vfio_pci vfio_iommu_type1
	systemctl start lightdm.service
else
	echo "1" > /sys/bus/pci/rescan
	virsh nodedev-detach $VIRSH_GPU_VIDEO
	virsh nodedev-detach $VIRSH_GPU_AUDIO
	virsh nodedev-detach $VIRSH_SSD_NVME
	modprobe vfio vfio_pci vfio_iommu_type1
fi
```

  </td>
  </tr>
  </table>
</details>

<details>
  <summary><b>Create Stop Script</b></summary>

```sh
mkdir -p /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/stop.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/stop.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/release/end/stop.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
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
```

  </td>
  </tr>
  </table>
</details>

### **Keyboard/Mouse Passthrough**

Change the first line of the xml to (Don't apply the xml before the next add):

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
```

</td>
</tr>
</table>

Find your keyboard and mouse devices in ***/dev/input/by-id***. You'd generally use the devices ending with ***event-kbd*** and ***event-mouse***. And the devices in your configuration right before closing `</domain>` tag.

You can verify if it works by `cat /dev/input/by-id/DEVICE_NAME`.

Replace ***MOUSE_NAME*** and ***KEYBOARD_NAME*** with your device id.

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  </devices>
  <qemu:commandline>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=mouse1,evdev=/dev/input/by-id/MOUSE_NAME'/>
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=kbd1,evdev=/dev/input/by-id/KEYBOARD_NAME,grab_all=on,repeat=on'/>
  </qemu:commandline>
</domain>
```

</td>
</tr>
</table>

At this time. you can apply the xml file. From now, apply each time the xml is changed.

You need to include these devices in your qemu config.

<table>
<tr>
<th>
/etc/libvirt/qemu.conf
</th>
</tr>

<tr>
<td>

```conf
...
user = "your_username"
group = "kvm"
...
cgroup_device_acl = [
    "/dev/input/by-id/KEYBOARD_NAME",
    "/dev/input/by-id/MOUSE_NAME",
    "/dev/null", "/dev/full", "/dev/zero",
    "/dev/random", "/dev/urandom",
    "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
    "/dev/rtc","/dev/hpet", "/dev/sev"
]
...
```

</td>
</tr>
</table>

Also, add the virtio devices (You cannot remove the PS/2 devices).

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
<devices>
  ...
  <input type='mouse' bus='virtio'/>
  <input type='keyboard' bus='virtio'/>
  ...
</devices>
...
```

</td>
</tr>
</table>

### **Video card driver virtualisation detection**

Video Card drivers refuse to run in Virtual Machine, so you need to spoof Hyper-V Vendor ID.
More information on the options configured [here](https://libvirt.org/formatdomain.html#elementsFeatures)

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  <features>
    <acpi/>
    <apic/>
    <hyperv mode="custom">
      ...
      <vendor_id state="on" value="deadbeef"/>
      ...
    </hyperv>
    ...
  </features>
...
```

</td>
</tr>
</table>

NVIDIA guest drivers also require hiding the KVM CPU leaf:

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
<features>
  ...
  <kvm>
    <hidden state='on'/>
  </kvm>
  <ioapic driver="kvm"/>
  <vmport state="off"/>
</features>
...
```

</td>
</tr>
</table>

### **CPU Pinning**

My setup is an Intel Core i7 13650HX with Xe Graphics which has 6 P-core (Hyperthreaded) and 8 E-core.

<details>
  <summary><b>How to bind the threads to the core</b></summary>

It's very important that when we passthrough a core, we include its sibling. To get a sense of your cpu topology, use the command `lscpu -e`. A matching core id (i.e. "CORE" column) means that the associated threads (i.e. "CPU" column) run on the same physical core. With intel P and E cores, it's still difficult to have a perfect matching, that's why, I prefered, in the previous steps, to only give Cores instead of threads in the CPU topology

```
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE    MAXMHZ   MINMHZ      MHZ
  0    0      0    0 0:0:0:0          oui 4700,0000 800,0000 800,3020
  1    0      0    0 0:0:0:0          oui 4700,0000 800,0000 800,0000
  2    0      0    1 4:4:1:0          oui 4700,0000 800,0000 800,0000
  3    0      0    1 4:4:1:0          oui 4700,0000 800,0000 800,0000
  4    0      0    2 8:8:2:0          oui 4900,0000 800,0000 800,0000
  5    0      0    2 8:8:2:0          oui 4900,0000 800,0000 800,0000
  6    0      0    3 12:12:3:0        oui 4900,0000 800,0000 800,0000
  7    0      0    3 12:12:3:0        oui 4900,0000 800,0000 800,0000
  8    0      0    4 16:16:4:0        oui 4700,0000 800,0000 800,0000
  9    0      0    4 16:16:4:0        oui 4700,0000 800,0000 800,0000
 10    0      0    5 20:20:5:0        oui 4700,0000 800,0000 800,0000
 11    0      0    5 20:20:5:0        oui 4700,0000 800,0000 800,0000
 12    0      0    6 24:24:6:0        oui 3600,0000 800,0000 800,0000
 13    0      0    7 25:25:6:0        oui 3600,0000 800,0000 880,5480
 14    0      0    8 26:26:6:0        oui 3600,0000 800,0000 867,6780
 15    0      0    9 27:27:6:0        oui 3600,0000 800,0000 800,0000
 16    0      0   10 28:28:7:0        oui 3600,0000 800,0000 800,2860
 17    0      0   11 29:29:7:0        oui 3600,0000 800,0000 800,0000
 18    0      0   12 30:30:7:0        oui 3600,0000 800,0000 800,0000
 19    0      0   13 31:31:7:0        oui 3600,0000 800,0000 800,0000
```

According to the logic seen above, here are my core and their threads binding.

```
P-Core 1 : 0, 1
P-Core 2 : 2, 3
P-Core 3 : 4, 5
P-Core 4 : 6, 7
P-Core 5 : 8, 9
P-Core 6 : 10, 11
E-Core 1 : 12
E-Core 2 : 13
E-Core 3 : 14
E-core 4 : 15
E-core 5 : 16
E-core 6 : 17
E-core 7 : 18
E-core 8 : 19
```

</details>

In this example, I want to get 1 (+ its thread) P-core and 2 E-core for the host, 5 P-Core (and their threads) and 6 E-Core to the guest. 

I show you the final result :

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  <vcpu placement='static'>16</vcpu>
  <iothreads>1</iothreads>
  <cputune>
    <vcpupin vcpu="0" cpuset="2"/>
    <vcpupin vcpu="1" cpuset="3"/>
    <vcpupin vcpu="2" cpuset="4"/>
    <vcpupin vcpu="3" cpuset="5"/>
    <vcpupin vcpu="4" cpuset="6"/>
    <vcpupin vcpu="5" cpuset="7"/>
    <vcpupin vcpu="6" cpuset="8"/>
    <vcpupin vcpu="7" cpuset="9"/>
    <vcpupin vcpu="8" cpuset="10"/>
    <vcpupin vcpu="9" cpuset="11"/>
    <vcpupin vcpu="10" cpuset="14"/>
    <vcpupin vcpu="11" cpuset="15"/>
    <vcpupin vcpu="12" cpuset="16"/>
    <vcpupin vcpu="13" cpuset="17"/>
    <vcpupin vcpu="14" cpuset="18"/>
    <vcpupin vcpu="15" cpuset="19"/>
    <emulatorpin cpuset="0-1,12-13"/>
    <iothreadpin iothread="1" cpuset="0-1,12-13"/>
  </cputune>
  ...
</domain>
```

</td>
</tr>
</table>

You need to match your CPU pathtrough.

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  <cpu mode="host-passthrough" check="none" migratable="on">
    <topology sockets="1" dies="1" cores="16" threads="1"/>
    <cache mode="passthrough"/>
    <feature policy="require" name="topoext"/>
  </cpu>
  ...
</domain>
```

</td>
</tr>
</table>

### **Hyper-V Enlightenments**

Hyper-V enlightenments help the guest VM handle virtualization tasks.

More documentation on [fossies.org](https://fossies.org/linux/qemu/docs/hyperv.txt) for qemu enlightenments.

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  <qemu:commandline>
    ...
    <qemu:arg value="-rtc"/>
    <qemu:arg value="base=localtime"/>
    <qemu:arg value="-cpu"/>
    <qemu:arg value="host,host-cache-info=on,kvm=on,l3-cache=on,kvm-hint-dedicated=on,migratable=no,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=deadbeef,+invtsc,+topoext,+x2apic,+pdpe1gb,-spec-ctrl,-md-clear,-ssbd"/>
  </qemu:commandline>
</devices>
```

</td>
</tr>
</table>

#### **Explanation on CPU options**

* host : Pass "real" CPU and all native extensions to the Guest
* host_cache_info=on and l3-cache=on : Pass the cache information to the Guest
* kvm=on (the default) : Use allow the use of KVM and prevent emulation by Qemu
* kvm-hint-dedicated=on : Indicates to the Guest that cores passed are dedicated to its own usage. Better performance
* migratable=off : Prevent Guest migration when running
* +topoext : A complement to the CPU pinning
* +invtsc : Time Stamp Counter (TSC) does not vary. Used by applications which are sensitive to time (Online games)
* +x2apic : Optimize interruption in system calls
* +pdpe1gb : Improve Page Memory allocation to 1GB for the Guest
* -spec-ctrl, -md-clear and -ssbd : Deactivate some securities. The Guest is vulnerable to Spectre, Meltdown and Speculative Store Bypass. Improve performance again

Specific options specific to Windows Guests (hyperV) :
* hv_relaxed : Ease the guest when in high load
* hv_spinlocks=0x1fff : Reduce the contention on Spinlocks. May improve hyperthreaded applications
* hv_vapic : Optimize interruption management (APIC)
* hv_time : Synchronize clock between Host and Guest

### **Disable Memballoon**

The VirtIO memballoon device allows the host to reclaim memory from a running VM. However, this functionality comes at a performance cost, so you can disable it by editing the <memballoon> tag in your XML like so:

```xml
...
  <devices>
    ... 
    <memballoon model="none"/>
  </devices>
...
```

### **Only laptop with Nvidia card Tuning**

Intel or AMD is the same so when you install nvidia driver,
you may have the dead `Code 43` and stay stuck on a maximum resolution of 800x600. It's because the driver searches for a battery on your laptop.
Yes, even in a VM

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

Download a fake bin for emulating battery on my repository in ***utils*** folder, the file is called "acpitable.bin"
And add these qemu vars:

```xml
...
  <qemu:commandline>
    ...
    <qemu:arg value="-acpitable"/>
    <qemu:arg value="file=/whereever/your/path/acpitable.bin"/>
  </qemu:commandline>
</devices>
...
```

</td>
</tr>
</table>

### **Hugepages**

Memory (RAM) is divided up into basic segments called pages. By default, the x86 architecture has a page size of 4KB. CPUs utilize pages within the built in memory management unit ([MMU](https://en.wikipedia.org/wiki/Memory_management_unit)). Although the standard page size is suitable for many tasks, hugepages are a mechanism that allow the Linux kernel to take advantage of large amounts of memory with reduced overhead. Hugepages can vary in size anywhere from 2MB to 1GB.

Many tutorials will have you reserve hugepages for your guest VM at host boot-time. There's a significant downside to this approach: a portion of RAM will be unavailable to your host even when the VM is inactive. In [bryansteiner](https://github.com/bryansteiner/gpu-passthrough-tutorial) setup, he chose to allocate hugepages before the VM starts and deallocate those pages on VM shutdown.

<details>
  <summary><b>Create Alloc Hugepages Script</b></summary>

```sh
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/alloc_hugepages.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/alloc_hugepages.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/prepare/begin/alloc_hugepages.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash

## Load the config file
source "/etc/libvirt/hooks/kvm.conf"

## Calculate number of hugepages to allocate from memory (in MB)
HUGEPAGES="$(($VM_MEMORY/$(($(grep Hugepagesize /proc/meminfo | awk '{print $2}')/1024))))"

echo "Allocating hugepages..."
echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
ALLOC_PAGES=$(cat /proc/sys/vm/nr_hugepages)

TRIES=0
while (( $ALLOC_PAGES != $HUGEPAGES && $TRIES < 1000 ))
do
  echo 1 > /proc/sys/vm/compact_memory            ## defrag ram
  echo $HUGEPAGES > /proc/sys/vm/nr_hugepages
  ALLOC_PAGES=$(cat /proc/sys/vm/nr_hugepages)
  echo "Succesfully allocated $ALLOC_PAGES / $HUGEPAGES"
  let TRIES+=1
done

if [ "$ALLOC_PAGES" -ne "$HUGEPAGES" ]
then
  echo "Not able to allocate all hugepages. Reverting..."
  echo 0 > /proc/sys/vm/nr_hugepages
  exit 1
fi
```

  </td>
  </tr>
  </table>
</details>

<details>
  <summary><b>Create Dealloc Hugepages Script</b></summary>

```sh
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/dealloc_hugepages.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/dealloc_hugepages.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/release/end/dealloc_hugepages.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash

echo 0 > /proc/sys/vm/nr_hugepages
```

  </td>
  </tr>
  </table>
</details>

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
  <memory unit="KiB">16777216</memory>
  <currentMemory unit="KiB">16777216</currentMemory>
  <memoryBacking>
    <hugepages/>
  </memoryBacking>
  ...
</domain>

```

</td>
</tr>
</table>

The memory need to match your `VM_MEMORY` from your config *(to convert KiB to MiB you need to divide by 1024)*.

### **CPU Governor**

This performance tweak takes advantage of the [CPU frequency scaling governor](https://wiki.archlinux.org/title/CPU_frequency_scaling#Scaling_governors) in Linux.

<details>
  <summary><b>Create CPU Performance Script</b></summary>

```sh
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/cpu_mode_performance.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/prepare/begin/cpu_mode_performance.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/prepare/begin/cpu_mode_performance.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash

## Enable CPU governor performance mode
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "performance" > $file; done
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

  </td>
  </tr>
  </table>
</details>

<details>
  <summary><b>Create CPU Powersave Script</b></summary>

```sh
vim /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/cpu_mode_powersave.sh
chmod +x /etc/libvirt/hooks/qemu.d/$KVM_NAME/release/end/cpu_mode_powersave.sh
```
  <table>
  <tr>
  <th>
    /etc/libvirt/hooks/qemu.d/VM_NAME/release/end/cpu_mode_powersave.sh
  </th>
  </tr>

  <tr>
  <td>

```sh
#!/bin/bash

## Enable CPU governor powersave mode
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo "powersave" > $file; done
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

  </td>
  </tr>
  </table>
</details>


### **Optimize Windows**

#### *AtlasOS*

If you want the best performance for your system when gaming, I highly recommend you to try [AtlasOS](https://atlasos.net/). It's a custom Windows 11 script which highly upgrades performance on the system by removing many Windows Tools and decreases the space needed for the installation. Download their Wizard and playbook and install everything you need. Don't hesitate to remove Windows Defender. Re-run the wizard each time you make some updates with Windows 11.

#### *Better performances*

In *Windows Settings*:
- set ***Power suply*** to ***Performances***
Note : it's already done when installing AtlasOS

In *NVIDIA Control Panel*:
- set ***Texture filtering quality*** to ***High performance***
- set ***Power management mode*** to ***Max performance***

### **Install looking-glass**

#### *Requirements*

This part of the tutorial is only if you can't play with a second monitor or if you want to have the 2 options in all case. In my case, I created another Guest (VM) based on the previously created. I cloned the domain on virt-manager. The new VM still uses the same PCI NVMe drive for booting the Windows. First of all, you will need a dummy HDMI plug or you wont see anything in the looking-glass client. It costs less than 10 bucks on Internet.

#### *Install Looking Glass Host Binary*

Start the previously created Guest, install the latest stable [Guest application](https://looking-glass.io/downloads) on your Windows.

#### *Install looking glass (client) and qemu packages for sound and graphics*

```sh
sudo pacman -S qemu-audio-pa qemu-ui-spice-core qemu-ui-opengl yay
```

Remember to use downgrade instead of pacman in case you still don't want to use qemu v9+. yay is only for installing looking-glass from the AUR, this package still doesn't exist in official repositories on Manjaro.

```sh
yay -S looking-glass
```

#### *Configure the guest*

On the host, create the tmp configuration file :

<details>
  <summary><b>Create Looking-glass tmp file</b></summary>

```sh
vim /etc/tmpfiles.d/10-looking-glass.conf
```
  <table>
  <tr>
  <th>
    /etc/tmpfiles.d/10-looking-glass.conf
  </th>
  </tr>

  <tr>
  <td>

```sh
f	/dev/shm/looking-glass	0666	root	libvirt	-
```

  </td>
  </tr>
  </table>
</details>

On the XML file of the guest, add these lines to create a shared memory area for looking-glass

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
<devices>
  ...
  <shmem name="looking-glass">
    <model type="ivshmem-plain"/>
    <size unit="M">64</size>
  </shmem>
</devices>

```

</td>
</tr>
</table>

Normally, if you followed all the tutorial, at this point you shouldn't have any graphics on libvirt, add these lines to the XML file in libvirt :

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
<devices>
  ...
  <graphics type="spice" autoport="yes">
    <listen type="address"/>
    <image compression="off"/>
  </graphics>
  <video>
    <model type="none"/>
  </video>
  ...
</devices>

```
</td>
</tr>
</table>

And last but not least, you may need sound to enjoy it in your VM, add these lines in the XML file :

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

```xml
...
<devices>
  ...
  <sound model="ich9">
      <audio id="1"/>
  </sound>
  <audio id="1" type="pulseaudio" serverName="/run/user/1000/pulse/native">
      <input mixingEngine="no"/>
      <output mixingEngine="no"/>
  </audio>
  ...
</devices>

```
</td>
</tr>
</table>

You can now plug the dummy HDMI plug and start the VM, in the terminal, to access the Windows Guest, type the following command, it will launch looking-glass and your VM should be running (no need to be root) :

```sh
# 97 is for rightCtrl key - sudo showkey  --keycodes 
looking-glass-client -m 97 -F input:grabKeyboardOnFocus input:rawMouse input:autoCapture
```
