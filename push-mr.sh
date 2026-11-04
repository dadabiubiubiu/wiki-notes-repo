#!/bin/bash

set -e

==============================

1. 固定参数

==============================

MR_ID=“123456”
LOCAL_BRANCH=“feature_branch”
REMOTE_BRANCH=“release_branch”

WORKSPACE=”/opt/git-workspace”
REMOTE=“origin”

==============================

2. Git 仓库路径

==============================

REPO_PATHS=(
“project-a”
“project-a/module-a”
“project-b/service”
“project-c”
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

for REPO_PATH in “${REPO_PATHS[@]}”; do

echo "正在推送：$REPO_PATH"
cd "$WORKSPACE/$REPO_PATH"
git push "$REMOTE" "$LOCAL_BRANCH:$REMOTE_BRANCH"

done

echo “所有仓库推送完成！”