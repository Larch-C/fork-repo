#!/usr/bin/env bash
set -e

echo "📊 正在生成结果表格..."

echo "# 🎯 AstrBot插件Fork/Sync结果报告" > results_summary.md
echo "" >> results_summary.md
echo "**操作时间:** $(date -u '+%Y-%m-%d %H:%M:%S UTC')" >> results_summary.md
if [ "${DRY_RUN}" = "true" ]; then
  echo "**操作模式:** 🔍 试运行" >> results_summary.md
else
  echo "**操作模式:** ▶️ 实际执行" >> results_summary.md
fi
echo "**冲突策略:** ${CONFLICT_STRATEGY}" >> results_summary.md
echo "**总仓库数:** ${TOTAL_COUNT}" >> results_summary.md
echo "" >> results_summary.md

total=0
forked=0
forked_renamed=0
synced=0
up_to_date=0
already_forked=0
failed=0
not_found=0
conflicts=0
renamed_count=0

echo "## 📋 详细结果" >> results_summary.md
echo "" >> results_summary.md
echo "| 仓库 | 状态 | 我的Fork | Fork名称 | 重命名 | 说明 | Fork状态 | 时间 |" >> results_summary.md
echo "|------|------|----------|----------|--------|------|----------|------|" >> results_summary.md

