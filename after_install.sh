#!/bin/bash

readonly SHELLS_SUDO=("zsh" "fish" "sudo")
readonly TRUE=0
readonly FALSE=1
readonly VIRTIO_MODULES=("virtio-net" "virtio-blk" "virtio-scsi" "virtio-serial" "virtio-balloon")
readonly KVM_SUBVOL=("@var_lib_libvirt" "/mnt/var/lib/libvirt")
# TODO
# DONE https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
# ROOTLESS SDDM UNDER WAYLAND
# KVM -> lsmod | grep kvm. Pone que hay que iniciarlos manualmente. Revisar por si.
# add_sentence_end_quote y el otro. Junstarlos en uno solo.
# PONER EN LOS PAQUETES DOSFSTOOLS

# GLOBAL VARS
# tty_layout
# has_swap
# swap_part
# boot_part
# root_part
# has_encryption
# DM_NAME
# machine_name
# is_intel
# is_laptop

# Asks for something to do in this script.
# 
# $1: Question to be displayed. It should not have a colon nor space at the end since it is appended.
#
# return: 0 if yes, 1 if no in $?.
ask(){
    local -r QUESTION="$1"
    local done="$FALSE"
    local ans
    local res

    while [ "$done" -eq "$FALSE" ]
    do
        echo -n "$QUESTION (y/n): "
        read -r ans

        case $ans in
            y|Y|[yY][eE][sS] )
                res="$TRUE"
                done="$TRUE"
                ;;
            n|N|[nN][oO] )
                res="$FALSE"
                done="$TRUE"
                ;;
            * )
                echo "other case"
                ;;
        esac
    done

    return "$res"
}

# $1: Pattern to find
# $2: Text to add
# $3: filename
# $4: is double quote (TRUE/FALSE)
# note: If you need to use "/", the put it like \/
add_sentence_end_quote(){
    # sed "/^example=/s/\"$/ adios\"/" example

    local -r PATTERN="$1"
    local -r NEW_TEXT="$2"
    local -r FILENAME="$3"
    local quote='\"'

    [ "$4" -eq "$FALSE" ] && quote="'"


    sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
}

# $1: Pattern to find
# $2: Text to add
# $3: filename
# $4: end quote
# note: If you need to use "/", the put it like \/
add_sentence_2(){
    # sed "/^example=/s/\"$/ adios\"/" example

    local -r PATTERN="$1"
    local -r NEW_TEXT="$2"
    local -r FILENAME="$3"
    local quote="$4"



    sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
}

enable_reisub(){
    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " sysrq_always_enabled=1" "/etc/default/grub" "$TRUE"

    grub-mkconfig -o /boot/grub/grub.cfg
}

enable_trim(){
    if [ -z "$has_encryption" ];
    then
        ask "Does it have encryption?"
        has_encryption="$?"
    fi

    pacman --noconfirm -S util-linux
    systemctl enable fstrim.timer

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=discard" "/etc/default/grub" "$TRUE"
        grub-mkconfig -o /boot/grub/grub.cfg 
    fi
}

install_shells(){
    pacman --noconfirm -S "${SHELLS_SUDO[@]}"

    sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

    echo "Check if everything is OK"
    grep -i "%wheel" /etc/sudoers
}

add_users(){
    local adduser_done="$TRUE"
    local username
    # local is_sudo
    local shell
    local passwd_ok="$FALSE"

    while [ "$adduser_done" -eq "$TRUE" ]
    do

        echo -n "Username: "
        read -r username

        echo "Available shells:"
        cat /etc/shells

        echo -n "Select a shell: "
        read -r shell

        if ask "Do you want this user to be part of the sudo (wheel) group?";
        then
            useradd -m -G wheel -s "$shell" "$username"
        else
            useradd -m -s "$shell" "$username"
        fi

        passwd_ok="$FALSE"

        while [ "$passwd_ok" -eq "$FALSE" ]
        do
            echo "Now you will be asked to type a password for the new user"
            passwd "$username"


            if [ "$?" -ne "$TRUE" ];
            then
                passwd_ok="$FALSE"
            else
                passwd_ok="$TRUE"
            fi
        done


        ask "Do you want to add another user?"
        adduser_done="$?"
    done
}

