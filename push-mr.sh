#!/bin/bash

set -e

==============================

1. 固定参数

==============================

MR_ID=“123456”
LOCAL_BRANCH=“feature_branch”
REMOTE_BRANCH=“release_branch”

WORKSPACE=”/opt/git-workspace”

==============================

2. Git 仓库路径及地址

==============================

格式：路径|Git仓地址

REPO_PATHS=(
“project-a|ssh://git@server/project-a.git”
“project-a/module-a|ssh://git@server/module-a.git”
“project-b/service|ssh://git@server/service.git”
)

==============================

3. Git-MM 操作

==============================

cd “$WORKSPACE”

git mm init

git mm sync

git mm start “$LOCAL_BRANCH”

git mm Cherry-Pick “$MR_ID”

==============================

4. 遍历仓库并推送

==============================

for REPO_INFO in “${REPO_PATHS[@]}”; do

IFS='|' read -r REPO_PATH REPO_URL <<< "$REPO_INFO"
echo "======================================"
echo "当前路径：$REPO_PATH"
echo "Git仓地址：$REPO_URL"
cd "$WORKSPACE/$REPO_PATH"
git push "$REPO_URL" "$LOCAL_BRANCH:$REMOTE_BRANCH"

done

echo “所有仓库推送完成！”