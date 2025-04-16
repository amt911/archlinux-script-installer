#!/bin/bash

OPTIONAL_PKGS=("onlyoffice-bin" "lrcget-bin" "brasero" "asunder" "xpadneo-dkms" "syncthing" "darktable" "rclone" "strawberry" "rsync" "yazi" "discord" "handbrake" "kdiskmark" "tmux" "chromium" "picard" "sonic-visualiser" "ghex" "7zip" "unrar" "lazygit" "fastfetch" "jdownloader2" "meld" "neofetch" "gparted" "bc" "wget" "dosfstools" "iotop-c" "less" "nano" "man-db" "git" "optipng" "oxipng" "pngquant" "imagemagick" "veracrypt" "gimp" "inkscape" "tldr" "fzf" "lsd" "bat" "keepassxc" "shellcheck" "btop" "htop" "fdupes" "firefox" "rebuild-detector" "reflector" "sane" "sane-airscan" "simple-scan" "evince" "qbittorrent" "fdupes" "gdu" "unzip" "visual-studio-code-bin" "exfatprogs")
readonly OPTIONAL_PKGS_BTRFS=("btdu" "compsize" "jdupes" "duperemove")

# COMPROBAR LA INSTALACION DE ESTE PAQUETE, LE FALTAN LAS FUENTES
readonly LIBREOFFICE_PKGS=("libreoffice-fresh" "libreoffice-extension-texmaths" "libreoffice-extension-writer2latex")
readonly LIBREOFFICE_PKGS_DEPS=("hunspell" "hunspell-es_es" "hyphen" "hyphen-es" "libmythes" "mythes-es")
readonly TEXLIVE_PKGS=("texlive" "texlive-lang")
readonly TEXLIVE_PKGS_DEPS=("biber")


readonly LAPTOP_PKGS=("powerstat")

# Sources:
# https://github.com/lutris/docs/blob/master/WineDependencies.md#archendeavourosmanjaroother-arch-derivatives
# https://wiki.archlinux.org/title/wine
readonly WINE_PKGS=("wine-staging" "wine-gecko" "wine-mono" "lib32-pipewire" "lib32-gnutls" "lib32-sdl2" "lib32-gst-plugins-base" "lib32-gst-plugins-good" "lib32-gst-plugins-bad" "lib32-gst-plugins-ugly" "lib32-gst-libav" "samba" "giflib" "lib32-giflib" "libpng" "lib32-libpng" "libldap" "lib32-libldap" "gnutls" "mpg123" "lib32-mpg123" "openal" "lib32-openal" "v4l-utils" "lib32-v4l-utils" "libpulse" "pipewire-pulse" "lib32-libpulse" "libgpg-error" "lib32-libgpg-error" "alsa-plugins" "lib32-alsa-plugins" "alsa-lib" "lib32-alsa-lib" "libjpeg-turbo" "lib32-libjpeg-turbo" "sqlite" "lib32-sqlite" "libxcomposite" "lib32-libxcomposite" "libxinerama" "lib32-libgcrypt" "libgcrypt" "lib32-libxinerama" "ncurses" "lib32-ncurses" "ocl-icd" "lib32-ocl-icd" "libxslt" "lib32-libxslt" "libva" "lib32-libva" "gtk3" "lib32-gtk3" "gst-plugins-base-libs" "lib32-gst-plugins-base-libs" "vulkan-icd-loader" "lib32-vulkan-icd-loader" "lib32-alsa-oss")

readonly GAMING_PKGS=("steam" "lutris" "protontricks" "zenity" "mangohud" "lib32-mangohud")

readonly EMU_PKGS=("rpcs3-bin" "dolphin-emu")

# for i in "/run/media/user/Ventoy/scripts"/*; do ln -sf "$i" "/root/$(echo $i | cut -d/ -f7)"; done

source common-functions.sh

readonly SHELLS_SUDO=("zsh" "fish" "sudo")
readonly VIRTIO_MODULES=("virtio-net" "virtio-blk" "virtio-scsi" "virtio-serial" "virtio-balloon")
# TODO
# ROOTLESS SDDM UNDER WAYLAND
# KVM -> lsmod | grep kvm. Pone que hay que iniciarlos manualmente. Revisar por si.
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

# $1 (optional: true/false): Install GRUB? Defaults to true, so it installs GRUB and generates config file.
redo_grub(){
    local -r INSTALL="${1:-$TRUE}"

    colored_msg "Reinstalling GRUB..." "${BRIGHT_CYAN}" "#"

    [ "$INSTALL" -eq "$TRUE" ] && grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg
}

# https://wiki.archlinux.org/title/Keyboard_shortcuts#Kernel_(SysRq)
enable_reisub(){
    colored_msg "Enabling REISUB..." "${BRIGHT_CYAN}" "#"
    
    if [ "$bootloader" = "grub" ];
    then
        add_option_bootloader "sysrq_always_enabled=1" "/etc/default/grub"
        redo_grub "$FALSE"
    else
        add_option_bootloader "sysrq_always_enabled=1" "/boot/loader/entries/arch.conf"
        add_option_bootloader "sysrq_always_enabled=1" "/boot/loader/entries/arch-fallback.conf"
    fi

}

# https://wiki.archlinux.org/title/Solid_state_drive#Periodic_TRIM
# https://wiki.archlinux.org/title/Dm-crypt/Specialties#Discard/TRIM_support_for_solid_state_drives_(SSD)
enable_trim(){
    colored_msg "Enabling TRIM..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S util-linux
    systemctl enable fstrim.timer

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        # add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=discard" "/etc/default/grub" "$TRUE" "$TRUE"
        # Commented out since the above configuration is recommended for LUKS1/plain devices
        cryptsetup --allow-discards --persistent refresh "$DM_NAME"
        # [ "redo_grub "$FALSE"
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

    local add_new_user="$TRUE"
    local username
    local shell
    local passwd_ok="$FALSE"

    while [ "$add_new_user" -eq "$TRUE" ]
    do

        echo -n "Username (empty to exit): "
        read -r username

        if [ -n "$username" ];
        then
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
            add_new_user="$?"
        else
            add_new_user="$FALSE"
        fi

        unset username
    done
}

