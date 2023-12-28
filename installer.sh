#!/bin/bash

# TODO:
# Poder detectar entre CSM y UEFI
# Intentar hacer algún menú interactivo

readonly TRUE=0
readonly FALSE=1



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

# Main function
main(){
    loadkeys_tty

    check_current_time

    # if is_efi;
    # then
    #     echo "is efi"
    # else
    #     echo "not an efi system"
    # fi

    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    # then
    #     echo "Laptop"
    # else
    #     echo "Tower"
    # fi

    
}

test1(){
    if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    then
        echo "Laptop"
    else
        echo "Tower"
    fi    
}

# test1

main