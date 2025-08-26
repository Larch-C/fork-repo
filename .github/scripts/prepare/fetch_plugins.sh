#!/usr/bin/env bash
set -e

echo "📥 正在获取 plugins.json..."
curl -fsSL "${PLUGIN_JSON_URL}" -o plugins.json
echo "✅ plugins.json 获取完成"


