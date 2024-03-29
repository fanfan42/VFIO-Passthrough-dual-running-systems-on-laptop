# Lenovo Legion 5 17ACH6H 

At this time, it "works" but needs a workaround

Many problems :
  - nouveau doesn't support RTX 30xx
  - I need optimus-manager in order to switch between nvidia and intel
  - I have to start the VM before I can use my dual-screen with nvidia 

After all configuration is finished, when you restart your PC, you may notice that your Nvidia card has disappeared from your lspci, nvidia isn't loaded and your second monitor isn't used by Manjaro, that's normal. Start the VM. Stop the VM. Nvidia is bound. You can now start/stop your VM as musch as you want but for each start/stop action, lightdm will restart

EDIT 1 : I can now autologin when lightdm restarts and still have to enter my password when rebooting the host, that spares some time

EDIT 2 : I created a new VM based on the same img file as this example (see the files in libvirt folder). On the top of it, I install Looking-glass when I don't have a second monitor. This is not a recommended step for performance. In facts, that doesn't give great performance. That's only for single monitor configuration

### **Table Of Contents**
- [**Enable & Verify IOMMU**](#enable-verify-iommu)
- [**Install required tools**](#install-required-tools)
- [**Configure optimus-manager**](#configure-optimus-manager)
- [**Enable required services**](#enable-required-services)
- [**Setup Guest OS**](#setup-guest-os)
- [**Install Windows**](#install-windows)
- [**Attaching PCI devices**](#attaching-pci-devices)
- [**Libvirt Hook Helper**](#libvirt-hook-helper)
- [**Config Libvirt Hooks**](#config-libvirt-hooks)
- [**Start/Stop Libvirt Hooks**](#startstop-libvirt-hooks)
- [**Keyboard/Mouse Passthrough**](#keyboardmouse-passthrough)
- [**Audio Passthrough**](#audio-passthrough)
- [**Video card driver virtualisation detection**](#video-card-driver-virtualisation-detection)
- [**CPU Pinning**](#cpu-pinning)
- [**Hyper-V Enlightenments**](#hyper-v-enlightenments)
- [**Disk Tuning**](#disk-tuning)
- [**Disable Memballoon**](#disable-memballoon)
- [**Only laptop with Nvidia card Tuning**](#only-laptop-with-nvidia-card-tuning)
- [**Hugepages**](#hugepages)
- [**CPU Governor**](#cpu-governor)
- [**Windows drivers**](#windows-drivers)
- [**Optimize Windows**](#optimize-windows)
- [**Enable Hyper-V**](#enable-hyper-v)
- [**Install looking-glass**](#install-looking-glass)

### **Enable & Verify IOMMU**

Ensure that ***AMD-Vi*** is supported by the CPU and enabled in the BIOS settings.

Enable IOMMU support by setting the kernel parameter for AMD CPU.

| /etc/default/grub                                              |
|----------------------------------------------------------------|
| `GRUB_CMDLINE_LINUX_DEFAULT="... amd_iommu=on iommu=pt iomem=relaxed ..."`   |

Generate grub.cfg
```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

When rebooting, go in the BIOS configuration, for the graphics/MUX configuration, I use "Switchable graphics". 
Yes, even if HDMI and usb-c are only connected to the Nvidia card.

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
IOMMU Group 10:
	01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106M [GeForce RTX 3060 Mobile / Max-Q] [10de:2560] (rev a1)
	01:00.1 Audio device [0403]: NVIDIA Corporation Device [10de:228e] (rev a1)
```

### **Install required tools**

```sh
pacman -S --needed qemu libvirt edk2-ovmf virt-manager dnsmasq ebtables vim yay linuxxxx-nvidia
```
You can replace iptables with iptables-nft if asked. linuxxxx-nvidia refers to your kernel version, ex: linux516-nvidia 

```sh
yay -S optimus-manager
```

Add yourself in the libvirt group so you can access to virt-manager without admin permission and autologin if you want to autologin when lightdm restarts :
```sh
sudo usermod -aG libvirt,autologin your_username
```

### **Configure optimus-manager**
in /usr/share/optimus-manager.conf :
```sh
[optimus]
...
pci_remove=yes
...
startup_mode=integrated
...
auto_logout=no
```

### **Enable required services**

```sh
systemctl enable --now libvirtd
systemctl start libvirtd
```

Start the default network manually.
```sh
virsh net-start default
virsh net-autostart default
```

Enable optimus-manager (needs reboot)
```sh
systemctl enable optimus-manager
```

### **Setup Guest OS**

If you want the best performance for your system when gaming, I highly recommend you to try [AtlasOS](https://atlasos.net/). It's a custom Windows 10 OS which highly upgrades performance on the system by removing many Windows Tools and decreases the space needed for the installation. Only one bad news, you won't be able to have Windows Updates. If you need to update, you will have to reinstall.

Download [virtio](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) driver.

Create your storage volume with the ***raw*** format. Select ***Customize before install*** on Final Step. 

| In Overview                                                                |
|:---------------------------------------------------------------------------|
| set **Chipset** to **Q35**                                                 |
| set **Firmware** to **UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd** |

WARNING: Click on "Apply" each time you switch panels in virt-manager

| In CPUs                                              |
|:-----------------------------------------------------|
| set **CPU model** to **host-passthrough**            |
| set **CPU Topology** match your cpu topology -1 core |

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

Windows can't detect the ***virtio disk***, so you need to ***Load Driver*** and select `virtio-iso/amd64/win10` when prompted.

Windows can't connect to the internet, we will activate internet later in this tutorial.

### **Attaching PCI devices**

The devices you want to passthrough.

| In Add PCI Host Device          |
|:--------------------------------|
| *PCI Host devices for your GPU* |

| In Add USB Host Device  |
|:------------------------|
| *Add whatever you want* |

| Remove          |
|:----------------|
| `Display spice` |
| `Channel spice` |
| `Video QXL`     |
| `Tablet`        |
| `USB redirect *`|

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
VM_MEMORY=24576

# VIRSH
VIRSH_GPU_VIDEO=pci_0000_01_00_0
VIRSH_GPU_AUDIO=pci_0000_01_00_1
```

</td>
</tr>
</table>

`VM_MEMORY` in MiB is the memory allocated tho the guest.

Make sure to substitute the correct bus addresses for the devices you'd like to passthrough to your VM.
Just in case it's still unclear, you get the virsh PCI device IDs from the [Enable & Verify IOMMU](#enable-verify-iommu) script.
Translate the address for each device as follows: IOMMU `Group 1 01:00.0 ...` --> `VIRSH_...=pci_0000_01_00_0`.

### **Start/Stop Libvirt Hooks**

This command will set the variable KVM_NAME so you can execute the rest of the commands without changing the name of the VM.

```sh
KVM_NAME="YOUR_VM_NAME"
```

**If the scripts are not working, use the scripts as template and write your own.**

My hardware for this scripts is:
- *AMD Ryzen 7 5800H with Radeon Graphics*
- *NVIDIA Corporation GA106M [GeForce RTX 3060 Mobile / Max-Q]*

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
systemctl set-property --runtime -- user.slice AllowedCPUs=0,1
systemctl set-property --runtime -- system.slice AllowedCPUs=0,1
systemctl set-property --runtime -- init.scope AllowedCPUs=0,1

# OPTIONAL: Only if you want looking glass last install step
# Create looking glass shm
systemd-tmpfiles --create /etc/tmpfiles.d/10-looking-glass.conf

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
systemctl set-property --runtime -- user.slice AllowedCPUs=0-15
systemctl set-property --runtime -- system.slice AllowedCPUs=0-15
systemctl set-property --runtime -- init.scope AllowedCPUs=0-15

# Unload VFIO-PCI Kernel Driver
modprobe -r vfio_pci
modprobe -r vfio_iommu_type1
modprobe -r vfio

# Re-Bind GPU to Nvidia Driver
virsh nodedev-reattach $VIRSH_GPU_VIDEO
virsh nodedev-reattach $VIRSH_GPU_AUDIO

# Avoid race condition
sleep 2

# Restart lightdm with nvidia
optimus-manager --switch hybrid --no-confirm
systemctl restart lightdm

# OPTIONAL : Only if you install looking-glass in the last step
# Delete looking glass shm
rm /dev/shm/looking-glass

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

Note: I don't passtrough the keyboard and mouse in case of looking-glass usage. It will be managed by Spice

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

Add yourself in the KVM group:
```sh
usermod -aG kvm your_username
```

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

### **Audio Passthrough**

This section is only useful if you use the looking-glass client. If not, in [Attaching PCI devices](#attaching-pci-devices) add your **Audio Controller** in `Add PCI Host Device`. 

VM's audio can be routed to the host. You need **Pulseaudio** (or **Pipewire** with *pipewire-pulse*).

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
      ...
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

My setup is an AMD Ryzen 7 5800H with Radeon Graphics which has 8 physical cores and 16 threads (2 threads per core).

<details>
  <summary><b>How to bind the threads to the core</b></summary>

It's very important that when we passthrough a core, we include its sibling. To get a sense of your cpu topology, use the command `lscpu -e`. A matching core id (i.e. "CORE" column) means that the associated threads (i.e. "CPU" column) run on the same physical core.

```
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE    MAXMHZ    MINMHZ      MHZ
  0    0      0    0 0:0:0:0          oui 3200,0000 1200,0000 1300.000
  1    0      0    0 0:0:0:0          oui 3200,0000 1200,0000 1200.000
  2    0      0    1 1:1:1:0          oui 3200,0000 1200,0000 1409.897
  3    0      0    1 1:1:1:0          oui 3200,0000 1200,0000 1297.473
  4    0      0    2 2:2:2:0          oui 3200,0000 1200,0000 1200.000
  5    0      0    2 2:2:2:0          oui 3200,0000 1200,0000 1200.000
  6    0      0    3 3:3:3:0          oui 3200,0000 1200,0000 1200.000
  7    0      0    3 3:3:3:0          oui 3200,0000 1200,0000 1200.000
  8    0      0    4 4:4:4:0          oui 3200,0000 1200,0000 1200.000
  9    0      0    4 4:4:4:0          oui 3200,0000 1200,0000 1200.000
 10    0      0    5 5:5:5:0          oui 3200,0000 1200,0000 1300.000
 11    0      0    5 5:5:5:0          oui 3200,0000 1200,0000 1200.000
 12    0      0    6 6:6:6:0          oui 3200,0000 1200,0000 1200.000
 13    0      0    6 6:6:6:0          oui 3200,0000 1200,0000 1200.000
 14    0      0    7 7:7:7:0          oui 3200,0000 1200,0000 1200.000
 15    0      0    7 7:7:7:0          oui 3200,0000 1200,0000 1200.000
```

According to the logic seen above, here are my core and their threads binding.

```
Core 1: 0, 1
Core 2: 2, 3
Core 3: 4, 5
Core 4: 6, 7
Core 5: 8, 9
Core 6: 10, 11
Core 7: 12, 13
Core 8: 14, 15
```

</details>

In this example, I want to get 1 core for the host and 7 cores for the guest. 
I will let the ***core 1*** for my host, so ***0*** and ***1*** are the logical threads.

I show you the final result, everything will be explained below.

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
  <vcpu placement='static'>14</vcpu>
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
    <vcpupin vcpu="10" cpuset="12"/>
    <vcpupin vcpu="11" cpuset="13"/>
    <vcpupin vcpu="12" cpuset="14"/>
    <vcpupin vcpu="13" cpuset="15"/>
    <emulatorpin cpuset="0-1"/>
    <iothreadpin iothread="1" cpuset="0-1"/>
  </cputune>
  ...
</domain>
```

</td>
</tr>
</table>

<details>
  <summary><b>Explanations of cpu pinning</b></summary>

  <table>
  <tr>
  <td>
  Number of threads to passthrough
  </td>
  </tr>

  <tr>
  <td>

```xml
<vcpu placement="static">14</vcpu>
```

  </td>
  </tr>
  </table>

  <table>
  <tr>
  <td>
  Same number as the iothreadpin below
  </td>
  </tr>

  <tr>
  <td>

```xml
<iothreads>1</iothreads>
```

  </td>
  </tr>
  </table>

  <table>
  <tr>
  <td>
  cpuset corresponds to the bindings of your host core
  </td>
  </tr>

  <tr>
  <td>

```xml
<cputune>
  ...
  <emulatorpin cpuset="0-1"/>
  <iothreadpin iothread="1" cpuset="0-1"/>
</cputune>
```

  </td>
  </tr>
  </table>

  <table>
  <tr>
  <td>
  vcpu corresponds to the guest cores, increment by 1 starting with 0.

  cpuset correspond to your threads you want to passthrough. It is necessary that your core and their threads binding follow each other.
  </td>
  </tr>
  </table>
</details>

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
    <topology sockets="1" dies="1" cores="7" threads="2"/>
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
    <qemu:arg value="host,host-cache-info=on,kvm=off,l3-cache=on,kvm-hint-dedicated=on,migratable=no,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=deadbeef,hv_vendor_id=AMD,+invtsc,+topoext"/>
  </qemu:commandline>
</devices>
```

</td>
</tr>
</table>

### **Disk Tuning**

KVM and QEMU provide two paravirtualized storage backends:
- virtio-blk (default)
- virtio-scsi (new)

For virtio-blk, you need to replace the `driver` line by:

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

You have to make `queues` correspond to the number of ***vcpus*** you pass to the host. In my case ***14*** because I pass *7* cores with *2* threads per core. Remember the [CPU Pinning](#cpu-pinning) section.

```xml
...
<devices>
  ...
  <disk type="file" device="disk">
    <driver name="qemu" type="raw" cache="none" io="threads" discard="unmap" iothread="1" queues="14"/>
    ...
  </disk>
  ...
</devices>
...
```

</td>
</tr>
</table>

For virtio-scsi, follow [bryansteiner](https://github.com/bryansteiner/gpu-passthrough-tutorial/#----disk-tuning) tutorial.

### **Disable Memballoon**

The VirtIO memballoon device allows the host to reclaim memory from a running VM. However, this functionality comes at a performance cost, so you can disable it by editing the <memballoon> tag in your XML like so:

```xml
...
    <memballoon model="none"/>
...
```

### **Only laptop with Nvidia card Tuning**

Intel or AMD is the same so when you install nvidia driver,
you may have the dead `Code 43` and stay stuck on a maximum resolution of 800x600. You can have more information here: (https://asus-linux.org/wiki/vfio-guide/). It's because the driver searches for a battery on your laptop.
Yes, even in a VM

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

Download a fake bin for emulating battery at : https://asus-linux.org/files/vfio/acpitable.bin
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
  <memory unit="KiB">25165824</memory>
  <currentMemory unit="KiB">25165824</currentMemory>
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

### **Windows drivers**

To get the *network*, *sound*, *mouse* and *keyboard* working properly you need to install the drivers.

In `Device Manager` update *network*, *sound*, *mouse* and *keyboard* drivers with the local virtio iso `/path/to/virtio-driver`.


### **Optimize Windows**

#### *Windows debloater*

```powershell
iwr -useb https://git.io/debloat|iex
```

#### *Better performances*

In *Windows Settings*:
- set ***Power suply*** to ***Performances***

If you have and NVIDIA card, in *NVIDIA Control Panel*:
- set ***Texture filtering quality*** to ***High performance***
- set ***Power management mode*** to ***Max performance***

### **Enable Hyper-V**

Warning: I can't install it anymore, it ends with an infinite loop at boot time leading to try a recovery install. If you want to try, I recommend you to make a copy of your img/qcow2 file.

Enable Hyper-V using PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Enable the Hyper-V through Settings:

Search for `Turn Windows Features on or off`, select **Hyper-V** and click **Ok**.

### **Install looking-glass**

This part of the tutorial is only if you can't play with a second monitor or if you want to have the 2 options in all case. In my case, I created another Guest (VM) based on the previously created. I copied the XML file, changed the name, the uuid and the nvram file (See my XML examples on this repository). The new VM still uses the same IMG file for booting the Windows system so be careful to not start the 2 VM, that could breaks all your install.

First of all, you will need a dummy HDMI plug or you wont see anything in the looking-glass client. It costs less than 10 bucks on Internet.

Start the previously created Guest, install the latest [Guest application](https://looking-glass.io/downloads) on your Windows. At this time, I installed the B6 version from Bleeding Edge, see below. Stop the Guest

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

On the XML file of the Guest, add these lines to create a shared memory area for looking-glass

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
     <address type="pci" domain="0x0000" bus="0x10" slot="0x01" function="0x0"/>
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

Still on the Host, install looking-glass client :

```sh
yay -S looking-glass-git
```

Beware of the version installed or updated, it follows the `Bleeding Edge` version, reserved for the developpers.
On 6th november 2023, I have `looking glass client` version `B6.r51`. It is compatible with `looking glass host` version `B6-92` on Windows.
Maybe upper also, didn't try yet.

You can now plug the dummy HDMI plug and start the VM, in the terminal, to access the Windows Guest, type the following command, it will launch looking-glass and your VM should be running (no need to be root) :

```sh
# 97 is for rightCtrl key - sudo showkey  --keycodes 
looking-glass-client -m 97 -F input:grabKeyboardOnFocus input:rawMouse input:autoCapture
```

Have fun !
