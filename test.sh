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

# 执行脚本
TARGET_SCRIPT="/opt/scripts/deploy.sh"

# ==============================
# 恢复函数
# ==============================

restore_owner() {
    STATUS=$?

    echo "开始恢复目录属主和属组..."

    for DIR in "${DIRS[@]}"; do
        chown -R "$OLD_OWNER:$OLD_GROUP" "$BASE_DIR/$DIR"
    done

    echo "所有目录恢复完成"

    exit "$STATUS"
}

# ==============================
# 检查目录
# ==============================

for DIR in "${DIRS[@]}"; do

    TARGET_DIR="$BASE_DIR/$DIR"

    if [ ! -d "$TARGET_DIR" ]; then
        echo "目录不存在：$TARGET_DIR"
        exit 1
    fi

    CURRENT_OWNER=$(stat -c '%U' "$TARGET_DIR")
    CURRENT_GROUP=$(stat -c '%G' "$TARGET_DIR")

    if [ "$CURRENT_OWNER" != "$OLD_OWNER" ] || \
       [ "$CURRENT_GROUP" != "$OLD_GROUP" ]; then

        echo "目录属主或属组不匹配：$TARGET_DIR"
        exit 1
    fi

done

# ==============================
# 注册恢复机制
# ==============================

trap restore_owner EXIT

# ==============================
# 修改临时属主和属组
# ==============================

for DIR in "${DIRS[@]}"; do

    echo "修改目录：$BASE_DIR/$DIR"

    chown -R "$NEW_OWNER:$NEW_GROUP" "$BASE_DIR/$DIR"

done

# ==============================
# 执行目标脚本
# ==============================

echo "开始执行目标脚本..."

bash "$TARGET_SCRIPT"

echo "目标脚本执行结束"