# https://wiki.archlinux.org/title/Pacman#Enabling_parallel_downloads
improve_pacman(){
    colored_msg "Improving pacman performance..." "${BRIGHT_CYAN}" "#"

    sed -i "s/^#Parallel/Parallel/" /etc/pacman.conf
    sed -i "s/^#Color/Color/" /etc/pacman.conf

    echo -e "${BRIGHT_CYAN}These are the changed lines:${NO_COLOR}"
    grep "Parallel" /etc/pacman.conf
    grep -E "^Color" /etc/pacman.conf
    sleep 3
}

# https://wiki.archlinux.org/title/Official_repositories#multilib
enable_multilib(){
    colored_msg "Enabling multilib repository..." "${BRIGHT_CYAN}" "#"

    awk 'BEGIN {num=2; first="#[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' /etc/pacman.conf > /etc/pacman.conf.TMP && mv /etc/pacman.conf.TMP /etc/pacman.conf

    pacman --noconfirm -Syu
    
    [ "$bootloader" = "grub" ] && redo_grub

    echo -e "${BRIGHT_CYAN}Check changes:${NO_COLOR}"
    awk 'BEGIN {num=2; first="[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){print $0;num--;entered="true"}' /etc/pacman.conf
    sleep 3
}

# https://wiki.archlinux.org/title/reflector
# https://wiki.archlinux.org/title/general_recommendations#Mirrors
enable_reflector(){
    colored_msg "Enabling reflector..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S reflector
    systemctl enable reflector.timer
}

# https://wiki.archlinux.org/title/Btrfs#Scrub
btrfs_scrub(){
    colored_msg "Enabling btrfs scrub on root subvolume..." "${BRIGHT_CYAN}" "#"

    systemctl enable btrfs-scrub@-.timer
}

# https://wiki.archlinux.org/title/Arch_User_Repository
# https://wiki.archlinux.org/title/makepkg#Parallel_compilation
prepare_for_aur(){
    colored_msg "Preparing system for AUR packages..." "${BRIGHT_CYAN}" "#"

    # Mejorar aqui el make para que sea multinucleo
    pacman --noconfirm -S base-devel git

    # https://wiki.archlinux.org/title/makepkg#Parallel_compilation
    # Enable multi-core compilation
    awk 'BEGIN { OFS=FS="="; name="#MAKEFLAGS" } {if($1==name){sub(/#/,""); $2="\"--jobs=$(nproc)\""}};1' /etc/makepkg.conf > /etc/makepkg.tmp && mv /etc/makepkg.tmp /etc/makepkg.conf

    echo -e "${BRIGHT_CYAN}Check changes: ${NO_COLOR}"
    grep "MAKEFLAGS=" /etc/makepkg.conf
    echo ""
    sleep 3
}

# https://wiki.archlinux.org/title/Bluetooth
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


copy_mangohud_config(){
    readarray -td"," arr < <(printf "%s" "$(grep -E "^wheel" /etc/gshadow | cut -d: -f4)")

    for i in "${arr[@]}"
    do
        mkdir -p "/home/$i/.config/MangoHud"
        cp "additional_resources/MangoHud.conf" "/home/$i/.config/MangoHud/"

        chown -R "$i":"$i" "/home/$i/.config/MangoHud"
    done
}

# https://wiki.archlinux.org/title/Discord#Discord_asks_for_an_update_not_yet_available_in_the_repository
disable_update_msg_discord(){
    readarray -td"," arr < <(printf "%s" "$(grep -E "^wheel" /etc/gshadow | cut -d: -f4)")

    for i in "${arr[@]}"
    do
        mkdir -p "/home/$i/.config/discord"
        cp "additional_resources/discord/settings.json" "/home/$i/.config/discord/"

        chown -R "$i":"$i" "/home/$i/.config/discord"
    done
}

