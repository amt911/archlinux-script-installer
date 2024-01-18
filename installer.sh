#!/bin/zsh

# testing commands for live environment: passwd
# set static ip to archiso: ip a add 192.168.56.101/24 broadcast + dev enp0s8
# testing commands for host: scp installer.sh root@192.168.56.101:/root

# TODO:
# Poder detectar entre CSM y UEFI
# Intentar hacer algún menú interactivo
# Fix sleep command (it is a hacky way of doing things)
# Preguntar por el layout final de cuando te pide las particiones (por si te has equivocado)
# Mejorar la lógica para mostrar los locales disponibles.
# DONE Mejorar la lógica de loadkeys_tty
# Añadir posibilidad de desencriptar utilizando USB
# Tener en cuenta mas opciones de swap
# Arreglar la logica del grep en generate_locales, que se le puede meter \ y puede ser que se puede ejecutar codigo

readonly TRUE=0
readonly FALSE=1
readonly BTRFS_SUBVOL=("@" "@home" "@var_cache" "@var_abs" "@var_log" "@srv" "@snapshots" "@home_snapshots")
readonly BTRFS_SUBVOL_MNT=("/mnt" "/mnt/home" "/mnt/var/cache" "/mnt/var/abs" "/mnt/var/log" "/mnt/srv")
# "@var_lib_libvirt"
# "/mnt/lib/libvirt"
# DA FALLO PORQUE DICE QUE EXISTE EL DIRECTORIO /lib
# HAY QUE QUITAR /mnt/lib/libvirt Y PONERLO DESPUES DE LA INSTALACION DE LOS PAQUETES CON PACSTRAP


# Packages
# 1
readonly BASE_PKGS=("base" "linux" "linux-firmware" "btrfs-progs")

readonly SHELLS_SUDO=("zsh" "fish" "sudo")

readonly OPTIONAL_PKGS=("mec.mec" "less" "nano" "man-db" "git" "optipng" "oxipng" "pngquant" "imagemagick" "veracrypt" "gimp" "inkscape" "tldr" "fzf" "lsd" "bat" "keepassxc" "shellcheck" "btop" "htop" "ufw" "gufw" "fdupes" "firefox" "rebuild-detector" "reflector" "sane" "sane-airscan" "simple-scan" "evince" "qbittorrent")

readonly AMD_PACKAGES=("cpupower")

# COMPROBAR LA INSTALACION DE ESTE PAQUETE, LE FALTAN LAS FUENTES
readonly LIBREOFFICE_PKGS=("libreoffice-fresh" "libreoffice-extension-texmaths" "libreoffice-extension-writer2latex" "hunspell" "hunspell-es_es" "hyphen" "hyphen-es" "libmythes" "mythes-es")

readonly TEXLIVE_PKGS=("texlive" "texlive-lang")

readonly BTRFS_EXTRA=("snapper" "snap-pac")
# readonly LAPTOP_ADD_PKGS=

# Paquetes que requieren configuración adidional: libreoffice, snapper, ufw, firefox, snapper, snap-pac, reflector, sane
# Paquetes especiales de la torre que requieren configuración adidional: cpupower
# Paquetes desactualizados: veracrypt, btop, 


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


    sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" ${FILENAME}
}

loadkeys_tty(){
    echo -n "Type desired locale (leave empty for default): "
    read -r tty_layout

    if [ -z "$tty_layout" ];
    then
        tty_layout="us"
    fi

    echo "Loading $tty_layout..."

    loadkeys "$tty_layout"
}

is_efi(){
    local res="$FALSE"

    # cat "/sys/firmware/efi/fw_platform_size" 2> /dev/null


    # if [ "$?" -eq 0 ];
    if cat "/sys/firmware/efi/fw_platform_size" 2> /dev/null;
    then
        res="$TRUE"
    fi

    return "$res"
}

check_current_time(){
    timedatectl

    if ! ask "Is it accurate?";
    then
        local date
        
        echo -n "Input the correct date (format: yyyy-mm-dd hh:mm:ss): "
        read -r date

        timedatectl set-time "$date"
    fi
}

