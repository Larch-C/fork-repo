#!/usr/bin/env bash
set -e

echo "📦 正在创建批次..."

repos="${REPOS_JSON}"
total_count="${TOTAL_COUNT}"

# 每批处理100个仓库
batch_size=100
batch_count=$(( (total_count + batch_size - 1) / batch_size ))

echo "总仓库数: $total_count"
echo "批次大小: $batch_size"
echo "批次数量: $batch_count"

# 创建批次数组
batches="["
for i in $(seq 0 $((batch_count - 1))); do
  start_idx=$((i * batch_size))
  end_idx=$(((i + 1) * batch_size))

  # 使用jq提取当前批次的仓库
  batch_repos=$(echo "$repos" | jq -c ".[$start_idx:$end_idx]")

  if [ $i -gt 0 ]; then
    batches="$batches,"
  fi
  batches="$batches{\"batch_id\":$i,\"repos\":$batch_repos}"
done
batches="$batches]"

{
  echo "batches=$batches"
  echo "batch_count=$batch_count"
} >> "$GITHUB_OUTPUT"

echo "✅ 创建了 $batch_count 个批次"