# https://wiki.archlinux.org/title/LibreOffice
# https://wiki.archlinux.org/title/TeX_Live
# https://wiki.archlinux.org/title/Wine
# https://wiki.archlinux.org/title/MangoHud
# https://wiki.dolphin-emu.org/index.php?title=Bluetooth_Passthrough#Linux
# https://wiki.archlinux.org/title/Udev#Allowing_regular_users_to_use_devices
install_optional_pkgs(){
    colored_msg "Installing optional packages..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)

    [ "$root_fs" = "btrfs" ] && OPTIONAL_PKGS=( "${OPTIONAL_PKGS[@]}" "${OPTIONAL_PKGS_BTRFS[@]}")

    sudo -S -i -u "$USER" yay -S "${OPTIONAL_PKGS[@]}"

    disable_update_msg_discord

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

    if ask "Do you want to install WINE? (Runs some Windows programs)";
    then
        # Bad packages: 
        # lib32-gst-plugins-bad -> lib32-libcdio-exit lib32-zvbi-exit
        # lib32-gst-plugins-ugly
        # lib32-gst-libav
        # lib32-ffmpeg -> ffmpeg version too low

        # Conflicts:
        # ffmpeg-libfdk_aac and ffmpeg (packages: lib32-gst-plugins-ugly and lib32-gst-plugins-bad)    
        sudo -S -i -u "$USER" yay -S "${WINE_PKGS[@]}"
    fi

    if ask "Do you want to install gaming apps?";
    then
        # https://wiki.archlinux.org/title/MangoHud
        sudo -S -i -u "$USER" yay -S "${GAMING_PKGS[@]}"
        copy_mangohud_config
    fi

    if ask "Do you want to install Clone Hero?";
    then
        if ask "Do you want to install the PTB (Public Test Build)?";
        then
            sudo -S -i -u "$USER" yay -S "clonehero-ptb"
        else
            sudo -S -i -u "$USER" yay -S "clonehero"
        fi
        
        sudo -S -i -u "$USER" yay -S --asdeps "pulseaudio-alsa"
    fi

    if ask "Do you want to install some emulators?";
    then
        sudo -S -i -u "$USER" yay -S "${EMU_PKGS[@]}"

        local is_done="$FALSE"

        # https://wiki.dolphin-emu.org/index.php?title=Bluetooth_Passthrough#Linux
        # https://wiki.archlinux.org/title/Udev#Allowing_regular_users_to_use_devices
        echo "You need to install a udev for the adapter to be working correctly for USB Passthrough on Dolphin"
        while [ "$is_done" -eq "$FALSE" ]
        do
            echo "
The following adapters are configured:

1) TP-Link UB400
"
            echo -ne "${YELLOW}Select an option (empty for no udev rule): ${NO_COLOR}"
            read -r option

            case $option in
                1)
                    echo "Installing udev rule for TP-Link UB400..."
                    cp additional_resources/udev_rules/50-dolphin-UB400.rules /etc/udev/rules.d/
                    udevadm trigger
                    udevadm control --reload
                    
                    is_done="$TRUE"
                    ;;
                "")
                    echo "Not doing anything. Continuing."
                    is_done="$TRUE"
                    ;;
                *)
                    echo -e "${RED}Invalid option${NO_COLOR}"
                    ;;
            esac
        done
    fi

    if ask "Do you intend to use a KROM Kreator or keyboard with VID:PID=5566:0008?";
    then
        echo -e "${BRIGHT_CYAN}Adding kernel parameter so the OS recognizes it...${NO_COLOR}"
        
        if [ "$bootloader" = "grub" ];
        then
            add_option_bootloader "usbcore.quirks=5566:0008:i" "/etc/default/grub"
            redo_grub "$FALSE"
        else
            add_option_bootloader "usbcore.quirks=5566:0008:i" "/boot/loader/entries/arch.conf"
            add_option_bootloader "usbcore.quirks=5566:0008:i" "/boot/loader/entries/arch-fallback.conf"
        fi
    fi

    if ask "Do you want to install OpenRGB?";
    then
        sudo -S -i -u "$USER" yay -S "openrgb"   
    fi
}


install_udev_rules(){
    cp additional_resources/udev_rules/1-qudelix.rules /etc/udev/rules.d/


    udevadm trigger
    udevadm control --reload    
}

# https://wiki.archlinux.org/title/CPU_frequency_scaling#power-profiles-daemon
# https://wiki.archlinux.org/title/CPU_frequency_scaling#Scaling_drivers
# https://wiki.archlinux.org/title/CPU_frequency_scaling#amd_pstate
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

        if [ "$bootloader" = "grub" ];
        then
            add_option_bootloader "amd_pstate=active" "/etc/default/grub"
            redo_grub "$FALSE"
        else
            add_option_bootloader "amd_pstate=active" "/boot/loader/entries/arch.conf"
            add_option_bootloader "amd_pstate=active" "/boot/loader/entries/arch-fallback.conf"
        fi
        
    fi
}

# https://wiki.archlinux.org/title/Hardware_video_acceleration
# https://github.com/elFarto/nvidia-vaapi-driver?tab=readme-ov-file#configuration
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
                pacman --noconfirm -S libva-nvidia-driver

                echo -e "${BRIGHT_CYAN}Creating environment variables...${NO_COLOR}"

                # It is mandatory to set the environment variables.
                if [ "$is_laptop" -eq "$TRUE" ];
                then
                    cp "additional_resources/laptop_scripts/laptop_hw_acc.sh" "/etc/profile.d"

                else
                    echo "LIBVA_DRIVER_NAME=nvidia
# NVD_BACKEND=direct
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

# https://wiki.archlinux.org/title/Firewalld
# https://serverfault.com/questions/485400/what-exactly-do-limit-1-s-and-limit-burst-mean-in-iptables-rules
install_firewall(){
    colored_msg "Installing firewall..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S firewalld

    echo -e "${BRIGHT_CYAN}Enabling and starting firewalld.service...${NO_COLOR}"
    systemctl enable --now firewalld.service

    firewall-cmd --permanent --zone=public --remove-service=ssh

    # https://serverfault.com/questions/485400/what-exactly-do-limit-1-s-and-limit-burst-mean-in-iptables-rules
    # We limit ssh connections to just 2 per minute before it kicks in the default 5 connections (and then it blocks the source)
    firewall-cmd --permanent --zone=public --add-rich-rule 'rule service name="ssh" accept limit value="2/m"'

    # We add the syncthing so it doesn't to connect to WAN, only to LAN (faster speeds).
    # https://docs.syncthing.net/users/firewall.html#firewalld
    firewall-cmd --zone=public --add-service=syncthing --permanent
    
    firewall-cmd --reload
}

# Install an aur package with the url passed as argument
# $1: URL. Must finish in ".git"
# https://stackoverflow.com/questions/5560442/how-to-run-two-commands-with-sudo
# https://unix.stackexchange.com/questions/176997/sudo-as-another-user-with-their-environment
install_aur_package(){
    local -r USER=$(get_sudo_user)
    local -r URL="$1"
    local pkg_name

    pkg_name=$(echo "$1" | cut -d/ -f4)
    pkg_name=${pkg_name::-4}

    sudo -S -i -u "$USER" git clone "$URL" "/home/$USER/$pkg_name"
    sudo -S -i -u "$USER" bash -c "cd \"/home/$USER/$pkg_name\" && makepkg -sri"
}

# https://wiki.archlinux.org/title/systemd-boot#pacman_hook
install_sd_boot_pkgs(){
    install_aur_package "https://aur.archlinux.org/systemd-boot-pacman-hook.git"
}

