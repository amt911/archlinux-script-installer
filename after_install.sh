#!/bin/bash

readonly SHELLS_SUDO=("zsh" "fish" "sudo")
readonly TRUE=0
readonly FALSE=1

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


    sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
}

enable_reisub(){
    add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " sysrq_always_enabled=1" "/etc/default/grub" "$TRUE"

    grub-mkconfig -o /boot/grub/grub.cfg
}

enable_trim(){
    if [ -z "$has_encryption" ];
    then
        ask "Does it have encryption?"
        has_encryption="$?"
    fi

    pacman --noconfirm -S util-linux
    systemctl enable fstrim.timer

    if [ "$has_encryption" -eq "$TRUE" ];
    then
        add_sentence_end_quote "^GRUB_CMDLINE_LINUX=" " rd.luks.options=discard" "/etc/default/grub" "$TRUE"
        grub-mkconfig -o /boot/grub/grub.cfg 
    fi
}

install_shells(){
    pacman --noconfirm -S "${SHELLS_SUDO[@]}"

    sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

    echo "Check if everything is OK"
    grep -i "%wheel" /etc/sudoers
}

add_users(){
    local adduser_done="$TRUE"
    local username
    # local is_sudo
    local shell
    local passwd_ok="$FALSE"

    while [ "$adduser_done" -eq "$TRUE" ]
    do

        echo -n "Username: "
        read -r username

        echo "Available shells:"
        cat /etc/shells

        echo -n "Select a shell: "
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
            echo "Now you will be asked to type a password for the new user"
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
    sed -i "s/^#Parallel/Parallel/" /etc/pacman.conf
    sed -i "s/^#Color/Color/" /etc/pacman.conf

    echo "These are the changed lines:"
    grep "Parallel" /etc/pacman.conf
    grep -E "^Color" /etc/pacman.conf
}

enable_multilib(){
    # awk 'BEGIN {num=20; first="#[h]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' example
    awk 'BEGIN {num=2; first="#[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){sub(/#/,"");num--;entered="true"};1' /etc/pacman.conf > /etc/pacman.conf.TMP && mv /etc/pacman.conf.TMP /etc/pacman.conf

    pacman --noconfirm -Syu
    
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg

    echo "Check changes:"
    awk 'BEGIN {num=2; first="[multilib]"; entered="false"} (($0==first||entered=="true")&&num>0){print $0;num--;entered="true"}' /etc/pacman.conf
}

enable_reflector(){
    pacman --noconfirm -S reflector
    systemctl enable reflector.timer
}

btrfs_scrub(){
    systemctl enable btrfs-scrub@-.timer
}

prepare_for_aur(){
    # Mejorar aqui el make para que sea multinucleo
    pacman --noconfirm -S base-devel git

    # https://wiki.archlinux.org/title/makepkg#Parallel_compilation
    # Enable multi-core compilation
    awk 'BEGIN { OFS=FS="="; name="#MAKEFLAGS" } {if($1==name){sub(/#/,""); $2="\"-j$(nproc)\""}};1' /etc/makepkg.conf > /etc/makepkg.tmp && mv /etc/makepkg.tmp /etc/makepkg.conf

    echo "Check changes: "
    grep "MAKEFLAGS=" /etc/makepkg.conf
    echo ""
}

install_bluetooth(){
    echo "WIP Installing bluetooth..."
    # arch-chroot /mnt pacman --noconfirm -S bluez bluez-utils
}

enable_ntfs(){
    true
}

install_optional_pkgs(){
true
}

install_cpu_scaler(){
true
}

enable_hw_acceleration(){
    true
}

install_firewall(){
true
}

install_kde(){
true
}

install_gnome(){
true
}

install_kvm(){
    # Aqui hay que crear el subvolumen libvirt
    # Aqui tambien hay que recordar instalar tpm
    true
}

install_printer(){
true
}

install_ms_fonts(){
true
}

install_lsd(){
    # Aqui se debe instalar lsd y la fuente nerd
    true
}

btrfs_snapshots(){
    # Aqui debe ir el hook de pacman
    true
}

disable_ssh_service(){
    systemctl disable sshd.service
    sed -i "s/^PermitRootLogin yes/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
}

get_sudo_user(){
    grep -E "^wheel" /etc/gshadow | cut -d: -f4 | cut -d, -f1
}

install_yay(){
    # https://stackoverflow.com/questions/5560442/how-to-run-two-commands-with-sudo
    local -r USER=$(get_sudo_user)

    sudo -S -i -u "$USER" git clone https://aur.archlinux.org/yay.git "/home/$USER/yay"

    # https://unix.stackexchange.com/questions/176997/sudo-as-another-user-with-their-environment
    sudo -S -i -u "$USER" bash -c "cd \"/home/$USER/yay\" && makepkg -sri"

    echo "Configuring yay..."
    sudo -S -i -u "$USER" yay -Y --gendb
    sudo -S -i -u "$USER" yay -Syu --devel
    sudo -S -i -u "$USER" yay -Y --devel --save 

    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
    grub-mkconfig -o /boot/grub/grub.cfg
}

# Laptop specific functions
enable_envycontrol(){
true
}


main(){
    if [ "$#" -eq "0" ];
    then
        ask "Do you want to have REISUB?" && enable_reisub
        ask "Do you want to enable TRIM?" && enable_trim
        install_shells
        add_users
        ask "Do you want to parallelize package downloads and color them?" && improve_pacman
        ask "Do you want to enable the multilib package (Steam)?" && enable_multilib
        ask "Do you want to enable reflector timer to update mirrorlist?" && enable_reflector
        ask "Do you want to enable scrub?" && btrfs_scrub
        ask "Do you want to install the dependencies to use the AUR and enable parallel compilation?" && prepare_for_aur
        ask "Do you want to install an AUR helper?" && install_yay
    fi
        # IN PROCESS
        ask "Do you want to install bluetooth service?" && install_bluetooth

    # IMPORTANTE NO OLVIDAR
    # disable_ssh_service
}

main "$@"