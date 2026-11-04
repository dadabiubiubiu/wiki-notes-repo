#!/bin/bash

set -e

==================================================

1. Jenkins 参数

==================================================

MR_ID=”${MR_ID}”
LOCAL_BRANCH=”${LOCAL_BRANCH}”
REMOTE_BRANCH=”${REMOTE_BRANCH}”

Git-MM 工作区

WORKSPACE=”/opt/git-workspace”

默认远端名称

REMOTE=“origin”

==================================================

2. Git 仓库路径

==================================================

相对于 WORKSPACE 的路径

支持多层目录嵌套

REPO_PATHS=(
“project-a”
“project-a/module-a”
“project-b”
“project-b/service/api”
“project-b/service/core”
“project-c”
)

==================================================

3. 执行结果

==================================================

SUCCESS_REPOS=()
FAILED_REPOS=()

==================================================

4. 参数检查

==================================================

if [[ -z “$MR_ID” || -z “$LOCAL_BRANCH” || -z “$REMOTE_BRANCH” ]]; then
echo “ERROR: Jenkins 参数不完整”
exit 1
fi

if [[ ! -d “$WORKSPACE” ]]; then
echo “ERROR: Git-MM 工作区不存在：$WORKSPACE”
exit 1
fi

cd “$WORKSPACE”

==================================================

5. Git-MM 初始化

==================================================

echo “========== Step 1: Git-MM Init ==========”

git mm init

==================================================

6. Git-MM 同步

==================================================

echo “========== Step 2: Git-MM Sync ==========”

git mm sync

==================================================

7. 创建本地分支

==================================================

echo “========== Step 3: Git-MM Start ==========”

git mm start “$LOCAL_BRANCH”

==================================================

8. 执行 MR Cherry-Pick

==================================================

echo “========== Step 4: Git-MM Cherry-Pick ==========”

git mm Cherry-Pick “$MR_ID”

==================================================

9. 批量推送仓库

==================================================

echo “========== Step 5: Push Repositories ==========”

for REPO_PATH in “${REPO_PATHS[@]}”; do

echo ""
echo "------------------------------------------"
echo "当前仓库：$REPO_PATH"
REPO="$WORKSPACE/$REPO_PATH"
# 检查仓库路径
if [[ ! -d "$REPO/.git" && ! -f "$REPO/.git" ]]; then
    echo "FAILED: Git 仓库不存在"
    FAILED_REPOS+=("$REPO_PATH")
    continue
fi
cd "$REPO"
# 检查本地分支
if ! git show-ref --verify --quiet "refs/heads/$LOCAL_BRANCH"; then
    echo "FAILED: 本地分支不存在"
    FAILED_REPOS+=("$REPO_PATH")
    continue
fi
# 检查远端
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "FAILED: 远端不存在"
    FAILED_REPOS+=("$REPO_PATH")
    continue
fi
# 推送到远端
if git push "$REMOTE" "$LOCAL_BRANCH:$REMOTE_BRANCH"; then
    echo "SUCCESS: Push 成功"
    SUCCESS_REPOS+=("$REPO_PATH")
else
    echo "FAILED: Push 失败"
    FAILED_REPOS+=("$REPO_PATH")
fi

done

==================================================

10. 执行结果汇总

==================================================

echo “”
echo “==========================================”
echo “Git-MM Cherry-Pick 执行结果”
echo “==========================================”

echo “”
echo “成功仓库数量：${#SUCCESS_REPOS[@]}”

for REPO in “${SUCCESS_REPOS[@]}”; do
echo “[SUCCESS] $REPO”
done

echo “”
echo “失败仓库数量：${#FAILED_REPOS[@]}”

for REPO in “${FAILED_REPOS[@]}”; do
echo “[FAILED] $REPO”
done

echo “”
echo “==========================================”

if [[ ${#FAILED_REPOS[@]} -gt 0 ]]; then
echo “任务结束：部分仓库执行失败”
exit 1
fi

echo “任务结束：所有仓库推送成功”
exit 0