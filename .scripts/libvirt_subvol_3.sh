#!/bin/bash

source common_functions.sh


readonly KVM_SUBVOL=("@var_lib_libvirt" "/var/lib/libvirt")

# TODO:
# HACER CRYPTSETUP OPEN CON BUCLE

mnt_system(){
    if [ "$has_encryption" -eq "$TRUE" ];
    then
        cryptsetup open "$root_part" "$DM_NAME"
        mount "/dev/mapper/$DM_NAME" /mnt -o compress-force=zstd
    else
        mount "$root_part" /mnt -o compress-force=zstd
    fi
}

libvirt_subvol(){
	btrfs subvol create "/mnt/${KVM_SUBVOL[0]}"
    mv "/mnt/@${KVM_SUBVOL[1]}"/* "/mnt/${KVM_SUBVOL[0]}"
    mv "/mnt/@${KVM_SUBVOL[1]}"/.* "/mnt/${KVM_SUBVOL[0]}"

    local dev_name="$root_part"

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        dev_name="/dev/mapper/$DM_NAME"
    fi

	echo "$dev_name ${KVM_SUBVOL[1]} btrfs compress-force=zstd,subvol=${KVM_SUBVOL[0]} 0 0" >> /mnt/@/etc/fstab

}

main(){
    ask_global_vars

    [ -f "$VAR_FILE_LOC" ] && source "$VAR_FILE_LOC"

    mnt_system
    libvirt_subvol
}

main