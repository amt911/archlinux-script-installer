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
readonly BTRFS_SUBVOL=("@" "@home" "@var_cache" "@var_abs" "@var_log" "@srv" "@var_tmp")
readonly BTRFS_SUBVOL_MNT=("/mnt" "/mnt/home" "/mnt/var/cache" "/mnt/var/abs" "/mnt/var/log" "/mnt/srv" "/mnt/var/tmp")

# Packages
readonly BASE_PKGS=("base" "linux" "linux-firmware" "btrfs-progs" "nano" "vi" "zsh")


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

    echo -e "${BRGIHT_CYAN}These are your system partitions:${NO_COLOR}" 
    lsblk

    while [ "$correct_layout" -eq "$FALSE" ]
    do
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

        ask "Does it have a swap partition?"
        has_swap="$?"
        add_global_var_to_file "has_swap" "$has_swap" "$VAR_FILE_LOC"

        
        if [ "$has_swap" -eq "$TRUE" ];
        then
            echo -ne "${YELLOW}Type swap partition: ${NO_COLOR}"
            read -r swap_part
            add_global_var_to_file "swap_part" "$swap_part" "$VAR_FILE_LOC"
        fi

        
        echo -ne "${YELLOW}Type root partition: ${NO_COLOR}"
        read -r root_part
        add_global_var_to_file "root_part" "$root_part" "$VAR_FILE_LOC"

        echo -ne "${YELLOW}Type boot partition: ${NO_COLOR}"
        read -r boot_part
        add_global_var_to_file "boot_part" "$boot_part" "$VAR_FILE_LOC"

        echo -e "${BRIGHT_CYAN}You have selected the following partitions:${NO_COLOR}"
        echo -e "${BRIGHT_CYAN}boot partition:${NO_COLOR} $boot_part"
        [ "$has_swap" -eq "$TRUE" ] && echo -e "${BRIGHT_CYAN}swap partition:${NO_COLOR} $swap_part"
        echo -e "${BRIGHT_CYAN}root partition:${NO_COLOR} $root_part"

        ask "Is that correct?"
        correct_layout="$?"
    done
}


mkfs_partitions(){
    colored_msg "Creating partitions..." "${BRIGHT_CYAN}" "#"

    local i
    ask "Do you want to encrypt root partition?"
    has_encryption="$?"
    add_global_var_to_file "has_encryption" "$has_encryption" "$VAR_FILE_LOC"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        DM_NAME="$(echo "$root_part" | cut -d "/" -f3)"
        add_global_var_to_file "DM_NAME" "$DM_NAME" "$VAR_FILE_LOC"

        local crypt_done="$FALSE"
        while [ "$crypt_done" -eq "$FALSE" ]
        do
            cryptsetup luksFormat "$root_part" && cryptsetup open "$root_part" "$DM_NAME" && crypt_done="$TRUE"
        done
    fi

    mkfs.btrfs -L root "/dev/mapper/$DM_NAME"
    mkfs.fat -F32 "$boot_part"

    mount "/dev/mapper/$DM_NAME" "/mnt" -o compress-force=zstd

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
        mount --mkdir "/dev/mapper/$DM_NAME" "${BTRFS_SUBVOL_MNT[i]}" -o compress-force=zstd,subvol="${BTRFS_SUBVOL[i]}"
    done   
    unset i 

    mount --mkdir "$boot_part" /mnt/boot
}

install_packages(){
    colored_msg "Base packages installation..." "${BRIGHT_CYAN}" "#"

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

    if [ "$#" -lt "2" ];
    then
        echo -ne "${YELLOW}Timezone region: ${NO_COLOR}"
        read -r region

        echo -ne "${YELLOW}City: ${NO_COLOR}"
        read -r city
    else
        region="$1"
        city="$2"
    fi

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
    # sed -i "s/#tres cuatro cinco/nano 33/g" example
    for i in "${selected_locales[@]}"
    do
        echo -e "${BRIGHT_CYAN}Adding ${i}...${NO_COLOR}"
        sed -i "s/#${i}/${i}/g" "/mnt/etc/locale.gen"
    done
    unset i
}

