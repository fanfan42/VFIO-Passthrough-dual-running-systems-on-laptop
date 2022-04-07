# VFIO-Passthrough-dual-running-systems-on-laptop
## Introduction

This repository has not the goal to be the most precise configuration for running Passthrough VM. It's just some success tests I tried on my own laptops. At this time, I can succesfully install a Windows 10 VM on :
Dual GPU PC :
- Lenovo Legion Y540-15IRH (with nvidia GTX 1660Ti)
- Lenovo Legion 5 17ACH6H (with nvidia RTX 3060)
Single GPU PC (intel, only from 6th to 9th generation):
- Lenovo Thinkpad E490
- Toshiba Satellite Pro A50-E-156

This repository is based the one created by Mageas at https://gitlab.com/Mageas/vfio-single-gup-passthrough so I keep all his greetings, thanks to all of you
The only real differences is that I install it on a laptop and it's not a Single GPU passthrough, I can use both my Linux and Windows 10

And of course, the link to the video : https://www.youtube.com/watch?v=CwEVj00SwYM.

The VM created is close to native performance with 3% of performance losses.

### **Thanks to**

**[Arch wiki](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF)**  
The best way to learn how GPU passthrough is working.

**[bryansteiner](https://github.com/bryansteiner/gpu-passthrough-tutorial)**  
The best tutorial on GPU passthrough!

**[QaidVoid](https://github.com/QaidVoid/Complete-Single-GPU-Passthrough)**  
The best tutorial to use VFIO!

**[joeknock90](https://github.com/joeknock90/Single-GPU-Passthrough)**  
Really good tutorial on the NVIDIA GPU patch.

**[SomeOrdinaryGamers](https://www.youtube.com/watch?v=BUSrdUoedTo)**  
Bring me in the VFIO community.

**[Zeptic](https://www.youtube.com/watch?v=VKh2eKPnmXs)**  
How to get good performances in nested virtualization.

**[Quentin Franchi](https://gitlab.com/dev.quentinfranchi/vfio)**  
The scripts for AMD GPUs.