# $1: Number of the snapshot
make_btrfs_install_snapshot(){
    local -r TARGET_DEV=$(mount | grep -i "on / type" | cut -f1 -d" " )
    local -r UUID=$(blkid -s UUID -o value "$TARGET_DEV")
    local -r SNAP_NUM="$1"

    # Mount the root btrfs subvolume
    mount UUID="$UUID" /mnt -o compress-force=zstd

    # If the subvolume snapshot does not exist, create it
    if ! btrfs subvolume list / | grep "@tmp_snaps" > /dev/null;
    then
        btrfs subvolume create "/mnt/@tmp_snaps"
    fi

    # If the bootloader subvolume does not exist, create it
    if ! btrfs subvolume list / | grep "@tmp_snaps/bootloader_entries" > /dev/null;
    then
        btrfs subvolume create "/mnt/@tmp_snaps/bootloader_entries"
    fi

    # Create the root snapshot
    btrfs subvolume snapshot -r "/mnt/@" "/mnt/@tmp_snaps/$SNAP_NUM"

    # Create the bootloader "snapshot"
    if [ "$bootloader" = "grub" ];
    then
        mkdir -p "/mnt/@tmp_snaps/bootloader_entries/grub/$SNAP_NUM"
        cp /etc/default/grub "/mnt/@tmp_snaps/bootloader_entries/grub/$SNAP_NUM/"
    else
        mkdir -p "/mnt/@tmp_snaps/bootloader_entries/systemd-boot/$SNAP_NUM"
        cp /boot/loader/entries/arch.conf "/mnt/@tmp_snaps/bootloader_entries/systemd-boot/$SNAP_NUM/"
        cp /boot/loader/entries/arch-fallback.conf "/mnt/@tmp_snaps/bootloader_entries/systemd-boot/$SNAP_NUM/"
    fi

    umount /mnt    
}

# https://wiki.archlinux.org/title/Xorg
# https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
install_xorg(){
    echo -e "${BRIGHT_CYAN}Installing Xorg...${NO_COLOR}"

    pacman --noconfirm -S xorg

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
                # First install the linux headers and dkms so it can build the packages for the current kernel
                pacman -S linux-headers dkms

                if ask "Do you have an RTX 2000 Series GPU (Turing) or newer?";
                then
                    if ask "Do you want to install NVIDIA beta packages?";
                    then
                        local -r USER=$(get_sudo_user)

                        echo -e "${BRIGHT_CYAN}Installing nvidia beta drivers...${NO_COLOR}"

                        install_aur_package "https://aur.archlinux.org/nvidia-utils-beta.git"
                        pacman -D --asdeps nvidia-utils-beta

                        sudo -S -i -u "$USER" yay -S nvidia-open-beta-dkms
                        install_aur_package "https://aur.archlinux.org/lib32-nvidia-utils-beta.git"
                    else
                        echo -e "${BRIGHT_CYAN}Installing nvidia drivers...${NO_COLOR}"
                        pacman --noconfirm -S nvidia-open-dkms lib32-nvidia-utils nvidia-settings
                    fi
                else
                    if ask "Do you want to install NVIDIA beta packages?";
                    then
                        echo -e "${BRIGHT_CYAN}Installing nvidia beta drivers...${NO_COLOR}"

                        install_aur_package "https://aur.archlinux.org/nvidia-utils-beta.git"
                        pacman -D --asdeps nvidia-utils-beta

                        install_aur_package "https://aur.archlinux.org/nvidia-beta-dkms.git"
                        install_aur_package "https://aur.archlinux.org/lib32-nvidia-utils-beta.git"
                    else
                        echo -e "${BRIGHT_CYAN}Installing nvidia drivers...${NO_COLOR}"
                        pacman --noconfirm -S nvidia-dkms lib32-nvidia-utils nvidia-settings
                    fi
                fi
                ;;
            *)
                echo -e "${RED}Unknown error. Exiting...${NO_COLOR}"
                exit 1
        esac
    done
    unset i

    # I do not disable kms HOOK because nvidia-utils blacklists nouveau by default.
    # Blacklisting location: /usr/lib/modprobe.d/nvidia-utils-beta.conf 
}


add_nvidia_modprobe_config(){
    colored_msg "Checking whether it is needed to add modprobe files to NVIDIA GPU..." "${BRIGHT_CYAN}" "#"

    if [ "$is_laptop" -eq "$FALSE" ];
    then
        # https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
        # https://superuser.com/questions/577307/how-to-get-a-list-of-active-drivers-that-are-statically-built-into-the-linux-ker
        # We can put the kernel module config in modprobe.d since they are not compiled in the kernel, they are in fact external, so they can be modified using a modprobe file. The following link says so:
        # https://wiki.archlinux.org/title/Kernel_module#Using_kernel_command_line
        
        local -r MODESET_STATUS=$(cat /sys/module/nvidia_drm/parameters/modeset)
        local -r FBDEV_STATUS=$(cat /sys/module/nvidia_drm/parameters/fbdev)

        if [ "$MODESET_STATUS" != "Y" ];
        then
            echo "options nvidia_drm modeset=1" >> /etc/modprobe.d/nvidia.conf
        fi

        if [ "$FBDEV_STATUS" != "Y" ];
        then
            echo "options nvidia_drm fbdev=1" >> /etc/modprobe.d/nvidia.conf
        fi


        # To check if it is working: 
        # cat /sys/module/nvidia_drm/parameters/modeset
    fi
}

install_kde(){
    colored_msg "Installing KDE Plasma..." "${BRIGHT_CYAN}" "#"

    # Aqui se deberia aplicar el fix para que sea xorg rootless
    pacman --noconfirm -S plasma-meta

    if ask "Do you want to install extra applications for KDE?";
    then
        pacman --noconfirm -S kde-graphics-meta kde-system-meta kde-utilities-meta kde-multimedia-meta
    fi

    if ask "Do you want to install printer optional packages? (only if you intend to install CUPS)";
    then
        pacman --noconfirm --asdeps -S system-config-printer
    fi

    systemctl enable sddm.service

    add_global_var_to_file "is_kde" "$TRUE" "$VAR_FILE_LOC"
}