partition_drive(){
    local part
    local selected="$FALSE"
    local correct_layout="$FALSE"

    echo "These are your system partitions:" 
    lsblk

    while [ "$correct_layout" -eq "$FALSE" ]
    do
        while [ "$selected" -eq "$FALSE" ]
        do
            echo -n "Type the drive/partitions where Arch Linux will be installed: "
            read -r part

            ask "You have selected $part. Is that correct?";
            selected="$?"
        done

        echo "Opening cfdisk..."
        cfdisk "$part"

        sleep 2
        echo "The partitions are as follows:"
        lsblk

        ask "Does it have a swap partition?"
        has_swap="$?"
        
        if [ "$has_swap" -eq "$TRUE" ];
        then
            echo -n "Type swap partition: "
            read -r swap_part
        fi

        
        echo -n "Type root partition: "
        read -r root_part

        echo -n "Type boot partition: "
        read -r boot_part

        echo "You have selected the following partitions:"
        echo "boot partition: $boot_part"
        [ "$has_swap" -eq "$TRUE" ] && echo "swap partition: $swap_part"
        echo "root partition: $root_part"

        ask "Is that correct?"
        correct_layout="$?"
    done
}


mkfs_partitions(){
    ask "Do you want to encrypt root partition?"
    has_encryption="$?"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        DM_NAME="$(echo "$root_part" | cut -d "/" -f3)"
        # local enc_root_part="/dev/mapper/$DM_NAME"

        local crypt_done="$FALSE"
        while [ "$crypt_done" -eq "$FALSE" ]
        do
            cryptsetup luksFormat "$root_part" && cryptsetup open "$root_part" "$DM_NAME" && crypt_done="$TRUE"
        done
    fi

    mkfs.btrfs -L root "/dev/mapper/$DM_NAME"
    mkfs.fat -F32 "$boot_part"

    mount "/dev/mapper/$DM_NAME" "/mnt" -o compress-force=zstd

    for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        btrfs subvolume create "/mnt/${BTRFS_SUBVOL[i]}"
    done
    unset i

    umount /mnt

    for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        mount --mkdir "/dev/mapper/$DM_NAME" "${BTRFS_SUBVOL_MNT[i]}" -o compress-force=zstd,subvol="${BTRFS_SUBVOL[i]}"
    done   
    unset i 

    mount --mkdir "$boot_part" /mnt/boot
}

install_packages(){
    echo "The following packages are going to be installed: " "${BASE_PKGS[@]}"

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
    local region
    local city

    if [ "$#" -lt "2" ];
    then
        echo -n "Timezone region: "
        read -r region

        echo -n "City: "
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
    echo "You are about to be shown all available locales, press q to exit"
    sleep 1

    less /mnt/etc/locale.gen

    local locale
    local selected_locales=()
    local is_done="$FALSE"
    local all_ok="$FALSE"
    local counter

    # Loop to start all over again in case there is a mistake
    while [ "$all_ok" -eq "$FALSE" ]
    do
        # Loop to select all locales
        while [ "$is_done" -eq "$FALSE" ]
        do
            echo -n "Please type in a locale (s to show locales and empty to continue): "
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
                    echo "Adding $locale to the list"
                    selected_locales=("$selected_locales[@]" $locale)
                else
                    echo "$locale not found. Not added to the list."
                fi
                ;;
            esac
        done


        # Lists all selected locales
        echo "These are the selected locales:"

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
        echo "Adding ${i}..."
        sed -i "s/#${i}/${i}/g" "/mnt/etc/locale.gen"
    done
    unset i
}

write_keymap(){
    echo "KEYMAP=$tty_layout" > /mnt/etc/vconsole.conf
}

net_config(){
    local hostname_ok="$FALSE"

    while [ "$hostname_ok" -eq "$FALSE" ]
    do
        # Create the hostname file
        echo -n "Type hostname: "
        read -r machine_name

        if [ -z "$machine_name" ];
        then
            echo "Invalid hostname"
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
    if [ "$#" -eq "0" ];
    then
        arch-chroot /mnt passwd
    else
        passwd arch-chroot /mnt "$1"
    fi
}

