#!/bin/bash


# TODO
# Mejorar la logica cuando hay array en add_global_var_to_file

# Just source the script once
if [ "$COMMON_FUNCTIONS" != yes ]; then
    COMMON_FUNCTIONS=yes
else
    return 0
fi

readonly RED='\033[0;31m'
readonly NO_COLOR='\033[0m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BRIGHT_CYAN='\033[0;96m'
readonly CYAN='\033[0;36m'

readonly TRUE=0
readonly FALSE=1
readonly VAR_FILENAME="vars.sh"
readonly VAR_FILE_LOC="/root/.scripts/$VAR_FILENAME"

readonly GLOBAL_VARS_NAME=("has_swap" "is_zram" "swap_part" "boot_part" "root_part" "has_encryption" "DM_NAME" "machine_name" "is_intel" "is_laptop" "gpu_type" "log_step" "is_kde" "root_fs")
readonly VARS_TYPE=("ask" "ask" "type" "type" "type" "ask" "DM_NAME" "MACHINE_NAME" "ask" "ask" "gpu" "log_step" "ask" "root_fs")
readonly VARS_QUESTIONS=("Does it have a swap?" "Is the system using zram?" "Please type swap partition: " "Please type boot partition: " "Please type root partition: " "Does the system have encryption?" "PLACEHOLDER" "PLACEHOLDER" "Is the system using an Intel CPU?" "Is the system a laptop?" "Please type dedicated GPU (amd/nvidia/intel): " "LOG STEP" "Is this machine using KDE?" "Used root filesystem: ")

# GLOBAL VARS
# 
# tty_layout
# has_swap=true/false
# is_zram=true/false
# swap_part
# boot_part
# root_part
# has_encryption=true/false
# DM_NAME
# machine_name
# is_intel=true/false
# is_laptop=true/false
# gpu_type=amd/intel/nvidia
# log_step="number"
# is_kde
# root_fs


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
        echo -ne "${YELLOW}$QUESTION (y/n): ${NO_COLOR}"
        read -r ans

        case $ans in
            y|Y|[yY][eE][sS]|"" )
                res="$TRUE"
                done="$TRUE"
                ;;
            n|N|[nN][oO] )
                res="$FALSE"
                done="$TRUE"
                ;;
            * )
                echo -e "${RED}Unknown answer.${NO_COLOR} Please type it again."
                ;;
        esac
    done

    return "$res"
}

# Displays a colored message with the text passed as argument.
# $1: Message to be written.
# $2: Color to be displayed.
# $3 (optional): Character to print as delimiter. If left empty, there will not be a delimiter.
colored_msg(){
    local -r MSG="$1"
    local -r COLOR="$2"
    local -r DELIM="${3:-""}"
    
    if [ -n "$DELIM" ];
    then
        printf "\n"
        printf "%0.b${COLOR}${DELIM}${NO_COLOR}" $(seq 1 $COLUMNS)
        printf "\n\n"
    fi
    printf "%b\n\n" "${COLOR}${MSG}${NO_COLOR}"
}

# $1: Pattern to find
# $2: Text to add
# $3: filename
# $4: is double quote (TRUE/FALSE)
# $5: Do it inline?
# note: If you need to use "/", the put it like \/
add_sentence_end_quote(){
    # sed "/^example=/s/\"$/ adios\"/" example

    local -r PATTERN="$1"
    local -r NEW_TEXT="$2"
    local -r FILENAME="$3"
    local quote='\"'

    [ "$4" -eq "$FALSE" ] && quote="'"

    local is_inline="$5"

    if [ "$is_inline" -eq "$TRUE" ];
    then
        sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
    else
        sed "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
    fi

}

# $1: Pattern to find
# $2: Text to add
# $3: filename
# $4: end quote
# note: If you need to use "/", the put it like \/
add_sentence_2(){
    # sed "/^example=/s/\"$/ adios\"/" example

    local -r PATTERN="$1"
    local -r NEW_TEXT="$2"
    local -r FILENAME="$3"
    local quote="$4"



    sed -i "/${PATTERN}/s/${quote}$/${NEW_TEXT}${quote}/" "${FILENAME}"
}

# $1: Option (or options, but ending without comma)
# $2: File location
# $3 ($TRUE/$FALSE): Do it inline?
add_option_inside_luks_options(){
    local -r OPTION="$1"
    local -r FILE="$2"
    local -r IS_INLINE="$3"

    if [ "$IS_INLINE" -eq "$TRUE" ];
    then
        sed -i "/^GRUB_CMDLINE_LINUX=/s/rd.luks.options=/rd.luks.options=$OPTION,/" "$FILE"
    else
        sed "/^GRUB_CMDLINE_LINUX=/s/rd.luks.options=/rd.luks.options=$OPTION,/" "$FILE"
    fi
}