if [ -d "all-results" ]; then
  for file in all-results/*.json; do
    if [ -f "$file" ]; then
      total=$((total + 1))
      repo=$(jq -r '.repo' "$file" 2>/dev/null || echo "unknown")
      status=$(jq -r '.status' "$file" 2>/dev/null || echo "unknown")
      message=$(jq -r '.message' "$file" 2>/dev/null || echo "无消息")
      my_fork=$(jq -r '.my_fork' "$file" 2>/dev/null || echo "unknown")
      final_name=$(jq -r '.final_fork_name // .repo_name' "$file" 2>/dev/null || echo "unknown")
      renamed=$(jq -r '.renamed // false' "$file" 2>/dev/null || echo "false")
      fork_status=$(jq -r '.fork_status // "unknown"' "$file" 2>/dev/null || echo "unknown")
      timestamp=$(jq -r '.timestamp' "$file" 2>/dev/null || echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)")

      formatted_time=$(date -d "$timestamp" '+%H:%M' 2>/dev/null || echo "N/A")

      if [ "$renamed" = "true" ]; then
        renamed_count=$((renamed_count + 1))
      fi

      case "$status" in
        forked) icon="🍴"; forked=$((forked + 1));;
        forked_renamed) icon="🏷️"; forked_renamed=$((forked_renamed + 1));;
        synced) icon="🔄"; synced=$((synced + 1));;
        up_to_date) icon="✅"; up_to_date=$((up_to_date + 1));;
        already_forked) icon="📁"; already_forked=$((already_forked + 1));;
        fork_failed|fork_rename_failed|sync_failed|auth_failed|api_check_failed) icon="❌"; failed=$((failed + 1));;
        not_found) icon="🚫"; not_found=$((not_found + 1));;
        skipped_conflict|conflict_detected|conflict_pending) icon="⚠️"; conflicts=$((conflicts + 1));;
        will_fork) icon="🔮";;
        will_fork_renamed) icon="🔮🏷️";;
        will_sync) icon="🔮";;
        *) icon="❓";;
      esac

      case "$fork_status" in
        valid_fork|valid_fork_api) fork_status_display="✅ 有效";;
        wrong_parent) fork_status_display="⚠️ 错误父级";;
        independent_repo) fork_status_display="🏠 独立仓库";;
        not_exists) fork_status_display="❌ 不存在";;
        invalid_fork) fork_status_display="❌ 无效fork";;
        api_check_failed) fork_status_display="❌ API检查失败";;
        *) fork_status_display="❓ 未知";;
      esac

      rename_display="❌ 否"
      if [ "$renamed" = "true" ]; then
        rename_display="✅ 是"
      fi

      echo "| [\`$repo\`](https://github.com/$repo) | $icon $status | [\`$my_fork\`](https://github.com/$my_fork) | \`$final_name\` | $rename_display | $message | $fork_status_display | $formatted_time |" >> results_summary.md
    fi
  done
fi

echo "" >> results_summary.md
echo "## 📊 统计摘要" >> results_summary.md
echo "" >> results_summary.md
echo "| 状态 | 数量 | 百分比 |" >> results_summary.md
echo "|------|------|--------|" >> results_summary.md

if [ $total -gt 0 ]; then
  [ $forked -gt 0 ] && echo "| 🍴 新fork成功 | $forked | $(( forked * 100 / total ))% |" >> results_summary.md
  [ $forked_renamed -gt 0 ] && echo "| 🏷️ 重命名fork成功 | $forked_renamed | $(( forked_renamed * 100 / total ))% |" >> results_summary.md
  [ $synced -gt 0 ] && echo "| 🔄 同步成功 | $synced | $(( synced * 100 / total ))% |" >> results_summary.md
  [ $up_to_date -gt 0 ] && echo "| ✅ 已是最新 | $up_to_date | $(( up_to_date * 100 / total ))% |" >> results_summary.md
  [ $already_forked -gt 0 ] && echo "| 📁 已fork(未同步) | $already_forked | $(( already_forked * 100 / total ))% |" >> results_summary.md
  [ $conflicts -gt 0 ] && echo "| ⚠️ 冲突/跳过 | $conflicts | $(( conflicts * 100 / total ))% |" >> results_summary.md
  [ $failed -gt 0 ] && echo "| ❌ 失败 | $failed | $(( failed * 100 / total ))% |" >> results_summary.md
  [ $not_found -gt 0 ] && echo "| 🚫 仓库不存在 | $not_found | $(( not_found * 100 / total ))% |" >> results_summary.md
fi

echo "" >> results_summary.md
echo "**总计:** $total 个仓库" >> results_summary.md
echo "**自动重命名:** $renamed_count 个仓库" >> results_summary.md

if [ $renamed_count -gt 0 ]; then
  echo "" >> results_summary.md
  echo "## 🏷️ 重命名详情" >> results_summary.md
  echo "" >> results_summary.md
  echo "| 原始仓库 | 原名称 | 新名称 | 原因 |" >> results_summary.md
  echo "|----------|--------|--------|------|" >> results_summary.md
  for file in all-results/*.json; do
    if [ -f "$file" ]; then
      renamed_check=$(jq -r '.renamed // false' "$file" 2>/dev/null || echo "false")
      if [ "$renamed_check" = "true" ]; then
        repo=$(jq -r '.repo' "$file" 2>/dev/null || echo "unknown")
        repo_name=$(jq -r '.repo_name' "$file" 2>/dev/null || echo "unknown")
        final_name=$(jq -r '.final_fork_name' "$file" 2>/dev/null || echo "unknown")
        fork_status=$(jq -r '.fork_status' "$file" 2>/dev/null || echo "unknown")
        case "$fork_status" in
          wrong_parent) reason="错误的父级仓库" ;;
          independent_repo) reason="存在同名独立仓库" ;;
          invalid_fork) reason="无效的fork" ;;
          *) reason="名称冲突" ;;
        esac
        echo "| [\`$repo\`](https://github.com/$repo) | \`$repo_name\` | \`$final_name\` | $reason |" >> results_summary.md
      fi
    fi
  done
fi

echo "" >> results_summary.md
echo "## 💡 建议" >> results_summary.md
echo "" >> results_summary.md
[ $failed -gt 0 ] && echo "- ⚠️  有 $failed 个仓库操作失败，建议检查权限或网络问题" >> results_summary.md
[ $conflicts -gt 0 ] && echo "- ⚠️  有 $conflicts 个仓库存在冲突，请检查冲突策略设置" >> results_summary.md
[ $not_found -gt 0 ] && echo "- 🔍 有 $not_found 个仓库不存在，可能已被删除或移动" >> results_summary.md
[ $already_forked -gt 0 ] && echo "- 🔄 有 $already_forked 个已fork仓库未同步，可使用'强制同步'选项更新" >> results_summary.md
if [ $renamed_count -gt 0 ]; then
  echo "- 🏷️  自动重命名了 $renamed_count 个fork，避免了名称冲突" >> results_summary.md
  echo "- 📝 重命名的仓库使用了后缀如 '-astrbot', '-fork', '-plugin' 等" >> results_summary.md
fi
echo "- 📅 建议启用定期同步保持fork最新" >> results_summary.md
echo "- 🧹 自动重命名功能可以避免大部分冲突问题" >> results_summary.md
echo "- 🔄 如果遇到失败，工作流会自动重试，提高成功率" >> results_summary.md
echo "- ⚙️  可以调整冲突策略：'rename'(自动重命名)、'skip'(跳过)、'interactive'(待处理)" >> results_summary.md

echo "✅ 结果表格生成完成"


