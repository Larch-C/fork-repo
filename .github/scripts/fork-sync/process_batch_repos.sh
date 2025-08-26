#!/usr/bin/env bash
set -e

echo "🔄 开始处理批次 ${BATCH_ID} 的仓库..."

mkdir -p results

CONFLICT_STRATEGY="${CONFLICT_STRATEGY:-rename}"
echo "🎯 冲突解决策略: ${CONFLICT_STRATEGY}"

repos_json="${REPOS_JSON}"

set +e

processed=0
total_in_batch=$(echo "$repos_json" | jq -r 'length')

find_available_name() {
  local base_name="$1"
  local my_login="$2"
  local suffix_counter=1
  local candidate_name

  local naming_strategies=(
    "${base_name}-astrbot"
    "${base_name}-fork"
    "${base_name}-plugin"
    "astrbot-${base_name}"
  )

  for strategy in "${naming_strategies[@]}"; do
    if ! timeout 20 gh repo view "${my_login}/${strategy}" >/dev/null 2>&1; then
      echo "$strategy"
      return 0
    fi
  done

  while true; do
    candidate_name="${base_name}-astrbot-${suffix_counter}"
    if ! timeout 20 gh repo view "${my_login}/${candidate_name}" >/dev/null 2>&1; then
      echo "$candidate_name"
      return 0
    fi
    suffix_counter=$((suffix_counter + 1))
    if [ $suffix_counter -gt 100 ]; then
      echo "${base_name}-$(date +%s)"
      return 0
    fi
  done
}

