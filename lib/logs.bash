#!/bin/bash 

# Module used for logs 

# Log format: [Type][Time] <Log Message>
# Log types: info,warning, fatal
# Log code colors: info(green), warning(yellow), fatal(red)

# Function: writeLog(log_flag, log_type,log_msg,log_file)
# Function: createLogFile(log_fpath)


# Some common log messages
INVALID_ARG_USAGE="INVALID ARGUMENT USAGE"
INVALID_FILE="INVALID FILE PROVIDED AS ARGUMENT"


function createLogFile {
    # Check if no arg
    if [[ "$#" -ne 1 ]]; then 
        return
    fi 
    
    # Check if empty arg
    if [[ -z "$1" ]]; then 
        return 
    fi 
    
    # if not exist log file, create 
    if [[ ! -e "$1" ]]; then 
        touch "$1"
        chmod 600 "$1"  # Security reasons (only owner can read/write to log file)
    fi 
}
function writeLog {
    # Check if invalid func call 
    if [[ "$#" -ne 4 ]]; then 
        return 
    fi 

    # Check if no log flag
    if [[ "$1" -eq 0 ]]; then
        return 
    fi 

    # In case log file not exist, create
    if [[ ! -e "$4" ]]; then 
        createLogFile "$4"
    fi 
    
    # Check if bad log type arg
    if [[ "$2" != "info"  && "$2" != "warning" && "$2" != "fatal" ]]; then
        return 
    fi 
   
    # Vars for log process
    CUR_TIME=$(date +%Y-%m-%d)
    
    LOG_FILE="$4"
    LOG_MSG="$3"


    # Dump log 2 file 
    if [[ "$2" == "info" ]]; then
        echo -ne "[\033[0;32mInfo\033[0m] " >> "$LOG_FILE"
    elif [[ "$2" == "warning" ]]; then
        echo -ne "[\033[0;33mWarning\033[0m] " >> "$LOG_FILE"
    else
        echo -ne "[\033[0;31mFatal\033[0m] " >> "$LOG_FILE"
    fi   

    echo "[$CUR_TIME] $LOG_MSG" >> "$LOG_FILE"    
}
