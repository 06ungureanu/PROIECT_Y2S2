#!/bin/bash 

# Module used to extract metadata from file 

# function extractMetaDates(in_fpath, out_fpath, log_flag, log_file, verbose_flag)
# output format: fname|owner|perms|acl|ctime|atime|mtime|sha256sum

# Util vars
METADATE_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

# Sources
source "$METADATE_DIR/logs.bash"
source "$METADATE_DIR/utils.bash"

function extractMetaDates {
    # Check if invalid func call 
    if [[ "$#" -ne 5 ]]; then  
        return 
    fi 

    # func args
    INPUT_FPATH="$1"
    OUTPATH_FPATH="$2"
    LOG_FLAG="$3"
    LOG_FILE="$4"
    VERBOSE_FLAG="$5"

    # Check if input_fpath exist, log and exit if not 
    if [[ ! -e "$INPUT_FPATH" ]]; then 
        if [[ "$VERBOSE_FLAG" -eq 1 ]]; then 
            printErrorMsg "warning" "$INPUT_FPATH does not exist(no metdata to extract)"
        fi

        writeLog "$LOG_FLAG" "warning" "$LOG_FILE" "$INPUT_FPATH does not exist(no metdata to extract)"
        return 1
    fi 

    # Check if user can read input_fpath, log and exit if not
    if [[ ! -r "$INPUT_FPATH" ]]; then 
        if [[ "$VERBOSE_FLAG" -eq 1 ]]; then 
            printErrorMsg "warning" "$(whoami) has no read perm for $INPUT_FPATH"
        fi 

        writeLog "$LOG_FLAG" "warning" "$LOG_FILE" "$(whoami) has no read access for $INPUT_FPATH"
        return 1
    fi 

    # Extract metadata
    file_owner=$(stat -c %U "$INPUT_FPATH")
    file_perm=$(stat -c %a "$INPUT_FPATH")
    file_acl=$(getfacl "$INPUT_FPATH" 2> /dev/null| paste -s)  
    
    file_ctime=$(stat -c "%z" "$INPUT_FPATH" | cut -d. -f1)
    file_atime=$(stat -c "%x" "$INPUT_FPATH" | cut -d. -f1)
    file_mtime=$(stat -c "%y" "$INPUT_FPATH" | cut -d. -f1)

    file_sha256sum=$(sha256sum "$INPUT_FPATH" | cut -f1 -d" ")
   
    # Get relativa path and build payload
    file_relative_path=$(realpath --relative-to="$(dirname "$METADATE_DIR")" "$INPUT_FPATH")
    FILE_METADATE_PAYLOAD="$file_relative_path|$file_owner|$file_perm|$file_acl|$file_ctime|$file_atime|$file_mtime|$file_sha256sum"

    # Prin some data to STDOUT if verbose_flag
    if [[ "$VERBOSE_FLAG" -eq 1 ]]; then 
        printErrorMsg "info" "Metadates payload from $INPUT_FPATH : $file_sha256sum (sha256sum)"
        printErrorMsg "info" "Metadates payload from $INPUT_FPATH dumped in $OUTPATH_FPATH"
    fi 
    
    # Check if out_fpath exist, and create if not
    if [[ ! -e "$OUTPATH_FPATH" ]]; then
        touch "$OUTPATH_FPATH"
        chmod 600 "$OUTPATH_FPATH"      # Security reasons (only owner can write/read to metadata file)
    fi

    # Dump payload to out_fpath and log
    echo "$FILE_METADATE_PAYLOAD" >> "$OUTPATH_FPATH"
    writeLog "$LOG_FLAG" "info" "Metadata from $INPUT_FPATH dumped in $OUTPATH_FPATH" "$LOG_FILE"
}

