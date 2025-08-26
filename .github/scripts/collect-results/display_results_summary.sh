#!/usr/bin/env bash
set -e

echo "📊 正在添加结果到步骤摘要..."
cat results_summary.md >> "$GITHUB_STEP_SUMMARY"


