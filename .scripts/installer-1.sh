#!/bin/bash

# testing commands for live environment: passwd
# set static ip to archiso: ip a add 192.168.56.101/24 broadcast + dev enp0s8
# testing commands for host: scp installer.sh root@192.168.56.101:/root

source common-functions.sh

# TODO:
# Poder detectar entre CSM y UEFI
# Intentar hacer algún menú interactivo
# Fix sleep command (it is a hacky way of doing things)
# Tener en cuenta mas opciones de swap
# Arreglar la logica del grep en generate_locales, que se le puede meter \ y puede ser que se puede ejecutar codigo

# https://wiki.archlinux.org/title/Snapper#Preventing_slowdowns
# https://wiki.archlinux.org/title/snapper#Suggested_filesystem_layout
# /var/lib/docker
# /var/lib/machines
# /var/lib/postgres
readonly BTRFS_SUBVOL=("@" "@home" "@var_cache" "@var_abs" "@var_log" "@srv" "@var_tmp")
readonly BTRFS_SUBVOL_MNT=("/mnt" "/mnt/home" "/mnt/var/cache" "/mnt/var/abs" "/mnt/var/log" "/mnt/srv" "/mnt/var/tmp")

# Packages
BASE_PKGS=("base" "linux" "linux-firmware" "nano" "vi" "zsh")
readonly BASE_PKGS_BTRFS=("btrfs-progs")

# Paquetes que requieren configuración adidional: libreoffice, snapper, ufw, firefox, snapper, snap-pac, reflector, sane
# Paquetes especiales de la torre que requieren configuración adidional: cpupower
# Paquetes desactualizados: veracrypt, btop, 

loadkeys_tty(){
    echo -ne "${YELLOW}Type desired locale (leave empty for default): ${NO_COLOR}"
    read -r tty_layout

    if [ -z "$tty_layout" ];
    then
        tty_layout="us"
    fi

    echo -e "${BRIGHT_CYAN}Loading $tty_layout...${NO_COLOR}"

    loadkeys "$tty_layout"
}

is_efi(){
    local res="$FALSE"

    if cat "/sys/firmware/efi/fw_platform_size" 2> /dev/null;
    then
        res="$TRUE"
    fi

    return "$res"
}

check_current_time(){
    colored_msg "Checking time..." "${BRIGHT_CYAN}" "#"

    timedatectl

    if ! ask "Is it accurate?";
    then
        local date
        
        echo -ne "${YELLOW}Input the correct date (format: yyyy-mm-dd hh:mm:ss): ${NO_COLOR}"
        read -r date

        timedatectl set-time "$date"
    fi
}

partition_drive(){
    colored_msg "Select system partitions..." "${BRIGHT_CYAN}" "#"

    local part
    local selected="$FALSE"
    local correct_layout="$FALSE"

    while [ "$correct_layout" -eq "$FALSE" ]
    do
        echo -e "${BRGIHT_CYAN}These are your system partitions:${NO_COLOR}"
        lsblk

        while [ "$selected" -eq "$FALSE" ]
        do
            echo -ne "${YELLOW}Type the drive/partitions where Arch Linux will be installed: ${NO_COLOR}"
            read -r part

            ask "You have selected $part. Is that correct?";
            selected="$?"
        done

        echo -e "${BRIGHT_CYAN}Opening cfdisk...${NO_COLOR}"
        cfdisk "$part"

        sleep 2
        echo -e "${BRIGHT_CYAN}The partitions are as follow:${NO_COLOR}"
        lsblk

        ask_global_var "has_swap" "$TRUE" "$TRUE"

        
        if [ "$has_swap" -eq "$TRUE" ];
        then
            ask_global_var "swap_part" "$TRUE" "$TRUE"
        fi

        
        ask_global_var "root_part" "$TRUE" "$TRUE"
        ask_global_var "boot_part" "$TRUE" "$TRUE"

        echo -e "${BRIGHT_CYAN}You have selected the following partitions:${NO_COLOR}"
        echo -e "${BRIGHT_CYAN}boot partition:${NO_COLOR} $boot_part"
        [ "$has_swap" -eq "$TRUE" ] && echo -e "${BRIGHT_CYAN}swap partition:${NO_COLOR} $swap_part"
        echo -e "${BRIGHT_CYAN}root partition:${NO_COLOR} $root_part"

        ask "Is that correct?"
        correct_layout="$?"
        selected="$FALSE"
    done
}

