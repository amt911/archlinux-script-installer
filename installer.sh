#!/bin/bash


# testing commands for live environment: passwd
# testing commands for host: scp installer.sh root@192.168.56.101:/root

# Asks for something to do in this script.
# 
# $1: Question to be displayed. It should not have a colon nor space at the end since it is appended.
#
# return: 0 if yes, 1 if no in $?.
ask(){
    local -r QUESTION="$1"
    local done=0
    local ans
    local res

    while [ "$done" -eq 0 ]
    do
        echo -n "$QUESTION (y/n): "
        read -r ans

        case $ans in
            y|Y|[yY][eE][sS] )
                echo "ok"
                res=0
                done=1
                ;;
            n|N|[nN][oO] )
                echo "not ok"
                res=1
                done=1
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
    if ask "prueba";
    then
        echo "si"
    else 
        echo "no"
    fi
}

main