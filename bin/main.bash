#!/bin/bash 

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

# Util vars
TEMP_BACKUP_DIR=".BAK_TMP_DATA"
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
    echo "      -e / --encrypt   [value]    [Provide encryption arguments]"
    echo "      -o / --output    [value]    [Output file name]"
    echo "      -v / --verbose   [no args]  [Enable verbose mode]"
    echo "      -h / --help      [no args]  [Show this help menu]"
}

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
    if [[ -z "$(ls -A  $(realpath "$TEMP_BACKUP_DIR"))" ]]; then 
        if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then 
            printErrorMsg "fatal" "Nothing to backup in $BAK_TMP_DATA"
        fi

        writeLog "$LOGFILE_FLAG_ARG" "fatal" "Nothing to backup in $BAK_TMP_DATA" "$LOG_FILE"
        return 1 # Return with error code (for testing)
    fi 

    # Zip al content to output file 
    (cd "$TEMP_BACKUP_DIR" && zip -r "../$OUTPUT_FILE.zip" .) > /dev/null
    
    # Some info if verbose flag
    if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then 
        printErrorMsg "info" "Backup succefuly dumped to $OUTPUT_FILE.zip"
    fi

    # Clear temp data and log
    writeLog "$LOGFILE_FLAG_ARG" "info" "Backup succefuly dumped to $OUTPUT_FILE.zip" "$LOG_FILE"
    
    rm -rf "$TEMP_BACKUP_DIR"

    if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then
        printErrorMsg "info" "$TEMP_BACKUP_DIR removed"
    fi

    writeLog "$LOGFILE_FLAG_ARG" "info" "$TEMP_BACKUP_DIR removed" "$LOG_FILE"
}

function pushFileToTempBackupDirectory {
    if [[ "$#" -ne 1 ]]; then 
        return 1
    fi 
   
    # Check if file is good
    checkFile "$1"
    if [[ "$?" -ne 0 ]]; then 
        printErrorMsg "warning" "$1 invalid file (skipped)"
        writeLog "$LOGFILE_FLAG_ARG" "warning" "$1 invalid file (skipped)" "$LOG_FILE"
        return 1
    fi 

    # Check if TEMP_BACKUP_DIR and create if not exist
    if [[ ! -d "$TEMP_BACKUP_DIR" ]]; then 
        mkdir "$TEMP_BACKUP_DIR"
        chmod 700 "$TEMP_BACKUP_DIR"        # Security reasons (Only owner have access to execute/read/write)
        writeLog "$LOGFILE_FLAG_ARG" "info" "$TEMP_BACKUP_DIR directory created" "$LOG_FILE"
    fi
    
    # Metdata file and extract metadata
    METADATA_FILE="$(basename $"OUTPUT_FILE").METADATA_BAK_$(date +%Y-%m-%d).txt"
    REALPATH_FPATH=$(realpath "$1")
   
    extractMetaDates "$REALPATH_FPATH" "$TEMP_BACKUP_DIR/.$METADATA_FILE" "$LOGFILE_FLAG_ARG" "$LOG_FILE" "$VERBOSE_ARG_FLAG"
}
function processDirectoryFiles {
    if [[ "$#" -ne 1 ]]; then 
        return 
    fi 
    
    # Recursive search of each file in dir
    find "$1" -print0 | while IFS= read -r -d '' item; do 
        if [[ -d "$item" ]]; then
            continue
        fi 
        
        # Print data to STDOUUT if VERBOSE_ARG_FLAG
        if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then 
            printErrorMsg "info" "Processing $item"
        fi
    
        # Log and send file to be pushed in temp dir 
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
    
    # Some info if VERBOSE_ARG_FLAG
    if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then 
        printErrorMsg "info" "Backup started with -d/--directory flag"
    fi 

    # Iterate array TARGET_DIRS
    for fpath in "${TARGET_DIRS[@]}"; do 
        
        # Check if dir ok
        checkDirectory "$fpath"
        
        # If not, send a warning and continue
        if [[ "$?" -ne 0 ]]; then 
            if [[ "$VERBOSE_ARG_FLAG" -eq 1 ]]; then 
                printErrorMsg "warning" "$fpath invalid directory (skipped)"
            fi
            writeLog "$LOGFILE_FLAG_ARG" "warning" "$fpath invalid directory (skipped)" "$LOG_FILE"
            continue
        fi

        # Log and start process dir files 
        writeLog "$LOGFILE_FLAG_ARG" "info" "backup started with directory flag" "$LOG_FILE"
        processDirectoryFiles "$fpath"
        
        # Copy items from dir to TEMP_BACKUP_DI
        cp -r "$item" "$TEMP_BACKUP_DIR"
    done

    # Zip BAK_TMP_DATA folder
    backupTmpDirectory "$BAK_TMP_DATA"
}

# Argument parsing

# Check number of args
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
        # TO DO: encrypt action / existing backup
        *)
            printHelpMenu
            exit 1
            ;;
    esac
done

checkAndPrintArguments

# Branch for each mode
if [[ "$DIR_ARG_FLAG" -eq 1 && "$FILE_ARG_FLAG" -eq 0 ]]; then
    backupFromDirectoryArr "${TARGET_DIRS[@]}"
elif [[ "$FILE_ARG_FLAG" -eq 1 && "$DIR_ARG_FLAG" -eq 0 ]]; then 
    echo "Backup from config file"
fi
