# archlinux-script-installer

## NOTE: TEMPORARY FIXES:

- Added to /etc/profile some lines to use the NVIDIA GPU on Wayland sessions.

## NOTE 2: THINGS TO WATCH OUT FOR:
- Enabled NVIDIA fbdev: This led to a black screen in the past if you start a VM with GPU and USB Passthrough, then stop and after that there will be a black screen.

## NOTE 3: Things to do
- Investigate about ```nvidia-powerd.service``` since it does not work on my laptop with an RTX 2080.
- The following packages from WINE do not compile and install:
    - Bad packages: 
    - lib32-gst-plugins-bad -> lib32-libcdio-exit lib32-zvbi-exit
    - lib32-gst-plugins-ugly
    - lib32-gst-libav
    - lib32-ffmpeg -> ffmpeg version too low
<!-- - Remove ```--nocheck``` from WINE installation. -->

## Disclaimer
**THIS IS ONLY INTENDED FOR PERSONAL USE!**

The scripts are not fully automated as I would like and they do very cuestionable things to setup the system, such as:

- Modifying ```sudo``` without ```visudo```.
- Rebooting the system without asking first more than once.
- Missing some error checking.

## Introduction

This repository is a collection of scripts used to install ArchLinux (almost) unattended, adjusting to my personal configuration, which is:

- BTRFS with subvolumes as the filesystem.
- Automatic snapshots using ```snapper```.
- GRUB or systemd-boot as the bootloader.
- Encrypted BTRFS filesystem using a password and a keyfile stored in external media.
- Using KDE Plasma as the default Desktop Environment.
- If using a laptop with NVIDIA Graphics, it uses ```envycontrol``` as the switching command.