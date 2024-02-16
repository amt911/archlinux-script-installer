#!/bin/bash

# TODO:
# Update repository periodically

source "common_functions.sh"

readonly REPO_LOC="/root/.vfio-tools"

clone_repo(){
    echo "Cloning repo..."
    git clone "https://github.com/PassthroughPOST/VFIO-Tools.git" "$REPO_LOC"
}


create_directories(){
    mkdir /etc/libvirt/hooks
    ln -sf "$REPO_LOC/libvirt_hooks/qemu" /etc/libvirt/hooks/qemu
    chmod +x /etc/libvirt/hooks/qemu

    mkdir -p /etc/libvirt/hooks/qemu.d
}

get_all_sudo_users(){
    local -r USERS_RAW=$(grep -E "^wheel" /etc/gshadow | cut -d: -f4)
    local -r OLD_IFS="$IFS"
    local i

    IFS="," read -ra users <<< "$USERS_RAW"

    IFS="$OLD_IFS"
}

# $1: VM name
create_config(){
    [ "$#" -eq "0" ] && return 1

    local -r VM_NAME="$1"

#     Start script
    mkdir -p "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin"
    echo -e "#!/bin/bash
set -x\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"

    if [ "$is_laptop" -eq "$FALSE" ];
    then
        if [ "$is_kde" -eq "$TRUE" ];
        then
            local i

            for i in "${users[@]}"
            do
                echo "systemctl --user -M $i@ stop plasma*" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"
            done
            unset i

            echo "" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"
        fi

        echo -e "systemctl stop display-manager\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"
    fi

    if is_element_in_array "nvidia" gpu_type;
    then
        echo -e "modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"
    fi

    echo -e "modprobe vfio-pci\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"

    chmod +x "/etc/libvirt/hooks/qemu.d/$VM_NAME/prepare/begin/start.sh"


#     Release script
    mkdir -p "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end"

    echo -e "#!/bin/bash
set -x\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end/stop.sh"

    echo -e "modprobe -r vfio-pci\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end/stop.sh"

    if is_element_in_array "nvidia" gpu_type;
    then
        echo -e "modprobe nvidia_drm
modprobe nvidia_modeset
modprobe nvidia_uvm
modprobe nvidia\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end/stop.sh"
    fi

    if [ "$is_laptop" -eq "$FALSE" ];
    then
        echo -e "systemctl start display-manager\n" >> "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end/stop.sh"
    fi

    chmod +x "/etc/libvirt/hooks/qemu.d/$VM_NAME/release/end/stop.sh"
}

main(){
    ask_global_vars

    [ -f "$VAR_FILE_LOC" ] && source "$VAR_FILE_LOC"

    get_all_sudo_users

    clone_repo
    create_directories
}

main
create_config "win11"
