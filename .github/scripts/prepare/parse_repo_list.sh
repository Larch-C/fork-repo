#!/usr/bin/env bash
set -e

echo "📋 正在解析仓库列表..."

# 提取所有仓库URL并清理格式
repos=$(jq -r '
  to_entries[] |
  select(.value.repo != null) |
  .value.repo
' plugins.json | \
sed 's|git@github.com:|https://github.com/|' | \
sed 's|\.git$||' | \
sed 's|/tree/.*||' | \
sed 's|/blob/.*||' | \
grep -E '^https://github\.com/[^/]+/[^/]+$' | \
sort -u)

# 转换为JSON数组格式
repo_array=$(echo "$repos" | jq -R -s -c 'split("\n") | map(select(. != ""))')
total_count=$(echo "$repos" | wc -l)

{
  echo "repos=$repo_array"
  echo "total_count=$total_count"
} >> "$GITHUB_OUTPUT"

echo "📊 找到 $total_count 个有效的GitHub仓库："
echo "$repos" | head -10
if [ "$total_count" -gt 10 ]; then
  echo "... 和其他 $((total_count - 10)) 个仓库"
fi