# $1: Variable name. If it is an array, pass just the variable name
# $2: Value. Can be overwritten by another call
# $3: File location
# $4 (optional): Is the value an array? Defaults to false
# return: $TRUE if written to file, $FALSE if it already exists on file
add_global_var_to_file(){
    local -r VAR_NAME="$1"
    local -r FILE_LOC="$3"
    local is_array="$FALSE"

    [ "$#" -eq "4" ] && is_array="$4"

    if [ "$is_array" -eq "$TRUE" ];
    then
        local -n VALUE="$2"
    else
        local -r VALUE="$2"
    fi

    if [ ! -f "$FILE_LOC" ];
    then
        echo "#!/bin/bash" > "$FILE_LOC"
        echo "
# Just source the script once
if [ \"\$VARS\" != yes ]; then
    VARS=yes
else
    return 0
fi
" >> "$FILE_LOC"
    fi

    if grep "$VAR_NAME" "$FILE_LOC" > /dev/null;
    then
        if [ "$is_array" -eq "$FALSE" ];
        then
            awk 'BEGIN{OFS=FS="="} /^'"$VAR_NAME"'=/{$NF="\"'"$VALUE"'\""};1' "$FILE_LOC" > "${FILE_LOC}.tmp" && mv "${FILE_LOC}.tmp" "$FILE_LOC"
        else
            awk 'BEGIN{OFS=FS="="} /^'"$VAR_NAME"'=/{$NF="('"${VALUE[*]}"')"};1' "$FILE_LOC" > "${FILE_LOC}.tmp" && mv "${FILE_LOC}.tmp" "$FILE_LOC"
        fi
    else
        # Checks if file ends in newline to avoid putting the new variable on the same line
        local -r ENDS_NEWLINE="$(tail -c1 "$FILE_LOC" | wc -l)"
        local first_char=""

        [ "$ENDS_NEWLINE" -eq "0" ] && first_char="\n"

        if [ "$is_array" -eq "$FALSE" ];
        then
            echo -e "$first_char$VAR_NAME=\"$VALUE\"" >> "$FILE_LOC"
        else
            echo -e "$first_char$VAR_NAME=(${VALUE[*]})" >> "$FILE_LOC"
        fi


    fi
}


# $1: Element
# $2: Array. It must be passed by its variable name, without $ sign and without double quotes
# return: $TRUE if the element is inside the array, $FALSE in other case
is_element_in_array(){
    # https://stackoverflow.com/questions/10953833/passing-multiple-distinct-arrays-to-a-shell-function
    local -r ELEMENT="$1"
    local -n _ARR="$2"

    local i
    for i in "${_ARR[@]}"
    do
        [ "$i" = "$ELEMENT" ] && return "$TRUE"
    done
    unset i

    return "$FALSE"
}

# $1: Name. Must be the same.
# return: Variable name.
get_var_index_by_name(){
    local -r NAME="$1"

    local i
    for ((i=0; i<${#GLOBAL_VARS_NAME[@]}; i++))
    do
        if [ "${GLOBAL_VARS_NAME[i]}" = "$NAME" ];
        then
            echo "$i"
            break
        fi
    done
    unset i

    return "$TRUE"
}

# $1: Index of global var.
# $2 (optional): Var file location. Defaults to $VAR_FILE_LOC
get_var_value_index(){
    local -r INDEX="$1"
    local var_file="$VAR_FILE_LOC"

    [ "$#" -gt "1" ] && var_file="$2"

    if [ "$INDEX" -lt "0" ] || [ "$INDEX" -ge "${#GLOBAL_VARS_NAME[@]}" ] || [ ! -f "$var_file" ] || ! grep -E "^${GLOBAL_VARS_NAME[$INDEX]}=" "$var_file" > /dev/null;
    then
        echo "error"
        return "$FALSE"
    fi

    awk 'BEGIN{OFS=FS="="} /'"${GLOBAL_VARS_NAME[$INDEX]}"'/{print $2}' "$var_file" | cut -d"\"" -f2

    return "$TRUE"
}

# $1: Global var index.
# $2 (optional): File location to be written. Defaults to $VAR_FILE_LOC
# post: Saves variable value to a file and assigns it on runtime.
# return: TRUE if it went OK, FALSE in any other case.
ask_global_var_by_index(){
    local -r INDEX="$1"
    local is_done="$FALSE"
    local tmp
    local aux_arr
    local ask_yes_no
    local var_file="$VAR_FILE_LOC"
    local res
    local res_bool="$FALSE"

    [ "$#" -gt "1" ] && var_file="$2"

    if [ "$INDEX" -lt "0" ] || [ "$INDEX" -ge "${#GLOBAL_VARS_NAME[@]}" ];
    then
        echo -e "${RED}Out of bounds index.${NO_COLOR}"
        return "$FALSE"
    fi

    if [ ! -f "$var_file" ] || ! grep -E "^${GLOBAL_VARS_NAME[$INDEX]}=" "$var_file" > /dev/null;
    then
        case ${VARS_TYPE[$INDEX]} in
            "ask")
                while [ "$is_done" -eq "$FALSE" ]
                do
                    ask "${VARS_QUESTIONS[$INDEX]}"
                    tmp="$?"

                    case $tmp in
                    "$TRUE")
                        ask_yes_no=yes
                        ;;
                    "$FALSE")
                        ask_yes_no=no
                        ;;
                    *)
                        ask_yes_no="unknown error"
                        ;;
                    esac

                    ask "You have selected $ask_yes_no. Is that correct?"
                    is_done="$?"
                done

                res="$tmp"
                ;;

            "type")
                while [ "$is_done" -eq "$FALSE" ]
                do
                    echo -n "${VARS_QUESTIONS[$INDEX]}"
                    read -r tmp

                    ask "You have selected $tmp. Is that correct?"
                    is_done="$?"
                done

                res="$tmp"
                ;;

            "DM_NAME")
                res="$(grep -E "^root_part" "$var_file" | awk 'BEGIN{OFS=FS="/"} {print substr($NF,1,length($NF)-1)}')"
                ;;

            "MACHINE_NAME")
                res="$(cat /etc/hostname)"
                ;;

            "root_fs")
                echo "Available filesystems:
