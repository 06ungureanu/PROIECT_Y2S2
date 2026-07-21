#!/bin/bash 


# Safety reasons 

set -euo pipefail 

# e = errexit (stop exection at first error) 
# u = nounset (no unitialized vars allowed )
# o pipefall = return error if one pipe error occur

# Config vars
CONF_FILE=""                 
BACKUP_FILE=""
OUTPUT_FILE=""
LOG_FILE=""

# Main vars 
declare -a TARGET_DIRS      

# Parser vars
FILE_ARG_FLAG=0
DIR_ARG_FLAG=0
ENC_ARG_FLAG=0 
BACKUP_FLAG_ARG=0
LOGFILE_FLAG_ARG=0
VERBOSE_ARG_FLAG=0
DEC_ARG_FLAG=0 

TEMP_BACKUP_DIR=""

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Sources 
source "$SCRIPT_DIR/../lib/utils.bash"
source "$SCRIPT_DIR/../lib/logs.bash"
source "$SCRIPT_DIR/../lib/metadate.bash"

# Utils
function printHelpMenu() {
    echo ""
    echo "Backup & Recovery System PROJECT_Y2S2"
    echo ""
    echo "[Script options]:"
    echo "      -f / --file      [value]    [Provide a file with directories to back up]"
    echo "      -b / --backup    [value]    [Provide an existing backup to refer to]"
    echo "      -d / --directory [value]    [Provide one or more directories to back up]"
    echo "      -e / --encrypt   [value]    [Requies BKP_PASS environment variable to be set]"
    echo "      -dec/ --decrypt  [value]    [Requies BKP_PASS environment variable to be set]"
    echo "      -o / --output    [value]    [Output file name]"
    echo "      -v / --verbose   [no args]  [Enable verbose mode]"
    echo "      -h / --help      [no args]  [Show this help menu]"
}

function  cleanup() {
    if [[ -n "${TEMP_BACKUP_DIR:-}" && -d "$TEMP_BACKUP_DIR" ]]; then 
        rm -rf "$TEMP_BACKUP_DIR"
    fi 
}

# If one of this cleanup
trap cleanup EXIT ERR INT TERM

function checkAndPrintArguments() {
    # Only one flag can be used
    if [[ "$FILE_ARG_FLAG" -eq 1 && "$DIR_ARG_FLAG" -eq 1 ]]; then
        printErrorMsg "fatal" "Only one argument from -d/--directory or -f/--file can be used"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$INVALID_ARG_USAGE" "$LOG_FILE" 
        exit 1
    fi

    # Check if no -d or -f flag used
    if [[ "$FILE_ARG_FLAG" -eq 0 && "$DIR_ARG_FLAG" -eq 0 ]]; then 
        printErrorMsg "fatal" "You must use -d/--directory or -f/--file flag"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$INVALID_ARG_USAGE" "$LOG_FILE" 
        exit 1
    fi 

    # Check if no output file
    if [[ -z "$OUTPUT_FILE" ]]; then 
        printErrorMsg "fatal" "You must provide an output fpath"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$INVALID_ARG_USAGE" "$LOG_FILE"
        exit 1
    fi 

    # Check config file
    if [[ "$FILE_ARG_FLAG" -eq 1 ]]; then
        checkFile "$CONF_FILE"
        
        if [[ "$?" -ne 0 ]]; then 
            printErrorMsg "fatal" "Invalid config file"
            writeLog "$LOGFILE_FLAG_ARG" "fatal" "$INVALID_FILE" "$LOG_FILE" 
            exit 1
        fi

        echo "[*] Config file: $CONF_FILE"
    else 
        echo -n "[*] Directory list: "
        printArrayNonl "${TARGET_DIRS[@]}"
        echo ""
    fi 
    
    # Print config info
    echo "[*] Output file: $OUTPUT_FILE"
    
    echo -n "[*] Log file: "
    [[ "$LOGFILE_FLAG_ARG" -eq 1 ]] && echo "$LOG_FILE" || echo "no"
    
    echo -n "[*] Verbose Mode: "
    [[ "$VERBOSE_ARG_FLAG" -eq 1 ]] && echo "yes" || echo "no"
    
    echo -n "[*] Backup file: "
    [[ "$BACKUP_FLAG_ARG" -eq 1 ]] && echo "$BACKUP_FILE" || echo "none"
}

