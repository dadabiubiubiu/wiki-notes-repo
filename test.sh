#!/bin/bash

set -e

# ==============================
# 固定配置
# ==============================

TARGET_DIR="/opt/project"
TARGET_SCRIPT="/opt/scripts/deploy.sh"

# 原始属主和属组
OLD_OWNER="root"
OLD_GROUP="optgroup"

# 临时属主和属组
NEW_OWNER="build"
NEW_GROUP="optgroup"

# ==============================
# 检查目录
# ==============================

if [ ! -d "$TARGET_DIR" ]; then
    echo "目录不存在：$TARGET_DIR"
    exit 1
fi

CURRENT_OWNER=$(stat -c '%U' "$TARGET_DIR")
CURRENT_GROUP=$(stat -c '%G' "$TARGET_DIR")

if [ "$CURRENT_OWNER" != "$OLD_OWNER" ] || \
   [ "$CURRENT_GROUP" != "$OLD_GROUP" ]; then
    echo "目录属主或属组不匹配，跳过执行"
    exit 0
fi

# ==============================
# 恢复函数
# ==============================

restore_owner() {
    STATUS=$?

    echo "开始恢复原始属主和属组..."

    chown -R "$OLD_OWNER:$OLD_GROUP" "$TARGET_DIR"

    echo "属主和属组恢复完成"

    exit "$STATUS"
}

# 注册退出时恢复
trap restore_owner EXIT

# ==============================
# 修改临时属主和属组
# ==============================

echo "修改临时属主和属组..."

chown -R "$NEW_OWNER:$NEW_GROUP" "$TARGET_DIR"

# ==============================
# 执行目标脚本
# ==============================

echo "开始执行目标脚本..."

bash "$TARGET_SCRIPT"

echo "目标脚本执行结束"