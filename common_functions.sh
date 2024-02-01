#!/bin/bash

# Just source the script once
if [ "$COMMON_FUNCTIONS" != yes ]; then
    COMMON_FUNCTIONS=yes
else
    return 0
fi

readonly TRUE=0
readonly FALSE=1
readonly VAR_FILENAME="vars.sh"
readonly VAR_FILE_LOC="/root/$VAR_FILENAME"

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
# 


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

# $1: Variable name
# $2: Value. Can be overwritten by another call
# $3: File location
# return: $TRUE if written to file, $FALSE if it already exists on file
add_global_var_to_file(){
    local -r VAR_NAME="$1"
    local -r VALUE="$2"
    local -r FILE_LOC="$3"

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
        awk 'BEGIN{OFS=FS="="} /'"$VAR_NAME"'/{$2="\"'"$VALUE"'\""};1' "$FILE_LOC" > "${FILE_LOC}.tmp" && mv "${FILE_LOC}.tmp" "$FILE_LOC"
    else
        # Checks if file ends in newline to avoid putting the new variable on the same line
        local -r ENDS_NEWLINE="$(tail -c1 "$FILE_LOC" | wc -l)"
        local first_char=""

        [ "$ENDS_NEWLINE" -eq "0" ] && first_char="\n"

        echo -e "$first_char$VAR_NAME=\"$VALUE\"" >> "$FILE_LOC"
    fi
}


readonly GLOBAL_VARS_NAME=("has_swap" "is_zram" "swap_part" "boot_part" "root_part" "has_encryption" "DM_NAME" "machine_name" "is_intel" "is_laptop" "gpu_type")
readonly VARS_TYPE=("ask" "ask" "type" "type" "type" "ask" "DM_NAME" "MACHINE_NAME" "ask" "ask" "gpu")
readonly VARS_QUESTIONS=("Does it have a swap?" "Is the system using zram?" "Please type swap partition: " "Please type boot partition: " "Please type root partition: " "Does the system have encryption?" "PLACEHOLDER" "PLACEHOLDER" "Is the system using an Intel CPU?" "Is the system a laptop?" "Please type dedicated GPU (amd/nvidia/intel): ")

# $1 (optiona): Variable file location. If not set, uses $VAR_FILE_LOC
ask_global_vars(){
    local var_file="$VAR_FILE_LOC"
    local tmp

    [ "$#" -gt "0" ] && var_file="$1"

    local is_done="$FALSE"
    local ask_yes_no

    for ((i=0; i<${#GLOBAL_VARS_NAME[@]}; i++))
    do
        if ! grep -E "^${GLOBAL_VARS_NAME[i]}=" "$var_file" > /dev/null;
        then
            # echo "No existe ${GLOBAL_VARS_NAME[i]}"
            case ${VARS_TYPE[i]} in
                "ask")
                    while [ "$is_done" -eq "$FALSE" ]
                    do
                        ask "${VARS_QUESTIONS[i]}"
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

                    add_global_var_to_file "${GLOBAL_VARS_NAME[i]}" "$tmp" "$var_file"
                    ;;

                "type")
                    while [ "$is_done" -eq "$FALSE" ]
                    do
                        echo -n "${VARS_QUESTIONS[i]}"
                        read -r tmp

                        ask "You have selected $tmp. Is that correct?"
                        is_done="$?"
                    done

                    add_global_var_to_file "${GLOBAL_VARS_NAME[i]}" "$tmp" "$var_file"
                    ;;

                "DM_NAME")
                    add_global_var_to_file "${GLOBAL_VARS_NAME[i]}" "$(grep -E "^root_part" "$var_file" | awk 'BEGIN{OFS=FS="/"} {print substr($NF,1,length($NF)-1)}')" "$var_file"
                    ;;

                "MACHINE_NAME")
                    add_global_var_to_file "${GLOBAL_VARS_NAME[i]}" "$(cat /etc/hostname)" "$var_file"
                    ;;
                
                "gpu")
                    echo "GPU TYPE"
                    ;;
                    
                *)
                    echo "WIP"
                    ;;
            esac

            is_done="$FALSE"
        fi
    done
    unset i

    
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
}

ask_global_vars "mec"