# Backup utils functions 
function backupTmpDirectory {
    if [[ "$#" -ne 1 ]]; then 
        return 1
    fi

    # Check if backup dir empty
    if [[ -z "$(ls -A "$(realpath "$TEMP_BACKUP_DIR")")" ]]; then 
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "Nothing to backup in $TEMP_BACKUP_DIR"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "Nothing to backup in $TEMP_BACKUP_DIR" "$LOG_FILE"
        return 1 # Return with error code (for testing)
    fi 

    # Zip all content to output file
    local curr_dir=$(pwd)
    (cd "$TEMP_BACKUP_DIR" && zip -r "$curr_dir/$OUTPUT_FILE.zip" . > /dev/null) || {
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "Failed to create $OUTPUT_FILE zip"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "Failed to create $OUTPUT_FILE" "$LOG_FILE"
    }
    
    # Some info if verbose flag
    printIfVerbose "$VERBOSE_ARG_FLAG" "info" "Backup succefuly dumped to $OUTPUT_FILE.zip"
    writeLog "$LOGFILE_FLAG_ARG" "info" "Backup succefuly dumped to $OUTPUT_FILE.zip" "$LOG_FILE"
}

function pushFileToTempBackupDirectory {
    if [[ "$#" -ne 1 ]]; then 
        return 1
    fi 
  
    local fpath="$1"
       
    # Check if valid file
    checkFile "$fpath" || {
        printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "$fpath invalid file skipped"
        writeLog "$LOGFILE_FLAG_ARG" "warning" "$fpath invalid file skipped" "$LOG_FILE"
        return 0 
    }
    
    local TARGET_FILE=""

    # copy dir in temp_file and save fpath 
    cp --parents "$fpath" "$TEMP_BACKUP_DIR/" 2>/dev/null 
    TARGET_FILE="$TEMP_BACKUP_DIR/$fpath"
    
    local METADATA_FILE="$(basename "$OUTPUT_FILE").METADATA_BAK_$(date +%Y-%m-%d).txt"
    local REALPATH_FPATH=$(realpath "$1")
   
    extractMetaDates "$REALPATH_FPATH" "$TEMP_BACKUP_DIR/.$METADATA_FILE" "$LOGFILE_FLAG_ARG" "$LOG_FILE" "$VERBOSE_ARG_FLAG"
    
    # Encrypt data if needed
    if [[ "$ENC_ARG_FLAG" -eq 1 ]]; then 
        printIfVerbose "$VERBOSE_ARG_FLAG" "info" "encrypting with aes backup file $TARGET_FILE"
        
        # Encrypt file from backupfile -> $TARGET_FILE.enc
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -in "$TARGET_FILE" -out "$TARGET_FILE.enc" -pass env:BKP_PASS || {
            printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "error while encrypting $TARGET_FILE"
            writeLog "$LOGFILE_FLAG_ARG" "warning" "failed to encrypt $TARGET_FILE" "$LOG_FILE"
            return 1 
        }

        writeLog "$LOGFILE_FLAG_ARG" "info" "$TARGET_FILE encrypted with AES"
    
        # Delete unecrypted file from backup
        rm -f "$TARGET_FILE"
    fi 
}

function processDirectoryFiles {
    if [[ "$#" -ne 1 ]]; then 
        return 
    fi 
    
    local dir_fpath="$1"

    # Recursive search of each file in dir
    find "$dir_fpath" -type f -print0 | while IFS= read -r -d '' item; do
        printIfVerbose "$VERBOSE_ARG_FLAG" "info" "Processing $item"
        writeLog "$LOGFILE_FLAG_ARG" "info" "Process started for $item" "$LOG_FILE"
        pushFileToTempBackupDirectory "$item"
    done
}

# Main functions 
function backupFromDirectoryArr {
    # Check if dir array empty
    if [[ "${#TARGET_DIRS[@]}" -eq 0 ]]; then 
        return 1  
    fi 
    
    printIfVerbose "$VERBOSE_ARG_FLAG" "info" "Backup started with -d/--directory flag"
    
    for dir_fpath in "${TARGET_DIRS[@]}"; do 
        checkDirectory "$dir_fpath" || {
            printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "$dir_fpath invalid directory skipped"
            writeLog "$LOGFILE_FLAG_ARG" "warning" "$dir_fpath invalid directory (skipped)" "$LOG_FILE"
            continue
        }
        
        writeLog "$LOGFILE_FLAG_ARG" "info" "backup started with directory flag" "$LOG_FILE"
        processDirectoryFiles "$dir_fpath"
    done
    
    backupTmpDirectory "$TEMP_BACKUP_DIR"
}