echo "$repos_json" | jq -r '.[]' | while read -r repo_url; do
  processed=$((processed + 1))
  echo "📦 处理仓库 ($processed/$total_in_batch): $repo_url"

  error_occurred=false
  status="unknown"
  message="处理中..."
  final_fork_name=""
  renamed=false

  owner_repo=${repo_url#*github.com/}
  owner_repo=${owner_repo%/}
  owner=$(echo "$owner_repo" | cut -d/ -f1)
  repo=$(echo "$owner_repo" | cut -d/ -f2)

  retry_count=0
  max_retries=3

  while [ $retry_count -lt $max_retries ]; do
    echo "🔄 尝试 $((retry_count + 1))/$max_retries: $owner_repo"

    if timeout 30 gh repo view "$owner_repo" --json name >/dev/null 2>&1; then
      echo "✅ 原始仓库存在: $owner_repo"
      break
    else
      if [ $retry_count -eq $((max_retries - 1)) ]; then
        echo "❌ 原始仓库不存在或无法访问: $owner_repo"
        status="not_found"
        message="原始仓库不存在或无法访问"
        error_occurred=true
      else
        echo "⏳ 重试中..."
        sleep 5
      fi
      retry_count=$((retry_count + 1))
    fi
  done

  if [ "$error_occurred" = "true" ]; then
    jq -n \
      --arg repo "$owner_repo" \
      --arg owner "$owner" \
      --arg repo_name "$repo" \
      --arg status "$status" \
      --arg message "$message" \
      --arg my_fork "unknown/$repo" \
      --arg final_name "$repo" \
      --argjson renamed false \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        repo: $repo,
        owner: $owner,
        repo_name: $repo_name,
        status: $status,
        message: $message,
        my_fork: $my_fork,
        final_fork_name: $final_name,
        renamed: $renamed,
        timestamp: $timestamp
      }' > "results/${owner}_${repo}.json"

    sleep 2
    continue
  fi

  my_login=""
  retry_count=0
  while [ $retry_count -lt $max_retries ] && [ -z "$my_login" ]; do
    my_login=$(timeout 15 gh api user --jq .login 2>/dev/null || echo "")
    if [ -z "$my_login" ]; then
      echo "⏳ 获取用户信息重试中..."
      sleep 3
      retry_count=$((retry_count + 1))
    fi
  done

  if [ -z "$my_login" ]; then
    echo "❌ 无法获取用户信息: $owner_repo"
    status="auth_failed"
    message="无法获取用户信息"

    jq -n \
      --arg repo "$owner_repo" \
      --arg owner "$owner" \
      --arg repo_name "$repo" \
      --arg status "$status" \
      --arg message "$message" \
      --arg my_fork "unknown/$repo" \
      --arg final_name "$repo" \
      --argjson renamed false \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        repo: $repo,
        owner: $owner,
        repo_name: $repo_name,
        status: $status,
        message: $message,
        my_fork: $my_fork,
        final_fork_name: $final_name,
        renamed: $renamed,
        timestamp: $timestamp
      }' > "results/${owner}_${repo}.json"

    sleep 2
    continue
  fi

  my_fork="${my_login}/$repo"
  final_fork_name="$repo"

  fork_exists=false
  fork_status="unknown"

  repo_check_result=""
  retry_count=0
  while [ $retry_count -lt $max_retries ]; do
    repo_check_result=$(timeout 30 gh repo view "$my_fork" --json name,parent,isFork,nameWithOwner 2>/dev/null || echo "ERROR")
    if [ "$repo_check_result" != "ERROR" ] && [ -n "$repo_check_result" ]; then
      break
    else
      echo "⏳ 检查fork状态重试中..."
      sleep 3
      retry_count=$((retry_count + 1))
    fi
  done

  if [ "$repo_check_result" != "ERROR" ] && [ -n "$repo_check_result" ]; then
    is_fork=$(echo "$repo_check_result" | jq -r '.isFork // false' 2>/dev/null || echo "false")
    parent_name=$(echo "$repo_check_result" | jq -r '.parent.nameWithOwner // empty' 2>/dev/null || echo "")

    echo "🔍 检查fork状态: is_fork=$is_fork, parent=$parent_name"

    if [ "$is_fork" = "true" ]; then
      if [ -n "$parent_name" ] && [ "$parent_name" = "$owner_repo" ]; then
        fork_exists=true
        fork_status="valid_fork"
        echo "✅ 已fork且parent匹配: $my_fork <- $owner_repo"
      elif [ -n "$parent_name" ]; then
        fork_exists=false
        fork_status="wrong_parent"
        echo "⚠️  已fork但parent不匹配: $my_fork (parent: $parent_name, expected: $owner_repo)"
      else
        echo "🔍 Fork无parent信息，尝试API检查..."

        api_info=""
        retry_count=0
        while [ $retry_count -lt $max_retries ]; do
          api_info=$(timeout 20 gh api repos/"$my_fork" --jq '{fork: .fork, parent: .parent.full_name}' 2>/dev/null || echo "ERROR")
          if [ "$api_info" != "ERROR" ]; then
            break
          else
            echo "⏳ API检查重试中..."
            sleep 3
            retry_count=$((retry_count + 1))
          fi
        done

        if [ "$api_info" != "ERROR" ]; then
          api_parent=$(echo "$api_info" | jq -r '.parent // empty' 2>/dev/null || echo "")
          if [ -n "$api_parent" ] && [ "$api_parent" = "$owner_repo" ]; then
            fork_exists=true
            fork_status="valid_fork_api"
            echo "✅ API确认为正确的fork: $my_fork <- $api_parent"
          else
            fork_exists=false
            fork_status="invalid_fork"
            echo "❌ API检查无法确认为有效fork"
          fi
        else
          fork_exists=false
          fork_status="api_check_failed"
          echo "❌ API检查失败"
        fi
      fi
    else
      fork_exists=false
      fork_status="independent_repo"
      echo "⚠️  仓库 $my_fork 存在但不是fork (独立仓库)"
    fi
  else
    fork_exists=false
    fork_status="not_exists"
    echo "🆕 尚未fork: $owner_repo"
  fi

  if [ "${DRY_RUN}" = "true" ]; then
    if [ "$fork_exists" = "false" ]; then
      if [ "$fork_status" = "wrong_parent" ] || [ "$fork_status" = "independent_repo" ]; then
        case "$CONFLICT_STRATEGY" in
          rename)
            available_name=$(find_available_name "$repo" "$my_login")
            final_fork_name="$available_name"
            renamed=true
            status="will_fork_renamed"
            message="将会fork为: $available_name"
            ;;
          skip)
            status="conflict_detected"
            message="检测到同名仓库冲突，将跳过"
            ;;
          interactive)
            status="conflict_pending"
            message="检测到冲突，待手动处理"
            ;;
        esac
      else
        status="will_fork"
        message="将会fork"
      fi
    else
      status="will_sync"
      message="已fork，需要时会同步"
    fi
  elif [ "$fork_exists" = "false" ]; then
    if [ "$fork_status" = "wrong_parent" ] || [ "$fork_status" = "independent_repo" ]; then
      case "$CONFLICT_STRATEGY" in
        rename)
          echo "🏷️  检测到重名冲突，启用自动重命名..."
          available_name=$(find_available_name "$repo" "$my_login")
          echo "🎯 找到可用名称: $available_name"
          fork_output=""
          fork_exit_code=1
          retry_count=0
          while [ $retry_count -lt $max_retries ] && [ $fork_exit_code -ne 0 ]; do
            echo "🔄 重命名Fork尝试 $((retry_count + 1))/$max_retries"
            fork_output=$(timeout 60 gh repo fork "$owner_repo" --repo-name "$available_name" --clone=false 2>&1)
            fork_exit_code=$?
            if [ $fork_exit_code -eq 0 ]; then
              echo "✅ 重命名Fork成功: $owner_repo -> ${my_login}/${available_name}"
              status="forked_renamed"
              message="重命名fork成功: $available_name"
              final_fork_name="$available_name"
              my_fork="${my_login}/${available_name}"
              renamed=true
              break
            else
              if echo "$fork_output" | grep -q "already exists"; then
                echo "⚠️  名称 $available_name 仍然冲突，寻找新名称..."
                available_name=$(find_available_name "$repo" "$my_login")
                echo "🎯 重新找到可用名称: $available_name"
              else
                if [ $retry_count -eq $((max_retries - 1)) ]; then
                  echo "❌ 重命名Fork失败: $owner_repo"
                  echo "错误输出: $fork_output"
                  status="fork_rename_failed"
                  message="重命名fork失败: $(echo "$fork_output" | head -1 | cut -c1-50)"
                else
                  echo "⏳ 重命名Fork重试中..."
                  sleep 5
                fi
                retry_count=$((retry_count + 1))
              fi
            fi
          done
          ;;
        skip)
          echo "⚠️  跳过fork，存在同名仓库: $my_fork"
          status="skipped_conflict"
          message="跳过：存在同名仓库冲突"
          ;;
        interactive)
          echo "🤔 记录冲突待手动处理: $my_fork"
          status="conflict_pending"
          message="冲突待手动处理：存在同名仓库"
          ;;
      esac
    else
      echo "🍴 正在fork: $owner_repo"
      fork_output=""
      fork_exit_code=1
      retry_count=0
      while [ $retry_count -lt $max_retries ] && [ $fork_exit_code -ne 0 ]; do
        echo "🔄 Fork尝试 $((retry_count + 1))/$max_retries"
        fork_output=$(timeout 60 gh repo fork "$owner_repo" --clone=false 2>&1)
        fork_exit_code=$?
        if [ $fork_exit_code -eq 0 ]; then
          echo "✅ Fork成功: $owner_repo"
          status="forked"
          message="新fork成功"
          break
        else
          if echo "$fork_output" | grep -q "already exists"; then
            echo "ℹ️  Fork已存在，检查状态: $my_fork"
            status="already_forked"
            message="Fork已存在"
            fork_exists=true
            break
          else
            if [ $retry_count -eq $((max_retries - 1)) ]; then
              echo "❌ Fork失败: $owner_repo"
              echo "错误输出: $fork_output"
              status="fork_failed"
              message="Fork失败: $(echo "$fork_output" | head -1 | cut -c1-50)"
            else
              echo "⏳ Fork重试中..."
              sleep 5
            fi
            retry_count=$((retry_count + 1))
          fi
        fi
      done
    fi
  else
    echo "🔄 正在同步fork: $my_fork"
    sync_needed=false
    if [ "${FORCE_SYNC}" = "true" ] || [ "${GITHUB_EVENT_NAME}" = "schedule" ]; then
      sync_needed=true
      echo "🔄 强制同步模式"
    fi
    if [ "$sync_needed" = true ]; then
      sync_output=""
      sync_exit_code=1
      retry_count=0
      while [ $retry_count -lt $max_retries ] && [ $sync_exit_code -ne 0 ]; do
        echo "🔄 同步尝试 $((retry_count + 1))/$max_retries"
        sync_output=$(timeout 120 gh repo sync "$my_fork" --source "$owner_repo" 2>&1)
        sync_exit_code=$?
        if [ $sync_exit_code -eq 0 ]; then
          echo "✅ 同步成功: $my_fork"
          status="synced"
          message="同步成功"
          break
        else
          if echo "$sync_output" | grep -q "up to date\|already up-to-date"; then
            echo "ℹ️  已是最新: $my_fork"
            status="up_to_date"
            message="已是最新版本"
            break
          else
            if [ $retry_count -eq $((max_retries - 1)) ]; then
              echo "⚠️  同步失败: $my_fork"
              echo "错误输出: $sync_output"
              status="sync_failed"
              message="同步失败: $(echo "$sync_output" | head -1 | cut -c1-50)"
            else
              echo "⏳ 同步重试中..."
              sleep 10
            fi
            retry_count=$((retry_count + 1))
          fi
        fi
      done
    else
      echo "🔍 检查是否需要同步..."
      if timeout 60 gh repo sync "$my_fork" --source "$owner_repo" 2>/dev/null; then
        echo "✅ 同步成功: $my_fork"
        status="synced"
        message="自动同步成功"
      else
        echo "ℹ️  无需同步或同步失败: $my_fork"
        status="up_to_date"
        message="已是最新或无需同步"
      fi
    fi
  fi

  mkdir -p results
  jq -n \
    --arg repo "$owner_repo" \
    --arg owner "$owner" \
    --arg repo_name "$repo" \
    --arg status "$status" \
    --arg message "$message" \
    --arg my_fork "$my_fork" \
    --arg final_name "$final_fork_name" \
    --argjson renamed "$renamed" \
    --arg fork_status "$fork_status" \
    --arg conflict_strategy "$CONFLICT_STRATEGY" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      repo: $repo,
      owner: $owner,
      repo_name: $repo_name,
      status: $status,
      message: $message,
      my_fork: $my_fork,
      final_fork_name: $final_name,
      renamed: $renamed,
      fork_status: $fork_status,
      conflict_strategy: $conflict_strategy,
      timestamp: $timestamp
    }' > "results/${owner}_${repo}.json" 2>/dev/null || {
      echo "⚠️  保存结果文件失败: ${owner}_${repo}.json"
    }

  echo "⏱️  等待 5 秒..."
  sleep 5
done

echo "✅ 批次 ${BATCH_ID} 处理完成"

set -e


