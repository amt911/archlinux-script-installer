# archlinux-script-installer

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