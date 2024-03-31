#!/bin/bash

readonly OPTIONAL_PKGS=("btdu" "meld" "compsize" "shellcheck" "neofetch" "gparted" "bc" "wget" "dosfstools" "iotop-c" "less" "nano" "man-db" "git" "optipng" "oxipng" "pngquant" "imagemagick" "veracrypt" "gimp" "inkscape" "tldr" "fzf" "lsd" "bat" "keepassxc" "shellcheck" "btop" "htop" "ufw" "gufw" "fdupes" "firefox" "rebuild-detector" "reflector" "sane" "sane-airscan" "simple-scan" "evince" "qbittorrent" "fdupes" "gdu" "unzip" "visual-studio-code-bin")

# COMPROBAR LA INSTALACION DE ESTE PAQUETE, LE FALTAN LAS FUENTES
readonly LIBREOFFICE_PKGS=("libreoffice-fresh" "libreoffice-extension-texmaths" "libreoffice-extension-writer2latex")
readonly LIBREOFFICE_PKGS_DEPS=("hunspell" "hunspell-es_es" "hyphen" "hyphen-es" "libmythes" "mythes-es")
readonly TEXLIVE_PKGS=("texlive" "texlive-lang")
readonly TEXLIVE_PKGS_DEPS=("biber")

# for i in "/run/media/user/Ventoy/scripts"/*; do ln -sf "$i" "/root/$(echo $i | cut -d/ -f7)"; done

source common-functions.sh

readonly SHELLS_SUDO=("zsh" "fish" "sudo")
readonly VIRTIO_MODULES=("virtio-net" "virtio-blk" "virtio-scsi" "virtio-serial" "virtio-balloon")
# TODO
# ROOTLESS SDDM UNDER WAYLAND
# KVM -> lsmod | grep kvm. Pone que hay que iniciarlos manualmente. Revisar por si.
# add_sentence_end_quote y el otro. Junstarlos en uno solo.
# Asegurar que al menos un usuario esta en el grupo wheel

# $1 (optional): Message to be displayed.
ask_reboot(){
    local -r MSG="${1:-"You need to reboot."}"

    if ask "$MSG";
    then
        reboot
    else
        echo -e "${BRIGHT_CYAN}You need to manually reboot.${NO_COLOR}"
    fi
}

# $1 (optional: true/false): Install GRUB? Defaults to yes, so it installs GRUB and generates config file.
redo_grub(){
    local -r INSTALL="${1:-$TRUE}"

    colored_msg "Reinstalling GRUB..." "${BRIGHT_CYAN}" "#"

    [ "$INSTALL" -eq "$TRUE" ] && grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg
}

enable_reisub(){
    colored_msg "Enabling REISUB..." "${BRIGHT_CYAN}" "#"

    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " sysrq_always_enabled=1" "/etc/default/grub" "$TRUE" "$TRUE"

    redo_grub "$FALSE"
}

enable_trim(){
    colored_msg "Enabling TRIM..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S util-linux
    systemctl enable fstrim.timer

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=discard" "/etc/default/grub" "$TRUE" "$TRUE"
        redo_grub "$FALSE"
    fi
}

install_shells(){
    colored_msg "Installing shells..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S "${SHELLS_SUDO[@]}"

    sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

    echo -e "${BRIGHT_CYAN}Check if everything is OK${NO_COLOR}"
    grep -i "%wheel" /etc/sudoers
    sleep 3
}

add_users(){
    colored_msg "User creation." "${BRIGHT_CYAN}" "#"

    local adduser_done="$TRUE"
    local username
    local shell
    local passwd_ok="$FALSE"

    while [ "$adduser_done" -eq "$TRUE" ]
    do

        echo -n "Username: "
        read -r username

        echo -e "${BRIGHT_CYAN}Available shells:${NO_COLOR}"
        cat /etc/shells

        echo -ne "${BRIGHT_CYAN}Select a shell: ${NO_COLOR}"
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
            echo -e "${BRIGHT_CYAN}Now you will be asked to type a password for the new user${NO_COLOR}"
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
    colored_msg "Improving pacman performance..." "${BRIGHT_CYAN}" "#"

    sed -i "s/^#Parallel/Parallel/" /etc/pacman.conf
    sed -i "s/^#Color/Color/" /etc/pacman.conf

    echo -e "${BRIGHT_CYAN}These are the changed lines:${NO_COLOR}"
    grep "Parallel" /etc/pacman.conf
    grep -E "^Color" /etc/pacman.conf
    sleep 3
}