improve_pacman(){
    sed -i "s/^#Parallel/Parallel/" /etc/pacman.conf
    sed -i "s/^#Color/Color/" /etc/pacman.conf

    echo "These are the changed lines:"
    grep "Parallel" /etc/pacman.conf
    grep -E "^Color" /etc/pacman.conf
}

enable_multilib(){
    # awk 'BEGIN {num=20; first="#[h]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' example
    awk 'BEGIN {num=2; first="#[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' /etc/pacman.conf > /etc/pacman.conf.TMP && mv /etc/pacman.conf.TMP /etc/pacman.conf

    pacman --noconfirm -Syu
    
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg

    echo "Check changes:"
    awk 'BEGIN {num=2; first="[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){print $0;num--;entered="true"}' /etc/pacman.conf
}

enable_reflector(){
    pacman --noconfirm -S reflector
    systemctl enable reflector.timer
}

btrfs_scrub(){
    systemctl enable btrfs-scrub@-.timer
}

prepare_for_aur(){
    # Mejorar aqui el make para que sea multinucleo
    pacman --noconfirm -S base-devel git

    # https://wiki.archlinux.org/title/makepkg#Parallel_compilation
    # Enable multi-core compilation
    awk 'BEGIN { OFS=FS="="; name="#MAKEFLAGS" } {if($1==name){sub(/#/,""); $2="\"-j$(nproc)\""}};1' /etc/makepkg.conf > /etc/makepkg.tmp && mv /etc/makepkg.tmp /etc/makepkg.conf

    echo "Check changes: "
    grep "MAKEFLAGS=" /etc/makepkg.conf
    echo ""
}

install_bluetooth(){
    echo "Installing bluetooth..."
    pacman --noconfirm -S bluez bluez-utils

    lsmod | grep -i btusb
    local -r EXIT_CODE="$?"

    if [ "$EXIT_CODE" -eq "$FALSE" ];
    then
        echo "btusb module not loaded. Creating file to load it..."

        modprobe btusb

        echo "btusb" > /etc/modules-load.d/bluetooth.conf 
    fi

    systemctl enable bluetooth.service
    systemctl start bluetooth.service
}

enable_ntfs(){
    echo "Installing ntfs-3g..."
    pacman --noconfirm -S ntfs-3g

#     https://wiki.archlinux.org/title/NTFS
}

install_optional_pkgs(){
true
}

cpu_type(){
    if [ -z "$is_intel" ];
    then
        ask "Is it an Intel CPU?"
        is_intel="$?"
    fi

    return "$is_intel"
}

check_machine(){
    ask "Is this machine a laptop?"
    is_laptop="$?"
}

install_cpu_scaler(){
    # To implement on a real machine
#     watch cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq
# Firtst, ask if it is AMD CPU: amd_pstate=guided
# https://docs.kernel.org/admin-guide/pm/amd-pstate.html
# https://gitlab.freedesktop.org/upower/power-profiles-daemon#power-profiles-daemon
#     if [ -z "$is_intel" ];
#     then
#         ask "Is it an Intel CPU?"
#         is_intel="$?"
#     fi

    cpu_type

    pacman --noconfirm -S powerdevil power-profiles-daemon python-gobject

    echo "Enabling and starting service..."
    systemctl enable power-profiles-daemon.service
    systemctl start power-profiles-daemon.service

    if [ "$is_intel" -eq "$FALSE" ];
    then
        echo "Adding AMD P-State driver..."
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " amd_pstate=active" "/etc/default/grub" "$TRUE"
        grub-mkconfig -o /boot/grub/grub.cfg
    fi

    echo "You need to reboot for changes to take effect"
}

