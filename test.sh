#!/bin/bash

set -e

# ==============================
# 固定配置
# ==============================

BASE_DIR="/opt"

# 需要处理的三个目录
DIRS=(
    "project1"
    "project2"
    "project3"
)

# 原始属主和属组
OLD_OWNER="root"
OLD_GROUP="optgroup"

# 临时属主和属组
NEW_OWNER="build"
NEW_GROUP="optgroup"

# 需要执行的脚本
TARGET_SCRIPT="/opt/scripts/deploy.sh"

# ==============================
# 恢复函数
# ==============================

restore_owner() {

    local STATUS=$?

    # 防止恢复失败导致后续目录无法恢复
    set +e

    echo "========== 开始恢复目录权限 =========="

    for DIR in "${DIRS[@]}"; do

        TARGET_DIR="$BASE_DIR/$DIR"

        echo "恢复目录：$TARGET_DIR"

        if sudo chown -R "$OLD_OWNER:$OLD_GROUP" "$TARGET_DIR"; then
            echo "恢复成功：$TARGET_DIR"
        else
            echo "恢复失败：$TARGET_DIR"
            STATUS=1
        fi

    done

    echo "========== 目录权限恢复结束 =========="

    exit "$STATUS"
}

# ==============================
# 检查目录
# ==============================

for DIR in "${DIRS[@]}"; do

    TARGET_DIR="$BASE_DIR/$DIR"

    if [ ! -d "$TARGET_DIR" ]; then
        echo "ERROR: 目录不存在：$TARGET_DIR"
        exit 1
    fi

    CURRENT_OWNER=$(stat -c '%U' "$TARGET_DIR")
    CURRENT_GROUP=$(stat -c '%G' "$TARGET_DIR")

    if [ "$CURRENT_OWNER" != "$OLD_OWNER" ] || \
       [ "$CURRENT_GROUP" != "$OLD_GROUP" ]; then

        echo "ERROR: 目录属主或属组不匹配：$TARGET_DIR"
        exit 1
    fi

done

# ==============================
# 注册退出恢复机制
# ==============================

trap restore_owner EXIT

# ==============================
# 修改临时属主和属组
# ==============================

for DIR in "${DIRS[@]}"; do

    TARGET_DIR="$BASE_DIR/$DIR"

    echo "修改临时权限：$TARGET_DIR"

    sudo chown -R "$NEW_OWNER:$NEW_GROUP" "$TARGET_DIR"

done

# ==============================
# 执行目标脚本
# ==============================

echo "========== 开始执行目标脚本 =========="

bash "$TARGET_SCRIPT"

echo "========== 目标脚本执行结束 =========="