1) btrfs
2) ext4"
                while [ "$is_done" -eq "$FALSE" ]
                do
                    echo -n "${VARS_QUESTIONS[$INDEX]}"
                    read -r tmp

                    case $tmp in
                        [Bb][Tt][Rr][Ff][Ss]|1)
                            tmp="btrfs"
                            ;;

                        [Ee][Xx][Tt]4|2)
                            tmp="ext4"
                            ;;
                        *)
                            tmp="unknown"
                            ;;
                    esac

                    ask "You have selected $tmp. Is that correct?"
                    is_done="$?"
                done
                res="$tmp"
            ;;

            "gpu")
                aux_arr=()
                while [ "$is_done" -eq "$FALSE" ]
                do
                    echo "GPU list:
1) amd
2) nvidia
3) intel
"
                    echo -n "Please select GPU (empty to finish): "
                    read -r tmp

                    case $tmp in
                        "1"|[aA][mM][dD])
                            is_element_in_array "amd" aux_arr
                            if [ "$?" -eq "$FALSE" ];
                            then
                                # echo "amd"
                                aux_arr=("${aux_arr[@]}" "amd")
                            fi
                            ;;

                        "2"|[nN][vV][iI][dD][iI][aA])
                            is_element_in_array "nvidia" aux_arr
                            if [ "$?" -eq "$FALSE" ];
                            then
                                # echo "nvidia"
                                aux_arr=("${aux_arr[@]}" "nvidia")
                            fi
                            ;;

                        "3"|[iI][nN][tT][eE][lL])
                            is_element_in_array "intel" aux_arr
                            if [ "$?" -eq "$FALSE" ];
                            then
                                # echo "intel"
                                aux_arr=("${aux_arr[@]}" "intel")
                            fi
                            ;;

                        "")
                            echo "These are the selected GPU(s): ${aux_arr[*]}"
                            ask "Are these correct?"
                            is_done="$?"

                            [ "$is_done" -eq "$FALSE" ] && aux_arr=()
                            ;;
                        *)
                            echo "Unknown option"
                            ;;
                    esac
                done
                res="aux_arr"
                res_bool="$TRUE"
                ;;

            "log_step")
                res="0"
                ;;
            *)
                echo "WIP"
                ;;
        esac

        add_global_var_to_file "${GLOBAL_VARS_NAME[$INDEX]}" "$res" "$var_file" "$res_bool"

    else
        # En caso de existir en el archivo, se obtiene del mismo para aniadirlo mas tarde.
        tmp="$(get_var_value_index "$INDEX" "$var_file")"
    fi

    # Assign variable so the script can use it.
    declare -g "${GLOBAL_VARS_NAME[$INDEX]}"="$tmp"

    return "$TRUE"
}



# $1: Name of global var. Must be the same
# $2 (optional): Var file location. Defaults to $VAR_FILE_LOC
get_var_value_by_name(){
    local -r NAME="$1"
    local var_file="$VAR_FILE_LOC"

    [ "$#" -gt "1" ] && var_file="$2"

    if [ ! -f "$var_file" ] || ! grep -E "^${GLOBAL_VARS_NAME[$INDEX]}=" "$var_file" > /dev/null;
    then
        echo "error"
        return "$FALSE"
    fi

    get_var_value_index "$(get_var_index_by_name "$NAME")" "$var_file"

    return "$TRUE"
}

# $1 (optional): Variable file location. If not set, uses $VAR_FILE_LOC
ask_global_vars(){
    local var_file="$VAR_FILE_LOC"
    [ "$#" -gt "0" ] && var_file="$1"

    local i
    for ((i=0; i<${#GLOBAL_VARS_NAME[@]}; i++))
    do
        ask_global_var_by_index "$i" "$var_file"
    done
    unset i
}

# $1: Var name. MUST be the same name.
# $2 (optional): Var file location. Defaults to $VAR_FILE_LOC
ask_global_var(){
    local -r NAME="$1"
    local -r INDEX="$(get_var_index_by_name "$NAME")"
    local var_file="$VAR_FILE_LOC"

    [ "$#" -gt "1" ] && var_file="$2"

    ask_global_var_by_index "$INDEX"
}
