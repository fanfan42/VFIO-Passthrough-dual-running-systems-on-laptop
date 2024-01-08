# Lenovo Thinkpad L14 Gen3

Remember, this mode of virtualization is "NOT" for gaming, I only use SR-IOV to create the new generation of virtualization on newest Intel CPU with integrated GPU to play old games which are not "AAA" games. You will have to tweak your games not just for bad graphics but also for 30 HZ/fps in all settings possible.

This tutorial is based on [Strongtz](https://github.com/strongtz/i915-sriov-dkms) work. I'm still "waiting" for the SR-IOV work from Intel promised in the 4th quarter 2023 (but not respected). The most unconvenient thing in my case is that I can't turn my Laptop in sleeping mode with the module activated (it freezes my system). But, many thanks to the strongtz repository and all my respects for their work. I use the Linux 6.1 LTS kernel for this setup. 

This tutorial works on a 12th Intel generation and probably the 13/14th

I play on a Windows 10 VM for RDP modified with AtlasOS and Windows 11 + Looking Glass also modified with AtlasOS (not mandatory, a Windows 10/11 VM can also do the work but I didn't test it)

### **Table Of Contents**
- [**Install required tools**](#install-required-tools)
- [**Enable IOMMU and SR-IOV**](#enable-iommu-and-SR-IOV)
- [**Enable required services**](#enable-required-services)
- [**Setup Guest OS**](#setup-guest-os)
- [**Install Windows**](#install-windows)
- [**Attaching PCI devices**](#attaching-pci-devices)
- [**Libvirt Hook Helper**](#libvirt-hook-helper)
- [**Config Libvirt Hooks**](#config-libvirt-hooks)
- [**Start/Stop Libvirt Hooks**](#startstop-libvirt-hooks)
- [**Audio Passthrough**](#audio-passthrough)
- [**CPU Pinning**](#cpu-pinning)
- [**Disk Tuning**](#disk-tuning)
- [**Hyper-V Enlightenments and others**](#hyper-v-enlightenments-and-others)
- [**Disable Memballoon**](#disable-memballoon)
- [**Hugepages**](#hugepages)
- [**CPU Governor**](#cpu-governor)
- [**Windows drivers**](#windows-drivers)
- [**Optimize Windows**](#optimize-windows)
- [**Optional Configure RDP on Windows Guest**](#optional-configure-rdp-on-windows-guest)
- [**Optional Configure Looking Glass and Idd Sample Driver**](#optional-configure-looking-glass-and-idd-sample-driver)

### **Install required tools**

```sh
pacman -S --needed qemu-base qemu-audio-pa qemu-hw-display-qxl qemu-chardev-spice qemu-audio-spice libvirt edk2-ovmf virt-manager dnsmasq ebtables sysfsutils vim htop remmina xfreerdp yay
```
You can replace iptables with iptables-nft if asked.

Note: remmina and xfreerdp are only needed for RDP use case. qemu-hw-display-qxl, qemu-chardev-spice and qemu-audio-spice can be removed when RDP installation works.

```sh
yay -S i915-sriov-dkms-git
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

### **Enable IOMMU and SR-IOV**

Ensure that ***Intel VT-d*** is supported by the CPU and enabled in the BIOS settings.

Enable IOMMU and intel SR-IOV support by setting these kernel parameters

| /etc/default/grub                                                                                              |
|----------------------------------------------------------------------------------------------------------------|
| `GRUB_CMDLINE_LINUX_DEFAULT="... intel_iommu=on iommu=pt i915.enable_guc=3 i915.max_vfs=7 i915.modeset=1 ..."` |

Generate grub.cfg
```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

Add some modules to load at boot in /etc/modules-load.d/modules.conf
```sh
vfio_iommu_type1
kvmgt
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

### **Setup Guest OS**

If you want the best performance for your system when gaming, I highly recommend you to try [AtlasOS](https://atlasos.net/). It's a custom Windows 10/11 OS which highly upgrades performance on the system by removing many Windows Tools and decreases the space needed for the installation. This mode is not mandatory but highly recommended, it's just for having the "best" OS for gaming in a VM. The installation for Atlas OS occurs after a clean installation and activation of Windows 10/11 VM, Professional Edition at least.

Download [virtio](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) driver.

Create your storage volume with the ***raw*** format. Select ***Customize before install*** on Final Step. 

| In Overview                                                                |
|:---------------------------------------------------------------------------|
| set **Chipset** to **Q35**                                                 |
| set **Firmware** to **UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd** |

Note:  **UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd** for Windows 11

| In CPUs                                                        |
|:---------------------------------------------------------------|
| set **CPU model** to **host-passthrough**                      |
| set **CPU Topology** to 1 socket, 4 cores and 2 Threads(*)     |

*My Intel Core 7 has 12 "cores/threads" but this kind of CPU is different from the previous generations we know since the Intel Core Pentium IV. I will explain it below.

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

Windows can't connect to the internet, we will activate internet later in this tutorial. For Windows 11 installation, when arriving to the point where asked to connect to the Internet, ignore it and press ***MAJ+F10***. It will open a command-line interface, type `OOBE\BYPASSNRO` and confirm. The system will reboot without asking you to configure Internet for the end of the installation.  

### **Attaching PCI devices**

You can find your VGA controller by typing the following command :
```sh
# lspci | grep VGA
00:02.0 VGA compatible controller: Intel Corporation Alder Lake-UP3 GT2 [UHD Graphics] (rev 0c)
```

In a terminal, become root, and launch the following command :
```sh
echo 1 > /sys/bus/pci/devices/pci0000\:00/0000\:00\:02.0/sriov_numvfs
```

The devices you want to passthrough :

| In Add PCI Host Device                                        |
|:--------------------------------------------------------------|
| 00:02.1, the device previously created from the above command |

| Remove/Update                                                          |
|:-----------------------------------------------------------------------|
| `Display spice` after configuring RDP / changed manually for Win11+LG  |
| `Channel spice`                                                        |
| `Video QXL`, Change it to `None`, after configuring RDP/Win11_LG       |
| `Tablet`                                                               |
| `USB redirect *`                                                       |

Note: When rebooting, the VM takes ~1 minute to boot, take your time and use Htop to "see" when the VM is really booting.

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

SRIOV_NUM_VFS=1
SRIOV_PCI=0000:00:02.0
```

</td>
</tr>
</table>

### **Start/Stop Libvirt Hooks**

The next command will set the variable KVM_NAME so you can execute the rest of the commands without changing the name of the VM.

```sh
KVM_NAME="YOUR_VM_NAME"
```

**If the scripts are not working, use the scripts as template and write your own.**

My CPU for these scripts is *12th Gen Intel(R) Core(TM) i7-1255U

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

# Instantiate VFS
echo "${SRIOV_NUM_VFS}" > "/sys/bus/pci/devices/$SRIOV_PCI/sriov_numvfs"

# Detach new PCI created
virsh nodedev-detach pci_0000_00_02_1

# Isolate host, careful, it follows my own CPU topology described below
systemctl set-property --runtime -- user.slice AllowedCPUs=0-1,4-5
systemctl set-property --runtime -- system.slice AllowedCPUs=0-1,4-5
systemctl set-property --runtime -- init.scope AllowedCPUs=0-1,4-5
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

# Delete VF
echo 0 > "/sys/bus/pci/devices/$SRIOV_PCI/sriov_numvfs"

# Deisolate host
systemctl set-property --runtime -- user.slice AllowedCPUs=0-11
systemctl set-property --runtime -- system.slice AllowedCPUs=0-11
systemctl set-property --runtime -- init.scope AllowedCPUs=0-11
```

  </td>
  </tr>
  </table>
</details>

### **Audio Passthrough**

Add yourself in the kvm group:
```sh
usermod -aG kvm your_username
```

Change the first line of the xml to (Don't apply the xml before adding anything relative to `<qemu:commandline>`, you will see below):

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

VM's audio can be routed to the host so you need **Pulseaudio**. Add/Modify these lines in the XML file :

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

My setup is a 12th Gen Intel(R) Core(TM) i7-1255U which has ***2 P-Cores*** hyperthreaded and ***8 E-Cores***.

<details>
  <summary><b>How to bind P-Cores and E-Cores</b></summary>

It's very important that when we passthrough a core, we include its sibling. To get a sense of your cpu topology, use the command `lscpu -e`. A matching core id (i.e. "CORE" column) means that the associated threads (i.e. "CPU" column) run on the same physical core.

```
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE    MAXMHZ   MINMHZ       MHZ
  0    0      0    0 0:0:0:0          oui 4700,0000 400,0000 1047,6160
  1    0      0    0 0:0:0:0          oui 4700,0000 400,0000  613,5020
  2    0      0    1 4:4:1:0          oui 4700,0000 400,0000  400,0000
  3    0      0    1 4:4:1:0          oui 4700,0000 400,0000  400,0000
  4    0      0    2 8:8:2:0          oui 3500,0000 400,0000  400,0000
  5    0      0    3 9:9:2:0          oui 3500,0000 400,0000  400,0000
  6    0      0    4 10:10:2:0        oui 3500,0000 400,0000  400,0000
  7    0      0    5 11:11:2:0        oui 3500,0000 400,0000  400,0000
  8    0      0    6 12:12:3:0        oui 3500,0000 400,0000  400,0000
  9    0      0    7 13:13:3:0        oui 3500,0000 400,0000  400,0000
 10    0      0    8 14:14:3:0        oui 3500,0000 400,0000  400,0000
 11    0      0    9 15:15:3:0        oui 3500,0000 400,0000  400,0000
```

According to the logic seen above, here are my cores and their threads binding.

```
P-Core 1: 0, 1
P-Core 2: 2, 3
E-Core 1: 4
E-Core 2: 5
...
```

</details>

In this example, I want to get 1 P-core with his thread and 2 E-Core for the host and all the others for the guest. 
I will let the ***P-Core 1*** for my host, so ***0*** and ***1*** are the logical threads. Also, I let ***E-Core 1*** and ***E-Core 2*** for the host.

Here is the result :

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
  <vcpu placement='static'>8</vcpu>
  <iothreads>1</iothreads>
  <cputune>
    <vcpupin vcpu='0' cpuset='2'/>
    <vcpupin vcpu='1' cpuset='3'/>
    <vcpupin vcpu='2' cpuset='6'/>
    <vcpupin vcpu='3' cpuset='7'/>
    <vcpupin vcpu='4' cpuset='8'/>
    <vcpupin vcpu='5' cpuset='9'/>
    <vcpupin vcpu='6' cpuset='10'/>
    <vcpupin vcpu='7' cpuset='11'/>
    <emulatorpin cpuset='0-1,4-5'/>
    <iothreadpin iothread='1' cpuset='0-1,4-5'/>
  </cputune>
  ...
</domain>
```

</td>
</tr>
</table>

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
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='4' threads='2'/> # You can also set only cores, I don't "see" any difference in performance
    <cache mode='passthrough'/>
    <feature policy='require' name='topoext'/>
  </cpu>
  ...
</domain>
```

</td>
</tr>
</table>

### **Hyper-V Enlightenments and others**

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
  <features>
  <hyperv mode='custom'>
      ...
      <vendor_id state='on' value='GenuineIntel'/>
    </hyperv>
    ...
  </features>
  <qemu:commandline>
    ...
    <qemu:arg value="-rtc"/>
    <qemu:arg value="base=localtime"/>
    <qemu:arg value="-cpu"/>
    <qemu:arg value="host,host-cache-info=on,kvm=off,l3-cache=on,kvm-hint-dedicated=on,migratable=no,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,hv_vendor_id=GuenineIntel,+invtsc,+topoext"/>
  </qemu:commandline>
</devices>
```

</td>
</tr>
</table>

At this step, you can apply your xml configuration.

### **Disk Tuning**

KVM and QEMU provide two paravirtualized storage backends:
- virtio-blk (used here)
- virtio-scsi (new)

<table>
<tr>
<th>
XML
</th>
</tr>

<tr>
<td>

You have to make `queues` correspond to the number of ***vcpus*** you pass to the host. In my case ***8***, remember the [CPU Pinning](#cpu-pinning) section.

```xml
...
<devices>
  ...
  <disk type="file" device="disk">
    <driver name="qemu" type="raw" cache="none" io="threads" discard="unmap" iothread="1" queues="8"/>
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
  <memory unit='KiB'>12582912</memory>
  <currentMemory unit='KiB'>12582912</currentMemory>
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

To get the *network* working properly you need to install the drivers.

In `Device Manager` update *network* drivers with the local virtio iso `/path/to/virtio-driver`.

### **Optimize Windows**

#### *Windows debloater*

If you don't want to install AtlasOS, you can still use this script in PowerShell to optimize your Windows guest (tested only on Windows 10). I personnally don't use it since AtlasOS removes nearly everything this script does.
```powershell
iwr -useb https://git.io/debloat|iex
```

#### *Better performances*

In *Windows Settings*:
- set ***Power supply*** to ***Performances***

Note: Not necessary when AtlasOS installed, it's already done.

### **Optional Configure RDP on Windows Guest**

Select Start > Settings > System > Remote Desktop, and turn on Enable Remote Desktop.

Select Search > gpedit.msc:

<ul>
	<li>Computer Configuration/Administrative Templates/Windows Components/Remote Desktop Services/Remote Desktop Session Host/Remote Session Environment/Use the hardware default graphics adapter for all Remote Desktop Services sessions > Edit > Enabled > OK</li>
	<li>.../Remote Session Environment/Limit maximum color depth > Edit > Enabled and set it to 32 bits > OK</li>
	<li>.../Remote Session Environment/Enforce Removal of Remote Desktop Wallpaper > Edit > Enabled > OK</li>
	<li>.../Remote Session Environment/Limit maximum display resolution > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Limit number of monitors > Edit > Enabled and set to 1 > OK</li>
	<li>.../Remote Session Environment/Remove "Disconnect" option from Shut Down Dialog > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Remove Windows Security from Start Menu > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Use advanced RemoteFX graphics for RemoteApp > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Prioritize H.264/AVC 444 graphics mode for Remote Desktop > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Configure H.264/AVC hardware encoding for Remote Desktop > Edit > Enabled > OK</li>
	<li>.../Remote Session Environment/Configure compression for RemoteFX data > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Configure image quality for RemoteFX Adaptive Graphics > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Enable RemoteFX encoding for RemoteFX clients designed for Windows Ser 2008 R2 SP1 > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/Configure RemoteFX Adaptive Graphics > Edit > Disabled > OK</li>
	<li>.../Remote Session Environment/use WDDM graphics display driver for Remote Desktop Connection > Edit > Enabled > OK</li>
	<li>Computer Configuration/Administrative Templates/Windows Components/Remote Desktop Services/Remote Desktop Session Host/Connexions/Select transfer protocols RDP > Edit > Enabled and select "Use UDP or TCP" </li>
</ul>

Disable all options in ***RemoteFX for Windows Server 2008 R2*** folder still in gpedit.msc

Now, configure remmina to connect to your virtual machine, I let my remmina conf in the folder. Compare it to yours in `/home/you/.local/share/remmina`

### **Configure Looking Glass and Idd Sample Driver**

Note : at this time HDR display is not supported on Windows 10, so I only tested it on Windows 11

#### *Idd Sample Driver*

Indirect Display Driver Sample creates a virtual display on Windows, it's needed to attach Looking Glass when using SR-IOV GPU. Go on [Virtual Display Driver](https://github.com/itsmikethetech/Virtual-Display-Driver) and download the latest release for Windows 11, with HDR support. Unzip the folder and copy `IddSampleDriver` directory in `C:\`. Go in the directory :

<ul>
	<li>Right-Click on "installCert.bat" > Execute with admin privileges > Close the window when finished</li>
    <li>Open "Device Manager" > Click on any device > Click on "Action" menu > "Add Legacy Hardware"</li>
	<li>Select "Add hardware from a list (Advanced)" > Select Display Adapters > Click "Have Disk..." > Browse > C:\IddSampleDriver\IddSampleDriver.inf</li>
</ul>

It's very important to understand that this vGPU is not powerful for gaming. On this example, I can only support a maximum of 30 HZ/fps as said before. So for the best performance:

<ul>
	<li>Go to "Settings" > "System" > "Display" > Activate "Use HDR" > I set the "Display resolution" to 1920x1080</li>
	<li>In "Advanced display" > "Choose a refresh rate" > 30Hz</li>
	<li>In "Graphics" > after installing games, set each game on "High performance"</li>
	<li>Still in "Graphics" > "Change default graphic settings" > set your vGPU in "Default high performance GPU" > Set "Auto HDR" to on</li>
</ul>

In `C:\IddSampleDriver\option.txt`, you can remove all unusable options, these are the ones I keep:

```
1
1280, 1024, 30
1360, 768, 30
1366, 768, 30
1400, 1050, 30
1440, 900, 30
1600, 900, 30
1680, 1050, 30
1600, 1024, 30
1920, 1080, 30

```

#### *Looking Glass*

Install the latest `Bleeding Edge` [Host application](https://looking-glass.io/downloads) on your Windows.

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

Add/Modify these lines to the XML file for configuring the graphics :

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
  ...
  <video>
    <model type="none"/>
  </video>
  ...
</devices>

```
</td>
</tr>
</table>

Still on the host, install looking-glass client :

```sh
yay -S looking-glass-git
```

To access the Windows Guest, in a terminal, type the following command, it will launch looking-glass and your VM should be running (no need to be root) :

```sh
# 97 is for rightCtrl key - sudo showkey  --keycodes 
looking-glass-client -m 97 -F input:grabKeyboardOnFocus input:rawMouse input:autoCapture
```


