#!/usr/bin/env bash
set -e

batch_id="${BATCH_ID:-0}"
if [ "$batch_id" -ne 0 ]; then
  delay_seconds=$(( batch_id * 15 ))
  echo "⏱️  批次 ${batch_id} 延迟 ${delay_seconds} 秒..."
  sleep "$delay_seconds"
fi


