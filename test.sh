#!/bin/bash

set -Eeuo pipefail

# ==========================================================
# 参数说明
# $1: 目标目录
# $2: 原属主（用于判断是否需要执行）
# $3: 原属组（用于判断是否需要执行）
# $4: 临时属主
# $5: 临时属组
# $6: 待执行脚本
# $7及以后: 传递给待执行脚本的参数
# ==========================================================

if [[ $# -lt 6 ]]; then
    echo "Usage: $0 <directory> <expected_owner> <expected_group> <temp_owner> <temp_group> <script> [args...]"
    exit 1
fi

TARGET_DIR="$1"
EXPECTED_OWNER="$2"
EXPECTED_GROUP="$3"
TEMP_OWNER="$4"
TEMP_GROUP="$5"
TARGET_SCRIPT="$6"

shift 6

# ==========================================================
# 1. 基础检查
# ==========================================================

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: Directory does not exist: $TARGET_DIR"
    exit 1
fi

if [[ ! -f "$TARGET_SCRIPT" ]]; then
    echo "ERROR: Script does not exist: $TARGET_SCRIPT"
    exit 1
fi

# 转换为绝对路径
TARGET_DIR=$(realpath -e "$TARGET_DIR")
TARGET_SCRIPT=$(realpath -e "$TARGET_SCRIPT")

# 获取用户 UID
get_uid() {
    id -u "$1"
}

# 获取用户组 GID
get_gid() {
    getent group "$1" | awk -F: 'NR==1 {print $3}'
}

# 检查用户和用户组是否存在
EXPECTED_UID=$(get_uid "$EXPECTED_OWNER")
EXPECTED_GID=$(get_gid "$EXPECTED_GROUP")
TEMP_UID=$(get_uid "$TEMP_OWNER")
TEMP_GID=$(get_gid "$TEMP_GROUP")

if [[ -z "$EXPECTED_GID" || -z "$TEMP_GID" ]]; then
    echo "ERROR: Invalid group"
    exit 1
fi

# ==========================================================
# 2. 检查目标目录当前属主和属组
# ==========================================================

CURRENT_UID=$(stat -c '%u' "$TARGET_DIR")
CURRENT_GID=$(stat -c '%g' "$TARGET_DIR")

if [[ "$CURRENT_UID" != "$EXPECTED_UID" || "$CURRENT_GID" != "$EXPECTED_GID" ]]; then
    echo "INFO: Directory owner/group does not match."
    echo "Expected: $EXPECTED_OWNER:$EXPECTED_GROUP"
    echo "Current:  $(stat -c '%U:%G' "$TARGET_DIR")"
    echo "Skip execution."
    exit 0
fi

echo "INFO: Directory owner/group matched."

# ==========================================================
# 3. 创建临时备份文件
# ==========================================================

umask 077

BACKUP_FILE=$(mktemp)
PATH_FILE=$(mktemp)

# ==========================================================
# 4. 备份所有文件和目录原始 UID/GID
# ==========================================================

echo "INFO: Backing up original ownership..."

if ! find "$TARGET_DIR" -print0 > "$PATH_FILE"; then
    echo "ERROR: Failed to scan directory."
    rm -f "$BACKUP_FILE" "$PATH_FILE"
    exit 1
fi

while IFS= read -r -d '' path; do

    ownership=$(stat -c '%u %g' -- "$path") || {
        echo "ERROR: Failed to read ownership: $path"
        rm -f "$BACKUP_FILE" "$PATH_FILE"
        exit 1
    }

    read -r uid gid <<< "$ownership"

    # 使用 NUL 分隔，兼容空格和特殊字符文件名
    printf '%s\0%s\0%s\0' "$path" "$uid" "$gid" >> "$BACKUP_FILE"

done < "$PATH_FILE"

rm -f "$PATH_FILE"

echo "INFO: Ownership backup completed."

# ==========================================================
# 5. 定义恢复函数
# ==========================================================

restore_ownership() {

    local original_status=$?

    local path
    local uid
    local gid
    local restore_failed=0

    echo ""
    echo "INFO: Starting ownership restoration..."

    while IFS= read -r -d '' path &&
          IFS= read -r -d '' uid &&
          IFS= read -r -d '' gid; do

        if [[ -e "$path" || -L "$path" ]]; then

            if ! chown -h "$uid:$gid" -- "$path"; then
                echo "ERROR: Failed to restore: $path"
                restore_failed=1
            fi

        fi

    done < "$BACKUP_FILE"

    rm -f "$BACKUP_FILE"

    if [[ "$restore_failed" -eq 0 ]]; then
        echo "INFO: Ownership restoration completed."
    else
        echo "ERROR: Some ownership restoration operations failed."
    fi

    # 恢复失败时，即使原脚本成功，也返回非零状态
    if [[ "$restore_failed" -ne 0 && "$original_status" -eq 0 ]]; then
        original_status=1
    fi

    echo "INFO: Original script exit code: $?"
    echo "INFO: Final exit code: $original_status"

    exit "$original_status"
}

# ==========================================================
# 6. 注册 EXIT 处理机制
# ==========================================================

trap restore_ownership EXIT

# 处理中断信号，转为退出并触发 EXIT trap
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ==========================================================
# 7. 临时修改目录及其所有文件的属主和属组
# ==========================================================

echo "INFO: Changing ownership to $TEMP_OWNER:$TEMP_GROUP"

while IFS= read -r -d '' path; do

    chown -h "$TEMP_UID:$TEMP_GID" -- "$path"

done < <(find "$TARGET_DIR" -print0)

echo "INFO: Ownership changed successfully."

# ==========================================================
# 8. 执行目标脚本
# ==========================================================

echo "INFO: Executing target script: $TARGET_SCRIPT"

SCRIPT_EXIT_CODE=0

if bash "$TARGET_SCRIPT" "$@"; then
    SCRIPT_EXIT_CODE=0
else
    SCRIPT_EXIT_CODE=$?
fi

echo "INFO: Target script finished with exit code: $SCRIPT_EXIT_CODE"

exit "$SCRIPT_EXIT_CODE"