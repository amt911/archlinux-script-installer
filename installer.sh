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
                echo "ok"
                res="$TRUE"
                done="$TRUE"
                ;;
            n|N|[nN][oO] )
                echo "not ok"
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

# Main function
main(){

    # if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    if ask "Is this a laptop or a tower PC? (yes=laptop/no=tower)" || [ "$var" = "yes" ];
    then
        echo "Laptop"
    else
        echo "Tower"
    fi
}

main