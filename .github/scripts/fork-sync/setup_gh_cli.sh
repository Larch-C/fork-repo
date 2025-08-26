#!/usr/bin/env bash
set -e

if [ -z "${GH_PAT:-}" ]; then
  echo "❌ 错误: 未找到 GH_PAT secret"
  echo "请按照以下步骤设置Personal Access Token:"
  echo "1. 访问 GitHub Settings → Developer settings → Personal access tokens"
  echo "2. 创建新token，需要 repo 和 workflow 权限"
  echo "3. 在仓库设置中添加名为 GH_PAT 的secret"
  exit 1
fi

echo "${GH_PAT}" | gh auth login --with-token


