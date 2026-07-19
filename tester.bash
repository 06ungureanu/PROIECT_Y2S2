#!/bin/bash

# vars
TEST_DIR="results"
SOURCE_DIR="$TEST_DIR/data"
CONFIG_DIR="$TEST_DIR/config"
LOG_DIR="$TEST_DIR/logs"
BACKUP_DIR="$TEST_DIR/backups"

# clean last test
rm -rf "$TEST_DIR"
mkdir -p "$SOURCE_DIR/dir1" "$SOURCE_DIR/dir2" "$CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR"

# Dummy files for testing
echo "Important data x1" > "$SOURCE_DIR/dir1/file1.txt"
echo "Important data x2" > "$SOURCE_DIR/dir2/file2.txt"
echo "$SOURCE_DIR/dir1" > "$CONFIG_DIR/backup_list.txt"

# run script with -l and not -v
function run_test() {
    local DESC="$1"
    local T_NAME="$2"
    local CMD="$3"

    echo "-> Running test $DESC"
    echo ""

    eval "$CMD -l $LOG_DIR/$T_NAME.log"

    if [[ "$?" -eq 0 ]]; then 
        echo "  * $T_NAME succes (log saved)"
        echo ""
    else 
        echo "  * $T_NAME failed (log not saved)"
        echo ""
    fi
}

# T_1 : Normal backup
run_test "Normal backup" "T_1" "./bin/main.bash -d $SOURCE_DIR/dir1 -o $BACKUP_DIR/simple_backup"

# T_2 : Encrypted backup
run_test "Encrypted backup" "T_2" "./bin/main.bash -d $SOURCE_DIR/dir2 -o $BACKUP_DIR/enc_backup -e pass"

# T_3 : Backup from config file
run_test "Backup from config file" "T_3" "./bin/main.bash -f $CONFIG_DIR/backup_list.txt -o $BACKUP_DIR/conf_backup"

# T_4 : Backup with existing zip

./bin/main.bash -d "$SOURCE_DIR/dir1" -o "$BACKUP_DIR/base" > /dev/null
echo "New Data" > "$SOURCE_DIR/dir1/new.txt"

run_test "Backup existing zip" "T_4" "./bin/main.bash -d $SOURCE_DIR/dir1 -o $BACKUP_DIR/diff_backup -b $BACKUP_DIR/base.zip"

# T_5 : Decrypt restore
run_test "Resotre Backup" "T_5" "./bin/main.bash -dec pass -b $BACKUP_DIR/enc_backup.zip"
mv RESTORED* "$TEST_DIR" 