enable_multilib(){
    colored_msg "Enabling multilib repository..." "${BRIGHT_CYAN}" "#"

    awk 'BEGIN {num=2; first="#[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' /etc/pacman.conf > /etc/pacman.conf.TMP && mv /etc/pacman.conf.TMP /etc/pacman.conf

    pacman --noconfirm -Syu
    
    redo_grub

    echo -e "${BRIGHT_CYAN}Check changes:${NO_COLOR}"
    awk 'BEGIN {num=2; first="[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){print $0;num--;entered="true"}' /etc/pacman.conf
    sleep 3
}

enable_reflector(){
    colored_msg "Enabling reflector..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S reflector
    systemctl enable reflector.timer
}

btrfs_scrub(){
    colored_msg "Enabling btrfs scrub on root subvolume..." "${BRIGHT_CYAN}" "#"

    systemctl enable btrfs-scrub@-.timer
}

prepare_for_aur(){
    colored_msg "Preparing system for AUR packages..." "${BRIGHT_CYAN}" "#"

    # Mejorar aqui el make para que sea multinucleo
    pacman --noconfirm -S base-devel git

    # https://wiki.archlinux.org/title/makepkg#Parallel_compilation
    # Enable multi-core compilation
    awk 'BEGIN { OFS=FS="="; name="#MAKEFLAGS" } {if($1==name){sub(/#/,""); $2="\"-j$(nproc)\""}};1' /etc/makepkg.conf > /etc/makepkg.tmp && mv /etc/makepkg.tmp /etc/makepkg.conf

    echo -e "${BRIGHT_CYAN}Check changes: ${NO_COLOR}"
    grep "MAKEFLAGS=" /etc/makepkg.conf
    echo ""
    sleep 3
}

install_bluetooth(){
    colored_msg "Installing bluetooth..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S bluez bluez-utils

    lsmod | grep -i btusb
    local -r EXIT_CODE="$?"

    if [ "$EXIT_CODE" -eq "$FALSE" ];
    then
        echo -e "${RED}btusb module not loaded.${NO_COLOR} ${BRIGHT_CYAN}Creating file to load it...${NO_COLOR}"

        modprobe btusb

        echo "btusb" > /etc/modules-load.d/bluetooth.conf 
    fi

    systemctl enable bluetooth.service
    systemctl start bluetooth.service
}

# https://wiki.archlinux.org/title/NTFS
enable_ntfs(){
    colored_msg "Installing NTFS-3G drivers..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S ntfs-3g
}

get_sudo_user(){
    grep -E "^wheel" /etc/gshadow | cut -d: -f4 | cut -d, -f1
}

install_optional_pkgs(){
    colored_msg "Installing optional packages..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)

    sudo -S -i -u "$USER" yay -S "${OPTIONAL_PKGS[@]}"

    if ask "Do you want to install LibreOffice?";
    then
        sudo -S -i -u "$USER" yay -S "${LIBREOFFICE_PKGS[@]}"
        sudo -S -i -u "$USER" yay -S --asdeps "${LIBREOFFICE_PKGS_DEPS[@]}"
    fi

    if ask "Do you want to install TexLive (LaTeX)?";
    then
        sudo -S -i -u "$USER" yay -S "${TEXLIVE_PKGS[@]}"
        sudo -S -i -u "$USER" yay -S --asdeps "${TEXLIVE_PKGS_DEPS[@]}"
    fi
}

install_cpu_scaler(){
    # To implement on a real machine
#     watch cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq
# Firtst, ask if it is AMD CPU: amd_pstate=active
# https://docs.kernel.org/admin-guide/pm/amd-pstate.html
# https://gitlab.freedesktop.org/upower/power-profiles-daemon#power-profiles-daemon

    colored_msg "Installing cpu scaler..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S powerdevil power-profiles-daemon python-gobject

    echo -e "${BRIGHT_CYAN}Enabling and starting service...${NO_COLOR}"
    systemctl enable power-profiles-daemon.service
    systemctl start power-profiles-daemon.service

    if [ "$is_intel" -eq "$FALSE" ];
    then
        echo -e "${BRIGHT_CYAN}Adding AMD P-State driver...${NO_COLOR}"
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " amd_pstate=active" "/etc/default/grub" "$TRUE" "$TRUE"
        redo_grub "$FALSE"
    fi
}