# This function needs a reboot
enable_hw_acceleration(){
    # To implement on a real machine
    echo "Enabling hardware acceleration..."

    cpu_type
    check_machine

#     Diagnostic tool
    pacman --noconfirm -S libva-utils vdpauinfo

#     Installation of NVIDIA codecs by default.
    echo "Installing codecs for NVIDIA GPU..."
    pacman --noconfirm -S libva-nvidia-driver

    echo "Checking if VA-API works on NVIDIA..."

    if ! vainfo;
    then
        echo "Creating environment variables..."

        if [ "$is_laptop" -eq "$TRUE" ];
        then
            echo "
#Mi config
if [ \$(envycontrol -q | awk '{print \$NF}') = \"nvidia\" ];
then
    export LIBVA_DRIVER_NAME=nvidia
    export MOZ_DISABLE_RDD_SANDBOX=1
    export NVD_BACKEND=direct
fi" >> /etc/profile

        else
            echo "LIBVA_DRIVER_NAME=nvidia" >> /etc/environment
            echo "NVD_BACKEND=direct" >> /etc/environment
            echo "MOZ_DISABLE_RDD_SANDBOX=1" >> /etc/environment
        fi

    else
        echo "Working correctly, there is nothing to do."
    fi


    if [ "$is_laptop" -eq "$TRUE" ];
    then
        echo "Installing VA-API for Intel CPU..."
        pacman --noconfirm -S intel-media-driver libvdpau-va-gl
    fi

    echo "Please reboot your system for changes to take effect."
}

install_firewall(){
    echo "Installing firewall..."
    pacman --noconfirm -S ufw gufw

    echo "Enabling and starting ufw.service..."
    systemctl enable ufw.service
    systemctl start ufw.service

    ufw enable

#     https://wiki.archlinux.org/title/Uncomplicated_Firewall#Basic_configuration
    ufw default deny
    ufw allow from 192.168.0.0/24
    ufw limit ssh
}

install_xorg(){
    ask "Is this machine a laptop?"
    is_laptop="$?"


    pacman --noconfirm -S xorg nvidia lib32-nvidia-utils

    if [ "$is_laptop" -eq "$TRUE" ];
    then
        echo "CHECK IF THESE PACKAGES ARE CORRECT!"
        sleep 3
        pacman --noconfirm -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel

    else
        # https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
        echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf
        echo "options nvidia_drm fbdev=1" >> /etc/modprobe.d/nvidia.conf
        # To check if it is working: 
        # cat /sys/module/nvidia_drm/parameters/modeset
    fi

    # I do not disable kms HOOK because nvidia-utils blacklists nouveau by default.
}

install_kde(){
    # Aqui se deberia aplicar el fix para que sea xorg rootless
    echo "Installing KDE Plasma..."
    pacman --noconfirm -S plasma-meta plasma-wayland-session 

    if ask "Do you want to install extra applications for KDE?";
    then
        pacman --noconfirm -S kde-graphics-meta kde-system-meta kde-utilities-meta kde-multimedia-meta
    fi

    systemctl enable sddm.service

    if ask "You need to reboot. Reboot?";
    then
        touch /root/after_install.tmp
        reboot
    fi
}

install_gnome(){
true
}

install_kvm(){
    # Aqui hay que crear el subvolumen libvirt
    # Aqui tambien hay que recordar instalar tpm
#     Huge pages, iommu, nested virt, tpm, uefi,
    echo "Installing KVM..."

    lsmod | grep kvm
    local -r MODPROBE_KVM="$?"

    if [ "$MODPROBE_KVM" -gt "0" ];
    then
        echo "Error. Cant use KVM. Exiting..."
        return "$FALSE"
    fi

    local modprobe_cpu
    local cpu_string="kvm_amd"

    cpu_type

    [ "$is_intel" -eq "$TRUE" ] && cpu_string="kvm_intel"

    lsmod | grep "$cpu_string"
    modprobe_cpu="$?"

    if [ "$modprobe_cpu" -gt "0" ];
    then
        echo "Error. Not loaded CPU specific KVM. Exiting."
        return "$FALSE"
    fi

#     Checking if virtio modules are loaded
    local virtio_status

    lsmod | grep virtio
    virtio_status="$?"

    if [ "$virtio_status" -gt "0" ];
    then
        echo "Virtio modules are not loaded. Loading and creating them..."

        truncate -s0 /etc/modules-load.d/virtio.conf

        for i in "${VIRTIO_MODULES[@]}"
        do
            modprobe "$i"
            echo "$i" >> /etc/modules-load.d/virtio.conf
        done
        unset i
    fi

#     Now to the nested virtualization
    modprobe -r "$cpu_string"
    modprobe "$cpu_string" nested=1

#     Create file to enable nested virtualization
    echo "options $cpu_string nested=1" > /etc/modprobe.d/nested_virt.conf

#     QEMU part
    pacman --noconfirm -S qemu-full qemu-block-gluster qemu-block-iscsi samba qemu-guest-agent qemu-user-static

#     UEFI Support
    echo "Installing packages for UEFI and TPM Support..."
    pacman --noconfirm -S edk2-ovmf swtpm

#     IOMMU
    echo "Setting up IOMMU..."
    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " iommu=pt" "/etc/default/grub" "$TRUE"

    if [ "$is_intel" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " intel_iommu=on" "/etc/default/grub" "$TRUE"
    fi

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg

#     Libvirt installation
    echo "Installing libvirt..."

    pacman -S libvirt
    pacman -S --asdeps iptables-nft dnsmasq openbsd-netcat dmidecode
    pacman -S virt-manager

#     Setting up libvirt authentication
    local more_users="$TRUE"
    local user
    local users_array=()

    while [ "$more_users" -eq "$TRUE" ]
    do
        echo -n "Type a user to add to libvirt group: "
        read -r user

        users_array=("${users_array[@]}" "$user")

        ask "Do you want to add another user?"
        more_users="$?"
    done

    for i in "${users_array[@]}"
    do
        echo "Adding $i"
        gpasswd -a "$i" libvirt
    done
    unset i

    echo "Starting daemons..."
    systemctl start libvirtd.service
    systemctl start virtlogd.service

    systemctl enable libvirtd.service
}

install_printer(){
    echo "Installing printer service..."

    pacman --noconfirm -S cups cups-pdf

    echo "Enabling CUPS socket..."
    systemctl enable cups.socket

    echo "Installing scanner (SANE) packages..."
    pacman --noconfirm -S sane
    pacman --noconfirm --asdeps -S sane-airscan

    ask "Do you want to install Simple Scan?" && pacman --noconfirm -S simple-scan
}

install_ms_fonts(){
true
}

install_lsd(){
    # Aqui se debe instalar lsd y la fuente nerd
    true
}

btrfs_snapshots(){
    # Aqui debe ir el hook de pacman
    true
}

disable_ssh_service(){
    systemctl disable sshd.service
    sed -i "s/^PermitRootLogin yes/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
}

get_sudo_user(){
    grep -E "^wheel" /etc/gshadow | cut -d: -f4 | cut -d, -f1
}

install_yay(){
    # https://stackoverflow.com/questions/5560442/how-to-run-two-commands-with-sudo
    local -r USER=$(get_sudo_user)

    sudo -S -i -u "$USER" git clone https://aur.archlinux.org/yay.git "/home/$USER/yay"

    # https://unix.stackexchange.com/questions/176997/sudo-as-another-user-with-their-environment
    sudo -S -i -u "$USER" bash -c "cd \"/home/$USER/yay\" && makepkg -sri"

    echo "Configuring yay..."
    sudo -S -i -u "$USER" yay -Y --gendb
    sudo -S -i -u "$USER" yay -Syu --devel
    sudo -S -i -u "$USER" yay -Y --devel --save 

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg
}

enable_crypt_keyfile(){
    echo "Enabling keyfile at boot..."

    ask "If your pendrive inserted? If not, insert it now."

    local drive
    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -n "Select drive: "
        read -r drive

        ask "You have selected $drive. Is that OK?"
        is_done="$?"
    done

    if ask "Do you want to reformat/repartition drive?";
    then
        cfdisk "$drive"
        sleep 2
    fi

    is_done="$FALSE"
    local part
    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -n "Select partition: "
        read -r part

        ask "You have selected $part. Is that OK?"
        is_done="$?"
    done

    local fs_type
    local selected_module

    local is_wrong="$FALSE"

    is_done="$FALSE"
    while [ "$is_done" -eq "$FALSE" ]
    do
        echo "
Select one of the following options:
    1) ext4
    2) fat32
    3) btrfs"

        read -r fs_type
        case $fs_type in
            "ext4"|"1")
                is_wrong="$FALSE"
                selected_module="ext4"
                ;;
            "fat32"|"2")
                is_wrong="$FALSE"
                selected_module="vfat"
                ;;
            "btrfs"|"3")
                is_wrong="$FALSE"
                selected_module="btrfs"
                ;;
            *)
                is_wrong="$TRUE"
                echo "Wrong filesystem."
                ;;
        esac

        if [ "$is_wrong" -eq "$FALSE" ];
        then
            ask "You have selected $selected_module. Is that OK?"
            is_done="$?"
        fi
    done

    echo "Formatting partition..."

    case "$selected_module" in
        "ext4")
            mkfs.ext4 "$part"
            ;;
        "vfat")
            pacman --noconfirm -S dosfstools
            mkfs.fat -F32 "$part"
            ;;
        "btrfs")
            mkfs.btrfs -L pen "$part"
            ;;
        *)
            echo "Unknown error."
            return 1
            ;;
    esac

