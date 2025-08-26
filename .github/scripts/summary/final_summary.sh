#!/usr/bin/env bash
set -e

{
  echo "# 🎯 AstrBot插件Fork/Sync操作完成"
  echo ""
  echo "📊 **基本信息:**"
  echo "- 总仓库数: ${TOTAL_COUNT}"
  echo "- 批次数量: ${BATCH_COUNT}"
  if [ "${DRY_RUN}" = "true" ]; then
    echo "- 操作模式: 🔍 试运行"
  else
    echo "- 操作模式: ▶️ 实际执行"
  fi
  if [ "${FORCE_SYNC}" = "true" ]; then
    echo "- 强制同步: ✅ 是"
  else
    echo "- 强制同步: ❌ 否"
  fi
  echo "- 冲突策略: ${CONFLICT_STRATEGY}"
  echo ""
  echo "🔧 **任务状态:**"
  echo "- 准备阶段: ${PREPARE_RESULT}"
  echo "- 批次创建: ${CREATE_BATCHES_RESULT}"
  echo "- Fork/Sync: ${FORK_SYNC_RESULT}"
  echo "- 结果收集: ${COLLECT_RESULTS_RESULT}"
  echo ""
  if [ "${COLLECT_RESULTS_RESULT}" = "success" ]; then
    echo "✅ **详细结果表格已生成！**"
    echo ""
    echo "📋 请查看上方的 \`collect-results\` 步骤获取完整的结果表格。"
    echo ""
    echo "💾 **结果文件:**"
    echo "- 可在 Artifacts 中下载 \`fork-sync-results\` 文件查看详细报告"
    echo "- 包含所有仓库的fork状态、重命名信息、链接和时间戳"
  else
    echo "⚠️  **结果收集状态异常**"
    echo "- 操作状态: ${FORK_SYNC_RESULT}"
    echo "- 结果收集: ${COLLECT_RESULTS_RESULT}"
    echo ""
    echo "🔍 **可能的原因:**"
    echo "- 网络超时或API限制"
    echo "- 某些仓库访问权限问题"
    echo "- GitHub API临时不可用"
  fi
  echo ""
  echo "🆕 **新增自动重命名功能:**"
  echo "- ✅ 智能检测重名冲突并自动重命名fork"
  echo "- ✅ 多种命名策略：'-astrbot', '-fork', '-plugin', 'astrbot-' 前缀"
  echo "- ✅ 数字后缀备选方案，确保找到可用名称"
  echo "- ✅ 完整的重命名记录和统计信息"
  echo "- ✅ 支持试运行模式预览重命名结果"
  echo ""
  echo "🔄 **改进特性:**"
  echo "- ✅ 增加了重试机制（每个操作最多重试3次）"
  echo "- ✅ 添加了超时保护，避免长时间阻塞"
  echo "- ✅ 改进了错误处理，单个仓库失败不影响整批"
  echo "- ✅ 减少了批次大小和并发数，降低API压力"
  echo "- ✅ 增加了延迟时间，更好地避免rate limit"
  echo ""
  echo "🔄 **冲突策略说明:**"
  echo "- 🏷️  **rename**: 自动重命名冲突的fork（推荐）"
  echo "- ⏭️  **skip**: 跳过冲突的仓库"
  echo "- 🤔 **interactive**: 记录冲突待手动处理"
  echo ""
  echo "💡 **使用建议:**"
  echo "- 首次运行建议使用试运行模式预览结果"
  echo "- 推荐使用 'rename' 策略自动处理冲突"
  echo "- 定期运行以保持fork同步最新"
  echo "- 检查重命名的仓库，确保符合预期"
} >> "$GITHUB_STEP_SUMMARY"