install_microcode(){
    local ucode="amd-ucode"

    ask "Is it an Intel CPU?"
    is_intel="$?"

    [ "$is_intel" -eq "$TRUE" ] && ucode="intel-ucode"
    
    arch-chroot /mnt pacman --noconfirm -S "$ucode"
}

install_bootloader(){
    # Install bootloader package
    arch-chroot /mnt pacman --noconfirm -S grub efibootmgr

    # Configure GRUB
    # /etc/default/grub
    sed -i "s/ quiet\"$/\"/" /mnt/etc/default/grub

    local -r ROOT_UUID=$(blkid -s UUID -o value /dev/$DM_NAME)

    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" "rd.luks.name=${ROOT_UUID}=${DM_NAME} root=\/dev\/mapper\/${DM_NAME} rootflags=compress-force=zstd,subvol=@" "/mnt/etc/default/grub" "$TRUE"


    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch

    install_microcode

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

enable_trim(){
    if [ -z "$has_encryption" ];
    then
        ask "Does it have encryption?"
        has_encryption="$?"
    fi

    arch-chroot /mnt pacman --noconfirm -S util-linux
    arch-chroot /mnt systemctl enable fstrim.timer

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=discard" "/mnt/etc/default/grub" "$TRUE"
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 
    fi
}

enable_reisub(){
    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " sysrq_always_enabled=1" "/mnt/etc/default/grub" "$TRUE"

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}


improve_pacman(){

}

install_bluetooth(){

}

enable_ntfs(){

}

btrfs_scrub(){

}

btrfs_snapshots(){

}

add_users(){
    local adduser_done="$TRUE"
    local username
    local is_sudo
    local shell
    local passwd_ok="$FALSE"

    while [ "$adduser_done" -eq "$TRUE" ]
    do

        echo -n "Username: "
        read -r username

        echo "Available shells:"
        cat /mnt/etc/shells

        echo -n "Select a shell: "
        read -r shell

        if ask "Do you want this user to be part of the sudo (wheel) group?";
        then
            arch-chroot /mnt useradd -m -G wheel -s "$shell" "$username"
        else
            arch-chroot /mnt useradd -m -s "$shell" "$username"
        fi

        passwd_ok="$FALSE"

        while [ "$passwd_ok" -eq "$FALSE" ]
        do
            echo "Now you will be asked to type a password for the new user"
            arch-chroot /mnt passwd "$username"


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

install_shells(){
    arch-chroot /mnt pacman --noconfirm -S ${SHELLS_SUDO[@]}

    sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /mnt/etc/sudoers

    echo "Check if everything is OK"
    grep -i "%wheel" /mnt/etc/sudoers
}

install_firewall(){

}

final_message(){
    # echo "You need to check the following things:
    #     - libreoffice: Enable LanguageTool and Spell checking. CHECK FOR FONTS, THEY ARE NOT INSTALLED.
    #     - To update LaTeX packages you need to use tlmgr, refer to archlinux doc.
    #     - WIP."

    # echo "Things to keep fix:
    #     - Read the tlmgr for latex in archlinux wiki.
    #     "

    # echo "${BASE_PKGS[@]}"
}



# Main function
main(){
    # for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))
    # do
    #     echo "${BTRFS_SUBVOL_MNT[i]} -> ${BTRFS_SUBVOL[i]}"
    # done

    if [ "$#" -eq "0" ];
    then
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
    fi
    

    if ask "Basic installation completed!. Do you want to proceed to the optional configuration?";
    then
        if [ "$#" -eq "0" ];
        then
            ask "Do you want to have REISUB?" && enable_reisub
            ask "Do you want to enable TRIM?" && enable_trim
            ask "Do you want to install additional shells and sudo? THIS WILL MODIFY THE SUDOERS FILE TO ENABLE SUDO IN WHEEL GROUP" && install_shells
        fi
        
        add_users

        # improve_pacman
    fi
    




    # final_message
    # If example with two variables
    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # then
    #     echo "Laptop"
    # else
    #     echo "Tower"
    # fi

    
}

main "$@"