write_keymap(){
    colored_msg "Writing keymap to vconsole..." "${BRIGHT_CYAN}"
    echo "KEYMAP=$tty_layout" > /mnt/etc/vconsole.conf
}

net_config(){
    colored_msg "Network configuration..." "${BRIGHT_CYAN}" "#"

    local hostname_ok="$FALSE"

    while [ "$hostname_ok" -eq "$FALSE" ]
    do
        # Create the hostname file
        echo -ne "${YELLOW}Type hostname: ${NO_COLOR}"
        read -r machine_name
        add_global_var_to_file "machine_name" "$machine_name" "$VAR_FILE_LOC"

        if [ -z "$machine_name" ];
        then
            echo -e "${RED}Invalid hostname${NO_COLOR}"
        else
            hostname_ok="$TRUE"
        fi
    done

    echo "$machine_name" > /mnt/etc/hostname

    # TODO: Modify files with IPv4 and IPv6, install NetworkManager and enable its service.

    # On my usual config, I use IPv6 as localhost6
    echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ${machine_name}" >> /mnt/etc/hosts

    # Installation of NetworkManager
    arch-chroot /mnt pacman --noconfirm -S networkmanager
    arch-chroot /mnt systemctl enable NetworkManager.service
}


# Only encrypted swap, for now
configure_swap(){
    colored_msg "Encrypted swap configuration..." "${BRIGHT_CYAN}" "#"
    # https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption

    # Create a consistent UUID for the partition
    mkfs.ext2 -L cryptswap "$swap_part" 1M

    # Insert into crypttab the new entry
    echo "swap LABEL=cryptswap /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size512" >> /mnt/etc/crypttab

    echo "/dev/mapper/swap none swap defaults 0 0" >> /mnt/etc/fstab
}

configure_mkinitcipio(){
    sed -i "s/^HOOKS/#HOOKS/g" "/mnt/etc/mkinitcpio.conf"

    # sed -e '/#1/a\' -e "new line" -i example

    # Insert new hook after commented one
    sed -e '/^#HOOKS/a\' -e "HOOKS=(base systemd btrfs autodetect modconf kms block keyboard sd-vconsole sd-encrypt filesystems fsck)" -i "/mnt/etc/mkinitcpio.conf"

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

install_microcode(){
    colored_msg "CPU microcode..." "${BRIGHT_CYAN}" "#"

    local ucode="amd-ucode"

    ask "Is it an Intel CPU?"
    is_intel="$?"
    add_global_var_to_file "is_intel" "$is_intel" "$VAR_FILE_LOC"

    [ "$is_intel" -eq "$TRUE" ] && ucode="intel-ucode"
    
    arch-chroot /mnt pacman --noconfirm -S "$ucode"
}

install_bootloader(){
    colored_msg "Bootloader installation..." "${BRIGHT_CYAN}" "#"

    # Install bootloader package
    arch-chroot /mnt pacman --noconfirm -S grub efibootmgr

    # Configure GRUB
    # /etc/default/grub
    sed -i "s/ quiet\"$/\"/" /mnt/etc/default/grub

    local -r ROOT_UUID=$(blkid -s UUID -o value "/dev/$DM_NAME")

    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" "rd.luks.name=${ROOT_UUID}=${DM_NAME} root=\/dev\/mapper\/${DM_NAME} rootflags=compress-force=zstd,subvol=@" "/mnt/etc/default/grub" "$TRUE" "$TRUE"


    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch

    install_microcode

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
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

    configure_mkinitcipio
    
    [ "$has_swap" -eq "$TRUE" ] && configure_swap

    set_password

    install_bootloader
    
    # install_ssh

    echo -e "${GREEN}Basic installation completed!.${NO_COLOR} Now boot to root user and continue with the installation"

    cp -r /root/.scripts /mnt/root/.scripts
}

main "$@"