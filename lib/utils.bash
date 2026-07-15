#!/bin/bash

# Module used for util funcs

# function printErrorMsg(msg_type, msg); msg_type = {info,warning, fatal}
# function printArrayNonl(array)
# function checkFile(fpath)
# function checkDirectory(fpath)

function printErrorMsg {    
    # check if invalid func call
    if [[ "$#" -ne 2 ]]; then 
        return 
    fi 
    
    # check if invalid args 
    if [[ "$1" != "warning" && "$1" != "fatal" && "$1" != "info" ]]; then 
        return
    fi 

    # check if null msg
    if [[ -z "$2" ]]; then 
        return  
    fi 
    
    # Branch by msg_type and print output to STDOUT
    if [[ "$1" == "info" ]]; then
        printf '[\033[0;32mInfo\033[0m]: '
    elif [[ "$1" == "warning" ]]; then
        printf '[\033[0;33mWarning\033[0m]: '
    else 
        printf '[\033[0;31mFatal\033[0m]: '
    fi

    echo "$2"
}

function printArrayNonl {
    # check if invalid func call
    if [[ "$#" -eq 0 ]]; then 
        return 
    fi

    for item in "${TARGET_DIRS[@]}"; do 
        echo -n "$item "
    done
}

function checkFile {
    # check if invalid func call 
    if [[ "$#" -ne 1 || -z "$1" ]]; then 
        return 1
    fi 
    
    # check if not exist or no read perm 
    if [[ ! -e "$1" || ! -r "$1" ]]; then 
        return 1
    fi

    return 0            # SUCCES_CODE RET
}
function checkDirectory {
    # check if invalid func call 
    if [[ "$#" -ne 1 || -z "$1" ]]; then 
        return 1 
    fi 

    # check if it's not a dir or no execution perm
    if [[ ! -d "$1" || ! -x "$1" ]]; then 
        return 1  
    fi 

    return 0
}
function checkNextMustArg {
    # check if invalid func call 
    if [[ "$#" -ne 2 ]]; then 
        exit 1
    fi 

    # check requierd arg 
    if [[ -z "$2" || "$2" == -* ]]; then
        printErrorMsg "fatal" "$1 must provide value"
        exit 1
    fi 
}