# https://wiki.archlinux.org/title/installation_guide#Format_the_partitions
mkfs_partitions(){
    colored_msg "Creating partitions..." "${BRIGHT_CYAN}" "#"

    local i
    # ask "Do you want to encrypt root partition?"
    # has_encryption="$?"
    # add_global_var_to_file "has_encryption" "$has_encryption" "$VAR_FILE_LOC"
    ask_global_var "has_encryption" "$TRUE"

    # DM_NAME="$(echo "$root_part" | cut -d "/" -f3)"
    # add_global_var_to_file "DM_NAME" "$DM_NAME" "$VAR_FILE_LOC"
    ask_global_var "DM_NAME" "$TRUE"

    local drive="/dev/$DM_NAME"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        local crypt_done="$FALSE"
        while [ "$crypt_done" -eq "$FALSE" ]
        do
            cryptsetup luksFormat "$root_part" && cryptsetup open "$root_part" "$DM_NAME" && crypt_done="$TRUE"
        done

        drive="/dev/mapper/$DM_NAME"
    fi

#     Ask for the preferred filesystem
    ask_global_var "root_fs" "$TRUE"

    case $root_fs in
        "btrfs")
            create_btrfs "$drive"
            ;;

        "ext4")
            create_ext4 "$drive"
            ;;

        *)
            echo "error"
            exit
            ;;
    esac

    mkfs.fat -F32 "$boot_part"
    mount --mkdir "$boot_part" /mnt/boot
}

# https://wiki.archlinux.org/title/ext4
# $1: Drive location
create_ext4(){
    local -r DRIVE="$1"

    mkfs.ext4 -L root "$DRIVE"

    mount "$DRIVE" /mnt
}

