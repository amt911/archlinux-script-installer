# archlinux-script-installer

## NOTE: TEMPORARY FIXES:
- Disabled NVIDIA fbdev: This must be disabled because it can lead to a black screen if you start a VM with GPU and USB Passthrough, then stop and after that there will be a black screen.
- Added to /etc/profile some lines to use the NVIDIA GPU on Wayland sessions.

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
- GRUB as the bootloader.
- Encrypted BTRFS filesystem using a password and a keyfile stored in external media.
- Using KDE Plasma as the default Desktop Environment.
- If using a laptop with NVIDIA Graphics, it uses ```envycontrol``` as the switching command.