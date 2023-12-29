#!/bin/zsh

# TODO:
# Poder detectar entre CSM y UEFI
# Intentar hacer algún menú interactivo
# Fix sleep command (it is a hacky way of doing things)

readonly TRUE=0
readonly FALSE=1
readonly BTRFS_SUBVOL=("@" "@home" "@var_cache" "@var_abs" "@var_log" "@var_lib_libvirt" "@srv" "@snapshots" "@home_snapshots")
readonly BTRFS_SUBVOL_MNT=("/mnt" "/mnt/home" "/mnt/var/cache" "/mnt/var/abs" "/mnt/var/log" "/mnt/lib/libvirt" "/mnt/srv")


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
    local locale

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

# Main function
main(){
    # for i in {1..${#BTRFS_SUBVOL_MNT[@]}}
    for ((i=1; i<=${#BTRFS_SUBVOL_MNT[@]}; i++))
    do
        echo "${BTRFS_SUBVOL_MNT[i]} -> ${BTRFS_SUBVOL[i]}"
    done
    
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

main