# https://wiki.archlinux.org/title/btrfs
# $1: Drive location
create_btrfs(){
    local -r DRIVE="$1"

    local i
    mkfs.btrfs -L root "$DRIVE"

    mount "$DRIVE" "/mnt" -o compress-force=zstd

    # for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))    # zsh version
    for ((i=0; i<${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        btrfs subvolume create "/mnt/${BTRFS_SUBVOL[i]}"
    done
    unset i

    umount /mnt

    # for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))    # zsh version
    for ((i=0; i<${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        mount --mkdir "$DRIVE" "${BTRFS_SUBVOL_MNT[i]}" -o compress-force=zstd,subvol="${BTRFS_SUBVOL[i]}"
    done
    unset i
}

# https://wiki.archlinux.org/title/installation_guide#Install_essential_packages
install_packages(){
    colored_msg "Base packages installation..." "${BRIGHT_CYAN}" "#"

    install_microcode

    [ "$root_fs" = "btrfs" ] && BASE_PKGS=("${BASE_PKGS[@]}" "${BASE_PKGS_BTRFS[@]}")

    echo -e "${BRIGHT_CYAN}The following packages are going to be installed: ${NO_COLOR}" "${BASE_PKGS[@]}"

    if ask "Do you want to start installation?";
    then
        pacman --noconfirm -Sy archlinux-keyring
        pacstrap -K /mnt "${BASE_PKGS[@]}"
    fi
}

configure_fstab(){
    genfstab -U /mnt >> /mnt/etc/fstab
}

# $1: Region
# $2: City
configure_timezone(){
    colored_msg "Timezone configuration..." "${BRIGHT_CYAN}" "#"
    local region
    local city
    local is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do

        if [ "$#" -lt "2" ];
        then
            echo -ne "${YELLOW}Timezone region: ${NO_COLOR}"
            read -r region

            echo -ne "${YELLOW}City: ${NO_COLOR}"
            read -r city

            [ -f "/usr/share/zoneinfo/$region/$city" ] && is_done="$TRUE"
        else
            region="$1"
            city="$2"
            is_done="$TRUE"
        fi
    done
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$region"/"$city" /etc/localtime

    arch-chroot /mnt hwclock --systohc
}

# $1: locales
generate_locales(){
    colored_msg "Locale generation..." "${BRIGHT_CYAN}" "#"

    echo -e "${BRIGHT_CYAN}You are about to be shown all available locales, press q to exit${NO_COLOR}"
    sleep 1

    less /mnt/etc/locale.gen

    local locale
    local selected_locales=()
    local is_done="$FALSE"
    local all_ok="$FALSE"
    local counter
    local i

    # Loop to start all over again in case there is a mistake
    while [ "$all_ok" -eq "$FALSE" ]
    do
        # Loop to select all locales
        while [ "$is_done" -eq "$FALSE" ]
        do
            echo -ne "${YELLOW}Please type in a locale (s to show locales and empty to continue): ${NO_COLOR}"
            read -r locale

            case $locale in
                [sS]) 
                less /mnt/etc/locale.gen
                ;;

                "")
                is_done="$TRUE"
                ;;

                *)
                if grep -E "#${locale}  $" "/mnt/etc/locale.gen" > /dev/null;
                then
                    echo -e "${BRIGHT_CYAN}Adding $locale to the list${NO_COLOR}"
                    selected_locales=("${selected_locales[@]}" "$locale")
                else
                    echo -e "${RED}$locale not found. Not added to the list.${NO_COLOR}"
                fi
                ;;
            esac
        done


        # Lists all selected locales
        echo -e "${BRIGHT_CYAN}These are the selected locales:${NO_COLOR}"

        counter=1
        for i in "${selected_locales[@]}"
        do
            echo "$counter.- $i"

            ((counter++))
        done
        unset i

        # Starts all over again if the selection is not okay
        ask "Is everything OK?"
        all_ok="$?"
        is_done="$all_ok"

        [ "$all_ok" -eq "$FALSE" ] && selected_locales=()
    done

    # Uncomment selected locales
    for i in "${selected_locales[@]}"
    do
        echo -e "${BRIGHT_CYAN}Adding ${i}...${NO_COLOR}"
        sed -i "s/#${i}/${i}/g" "/mnt/etc/locale.gen"
    done
    unset i

    # Generate the locales
    echo -e "${BRIGHT_CYAN}Generating locales...${NO_COLOR}"
    arch-chroot /mnt locale-gen

    # Create locale.conf file with the first locale
    # It should show all selected locales and should prompt the user to select one
    is_done="$FALSE"

    while [ "$is_done" -eq "$FALSE" ]
    do
        # Lists available locales
        echo -e "${BRIGHT_CYAN}These are the available locales:${NO_COLOR}"

        counter=1
        for i in "${selected_locales[@]}"
        do
            echo "$counter.- $i"

            ((counter++))
        done
        unset i

        echo -ne "${YELLOW}Please select an option (only a number): ${NO_COLOR}"
        read -r locale

        # Checks if the selected value is a number
        re='^[0-9]+$'
        if [[ $locale =~ $re ]] && [ "$locale" -gt "0" ] && [ "$locale" -le "${#selected_locales[@]}" ]; 
        then
            if ask "You have selected $locale. Is that OK?";
            then
                # Getting the desired index (starts at 0) and the desired locale without the end
                locale_index=$((locale - 1))
                locale=$(echo "${selected_locales[locale_index]}" | cut -d" " -f1)

                echo -e "${BRIGHT_CYAN}Adding $locale...${NO_COLOR}"
                echo "LANG=$locale" > /mnt/etc/locale.conf

                is_done="$TRUE"
            fi
        else
            echo -e "${RED}Error: The selected option is not a number or is not in range.${NO_COLOR}"
            is_done="$FALSE"
        fi
    done
}

write_keymap(){
    colored_msg "Writing keymap to vconsole..." "${BRIGHT_CYAN}"
    echo "KEYMAP=$tty_layout" > /mnt/etc/vconsole.conf
}

# https://wiki.archlinux.org/title/Network_configuration#Network_managers
# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
# https://wiki.archlinux.org/title/Installation_guide#Network_configuration
# https://wiki.archlinux.org/title/Network_configuration#localhost_is_resolved_over_the_network
net_config(){
    colored_msg "Network configuration..." "${BRIGHT_CYAN}" "#"

    local hostname_ok="$FALSE"

    while [ "$hostname_ok" -eq "$FALSE" ]
    do
        # Create the hostname file
        ask_global_var "machine_name" "$TRUE"

        if [ -z "$machine_name" ];
        then
            echo -e "${RED}Invalid hostname${NO_COLOR}"
        else
            hostname_ok="$TRUE"
        fi
    done

    echo "$machine_name" > /mnt/etc/hostname

    # On my usual config, I use IPv6 as localhost6
    echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${machine_name}" >> /mnt/etc/hosts

    # Installation of NetworkManager
    arch-chroot /mnt pacman --noconfirm -S networkmanager
    arch-chroot /mnt systemctl enable NetworkManager.service
}


# Only encrypted swap, for now
# https://wiki.archlinux.org/title/dm-crypt/Swap_encryption#Without_suspend-to-disk_support
configure_swap(){
    colored_msg "Swap configuration..." "${BRIGHT_CYAN}" "#"
    # https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption
    
    local final_swap_part="$swap_part"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        echo -e "${BRIGHT_CYAN}Creating encrypted swap partition...${NO_COLOR}"

        # Create a consistent UUID for the partition
        mkfs.ext2 -L cryptswap "$swap_part" 1M

        # Insert into crypttab the new entry
        echo "swap LABEL=cryptswap /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size512" >> /mnt/etc/crypttab
        
        final_swap_part="/dev/mapper/swap"
    else
        echo -e "${BRIGHT_CYAN}Creating swap partition...${NO_COLOR}"

        mkswap "$swap_part"
        swapon "$swap_part"
    fi

    echo "$final_swap_part none swap defaults 0 0" >> /mnt/etc/fstab
}


# https://wiki.archlinux.org/title/Mkinitcpio#Common_hooks
# https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system
# If a module the is needed is not loaded, you can load it using
configure_mkinitcpio(){
    readarray -td" " a < <(printf "%s" "$(grep -e "^HOOKS=" /mnt/etc/mkinitcpio.conf | cut -d= -f2 | sed "s/[()]//g")")

    local i
    local aux=()
    # First pass to add keyboard before autodetect
    for i in "${a[@]}"
    do
        if [ "$i" = "autodetect" ];
        then
            aux+=("keyboard" "autodetect")

        elif [ "$i" != "keyboard" ];
        then
            aux+=("$i")
        fi
    done
    a=("${aux[@]}")
    aux=()

    unset i

    # If it has encryption, it need to do a second pass to substitute some hooks to systemd
    if [ "$has_encryption" -eq "$TRUE" ];
    then
        for i in "${a[@]}"
        do
            if [ "$i" = "udev" ];
            then
                aux+=("systemd")

            elif [ "$i" = "keymap" ];
            then
                aux+=("sd-vconsole")

            elif [ "$i" = "block" ];
            then
                aux+=("$i")
                aux+=("sd-encrypt")

            elif [ "$i" != "usr" ] && [ "$i" != "resume" ] && [ "$i" != "consolefont" ];
            then
                aux+=("$i")

            fi
        done
        unset i
        a=("${aux[@]}")
        aux=()
    fi


    # If the filesystem is btrfs, it does a last pass to add the btrfs hook
    if [ "$root_fs" = "btrfs" ];
    then
        local last_hook

        if [ "$has_encryption" -eq "$FALSE" ];
        then
            # Finds if btrfs should be after udev, usr or resume. Only if it does not have FSE
            for i in "${a[@]}"
            do
                if [ "$i" = "udev" ] || [ "$i" = "usr" ] || [ "$i" = "resume" ];
                then
                    last_hook="$i"
                fi
            done
            unset i
        fi

        # Finally, it add the btrfs hook
        for i in "${a[@]}"
        do
            aux+=("$i")
            if [ "$i" = "systemd" ] || [ "$i" = "$last_hook" ];
            then
                aux+=("btrfs")
            fi
        done
        unset i
        a=("${aux[@]}")
        aux=()
    fi

    awk -v hooks="${a[*]}" '
    /^HOOKS=/{
        print "#", $0
        printf("HOOKS=(%s)\n", hooks)
    }

    ! /^HOOKS=/{
        print $0
    }
    ' /mnt/etc/mkinitcpio.conf > /mnt/etc/mkinitcpio.conf.aux
    
    mv /mnt/etc/mkinitcpio.conf{.aux,}    

    arch-chroot /mnt mkinitcpio -P
}

# $1: username. Empty for root
set_password(){
    colored_msg "Root password configuration..." "${BRIGHT_CYAN}" "#"

    if [ "$#" -eq "0" ];
    then
        arch-chroot /mnt passwd
    else
        passwd arch-chroot /mnt "$1"
    fi
}

# https://wiki.archlinux.org/title/Microcode
# https://wiki.archlinux.org/title/installation_guide#Install_essential_packages
install_microcode(){
#     colored_msg "CPU microcode..." "${BRIGHT_CYAN}" "#"

    local ucode="amd-ucode"

    # ask "Is it an Intel CPU?"
    # is_intel="$?"
    # add_global_var_to_file "is_intel" "$is_intel" "$VAR_FILE_LOC"
    ask_global_var "is_intel" "$TRUE"

    [ "$is_intel" -eq "$TRUE" ] && ucode="intel-ucode"
    
#     arch-chroot /mnt pacman --noconfirm -S "$ucode"

    BASE_PKGS=("${BASE_PKGS[@]}" "$ucode")
}

# https://wiki.archlinux.org/title/Arch_boot_process#Boot_loader
# https://wiki.archlinux.org/title/GRUB
# https://wiki.archlinux.org/title/Systemd-boot
# https://wiki.archlinux.org/title/Kernel_parameters#Parameter_list
# https://wiki.archlinux.org/title/Btrfs#Mounting_subvolume_as_root
install_bootloader(){
    colored_msg "Bootloader installation..." "${BRIGHT_CYAN}" "#"

    ask_global_var "bootloader" "$TRUE" "$TRUE"

    if [ "$bootloader" = "grub" ];
    then
        # Install bootloader package
        arch-chroot /mnt pacman --noconfirm -S grub efibootmgr

        # Configure GRUB
        sed -i "s/ quiet\"$/\"/" /mnt/etc/default/grub

        # Add the following lines ONLY if root partition is encrypted
        if [ "$has_encryption" -eq "$TRUE" ];
        then
            local -r ROOT_UUID=$(blkid -s UUID -o value "/dev/$DM_NAME")

            add_option_bootloader "rd.luks.name=${ROOT_UUID}=${DM_NAME} root=/dev/mapper/${DM_NAME}" "/mnt/etc/default/grub"
        fi

        # If the filesystem is btrfs, we add the necessary rootflags
        [ "$root_fs" = "btrfs" ] && add_option_bootloader "rootflags=compress-force=zstd,subvol=@" "/mnt/etc/default/grub"

        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

    else
        # Install bootloader to NVRAM
        arch-chroot /mnt bootctl install --esp-path=/boot

        # Copying loader and entries configuration
        cp additional_resources/systemd-boot/loader.conf /mnt/boot/loader
        cp additional_resources/systemd-boot/arch.conf /mnt/boot/loader/entries
        cp additional_resources/systemd-boot/arch-fallback.conf /mnt/boot/loader/entries

        if [ "$has_encryption" -eq "$TRUE" ];
        then
            local -r ROOT_UUID=$(blkid -s UUID -o value "/dev/$DM_NAME")

            add_option_bootloader "rd.luks.name=${ROOT_UUID}=${DM_NAME} root=/dev/mapper/${DM_NAME} rw" "/mnt/boot/loader/entries/arch.conf"
            add_option_bootloader "rd.luks.name=${ROOT_UUID}=${DM_NAME} root=/dev/mapper/${DM_NAME} rw" "/mnt/boot/loader/entries/arch-fallback.conf"

        else
            add_option_bootloader "root=/dev/${DM_NAME} rw" "/mnt/boot/loader/entries/arch.conf"
            add_option_bootloader "root=/dev/${DM_NAME} rw" "/mnt/boot/loader/entries/arch-fallback.conf"
        fi

        # If the filesystem is btrfs, we add the necessary rootflags
        if [ "$root_fs" = "btrfs" ];
        then
            add_option_bootloader "rootflags=compress-force=zstd,subvol=@" "/mnt/boot/loader/entries/arch.conf"
            add_option_bootloader "rootflags=compress-force=zstd,subvol=@" "/mnt/boot/loader/entries/arch-fallback.conf"
        fi
    fi
}

# Only for debugging purposes
install_ssh(){
    arch-chroot /mnt pacman --noconfirm -S openssh
    arch-chroot /mnt systemctl enable sshd.service

    # Modify file to accept root
    sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/" /mnt/etc/ssh/sshd_config
}

# Main function
main(){
    [ -f "$VAR_FILE_LOC" ] && source "$VAR_FILE_LOC"

    loadkeys_tty

    if is_efi;
    then
        echo "EFI system"
    else
        echo "CSM system"
    fi

    check_current_time

    partition_drive

    mkfs_partitions
    
    install_packages

    configure_timezone

    configure_fstab

    generate_locales

    write_keymap

    net_config

    configure_mkinitcpio
    
    [ "$has_swap" -eq "$TRUE" ] && configure_swap

    set_password

    install_bootloader
    
    # install_ssh

    echo -e "${GREEN}Basic installation completed!.${NO_COLOR} Now boot to root user and continue with the installation"

    cp -r /root/.scripts /mnt/root/.scripts
}

main "$@"