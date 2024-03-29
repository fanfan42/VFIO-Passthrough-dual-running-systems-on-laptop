# Lenovo Thinkpad E490

This mode cannot allow to play high-end graphics games but I can still play AOE II DE with the lowest graphics settings 

Update 6th november 2023, `qemu` version `8.1.1` has black screen bug after booting the VM (just after the "BIOS" boot).
`qemu` version `8.1.2` is available today on Manjaro. You can also downgrade to version `8.0.4`

### **Table Of Contents**
- [**Enable & Verify IOMMU and GVT**](#enable-verify-iommu-and-gvt)
- [**Install required tools**](#install-required-tools)
- [**Enable required services**](#enable-required-services)
- [**Setup Guest OS**](#setup-guest-os)
- [**Install Windows**](#install-windows)
- [**Attaching PCI devices**](#attaching-pci-devices)
- [**Libvirt Hook Helper**](#libvirt-hook-helper)
- [**Config Libvirt Hooks**](#config-libvirt-hooks)
- [**Start/Stop Libvirt Hooks**](#startstop-libvirt-hooks)
- [**Keyboard/Mouse Passthrough**](#keyboardmouse-passthrough)
- [**Audio Passthrough**](#audio-passthrough)
- [**CPU Pinning**](#cpu-pinning)
- [**Disk Tuning**](#disk-tuning)
- [**Hyper-V Enlightenments and others**](#hyper-v-enlightenments-and-others)
- [**Disable Memballoon**](#disable-memballoon)
- [**Hugepages**](#hugepages)
- [**CPU Governor**](#cpu-governor)
- [**Windows drivers**](#windows-drivers)
- [**Optimize Windows**](#optimize-windows)

### **Enable & Verify IOMMU and GVT**

Ensure that ***Intel VT-d*** is supported by the CPU and enabled in the BIOS settings.

Also, in Config -> Display -> Total Graphics Memory is set to the maximum, for me, it's 512 MB

Enable IOMMU and intel gvt-g support by setting the kernel parameters

| /etc/default/grub                                                                                           |
|-------------------------------------------------------------------------------------------------------------|
| `GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=on i915.enable_gvt=1 i915.enable_guc=0 i915.enable_fbc=0 ..."` |

Generate grub.cfg
```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

Add some modules to load at boot in /etc/modules-load.d/modules.conf
```sh
mdev
vfio_iommu_type1
kvmgt
```

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
IOMMU Group 1:
	00:02.0 VGA compatible controller [0300]: Intel Corporation WhiskeyLake-U GT2 [UHD Graphics 620] [8086:3ea0] (rev 02)
```

### **Install required tools**

```sh
pacman -S --needed qemu-base qemu-ui-gtk qemu-ui-opengl qemu-audio-pa libvirt edk2-ovmf virt-manager dnsmasq ebtables vim
```
You can replace iptables with iptables-nft if asked

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

### **Setup Guest OS**

If you want the best performance for your system when gaming, I highly recommend you to try [AtlasOS](https://atlasos.net/). It's a custom Windows 10 OS which highly upgrades performance on the system by removing many Windows Tools and decreases the space needed for the installation. Only one bad news, you won't be able to have Windows Updates. If you need to update, you will have to reinstall.

Download [virtio](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) driver.

Create your storage volume with the ***raw*** format. Select ***Customize before install*** on Final Step. 

| In Overview                                                                |
|:---------------------------------------------------------------------------|
| set **Chipset** to **Q35**                                                 |
| set **Firmware** to **UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd** |

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
https://wiki.archlinux.org/title/Intel_GVT-g#Prerequisite

in a terminal :

```sh
ls /sys/devices/pci/0000\:00\:02.0/mdev_supported_types
i915-GVTg_V5_2  # Video memory: <256MB, 1024MB>, resolution: up to 1920x1200, this mode only appears if total memory graphics in BIOS is set to 512 MB
i915-GVTg_V5_4  # Video memory: <128MB, 512MB>, resolution: up to 1920x1200
i915-GVTg_V5_8  # Video memory: <64MB, 384MB>, resolution: up to 1024x768

sudo -s
# uuidgen
echo 65e0c490-1f9f-47e2-87b4-3f3d14255b2f > /sys/bus/pci/devices/i915-GVTg_V5_4/create
```

The devices you want to passthrough.

| In Add PCI Host Device          |
|:--------------------------------|
| *PCI Host devices for your GPU* |

| In Add MDEV Host Device                     |
|:--------------------------------------------|
| *the device created in cmd line just before |

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
#

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
VM_MEMORY=12288

GVT_GUID=65e0c490-1f9f-47e2-87b4-3f3d14255b2f
MDEV_TYPE=i915-GVTg_V5_2
GVT_PCI=0000:00:02.0
```

</td>
</tr>
</table>

`VM_MEMORY` in MiB is the memory allocated to the guest.

### **Start/Stop Libvirt Hooks**

This command will set the variable KVM_NAME so you can execute the rest of the commands without changing the name of the VM.

```sh
KVM_NAME="YOUR_VM_NAME"
```

**If the scripts are not working, use the scripts as template and write your own.**

My hardware for this scripts are:
- *Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz* (Lenovo Thinkpad E490)
- *Intel(R) Core(TM) i5-10210U CPU @ 1.60GHz* (Lenovo Thinkpad L14)

But you will no difference in the following tuto between the two CPU

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

# Isolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0,4
systemctl set-property --runtime -- system.slice AllowedCPUs=0,4
systemctl set-property --runtime -- init.scope AllowedCPUs=0,4

echo "$GVT_GUID" > "/sys/bus/pci/devices/$GVT_PCI/mdev_supported_types/$MDEV_TYPE/create"
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
systemctl set-property --runtime -- user.slice AllowedCPUs=0-7
systemctl set-property --runtime -- system.slice AllowedCPUs=0-7
systemctl set-property --runtime -- init.scope AllowedCPUs=0-7

echo 1 > "/sys/bus/pci/devices/$GVT_PCI/$GVT_GUID/remove"
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

Add yourself in the input group :
```sh
usermod -aG input your_username
``` 
Find your mouse device in ***/dev/input/by-id***. You'd generally use the devices ending with ***event-mouse***. And the devices in your configuration right before closing `</domain>` tag.

You can verify if it works by `cat /dev/input/by-id/DEVICE_NAME`.

Replace ***MOUSE_NAME*** with your device id.

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
    <qemu:arg value='-object'/>
    <qemu:arg value='input-linux,id=mouse1,evdev=/dev/input/by-id/MOUSE_NAME'/>
  </qemu:commandline>
</domain>
```

</td>
</tr>
</table>

At this time. you can apply the xml file. From now, apply each time the xml is changed.

Add yourself in the kvm group:
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
  ...
</devices>
...
```

</td>
</tr>
</table>

### **Audio Passthrough**

This section is only useful if you intend to use the audio output from your GPU. If not, in [Attaching PCI devices](#attaching-pci-devices) add your **Audio Controller** in `Add PCI Host Device`.

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

### **CPU Pinning**

My setup is an Intel(R) Core(TM) i5-8265U CPU @ 1.60GHz which has 4 physical cores and 8 threads (2 threads per core).

<details>
  <summary><b>How to bind the threads to the core</b></summary>

It's very important that when we passthrough a core, we include its sibling. To get a sense of your cpu topology, use the command `lscpu -e`. A matching core id (i.e. "CORE" column) means that the associated threads (i.e. "CPU" column) run on the same physical core.

```
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE    MAXMHZ   MINMHZ      MHZ
  0    0      0    0 0:0:0:0          oui 3900,0000 400,0000 1800.000
  1    0      0    1 1:1:1:0          oui 3900,0000 400,0000 1800.000
  2    0      0    2 2:2:2:0          oui 3900,0000 400,0000 1800.000
  3    0      0    3 3:3:3:0          oui 3900,0000 400,0000 1800.000
  4    0      0    0 0:0:0:0          oui 3900,0000 400,0000 2544.018
  5    0      0    1 1:1:1:0          oui 3900,0000 400,0000 1800.000
  6    0      0    2 2:2:2:0          oui 3900,0000 400,0000 1800.000
  7    0      0    3 3:3:3:0          oui 3900,0000 400,0000 1800.000
```

According to the logic seen above, here are my core and their threads binding.

```
Core 1: 0, 4
Core 2: 1, 5
Core 3: 2, 6
Core 4: 3, 7
```

</details>

In this example, I want to get 1 core for the host and 3 cores for the guest. 
I will let the ***core 1*** for my host, so ***0*** and ***4*** are the logical threads.

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
  <vcpu placement='static'>6</vcpu>
  <iothreads>1</iothreads>
  <cputune>
    <vcpupin vcpu='0' cpuset='1'/>
    <vcpupin vcpu='1' cpuset='5'/>
    <vcpupin vcpu='2' cpuset='2'/>
    <vcpupin vcpu='3' cpuset='6'/>
    <vcpupin vcpu='4' cpuset='3'/>
    <vcpupin vcpu='5' cpuset='7'/>
    <emulatorpin cpuset='0,4'/>
    <iothreadpin iothread='1' cpuset='0,4'/>
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
<vcpu placement="static">6</vcpu>
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
  <emulatorpin cpuset="0,4"/>
  <iothreadpin iothread="1" cpuset="0,4"/>
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

  <tr>
  <td>

```xml
  <cputune>
    <vcpupin vcpu='0' cpuset='1'/>
    <vcpupin vcpu='1' cpuset='5'/>
    <vcpupin vcpu='2' cpuset='2'/>
    <vcpupin vcpu='3' cpuset='6'/>
    <vcpupin vcpu='4' cpuset='3'/>
    <vcpupin vcpu='5' cpuset='7'/>
    ...
  </cputune>
```

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
    <topology sockets="1" dies="1" cores="3" threads="2"/>
    <cache mode="passthrough"/>
    <feature policy="require" name="topoext"/>
  </cpu>
  ...
</domain>
```

</td>
</tr>
</table>

### **Hyper-V Enlightenments and others**
When you will add the MDEV device, you will lose all display with a classic QXL display
There are several ways to have the display working. I chose DMA-BUF. For other ways or more explanation, please read this link:https://wiki.archlinux.org/title/Intel_GVT-g#Using_DMA-BUF_display

In a terminal:
```sh
wget https://web.archive.org/web/20201020144354/http://120.25.59.132:3000/vbios_gvt_uefi.rom
```

In order to know your current display:
```sh
echo $DISPLAY # ex: :O
```

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
    <qemu:arg value="host,host-cache-info=on,kvm=off,l3-cache=on,kvm-hint-dedicated=on,migratable=no,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=deadbeef,+invtsc,+topoext"/>
    <qemu:arg value='-display'/>
    <qemu:arg value='gtk,gl=on,zoom-to-fit=on'/>
    <qemu:env name='INTEL_DEBUG' value='norbc'/>
    <qemu:env name='DISPLAY' value=':0'/>
  </qemu:commandline>
  <qemu:override>
    <qemu:device alias='hostdev0'>
      <qemu:frontend>
        <qemu:property name='x-igd-opregion' type='bool' value='true'/>
        <qemu:property name='romfile' type='string' value='/whereever/your/path/vbios_gvt_uefi.rom'/>
        <qemu:property name='ramfb' type='bool' value='true'/>
        <qemu:property name='driver' type='string' value='vfio-pci-nohotplug'/>
        <qemu:property name='display' type='string' value='on'/>
      </qemu:frontend>
    </qemu:device>
  </qemu:override>
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

You have to make `queues` correspond to the number of ***vcpus*** you pass to the host. In my case ***6*** because I pass *3* cores with *2* threads per core. Remember the [CPU Pinning](#cpu-pinning) section.

```xml
...
<devices>
  ...
  <disk type="file" device="disk">
    <driver name="qemu" type="raw" cache="none" io="threads" discard="unmap" iothread="1" queues="6"/>
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
  <memory unit="KiB">12582912</memory>
  <currentMemory unit="KiB">12582912</currentMemory>
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

## Enable CPU governor on-demand mode
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
