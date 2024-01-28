#!/bin/bash

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

readonly KVM_SUBVOL=("@var_lib_libvirt" "/var/lib/libvirt")
readonly TRUE="0"
readonly FALSE="1"

# TODO:
# HACER CRYPTSETUP OPEN CON BUCLE

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

mnt_system(){
    local is_done="$FALSE"
    local part

    while [ "$is_done" -eq "$FALSE" ]
    do
        lsblk
        echo -n "Select partition: "
        read -r part

        ask "You have selected $part. Is that correct?"
        is_done="$?"
    done

    if ask "Is the system encrypted?";
    then
	has_encryption="$TRUE"
        is_done="$FALSE"
        DM_NAME=$(echo "$part" | awk 'BEGIN{OFS=FS="/"} {print $NF}')

        cryptsetup open "$part" "$DM_NAME"

        mount "/dev/mapper/$DM_NAME" /mnt -o compress-force=zstd
    else
	has_encryption="$FALSE"
        mount "$part" /mnt -o compress-force=zstd
    fi
}

libvirt_subvol(){
    #mv "/mnt/@/${KVM_SUBVOL[1]}" "/mnt/@/${KVM_SUBVOL[1]}.OLD"
	btrfs subvol create "/mnt/${KVM_SUBVOL[0]}"
    mv "/mnt/@${KVM_SUBVOL[1]}"/* "/mnt/${KVM_SUBVOL[0]}"
 mv "/mnt/@${KVM_SUBVOL[1]}"/.* "/mnt/${KVM_SUBVOL[0]}"

local dev_name="/dev/$DM_NAME"

if [ "$has_encryption" -eq "$TRUE" ];
then
	dev_name="/dev/mapper/$DM_NAME"
fi

	echo "$dev_name ${KVM_SUBVOL[1]} btrfs compress-force=zstd,subvol=${KVM_SUBVOL[0]} 0 0" >> /mnt/@/etc/fstab

}

main(){
    mnt_system
    libvirt_subvol
}

main