function backupFromConfigFile {
    # Check if file empty
    if [[ ! -s "$CONF_FILE" ]]; then 
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "$CONF_FILE file is empty!"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$CONF_FILE is empty!" "$LOG_FILE" 
    fi 
    
    # Iterate all dir_fpaths from config file
    while IFS= read -r dir_fpath; do 
        # Check if empty line
        if [[ -z "$dir_fpath" ]]; then
            printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "Empty line found in $CONF_FILE"
            writeLog "$LOGFILE_FLAG_ARG" "warning" "$CONF_FILE contain empty lines" "$LOG_FILE"
            continue            
        fi 
        
        # Check if not exist
        if [[ ! -e "$dir_fpath" ]]; then  
            printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "$dir_fpath does not exist in system" 
            writeLog "$LOGFILE_FLAG_ARG" "warning" "$dir_fpath skiped (does not exist)" "$LOG_FILE"
            continue
        fi 
        
        processDirectoryFiles "$dir_fpath"
    
    done < "$CONF_FILE"

    backupTmpDirectory "$TEMP_BACKUP_DIR"
}

function backupWithExstingBackupFile {
    # Safety check
    checkIfGoodZip "$BACKUP_FILE" || {
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "$BACKUP_FILE it's not a zip file"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$BACKUP_FILE not a zip file" "$LOG_FILE"
        exit 1
    }

    # Unzip metadta file and log 
    unzip -p "$BACKUP_FILE" ".*METADATA_BAK*.txt" > "$TEMP_BACKUP_DIR/old_metadata.txt" || true
    
    printIfVerbose "$VERBOSE_ARG_FLAG" "info" "$BACKUP_FILE unziped in $TEMP_BACKUP_DIR"
    writeLog "$LOGFILE_FLAG_ARG" "info" "$BACKUP_FILE unziped in $TEMP_BACKUP_DIR" "$LOG_FILE"
    
    # Branch for each case (config file or directory flag)
    if [[ "$DIR_ARG_FLAG" -eq  1 ]]; then
        for dir_fpath in "${TARGET_DIRS[@]}"; do 
            checkDirectory "$dir_fpath" || continue
            processDirectoryFiles "$dir_fpath"
        done
    elif [[ "$FILE_ARG_FLAG" -eq 1 ]]; then
        while IFS= read -r dir_fpath; do 
            [[ -z "$dir_fpath" || ! -e "$dir_fpath" ]] && continue
            processDirectoryFiles "$dir_fpath"
        done < "$CONF_FILE"
    fi 
    

    local backup_metadata_file=$(find "$TEMP_BACKUP_DIR" -maxdepth 1 -type f -name ".*.METADATA*.txt" | head -n 1)
    
    # Check metdata and backup if condtions true 
    if [[ -f "$TEMP_BACKUP_DIR/old_metadata.txt" && -n "$backup_metadata_file" && -f "$backup_metadata_file" ]]; then 
        while IFS= read -r f_metadata; do
            [[ -z "$f_metadata" ]] && continue
            
            local f_name="${f_metadata%%|*}"
            printIfVerbose "$VERBOSE_ARG_FLAG" "info" "checking $f_name from existing backup"
            
            # Compare new metadata with old metadata
            grep -q "$f_metadata" "$backup_metadata_file"
            if [[ "$?" -eq 0 ]]; then 
                printIfVerbose "$VERBOSE_ARG_FLAG" "info" "file $f_name will be skipped (unmodified)"
                rm -f "$TEMP_BACKUP_DIR/$f_name" 2>/dev/null || true
            fi 

        done < "$TEMP_BACKUP_DIR/old_metadata.txt"
    fi

    # Backup and log
    backupTmpDirectory "$TEMP_BACKUP_DIR"
    
    printIfVerbose "$VERBOSE_ARG_FLAG" "info" "backup created from existing backup"
    writeLog "$LOGFILE_FLAG_ARG" "info" "backup created from existing backup" "$LOG_FILE"
}