enable_hw_acceleration(){
    colored_msg "Enabling hardware acceleration..." "${BRIGHT_CYAN}" "#"

    # Diagnostic tools
    pacman --noconfirm -S libva-utils vdpauinfo nvtop

    local i
    for i in "${gpu_type[@]}"
    do
        case $i in
            "nvidia")
                # Installation of NVIDIA codecs
                echo -e "${BRIGHT_CYAN}Installing codecs for NVIDIA GPU...${NO_COLOR}"
                pacman --noconfirm -S libva-nvidia-driver nvidia-settings

                echo -e "${BRIGHT_CYAN}Creating environment variables...${NO_COLOR}"

                # It is mandatory to set the environment variables.
                if [ "$is_laptop" -eq "$TRUE" ];
                then
                    echo "
# Mi config
if [ \$(envycontrol -q | awk '{print \$NF}') = \"nvidia\" ];
then
    export LIBVA_DRIVER_NAME=nvidia
    export MOZ_DISABLE_RDD_SANDBOX=1
    export NVD_BACKEND=direct
fi" >> /etc/profile

                else
                    echo "LIBVA_DRIVER_NAME=nvidia
NVD_BACKEND=direct
MOZ_DISABLE_RDD_SANDBOX=1" >> /etc/environment
                fi
                ;;

            "intel")
                echo -e "${BRIGHT_CYAN}Installing VA-API for Intel CPU...${NO_COLOR}"
                pacman --noconfirm -S intel-gpu-tools intel-media-driver libvdpau-va-gl
                ;;

            *)
                echo -e "${RED}Unknown error. Exiting...${NO_COLOR}"
                exit 1
                ;;
        esac
    done
}

install_firewall(){
    colored_msg "Installing firewall..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S ufw gufw

    echo -e "${BRIGHT_CYAN}Enabling and starting ufw.service...${NO_COLOR}"
    systemctl enable ufw.service
    systemctl start ufw.service

    ufw enable

    # https://wiki.archlinux.org/title/Uncomplicated_Firewall#Basic_configuration
    ufw default deny
    ufw allow from 192.168.0.0/24
    ufw limit ssh
}

install_xorg(){
    local i
    for i in "${gpu_type[@]}"
    do
        case $i in
            "amd")
                echo -e "${BRIGHT_CYAN}WIP since I do not have an AMD GPU. Exiting...${NO_COLOR}"
                exit 0
                ;;

            "intel")
                echo -e "${BRIGHT_CYAN}Installing Intel drivers...${NO_COLOR}"
                echo -e "${YELLOW}CHECK IF THESE PACKAGES ARE CORRECT!${NO_COLOR}"
                sleep 3
                pacman --noconfirm -S mesa lib32-mesa vulkan-intel lib32-vulkan-intel
                ;;
            
            "nvidia")
                echo -e "${BRIGHT_CYAN}Installing nvidia drivers...${NO_COLOR}"
                pacman --noconfirm -S xorg nvidia lib32-nvidia-utils

                if [ "$is_laptop" -eq "$FALSE" ];
                then
                    # https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
                    echo "options nvidia_drm modeset=1" > /etc/modprobe.d/nvidia.conf
                    echo "options nvidia_drm fbdev=1" >> /etc/modprobe.d/nvidia.conf
                    # To check if it is working: 
                    # cat /sys/module/nvidia_drm/parameters/modeset
                fi
                ;;
            *)
                echo -e "${RED}Unknown error. Exiting...${NO_COLOR}"
                exit 1
        esac
    done
    unset i

    # I do not disable kms HOOK because nvidia-utils blacklists nouveau by default.
}

install_kde(){
    colored_msg "Installing KDE Plasma..." "${BRIGHT_CYAN}" "#"

    # Aqui se deberia aplicar el fix para que sea xorg rootless
    pacman --noconfirm -S plasma-meta

    if ask "Do you want to install extra applications for KDE?";
    then
        pacman --noconfirm -S kde-graphics-meta kde-system-meta kde-utilities-meta kde-multimedia-meta
    fi

    systemctl enable sddm.service

    add_global_var_to_file "is_kde" "$TRUE" "$VAR_FILE_LOC"
}