#     Asking for the encrypted partition
    is_done="$FALSE"
    local sys_part
    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -n "Type encrypted partition: "
        read -r sys_part

        ask "You have selected $disk_part. Is that correct?"
        is_done="$?"
    done

#     Creating the keyfile
    mount $part /mnt
    dd bs=512 count=4 if=/dev/random of="$part/keyfile" iflag=fullblock
    cryptsetup luksAddKey "$sys_part" "$part/keyfile"

#     Adding the modules on mkinitcpio
    add_sentence_2 "^MODULES=" "$selected_module" "/etc/mkinitcpio.conf" ")"
    mkinitcpio -P



    local -r ROOT_UUID=$(blkid -s UUID -o value /dev/$DM_NAME)
}

# CHECK FOR ROOTLESS WAYLAND!!!
rootless_kde(){
    local -r RESULT=$(ps -o user= -C Xorg)

    echo "Making SDDM Rootless..."

    if [ "$RESULT" = "root" ];
    then
        echo "Creating file..."

        mkdir /etc/sddm.conf.d

        echo "[General]" > /etc/sddm.conf.d/rootless-x11.conf
        echo "DisplayServer=x11-user" >> /etc/sddm.conf.d/rootless-x11.conf
    else
        echo "Already running in rootless mode."
    fi
}

