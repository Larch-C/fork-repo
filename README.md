# 🚀 Fork / Sync All AstrBot Plugins

本工作流用于自动 **Fork** 或 **同步** [AstrBot 插件仓库](https://github.com/AstrBotDevs/AstrBot_Plugins_Collection)中列出的所有插件仓库。支持手动触发或每小时自动运行，确保所有插件仓库与你的 GitHub 帐号保持同步。

## ✨ 功能简介

* 🔍 从 [`plugins.json`](https://raw.githubusercontent.com/AstrBotDevs/AstrBot_Plugins_Collection/main/plugins.json) 中提取插件仓库列表
* 🍴 自动 Fork 尚未 Fork 的插件仓库
* 🔄 自动同步已有的 Fork 仓库（支持强制同步）
* 📦 仓库按批次分组处理，避免 API 限速或矩阵限制
* 📝 生成详细同步报告，支持 artifact 下载及步骤摘要查看
* 🧪 支持 `dry_run` 试运行模式，仅展示将执行的操作不实际执行

## ⏱️ 触发方式

```yaml
on:
  workflow_dispatch: # 手动触发
  schedule:           # 每小时 UTC 自动同步（北京时间 +8 即每小时的 08 分执行）
    - cron: "0 * * * *"
```

## 🧰 输入参数（Workflow Dispatch）

| 参数名          | 类型      | 默认值   | 说明                        |
| ------------ | ------- | ----- | ------------------------- |
| `dry_run`    | boolean | false | 开启试运行模式，仅展示将执行的操作         |
| `force_sync` | boolean | false | 强制同步所有 Fork 仓库（跳过是否有更新判断） |

## 🔐 必需的 Secret

| 名称       | 说明                                                                   |
| -------- | -------------------------------------------------------------------- |
| `GH_PAT` | 一个拥有 `repo` 和 `workflow` 权限的 GitHub Personal Access Token。用于操作仓库及同步。 |

## 📦 工作流程详解

### 1. `prepare`：准备阶段

* 下载并解析 `plugins.json`
* 提取插件仓库 URL 列表
* 输出总仓库数量和 JSON 格式的仓库数组

### 2. `create-batches`：生成批次

* 将仓库按 50 个为一组分成多个批次，便于并发控制和 API 限流保护

### 3. `fork-sync`：执行 Fork 或同步操作

* 使用 GitHub CLI 登录（基于 `GH_PAT`）
* 支持并发处理批次（默认最大3个并行）
* 每个仓库：

  * 检查是否已 Fork、是否为正确上游
  * 若未 Fork，则 Fork 到当前用户
  * 若已 Fork，则根据条件判断是否需要同步
  * 支持 `dry_run` 模式与 `force_sync` 强制同步

### 4. `collect-results`：收集并生成结果

* 汇总所有批次结果 JSON
* 生成 Markdown 格式的汇总报告（仓库状态、链接、操作说明等）
* 上传为 Artifact 并显示在 step summary

### 5. `summary`：最终摘要

* 输出关键统计数据和总结建议

## 📊 输出报告样例

在每次运行后，将生成如下内容：

* 📋 每个仓库的处理状态（如 `已Fork`、`已同步`、`Fork失败` 等）
* 🔗 原始仓库和用户Fork链接
* ⏱️ 操作时间戳
* 📈 汇总统计表（百分比展示）
* 💾 报告文件 `fork-sync-results` 可在 Action artifacts 中下载

## 💡 使用建议

* ✅ 推荐设置定时任务，确保仓库持续同步最新版本
* 🧪 手动触发时，建议先使用 `dry_run: true` 进行预览
* 🛠 若发现操作失败或仓库不存在，请检查是否已删除或权限受限
* 🔄 若 Fork 后未自动同步，可启用 `force_sync: true` 强制覆盖

## 🧷 示例：手动触发 Workflow

```yaml
inputs:
  dry_run: true
  force_sync: false
```

点击 GitHub 页面右上角的 **"Run workflow"** 按钮，填写参数后运行即可。

## 📎 插件来源说明

所有插件仓库由 AstrBot 官方在以下地址集中管理：

```
https://github.com/AstrBotDevs/AstrBot_Plugins_Collection/blob/main/plugins.json
```

---

## 🧠 灵感来源

此项目旨在解决：

* 有些插件跑路的问题，故用此账号作为备份

## 🛠️ 目前的问题

- fork 后的仓库无法同步 (解决了喵～)
- action 运行到后面后，有些仓库 fork 失败
- 存在 github API 限制
