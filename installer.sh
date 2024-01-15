#!/bin/zsh

# TODO:
# Poder detectar entre CSM y UEFI
# Intentar hacer algún menú interactivo
# Fix sleep command (it is a hacky way of doing things)
# Preguntar por el layout final de cuando te pide las particiones (por si te has equivocado)

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

readonly OPTIONAL_PKGS=("nano" "man-db" "git" "optipng" "oxipng" "pngquant" "imagemagick" "veracrypt" "gimp" "inkscape" "tldr" "zsh" "fzf" "lsd" "fish" "bat" "keepassxc" "shellcheck" "btop" "htop" "ufw" "gufw" "fdupes" "firefox" "rebuild-detector" "reflector" "sane" "sane-airscan" "simple-scan" "evince" "qbittorrent")

readonly AMD_PACKAGES=("cpupower")

# COMPROBAR LA INSTALACION DE ESTE PAQUETE, LE FALTAN LAS FUENTES
readonly LIBREOFFICE_PKGS=("libreoffice-fresh" "libreoffice-extension-texmaths" "libreoffice-extension-writer2latex" "hunspell" "hunspell-es_es" "hyphen" "hyphen-es" "libmythes" "mythes-es")

readonly TEXLIVE_PKGS=("texlive" "texlive-lang")

readonly BTRFS_EXTRA=("snapper" "snap-pac")
# readonly LAPTOP_ADD_PKGS=

# Paquetes que requieren configuración adidional: libreoffice, snapper, ufw, firefox, snapper, snap-pac, reflector, sane
# Paquetes especiales de la torre que requieren configuración adidional: cpupower
# Paquetes desactualizados: veracrypt, btop, 


# testing commands for live environment: passwd
# testing commands for host: scp installer.sh root@192.168.56.101:/root

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

loadkeys_tty(){
    echo -n "Type desired locale (leave empty for default): "
    read -r locale

    if [ -n "$locale" ];
    then
        echo "Loading $locale..."

        loadkeys "$locale"
    fi
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

    echo "These are your system partitions:" 
    lsblk

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
}


mkfs_partitions(){
    ask "Do you want to encrypt root partition?"
    has_encryption="$?"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        readonly DM_NAME="$(echo "$root_part" | cut -d "/" -f3)"
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

    umount /mnt

    for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        mount --mkdir "/dev/mapper/$DM_NAME" "${BTRFS_SUBVOL_MNT[i]}" -o compress-force=zstd,subvol="${BTRFS_SUBVOL[i]}"
    done    

    mount --mkdir "$boot_part" /mnt/boot
}

install_packages(){
    echo "The following packages are going to be installed: " "${BASE_PKGS[@]}"

    if ask "Do you want to star installation?";
    then
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
    less /etc/locale.gen

    local locales

    if [ "$#" -eq "0" ];
    then
        echo -n "Please type in (space separated) every locale: "
        read -r locales

    else
        locales="$1"
    fi

    echo "$locales"


    # grep -iE "#tre" "example"
}

final_message(){
    echo "You need to check the following things:
        - libreoffice: Enable LanguageTool and Spell checking. CHECK FOR FONTS, THEY ARE NOT INSTALLED.
        - To update LaTeX packages you need to use tlmgr, refer to archlinux doc.
        - WIP."

    echo "Things to keep fix:
        - Read the tlmgr for latex in archlinux wiki.
        "

    echo "${BASE_PKGS[@]}"
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
    fi

    generate_locales

    # DEBUG
    locale="us"


    final_message
    # If example with two variables
    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # then
    #     echo "Laptop"
    # else
    #     echo "Tower"
    # fi

    
}

test1(){
    mkfs_partitions
}

# test1

main "$@"