cleanup(){
    rm -rf /root/after_install.tmp
}

is_encrypted(){
    ask "Is the system encrypted?"
    has_encryption="$?"
}

# Laptop specific functions
enable_envycontrol(){
true
}

laptop_extra_config(){
    # aqui va la configuracion de los altavoces y eso
    true
}

main(){
    if [ "$#" -eq "0" ];
    then
        ask "Do you want to have REISUB?" && enable_reisub
        ask "Do you want to enable TRIM?" && enable_trim
        install_shells
        add_users
        ask "Do you want to parallelize package downloads and color them?" && improve_pacman
        ask "Do you want to enable the multilib package (Steam)?" && enable_multilib
        ask "Do you want to enable reflector timer to update mirrorlist?" && enable_reflector
        ask "Do you want to enable scrub?" && btrfs_scrub
        ask "Do you want to install the dependencies to use the AUR and enable parallel compilation?" && prepare_for_aur
        ask "Do you want to install an AUR helper?" && install_yay
        ask "Do you want to install bluetooth service?" && install_bluetooth

        # CHECK INSTALL_XORG ON LAPTOP. 
        ask "Do you want to install Xorg and graphics driver?" && install_xorg

    if [ ! -f "/root/after_install.tmp" ];
    then
        ask "Do you want to install KDE?" && install_kde
    else
        # CHECK FOR ROOTLESS WAYLAND!!!
        rootless_kde
    fi
        ask "Do you want to install a cpu scaler?" && install_cpu_scaler
    ask "Do you want to install the printer service?" && install_printer
    ask "Do you want to install a firewall?" && install_firewall

#     PENSAR EN SI PONER LA REGLA UDEV
    ask "Do you want to install NTFS driver?" && enable_ntfs

    #     CHECK IN THE FUTURE THE DAEMONS, THEY ARE SPLITTING THEM
        ask "Do you want to install KVM?" && install_kvm
        ask "Do you want to enable hardware acceleration?" && enable_hw_acceleration
    fi

    is_encrypted

#     CONTINUAR CON LA GUIA
    [ "$has_encryption" -eq "$TRUE" ] && ask "Do you want to store a keyfile to decrypt system?" && enable_crypt_keyfile

    echo "BOOT INTO ARCHISO, MOUNT FILESYSTEM AND EXECUTE /mnt/root/last_step.sh"
    echo "Please enable on boot in virt manager the default network by going into Edit->Connection details->Virtual Networks->default."
    echo "It is normal for colord.service to fail. You can restart the service, but it won't make a difference."
    echo "You need to follow https://github.com/elFarto/nvidia-vaapi-driver/#environment-variables to configure Firefox HW ACC."
        # IN PROCESS
    # IMPORTANTE NO OLVIDAR
    # disable_ssh_service
}

main "$@"