install_gnome(){
    colored_msg "Installing GNOME..." "${BRIGHT_CYAN}" "#"
    # if ask "Do you want to install printer optional packages? (only if you intend to install CUPS)";
    # then
    #     pacman --noconfirm --asdeps -S system-config-printer
    # fi    
    add_global_var_to_file "is_kde" "$FALSE" "$VAR_FILE_LOC"
    echo "WIP"
}

# Huge pages, iommu, nested virt, tpm, uefi,
# https://wiki.archlinux.org/title/KVM
# https://wiki.archlinux.org/title/KVM#Nested_virtualization
# https://wiki.archlinux.org/title/KVM#Secure_Boot
# https://wiki.archlinux.org/title/KVM#Enabling_huge_pages
# https://wiki.archlinux.org/title/QEMU
# https://wiki.archlinux.org/title/QEMU#Booting_in_UEFI_mode
# https://wiki.archlinux.org/title/QEMU#Trusted_Platform_Module_emulation
# https://wiki.archlinux.org/title/Libvirt
# https://wiki.archlinux.org/title/Libvirt#UEFI_support
# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Enabling_IOMMU
# https://wiki.archlinux.org/title/QEMU#Enabling_SPICE_support_on_the_guest
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
        echo -e "${RED}Error. Not loaded CPU specific KVM. Exiting...${NO_COLOR}"
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
    echo -e "${BRIGHT_CYAN}Installing packages for UEFI, TPM and Secure Boot Support...${NO_COLOR}"
    pacman --noconfirm -S edk2-ovmf swtpm virt-firmware

    # IOMMU
    echo -e "${BRIGHT_CYAN}Setting up IOMMU...${NO_COLOR}"
    # Commented out since it is advised against using it
    # add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " iommu=pt" "/etc/default/grub" "$TRUE" "$TRUE"

    if [ "$is_intel" -eq "$TRUE" ];
    then
        if [ "$bootloader" = "grub" ];
        then
            add_option_bootloader "intel_iommu=on" "/etc/default/grub"
            redo_grub
        else
            add_option_bootloader "intel_iommu=on" "/boot/loader/entries/arch.conf"
            add_option_bootloader "intel_iommu=on" "/boot/loader/entries/arch-fallback.conf"
        fi
    fi


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

# https://wiki.archlinux.org/title/CUPS
# https://wiki.archlinux.org/title/SANE
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

