# archlinux-script-installer

## Introduction

This repository is a collection of scripts used to install ArchLinux (almost) unattended and to create VMs passing the only NVIDIA GPU. It adjusts to my personal configuration, which is:

- Multiple filesystem configurations:
  - Encrypted (with the possibility of decrypting using a pendrive) and unencrypted systems.
  - EXT4 or BTRFS with subvolumes as the filesystem.
- Automatic snapshots using ```snapper``` (if you chose btrfs as the filesystem).
- GRUB or systemd-boot as the bootloader.
- Using KDE Plasma as the default (and only for now) Desktop Environment.
- If using a laptop with NVIDIA Graphics, it uses ```envycontrol``` as the switching command.

## Disclaimer
**THIS IS ONLY INTENDED FOR PERSONAL USE!**

The scripts are not fully automated as I would like and they do very cuestionable things to setup the system, such as:

- Modifying ```sudo``` without ```visudo```.
- Missing some error checking.
  

### NOTE: TEMPORARY FIXES:
---
- Added to ```/etc/profile``` some lines to use the NVIDIA GPU on Wayland sessions.

### NOTE 2: Things to do
---
- Investigate about ```nvidia-powerd.service``` since it does not work on my laptop with an RTX 2080.
- The following packages from WINE do not compile and install:
    - Bad packages: 
    - lib32-gst-plugins-bad -> lib32-libcdio-exit lib32-zvbi-exit
    - lib32-gst-plugins-ugly
    - lib32-gst-libav
    - lib32-ffmpeg -> ffmpeg version too low
- Think about how to install only the incremental changes on already installed systems.