install_gnome(){
    colored_msg "Installing GNOME..." "${BRIGHT_CYAN}" "#"
    add_global_var_to_file "is_kde" "$FALSE" "$VAR_FILE_LOC"
    echo "WIP"
}

# Huge pages, iommu, nested virt, tpm, uefi,
install_kvm(){
    colored_msg "Installing KVM..." "${BRIGHT_CYAN}" "#"

    lsmod | grep kvm
    local -r MODPROBE_KVM="$?"

    if [ "$MODPROBE_KVM" -gt "0" ];
    then
        echo -e "${RED}Error. Cant use KVM. Exiting...${NO_COLOR}"
        return "$FALSE"
    fi

    local modprobe_cpu
    local cpu_string="kvm_amd"

    [ "$is_intel" -eq "$TRUE" ] && cpu_string="kvm_intel"

    lsmod | grep "$cpu_string"
    modprobe_cpu="$?"

    if [ "$modprobe_cpu" -gt "0" ];
    then
        echo -e "${RED}Error. Not loaded CPU specific KVM. Exiting.${NO_COLOR}"
        return "$FALSE"
    fi

    # Checking if virtio modules are loaded
    local virtio_status

    lsmod | grep virtio
    virtio_status="$?"

    if [ "$virtio_status" -gt "0" ];
    then
        echo -e "${RED}Virtio modules are not loaded.${NO_COLOR} ${BRIGHT_CYAN}Loading and creating them...${NO_COLOR}"

        truncate -s0 /etc/modules-load.d/virtio.conf

        for i in "${VIRTIO_MODULES[@]}"
        do
            modprobe "$i"
            echo "$i" >> /etc/modules-load.d/virtio.conf
        done
        unset i
    fi

    # Now to the nested virtualization
    modprobe -r "$cpu_string"
    modprobe "$cpu_string" nested=1

    # Create file to enable nested virtualization
    echo "options $cpu_string nested=1" > /etc/modprobe.d/nested_virt.conf

    # QEMU part
    pacman --noconfirm -S qemu-full qemu-block-gluster qemu-block-iscsi samba qemu-guest-agent qemu-user-static

    # UEFI Support
    echo -e "${BRIGHT_CYAN}Installing packages for UEFI and TPM Support...${NO_COLOR}"
    pacman --noconfirm -S edk2-ovmf swtpm

    # IOMMU
    echo -e "${BRIGHT_CYAN}Setting up IOMMU...${NO_COLOR}"
    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " iommu=pt" "/etc/default/grub" "$TRUE" "$TRUE"

    if [ "$is_intel" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " intel_iommu=on" "/etc/default/grub" "$TRUE" "$TRUE"
    fi

    redo_grub

    # Libvirt installation
    echo -e "${BRIGHT_CYAN}Installing libvirt...${NO_COLOR}"

    pacman -S libvirt
    pacman -S --asdeps iptables-nft dnsmasq openbsd-netcat dmidecode
    pacman -S virt-manager

    # Setting up libvirt authentication
    local more_users="$TRUE"
    local user
    local users_array=()

    while [ "$more_users" -eq "$TRUE" ]
    do
        echo -ne "${YELLOW}Type a user to add to libvirt group (empty to skip adding a user): ${NO_COLOR}"
        read -r user

        [ -n "$user" ] && users_array=("${users_array[@]}" "$user")

        ask "Do you want to add another user?"
        more_users="$?"
    done

    for i in "${users_array[@]}"
    do
        echo -e "${BRIGHT_CYAN}Adding $i${NO_COLOR}"
        gpasswd -a "$i" libvirt
    done
    unset i

    echo -e "${BRIGHT_CYAN}Starting daemons...${NO_COLOR}"
    systemctl start libvirtd.service
    systemctl start virtlogd.service

    systemctl enable libvirtd.service
}

install_printer(){
    colored_msg "Installing printer service..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S cups cups-pdf

    echo -e "${BRIGHT_CYAN}Enabling CUPS socket...${NO_COLOR}"
    systemctl enable cups.socket

    echo -e "${BRIGHT_CYAN}Installing scanner (SANE) packages...${NO_COLOR}"
    pacman --noconfirm -S sane
    pacman --noconfirm --asdeps -S sane-airscan

    ask "Do you want to install Simple Scan?" && pacman --noconfirm -S simple-scan
}

install_ms_fonts(){
    colored_msg "Installing Microsoft Fonts..." "${BRIGHT_CYAN}" "#"

    local is_7z_installed="$TRUE"

    pacman -Qi p7zip
    is_7z_installed="$?"

    [ "$is_7z_installed" -eq "$FALSE" ] && pacman --noconfirm -S p7zip

    # In case the image is in another partition
    ask "Is the Windows ISO on another drive?"
    local -r OTHER_DRIVE="$?"
    local drive
    local is_done="$FALSE"

    if [ "$OTHER_DRIVE" -eq "$TRUE" ];
    then
        while [ "$is_done" -eq "$FALSE" ]
        do
            lsblk
            echo -ne "${YELLOW}Please type partition: ${NO_COLOR}"
            read -r drive

            ask "You have selected $drive. Is that correct?"
            is_done="$?"
        done
    fi

    mount "$drive" /mnt -o ro,noexec

    local location
    is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        echo -ne "${YELLOW}Please type location: ${NO_COLOR}"
        read -r location

        if [ -f "$location" ];
        then
            ask "Image exists. Do you want to continue?"
            is_done="$?"
        else
            echo -e "${RED}File does not exist at this location:${NO_COLOR} $location"
        fi
    done

    # Now we need to copy the iso to another location
    echo -e "${BRIGHT_CYAN}Copying ISO to another folder...${NO_COLOR}"
    cp "$location" /root

    # We now unmount the drive since we dont need it anymore
    umount /mnt

    # We extract the contents of the ISO
    local -r ISO_LOCATION=$(echo "$location" | awk 'BEGIN{ OFS=FS="/" } { print "/root",$NF }')
    7z e "$ISO_LOCATION" sources/install.wim
    7z e install.wim 1/Windows/{Fonts/"*".{ttf,ttc},System32/Licenses/neutral/"*"/"*"/license.rtf} -ofonts/

    mkdir -p /usr/local/share/fonts/WindowsFonts
    cp /root/fonts/* /usr/local/share/fonts/WindowsFonts/
    chmod 644 /usr/local/share/fonts/WindowsFonts/*

    fc-cache --force
    fc-cache-32 --force

    echo -e "${BRIGHT_CYAN}Deleting Windows image and tmp directories...${NO_COLOR}"
    rm -r "$ISO_LOCATION" "/root/install.wim /root/fonts"

    [ "$is_7z_installed" -eq "$FALSE" ] && pacman -Rs p7zip
}

install_lsd(){
    colored_msg "Installing lsd and a nerd font..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S lsd ttf-hack-nerd
}

btrfs_snapshots(){
    colored_msg "Installing snapper and snap-pac..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S snapper snap-pac

    snapper -c root create-config /

    echo -e "${BRIGHT_CYAN}Deleting default snapper layout...${NO_COLOR}"

    btrfs subvolume delete /.snapshots
    mkdir /.snapshots

    local part="/dev/$DM_NAME"

    [ "$has_encryption" -eq "$TRUE" ] && part="/dev/mapper/$DM_NAME"

    mount "$part" /mnt -o compress-force=zstd
    btrfs subvolume create /mnt/@snapshots

    echo "$part /.snapshots btrfs compress-force=zstd,subvol=@snapshots 0 0" >> /etc/fstab

    mount "$part" "/.snapshots" -o compress-force=zstd,subvol=@snapshots

    chmod 750 /.snapshots

    echo -e "${BRIGHT_CYAN}Enabling snapper timers...${NO_COLOR}"
    systemctl enable snapper-timeline.timer
    systemctl enable snapper-cleanup.timer
    systemctl enable snapper-boot.timer

    systemctl start snapper-timeline.timer
    systemctl start snapper-cleanup.timer
    systemctl start snapper-boot.timer
}

disable_ssh_service(){
    colored_msg "DEBUG. Disabling SSH service..." "${RED}" "#"

    systemctl disable sshd.service
    sed -i "s/^PermitRootLogin yes/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
}

install_yay(){
    colored_msg "Installing AUR helper (yay)..." "${BRIGHT_CYAN}" "#"

    # https://stackoverflow.com/questions/5560442/how-to-run-two-commands-with-sudo
    local -r USER=$(get_sudo_user)

    sudo -S -i -u "$USER" git clone https://aur.archlinux.org/yay.git "/home/$USER/yay"

    # https://unix.stackexchange.com/questions/176997/sudo-as-another-user-with-their-environment
    sudo -S -i -u "$USER" bash -c "cd \"/home/$USER/yay\" && makepkg -sri"

    echo -e "${BRIGHT_CYAN}Configuring yay...${NO_COLOR}"
    sudo -S -i -u "$USER" yay -Y --gendb
    sudo -S -i -u "$USER" yay -Syu --devel
    sudo -S -i -u "$USER" yay -Y --devel --save 

    redo_grub
}

enable_crypt_keyfile(){
    colored_msg "Enabling keyfile at boot..." "${BRIGHT_CYAN}" "#"

    ask "Is your pendrive inserted? If not, insert it now."

    local drive
    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -ne "${YELLOW}Select drive: ${NO_COLOR}"
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
        lsblk "$drive"
        echo -ne "${Y}Select partition: ${NO_COLOR}"
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

        echo -ne "${BRIGHT_CYAN}Type current or desired filesystem: ${NO_COLOR}"
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
                echo -e "${RED}Wrong filesystem.${NO_COLOR}"
                ;;
        esac

        if [ "$is_wrong" -eq "$FALSE" ];
        then
            ask "You have selected $selected_module. Is that OK?"
            is_done="$?"
        fi
    done

    local wants_format="$FALSE"

    ask "Do you want to format partition?"
    wants_format="$?"

    if [ "$wants_format" -eq "$TRUE" ];
    then
        echo -e "${BRIGHT_CYAN}Formatting partition...${NO_COLOR}"

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
                echo -e "${RED}Unknown error.${NO_COLOR}"
                return 1
                ;;
        esac
    fi

    # Asking for the encrypted partition
    local sys_part="/dev/$DM_NAME"


    # Creating the keyfile
    mount "$part" /mnt

    # Creating keyfile name (it may already exist)
    local keyfile_name="keyfile-$machine_name-$RANDOM"

    # Generate keyfile name until
    while [ -f "/mnt/$keyfile_name" ]
    do
        keyfile_name="keyfile-$machine_name-$RANDOM"
    done

    # Creating the keyfile
    dd bs=512 count=4 if=/dev/random of="/mnt/$keyfile_name" iflag=fullblock
    cryptsetup luksAddKey "$sys_part" "/mnt/$keyfile_name"

    # Adding the modules on mkinitcpio, only if they are not already there
    echo -e "${BRIGHT_CYAN}Adding $selected_module to mkinitcpio.conf...${NO_COLOR}"
    ! grep -E "^MODULES=\(.*$selected_module.*\)$" "/etc/mkinitcpio.conf" && add_sentence_2 "^MODULES=" "$selected_module" "/etc/mkinitcpio.conf" ")"
    mkinitcpio -P


    # We need to add a new kernel parameter.
    # First, we check if rd.luks.options exists.
    if grep -i "rd.luks.options" /etc/default/grub > /dev/null;
    then
        # If the entry exists, we add a new parameter inside
        echo -e "${BRIGHT_CYAN}The entry exists. Adding new option.${NO_COLOR}"
        add_option_inside_luks_options "keyfile-timeout=10s" "/etc/default/grub" "$TRUE"
    else
        # If the entry does not exist, we add rd.luks.options directly.
        echo -e "${BRIGHT_CYAN}The entry does not exist. Adding new option.${NO_COLOR}"
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=keyfile-timeout=10s" "/etc/default/grub" "$TRUE" "$TRUE"
    fi

#   Now we need to add the key UUID to the kernel parameter.
    local -r PEN_UUID=$(blkid -s UUID -o value "$part")
    local -r ROOT_UUID=$(blkid -s UUID -o value "$sys_part")

    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.key=$ROOT_UUID=$keyfile_name:UUID=$PEN_UUID" "/etc/default/grub" "$TRUE" "$TRUE"

    # We regenerate the grub config
    redo_grub

    # Finally, unmount the pendrive
    umount /mnt
}

# CHECK FOR ROOTLESS WAYLAND!!!
rootless_kde(){
    colored_msg "Enabling rootless SDDM..." "${BRIGHT_CYAN}" "#"

    local -r RESULT=$(ps -o user= -C Xorg)

    if [ "$RESULT" = "root" ];
    then
        mkdir /etc/sddm.conf.d

        echo "[General]" > /etc/sddm.conf.d/rootless-x11.conf
        echo "DisplayServer=x11-user" >> /etc/sddm.conf.d/rootless-x11.conf
    else
        echo -e "${BRIGHT_CYAN}Already running in rootless mode.${NO_COLOR}"
    fi
}

cleanup(){
    rm -rf /root/after_install.tmp
}

enable_paccache(){
    colored_msg "Enabling paccache..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S pacman-contrib

    if ask "Do you want to set a custom number of cached file?";
    then
        local RK="1"
        local RUK="0"

        echo "Recent version: $RK
Unused packages: $RUK"

        ask "Do you want to keep these custom settings?"
        local -r ans="$?"

        if [ "$ans" -eq "$FALSE" ];
        then
            echo -ne "${BRIGHT_CYAN}Recent version number (default: $RK): ${NO_COLOR}"
            read -r RK

            echo -ne "${BRIGHT_CYAN}Unused packages number (default: $RUK): ${NO_COLOR}"
            read -r RUK
        fi

        echo -e "${BRIGHT_CYAN}Changing paccache.service...${NO_COLOR}"
        awk 'BEGIN{OFS=FS="="} /^ExecStart=/{cmd=substr($0,1,length($0)-3); $0="# "$0"\n"cmd" -rk"'"$RK"'"\n"cmd" -ruk"'"$RUK"'};1' /usr/lib/systemd/system/paccache.service > /usr/lib/systemd/system/paccache.service.TMP && mv /usr/lib/systemd/system/paccache.service.TMP /usr/lib/systemd/system/paccache.service
        
        echo -e "${BRIGHT_CYAN}IMPORTANT! You need to manually edit the service file every time paccache updates.${NO_COLOR}"
        sleep 3
    fi

    echo -e "${BRIGHT_CYAN}Enabling and starting paccache.timer...${NO_COLOR}"
    systemctl enable paccache.timer
    systemctl start paccache.timer
}


# https://epson.com/Support/wa00821
install_printer_drivers(){
    local -r USER=$(get_sudo_user)

    colored_msg "Printer specific drivers installation" "${BRIGHT_CYAN}" "#"

    echo "Currently available printers:
1) EPSON ET-2860 (also for other inkjet printers, check epson page for more info)"

    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        echo -ne "${YELLOW}Choose an option (empty to exit):${NO_COLOR} "
        read -r selection

        case $selection in
            "1")
                echo -e "${BRIGHT_CYAN}Installing EPSON inkjet printer drivers...${NO_COLOR}"
                sudo -S -i -u "$USER" yay -S epson-inkjet-printer-escpr epsonscan2 epsonscan2-non-free-plugin
                is_done="$TRUE"
                ;;

            "")
                echo -e "${BRIGHT_CYAN}Not installing anything${NO_COLOR}"
                is_done="$TRUE"
                ;;

            *)
                echo -e "${RED}Wrong option${NO_COLOR}"
                is_done="$FALSE"
                ;;
        esac
    done
}

# https://wiki.archlinux.org/title/Dual_boot_with_Windows#Time_standard
# https://wiki.archlinux.org/title/systemd-timesyncd
sync_time_dual_boot(){
    colored_msg "Time synchronization" "${BRIGHT_CYAN}" "#"

    if ask "Are you dual-booting another OS that is not Linux?";
    then
        echo -e "${GREEN}IMPORTANT!!${NO_COLOR} You need to complete the configuration by going to the following URL: ${BRIGHT_CYAN}https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows${NO_COLOR}

In any case, you can use the *.reg file located in .scripts/win64 to install it on Windows."
    fi

    echo -e "${BRIGHT_CYAN}Enabling NTP...${NO_COLOR}"
    systemctl enable systemd-timesyncd.service
    systemctl start systemd-timesyncd.service

    timedatectl set-ntp true
}

# Laptop specific functions
enable_envycontrol(){
    colored_msg "Enabling envycontrol..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)
    
    sudo -S -i -u "$USER" yay -S envycontrol

    echo -e "${BRIGHT_CYAN}Switching to integrated mode...${NO_COLOR}"
    envycontrol -s integrated
}

laptop_extra_config(){
    # aqui va la configuracion de los altavoces y eso
    echo -e "${BRIGHT_CYAN}Enabling modprobe config...${NO_COLOR}"

    echo "options snd_hda_intel model=lenovo-y530" > /etc/modprobe.d/msi_laptop.conf
}

main(){
    ask_global_vars

    # Source var files
    [ -f "$VAR_FILE_LOC" ] && source "$VAR_FILE_LOC"

    case $log_step in
        0)
            ask "Do you want to enable NTP?" && sync_time_dual_boot
            ask "Do you want to have REISUB?" && enable_reisub
            ask "Do you want to enable TRIM?" && enable_trim
            install_shells
            add_users
            ask "Do you want to parallelize package downloads and color them?" && improve_pacman
            ask "Do you want to enable periodic pacman cache cleaning?" && enable_paccache
            ask "Do you want to enable the multilib package (Steam)?" && enable_multilib
            ask "Do you want to enable reflector timer to update mirrorlist?" && enable_reflector
            ask "Do you want to enable scrub?" && btrfs_scrub
            ask "Do you want to install the dependencies to use the AUR and enable parallel compilation?" && prepare_for_aur
            ask "Do you want to install an AUR helper?" && install_yay
            ask "Do you want to install bluetooth service?" && install_bluetooth

            # CHECK INSTALL_XORG ON LAPTOP. 
            ask "Do you want to install Xorg and graphics driver?" && install_xorg

            ask "Do you want to install KDE?" && install_kde
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"
            ask_reboot
            ;;

        1)
            # CHECK FOR ROOTLESS WAYLAND!!!
            rootless_kde

            ask "Do you want to install a cpu scaler?" && install_cpu_scaler
            # REBOOT
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"            
            ask_reboot
            ;;

        2)
            ask "Do you want to install the printer service?" && install_printer
            ask "Do you want to install a firewall?" && install_firewall

            # PENSAR EN SI PONER LA REGLA UDEV
            ask "Do you want to install NTFS driver?" && enable_ntfs

            # CHECK IN THE FUTURE THE DAEMONS, THEY ARE SPLITTING THEM
            ask "Do you want to install KVM?" && install_kvm
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"    
                    
            ask_reboot "Please reboot your system to archiso again and copy .scripts folder to archiso root folder."
            ;;

        3)
            # REBOOT TO ARCHISO
            ask "Do you want to enable hardware acceleration?" && enable_hw_acceleration
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"            
            ask_reboot
            ;;

        4)
            # REBOOT
            [ "$has_encryption" -eq "$TRUE" ] && ask "Do you want to store a keyfile to decrypt system?" && enable_crypt_keyfile

            ask "Do you want to install lsd and hack nerd font?" && install_lsd
            ask "Do you want to install Microsoft Fonts?" && install_ms_fonts

            ask "Do you want to install snapper and snap-pac?" && btrfs_snapshots
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"
            ask_reboot
            ;;
        
        5)
            ask "Do you want to install optional packages?" && install_optional_pkgs
            ask "Do you want to install printer specific drivers? (only if IPP is not working as intended)" && install_printer_drivers

            if [ "$is_laptop" -eq "$TRUE" ] && is_element_in_array "nvidia" "gpu_type";
            then 
                ask "Do you want to enable laptop specific features?" && laptop_extra_config
                ask "Do you want to enable envycontrol?" && enable_envycontrol
            fi
            ;;

        *)
            echo "Unknown error"
            exit 1
            ;;
    esac


    echo "BOOT INTO ARCHISO, MOUNT FILESYSTEM AND EXECUTE /mnt/root/last_step.sh"
    echo "Enable nerd font on Terminal emulator."
    echo "Please enable on boot in virt manager the default network by going into Edit->Connection details->Virtual Networks->default."
    echo "It is normal for colord.service to fail. You need to execute manually colord command once and then the service will start."
    echo "You need to follow https://github.com/elFarto/nvidia-vaapi-driver/#environment-variables to configure Firefox HW ACC."
    echo "CHECK FREEFILESYNC PACKAGE"
    # IN PROCESS
    # IMPORTANTE NO OLVIDAR
    # disable_ssh_service
}

main "$@"