# https://wiki.archlinux.org/title/Microsoft_fonts#Extracting_fonts_from_a_Windows_ISO
install_ms_fonts(){
    colored_msg "Installing Microsoft Fonts..." "${BRIGHT_CYAN}" "#"

    local is_7z_installed="$TRUE"

    pacman -Qi 7zip
    is_7z_installed="$?"

    [ "$is_7z_installed" -eq "$FALSE" ] && pacman --noconfirm -S 7zip

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

        mount "$drive" /mnt -o ro,noexec
    fi

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
    [ "$OTHER_DRIVE" -eq "$TRUE" ] && umount /mnt

    # We extract the contents of the ISO
    local -r ISO_LOCATION=$(echo "$location" | awk 'BEGIN{ OFS=FS="/" } { print "/root",$NF }')
    7z e "$ISO_LOCATION" sources/install.wim -o/root
    7z e /root/install.wim 1/Windows/{Fonts/"*".{ttf,ttc},System32/Licenses/neutral/"*"/"*"/license.rtf} -o/root/fonts/

    mkdir -p /usr/local/share/fonts/WindowsFonts
    cp /root/fonts/* /usr/local/share/fonts/WindowsFonts/
    chmod 644 /usr/local/share/fonts/WindowsFonts/*

    fc-cache --force
    fc-cache-32 --force

    echo -e "${BRIGHT_CYAN}Deleting Windows image and tmp directories...${NO_COLOR}"
    rm -r "$ISO_LOCATION" "/root/install.wim" "/root/fonts"

    # [ "$is_7z_installed" -eq "$FALSE" ] && pacman -Rs 7zip
}

install_lsd(){
    colored_msg "Installing lsd and a nerd font..." "${BRIGHT_CYAN}" "#"

    pacman --noconfirm -S lsd ttf-hack-nerd
}

# https://wiki.archlinux.org/title/snapper
# https://wiki.archlinux.org/title/snapper#Suggested_filesystem_layout
# https://wiki.archlinux.org/title/snapper#Configuration_of_snapper_and_mount_point
# https://wiki.archlinux.org/title/snapper#Wrapping_pacman_transactions_in_snapshots
# https://wiki.archlinux.org/title/Snapper#Snapshots_on_boot
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

    local -r USER=$(get_sudo_user)

    install_aur_package "https://aur.archlinux.org/yay.git"

    echo -e "${BRIGHT_CYAN}Configuring yay...${NO_COLOR}"
    sudo -S -i -u "$USER" yay -Y --gendb
    sudo -S -i -u "$USER" yay -Syu --devel
    sudo -S -i -u "$USER" yay -Y --devel --save 

    [ "$bootloader" = "grub" ] && redo_grub
}

# https://wiki.archlinux.org/title/dm-crypt/Device_encryption#Keyfiles
# https://wiki.archlinux.org/title/Dm-crypt/System_configuration#rd.luks.key
enable_crypt_keyfile(){
    colored_msg "Enabling keyfile at boot..." "${BRIGHT_CYAN}" "#"

    ask "Is your pendrive inserted? If not, insert it now."

    local drive
    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -ne "${YELLOW}Select drive (not the partition): ${NO_COLOR}"
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
    # Denying access to other users but root
    chmod 600 "/mnt/$keyfile_name"
    
    cryptsetup luksAddKey "$sys_part" "/mnt/$keyfile_name"

    # Adding the modules on mkinitcpio, only if they are not already there
    echo -e "${BRIGHT_CYAN}Adding $selected_module to mkinitcpio.conf...${NO_COLOR}"
    ! grep -E "^MODULES=\(.*$selected_module.*\)$" "/etc/mkinitcpio.conf" && add_option_mkinitcpio "MODULES" "$selected_module" "/etc/mkinitcpio.conf"
    mkinitcpio -P


    # !!!
    # We need to add a new kernel parameter.
    # First, we check if rd.luks.options exists.
    if grep -i "rd.luks.options" /etc/default/grub > /dev/null;
    then
        # If the entry exists, we add a new parameter inside
        echo -e "${BRIGHT_CYAN}The entry exists. Adding new option.${NO_COLOR}"

        # !!!
        if [ "$bootloader" = "grub" ];
        then
            add_option_inside_luks_options "keyfile-timeout=10s" "/etc/default/grub" "$TRUE"
        else
            add_option_inside_luks_options "keyfile-timeout=10s" "/boot/loader/entries/arch.conf" "$TRUE"            
            add_option_inside_luks_options "keyfile-timeout=10s" "/boot/loader/entries/arch-fallback.conf" "$TRUE"
        fi
    else
        # If the entry does not exist, we add rd.luks.options directly.
        echo -e "${BRIGHT_CYAN}The entry does not exist. Adding new option.${NO_COLOR}"

        if [ "$bootloader" = "grub" ];
        then
            add_option_bootloader "rd.luks.options=keyfile-timeout=10s" "/etc/default/grub"
        else
            add_option_bootloader "rd.luks.options=keyfile-timeout=10s" "/boot/loader/entries/arch.conf"
            add_option_bootloader "rd.luks.options=keyfile-timeout=10s" "/boot/loader/entries/arch-fallback.conf"
        fi
    fi

#   Now we need to add the key UUID to the kernel parameter.
    local -r PEN_UUID=$(blkid -s UUID -o value "$part")
    local -r ROOT_UUID=$(blkid -s UUID -o value "$sys_part")

    if [ "$bootloader" = "grub" ];
    then
        add_option_bootloader "rd.luks.key=$ROOT_UUID=$keyfile_name:UUID=$PEN_UUID" "/etc/default/grub"

        # We regenerate the grub config
        redo_grub
    else
        add_option_bootloader "rd.luks.key=$ROOT_UUID=$keyfile_name:UUID=$PEN_UUID" "/boot/loader/entries/arch.conf"
        add_option_bootloader "rd.luks.key=$ROOT_UUID=$keyfile_name:UUID=$PEN_UUID" "/boot/loader/entries/arch-fallback.conf"
    fi

    # Finally, unmount the pendrive
    umount /mnt
}

# CHECK FOR ROOTLESS WAYLAND!!!
# https://wiki.archlinux.org/title/SDDM#Rootless
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

# https://wiki.archlinux.org/title/SDDM#Theme_settings
breeze_sddm(){
    colored_msg "Changing SDDM theme to Breeze..." "${BRIGHT_CYAN}" "#"

    if [ ! -d "/etc/sddm.conf.d" ];
    then
        mkdir -p "/etc/sddm.conf.d"
    fi

    echo "[Theme]" > /etc/sddm.conf.d/sddm-theme.conf
    echo "Current=breeze" >> /etc/sddm.conf.d/sddm-theme.conf
}

cleanup(){
    rm -rf /root/after_install.tmp
}

# https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache
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

In any case, you can use the *.reg file located in .scripts/additional_resources/win64 to install it on Windows."
    fi

    echo -e "${BRIGHT_CYAN}Enabling NTP...${NO_COLOR}"
    systemctl enable systemd-timesyncd.service
    systemctl start systemd-timesyncd.service

    timedatectl set-ntp true
}


# https://wiki.archlinux.org/title/fan_speed_control
# https://gitlab.com/coolercontrol/coolercontrol/-/wikis/config-files
enable_fan_control(){
    local -r USER=$(get_sudo_user)
    colored_msg "Installing Fan Control software..." "${BRIGHT_CYAN}" "#"

    echo -e "${BRIGHT_CYAN}Installing lm_sensors...${NO_COLOR}"
    sudo -S -i -u "$USER" yay -S lm_sensors

    # This is needed so CoolerControl can detect missing sensors
    sensors-detect

    echo -e "${BRIGHT_CYAN}Installing CoolerControl...${NO_COLOR}"
    sudo -S -i -u "$USER" yay -S coolercontrol-bin

    echo -e "${BRIGHT_CYAN}Enabling coolercontrol service...${NO_COLOR}"
    systemctl enable --now coolercontrold

    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        echo "
Options:
1) Torre-AMD (R9 5900X - NVIDIA RTXC 3080 Ti)
"

        echo -ne "${YELLOW}Please select an option: ${NO_COLOR}"
        read -r selection

        case $selection in
            "1")
                echo -e "${BRIGHT_CYAN}Copying profile...${NO_COLOR}"
                cp additional_resources/CoolerControl/Torre-AMD/* /etc/coolercontrol
                systemctl restart coolercontrold
                is_done="$TRUE"
                ;;
            
            *)
                echo -e "${RED}Wrong option${NO_COLOR}"
                is_done="$FALSE"
                ;;
        esac
    done
}

# https://wiki.archlinux.org/title/improving_performance#Improving_system_responsiveness_under_low-memory_conditions
# Configuration extracted from Fedora and Ubuntu
# See config: systemd-analyze cat-config systemd/oomd.conf
enable_oomd(){
    colored_msg "Enabling systemd-oomd.service..." "${BRIGHT_CYAN}" "#"

    if ask "Do you want to add the recommended configuration?";
    then
        echo -e "${BRIGHT_CYAN}Adding the recommended configuration to /etc/systemd/oomd.conf...${NO_COLOR}"
        echo "DefaultMemoryPressureDurationSec=20s" >> /etc/systemd/oomd.conf
    fi

    echo -e "${BRIGHT_CYAN}Enabling and starting the service...${NO_COLOR}"
    systemctl enable --now systemd-oomd.service
}


# https://wiki.archlinux.org/title/WireGuard
# https://wiki.archlinux.org/title/WireGuard#NetworkManager
install_wireguard(){
    colored_msg "Installing wireguard and GUI..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)

    echo -e "${BRIGHT_CYAN}Installing wireguard-tools...${NO_COLOR}"
    sudo -S -i -u "$USER" yay -S wireguard-tools

    local is_done

    if ask "Do you want to add a Wireguard configuration file to the system?";
    then
        is_done="$FALSE"
    else
        is_done="$TRUE"
    fi


    local conf_filename
    while [ "$is_done" -eq "$FALSE" ]
    do
        echo -n "Please provide a wg-quick configuration file (use full path name): "
        read -r conf_file

        if [ -f "$conf_file" ];
        then
            conf_filename=$(echo "$conf_file" | rev | cut -d/ -f1 | rev )

            ask "You have selected $conf_filename. Is that correct?" && is_done="$TRUE"
            
            # Only add the config file if the user has agreed
            [ "$is_done" -eq "$TRUE" ] && nmcli connection import type wireguard file "$conf_file"
        else
            echo -e "${RED}The file does not exist${NO_COLOR}"
        fi
    done

}


install_autoeq(){
    colored_msg "Installing EasyEffects..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)
    
    sudo -S -i -u "$USER" yay -S easyeffects lsp-plugins calf
}

update_gendb(){
    colored_msg "Updating yay development database..." "${BRIGHT_CYAN}" "#"
    local -r USER=$(get_sudo_user)

    sudo -S -i -u "$USER" yay -Y --gendb
}

install_plymouth(){
    colored_msg "Installing Plymouth..." "${BRIGHT_CYAN}" "#"
    local -r USER=$(get_sudo_user)
    
    sudo -S -i -u "$USER" yay -S plymouth

    local hook="kms"
    
    [ "$has_encryption" -eq "$TRUE" ] && hook="systemd"

    awk '
    BEGIN{OFS=FS="="}
    /^HOOKS=/{
        len=split($2, arr, / /);
        printf("HOOKS=")

        for(i=1; i<=len; i++){
            if (arr[i]=="'$hook'")
                arr[i]=arr[i]" plymouth"

            if (i==len)
                printf("%s", arr[i])
            else
                printf("%s ", arr[i])
        }

        printf("\n")
    };

    !/^HOOKS=/{print $0}

    ' /etc/mkinitcpio.conf > aux

    mv aux /etc/mkinitcpio.conf

    # Regenerate initramfs
    mkinitcpio -P


    if [ "$bootloader" = "grub" ];
    then
        add_option_bootloader "splash" "/etc/default/grub"
        redo_grub "$FALSE"
    else
        add_option_bootloader "splash" "/boot/loader/entries/arch.conf"
        add_option_bootloader "splash" "/boot/loader/entries/arch-fallback.conf"
    fi
}


# https://wiki.archlinux.org/title/GRUB/Tips_and_tricks
lower_grub_res(){
    colored_msg "Lowering GRUB resolution..." "${BRIGHT_CYAN}" "#"

    awk '/^GRUB_GFXMODE=/{
        printf("# %s\n",$0)
        printf("GRUB_GFXMODE=1920x1080x24,1024x768x32,auto\n")
    }
    
    ! /^GRUB_GFXMODE=/{print $0}

    ' "/etc/default/grub" > aux

    mv aux /etc/default/grub
    
    redo_grub "$FALSE"
}


# Laptop specific functions

# https://wiki.archlinux.org/title/External_GPU#Xorg_rendered_on_iGPU,_PRIME_render_offload_to_eGPU
# https://wiki.archlinux.org/title/PRIME#PRIME_GPU_offloading
# https://wiki.archlinux.org/title/PRIME#PCI-Express_Runtime_D3_(RTD3)_Power_Management
enable_envycontrol(){
    colored_msg "Enabling envycontrol..." "${BRIGHT_CYAN}" "#"

    local -r USER=$(get_sudo_user)
    
    sudo -S -i -u "$USER" yay -S envycontrol nvidia-prime

    # echo -e "${BRIGHT_CYAN}Switching to integrated mode...${NO_COLOR}"
    # envycontrol -s integrated

    echo -e "${BRIGHT_CYAN}Adding temporary configuration...${NO_COLOR}"
    cp "additional_resources/laptop_scripts/laptop_prime.sh" "/etc/profile.d"
}


# https://wiki.archlinux.org/title/MSI_GE75_Raider_8SX#Driver_options
laptop_extra_config(){
    # aqui va la configuracion de los altavoces y eso
    echo -e "${BRIGHT_CYAN}Enabling modprobe config...${NO_COLOR}"

    echo "options snd_hda_intel model=lenovo-y530" > /etc/modprobe.d/msi_laptop.conf
}


install_laptop_opt_pkgs(){
    colored_msg "Installing lapatop optional packages..." "${BRIGHT_CYAN}" "#"
    local -r USER=$(get_sudo_user)
    
    sudo -S -i -u "$USER" yay -S "${LAPTOP_PKGS[@]}"
}


main(){
    ask_global_vars "$FALSE" "$FALSE"

    # Source var files
    [ -f "$VAR_FILE_LOC" ] && source "$VAR_FILE_LOC"

    # First, make a btrfs snapshot, just in case something goes wrong"
    [ "$root_fs" = "btrfs" ] && make_btrfs_install_snapshot "$log_step"

    case $log_step in
        0)
            [ "$bootloader" = "grub" ] && ask "Do you want to lower grub resolution to 1080p to make menu navigation faster (usually occurs on HiDPI displays)?" && lower_grub_res
            ask "Do you want to enable NTP?" && sync_time_dual_boot
            ask "Do you want to have REISUB?" && enable_reisub
            ask "Do you want to enable TRIM?" && enable_trim
            install_shells
            add_users
            ask "Do you want to parallelize package downloads and color them?" && improve_pacman
            ask "Do you want to enable periodic pacman cache cleaning?" && enable_paccache
            ask "Do you want to enable the multilib package (Steam)?" && enable_multilib
            ask "Do you want to enable reflector timer to update mirrorlist?" && enable_reflector
            [ "$root_fs" = "btrfs" ] && ask "Do you want to enable scrub?" && btrfs_scrub
            # ask "Do you want to install the dependencies to use the AUR and enable parallel compilation?" && prepare_for_aur
            # ask "Do you want to install an AUR helper?" && install_yay
            prepare_for_aur
            install_yay
            [ "$bootloader" = "sd-boot" ] && ask "Do you want to update systemd-boot every time systemd updates?" && install_sd_boot_pkgs
            ask "Do you want to install bluetooth service?" && install_bluetooth

            # CHECK INSTALL_XORG ON LAPTOP. 
            ask "Do you want to install Xorg and graphics driver?" && install_xorg

            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"
            ask_reboot
            ;;

        1)
            is_element_in_array "nvidia" gpu_type && add_nvidia_modprobe_config
            ask "Do you want to install KDE?" && install_kde


            # REBOOT
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"            
            ask_reboot
            ;;

        2)
            if [ "$is_kde" -eq "$TRUE" ];
            then
                # CHECK FOR ROOTLESS WAYLAND!!!
                rootless_kde
                ask "Do you want to change the default theme of SDDM to breeze?" && breeze_sddm
            fi

            ask "Do you want to install a cpu scaler?" && install_cpu_scaler
            ask "Do you want to install Plymouth (boot splash, not recommended)?" && install_plymouth
            ask "Do you want to enable OOM Killer (systemd-oomd)?" && enable_oomd
            ask "Do you want to install the printer service?" && install_printer
            ask "Do you want to install a firewall?" && install_firewall

            # PENSAR EN SI PONER LA REGLA UDEV
            ask "Do you want to install NTFS driver?" && enable_ntfs

            # CHECK IN THE FUTURE THE DAEMONS, THEY ARE SPLITTING THEM
            ask "Do you want to install KVM?" && install_kvm
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"    

            if [ "$has_encryption" -eq  "$TRUE" ] && [ "$root_fs" = "btrfs" ];
            then        
                ask_reboot "Please reboot your system to archiso again and copy .scripts folder to archiso root folder."
            else
                ask_reboot
            fi
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

            [ "$root_fs" = "btrfs" ] && ask "Do you want to install snapper and snap-pac?" && btrfs_snapshots
            add_global_var_to_file "log_step" "$((log_step+1))" "$VAR_FILE_LOC"
            ask_reboot
            ;;
        
        5)
            ask "Do you want to install Wireguard?" && install_wireguard
            ask "Do you want to install EasyEffects (for AutoEq)?" && install_autoeq
            ask "Do you want to install optional packages?" && install_optional_pkgs
            ask "Do you want to install printer specific drivers? (only if IPP is not working as intended)" && install_printer_drivers
            ask "Do you want to install additional udev rules?" && install_udev_rules
            
            [ "$is_laptop" -eq "$FALSE" ] && ask "Do you want to enable fan control?" && enable_fan_control
            
            if [ "$is_laptop" -eq "$TRUE" ] && is_element_in_array "nvidia" "gpu_type";
            then 
                ask "Do you want to enable laptop specific features?" && laptop_extra_config
                ask "Do you want to enable envycontrol?" && enable_envycontrol
                ask "Do you want to install laptop optional packages?" && install_laptop_opt_pkgs
            fi

            update_gendb
            ;;

        *)
            echo "Unknown error"
            exit 1
            ;;
    esac


    # echo "BOOT INTO ARCHISO, MOUNT FILESYSTEM AND EXECUTE /mnt/root/last_step.sh"
    echo "Enable nerd font on Terminal emulator."
    echo "Please enable on boot in virt manager the default network by going into Edit->Connection details->Virtual Networks->default."
    echo "It is normal for colord.service to fail. You need to execute manually colord command once and then the service will start."
    echo "You need to follow https://github.com/elFarto/nvidia-vaapi-driver/#environment-variables to configure Firefox HW ACC."
    # echo "CHECK FREEFILESYNC PACKAGE"
    echo "Disable automatic sleeping, screen shutoff and screen locking on Plasma"
    echo -e "${GREEN}KVM Guests${NO_COLOR} -> Install spice-vdagent to share clipboard or use the iso image and install it on Windows."
    echo "Refer to this link for more information: https://wiki.archlinux.org/title/QEMU#Enabling_SPICE_support_on_the_guest"
    echo -e "If lrcget doesn't work (opens and closes back) you can execute it in a terminal like so: ${YELLOW}WEBKIT_DISABLE_COMPOSITING_MODE=1 LRCGET${NO_COLOR}"
    
    if [ "$is_laptop" -eq "$FALSE" ];
    then
        echo -e "${GREEN}IMPORTANT!!${NO_COLOR}"
        echo -e "Check inside CoolerControl if the ${YELLOW}GPU FAN PROFILE${NO_COLOR} is set to ${YELLOW}DEFAULT PROFILE${NO_COLOR}."
        echo -e "If you want to play a game, change the ${YELLOW}GPU FAN PROFILE${NO_COLOR} to ${YELLOW}GPU Fan${NO_COLOR}."
    else
        echo -e "${BRIGHT_CYAN}Switching to integrated mode...${NO_COLOR}"
        echo -e "If you are using ${YELLOW}Wayland${NO_COLOR} and ${YELLOW}NVIDIA${NO_COLOR} mode and you want to use the NVIDIA GPU, append ${GREEN}prime-run${NO_COLOR} to your programs"
    fi

    # disable_ssh_service
}

main "$@"