function restoreAndDecrypt {
    # Check if backup good
    checkIfGoodZip "$BACKUP_FILE" || {
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "$BACKUP_FILE it's not a zip file"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$BACKUP_FILE not a zip file" "$LOG_FILE"
        exit 1
    }
    
    # Dir to save decrypted data
    local RESTORE_DIR="RESTORED_$(basename "$BACKUP_FILE" .zip)_$(date +%s)"
    mkdir -p "$RESTORE_DIR"

    printIfVerbose "$VERBOSE_ARG_FLAG" "info" "$RESTORE_DIR created"
    writeLog "$LOGFILE_FLAG_ARG" "info" "$RESTORE_DIR created" "$LOG_FILE"

    # Unzip data 
    unzip "$BACKUP_FILE" -d "$RESTORE_DIR" > /dev/null || {
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "failed to unzip $BACKUP_FILE"
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "$BACKUP_FILE failed to unzip" "$LOG_FILE"
        exit 1
    }

    # Iterate all fpaths from encrypted backup
    while IFS= read -r -d '' fpath; do
        local ORIG_FILE="${fpath%.enc}"
        local TEMP_DEC_FILE="${ORIG_FILE}.tmp_dec"
        
        # Decrypt data and show some info 
        openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in "$fpath" -out "$TEMP_DEC_FILE" -pass env:BKP_PASS

        if [[ "$?" -eq 0 ]]; then 
            # Safe file with original name and remov temp name
            mv -f "$TEMP_DEC_FILE" "$ORIG_FILE"
            rm -f "$fpath"
           
            # Some logs
            printIfVerbose "$VERBOSE_ARG_FLAG" "info" "$fpath decrypted succesfuly ($ORIG_FILE)"
            writeLog "$LOGFILE_FLAG_ARG" "info" "$fpath decrypted ($ORIG_FILE)" "$LOG_FILE"
        else
            # If bad delete temp dec file and log 
            rm -f "$TEMP_DEC_FILE" 2>/dev/null || true
            
            printIfVerbose "$VERBOSE_ARG_FLAG" "warning" "failed to decrypt $fpath (wrong password or corrupted data?)"
            writeLog "$LOGFILE_FLAG_ARG" "warning" "$fpath failed to decrypt" "$LOG_FILE"
        fi
    done < <(find "$RESTORE_DIR" -type f -name "*.enc" -print0)
    
    # Exit with succes code 
    exit 0
}

# Argument parsing
if [[ $# -eq 0 ]]; then
    echo "Invalid usage: $0 <args>"
    printHelpMenu
    exit 1
fi

while [[ "$#" -gt 0 ]]; do
    case "$1" in 
        -f | --file)
            checkNextMustArg "$1" "$2"
            CONF_FILE="$2"
            FILE_ARG_FLAG=1
            shift 2
            ;;
        -d | --directory)
            checkNextMustArg "$1" "$2"
            DIR_ARG_FLAG=1
            shift 1
            while [[ "$#" -gt 0 && ! "$1" == -* ]]; do 
                TARGET_DIRS+=("$1")
                shift 1
            done 
            
            if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
                printErrorMsg "fatal" "no path provided after -d/--directory flag"
                writeLog "$LOGFILE_FLAG_ARG" "fatal" "$INVALID_ARG_USAGE" "$LOG_FILE" 
                exit 1
            fi 
            ;;
        -v | --verbose) 
            VERBOSE_ARG_FLAG=1
            shift 1
            ;;
        -o | --output)
            checkNextMustArg "$1" "$2"
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -l | --log) 
            checkNextMustArg "$1" "$2"
            LOGFILE_FLAG_ARG=1 
            LOG_FILE="$2"
            shift 2 
            ;;
        -b | --backup) 
            checkNextMustArg "$1" "$2"
            BACKUP_FLAG_ARG=1
            BACKUP_FILE="$2"
            shift 2
            ;;
        -e | --encrypt)
            ENC_ARG_FLAG=1
            shift 1
            ;;
        -dec | --decrypt) 
            DEC_ARG_FLAG=1 
            shift 1
            ;;
        *)
            printHelpMenu
            exit 1
            ;;
    esac
done

# ceheck BKP_PASS var
if [[ "$ENC_ARG_FLAG" -eq 1 || "$DEC_ARG_FLAG" -eq 1 ]]; then 
    if [[ -z "${BKP_PASS:-}" ]]; then
        printIfVerbose "$VERBOSE_ARG_FLAG" "fatal" "BKP_PASS env var not set" 
        writeLog "$LOGFILE_FLAG_ARG" "fatal" "BKP_PASS env var not set" "$LOG_FILE"
        exit 1
    fi
fi

TEMP_BACKUP_DIR=$(mktemp -d -t backup_sys_XXXXXX)

# Branch for each mode
if [[ "$DEC_ARG_FLAG" -eq 1 && "$BACKUP_FLAG_ARG" -eq 1 ]]; then 
    restoreAndDecrypt 
fi

checkAndPrintArguments

if [[ "$BACKUP_FLAG_ARG" -eq 1 && ( "$FILE_ARG_FLAG" -eq 1 || "$DIR_ARG_FLAG" -eq 1 ) ]]; then 
    backupWithExstingBackupFile 
elif [[ "$DIR_ARG_FLAG" -eq 1 && "$FILE_ARG_FLAG" -eq 0 ]]; then
    backupFromDirectoryArr "${TARGET_DIRS[@]}"
elif [[ "$FILE_ARG_FLAG" -eq 1 && "$DIR_ARG_FLAG" -eq 0 ]]; then 
    backupFromConfigFile "$CONF_FILE"
else
    printErrorMsg "fatal" "Invalid args combination"
    exit 1
fi
