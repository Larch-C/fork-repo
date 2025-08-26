# AstrBot 插件 Fork/Sync 工作流

一个可批量 Fork 与同步 GitHub 仓库的工作流，支持批次处理、重试与超时保护、速率限制防护、冲突自动重命名，以及试运行模式与结果汇总报告。脚本已按 Job 分类拆分，便于维护与复用。

## 特性

- 批量处理仓库（默认每批 100 个），并行度可控（`max-parallel`）
- 支持手动触发与定时任务，支持强制同步与试运行模式
- 冲突自动处理：`rename`（自动重命名）、`skip`、`interactive`
- 对关键操作增加重试与超时，增强稳定性
- 自动生成结果表（Artifacts + Step Summary），包含统计与重命名明细
- 脚本分层：`prepare`、`create-batches`、`fork-sync`、`collect-results`、`summary`

## 快速开始

1) 准备一个 Personal Access Token，命名为仓库 Secret：`GH_PAT`
- 必须包含至少 `repo` 与 `workflow` 权限

2) 配置触发方式与输入参数
- 在 `.github/workflows/fork.yml` 中已默认开启 `workflow_dispatch` 与 `schedule`

3) 运行
- 在 Actions 页面选择该工作流，按需填写输入项并触发

## 触发与输入

工作流触发：
- 手动：`workflow_dispatch`
- 定时：`schedule`（默认每小时）

可用输入（`workflow_dispatch.inputs`）：
- `dry_run`（boolean，默认 `false`）：试运行，不执行实际 fork/sync，仅预览动作
- `force_sync`（boolean，默认 `false`）：对已 fork 的仓库强制执行同步
- `conflict_resolution`（choice，默认 `rename`）：重名冲突策略，可选 `skip` | `rename` | `interactive`

环境变量：
- `PLUGIN_JSON_URL`：包含插件列表的 JSON 地址（默认为 AstrBot 的 `plugins.json`）

Secrets：
- `GH_PAT`：GitHub Personal Access Token（需要 `repo`、`workflow` 权限）

依赖：
- 运行环境：`ubuntu-latest`
- 预装工具（Actions Runner 已内置或可用）：`gh`、`jq`、`curl`

## 目录结构（脚本分组）

```text
.github/
  scripts/
    prepare/
      fetch_plugins.sh
      parse_repo_list.sh
    create-batches/
      create_batches.sh
    fork-sync/
      setup_env.sh
      setup_gh_cli.sh
      verify_auth.sh
      batch_delay.sh
      process_batch_repos.sh
    collect-results/
      generate_results_table.sh
      display_results_summary.sh
    summary/
      final_summary.sh
```

## 工作原理（Jobs）

1) `prepare`
- 下载 `plugins.json` 并解析仓库列表，产出：
  - `steps.list.outputs.repos`：去重后的仓库数组（JSON 字符串）
  - `steps.list.outputs.total_count`：仓库总数

2) `create-batches`
- 将仓库均分为批次（默认每批 100），产出：
  - `steps.batch.outputs.batches`：批次数组（含 `batch_id` 与 `repos`）
  - `steps.batch.outputs.batch_count`：批次数量

3) `fork-sync`（矩阵并行执行）
- 对每个批次：
  - 登录 `gh`（使用 `GH_PAT`）
  - 防抖延迟（随批次递增）以降低 Rate Limit 风险
  - 遍历批次内仓库：
    - 检查原仓库存在性
    - 检查是否已有有效 fork
    - 根据输入策略执行 fork 或同步
    - 失败/超时场景做重试与错误归类
  - 生成每个仓库的 JSON 结果文件并上传为 Artifact（分批）

4) `collect-results`
- 下载所有批次的结果 JSON，生成 `results_summary.md` 并上传 Artifact，同时输出到 Step Summary

5) `summary`
- 汇总整次运行的关键指标与说明到 Step Summary

## 使用示例（手动触发）

```yaml
name: Fork/Sync Plugins

on:
  workflow_dispatch:
    inputs:
      dry_run:
        type: boolean
        default: false
      force_sync:
        type: boolean
        default: false
      conflict_resolution:
        type: choice
        default: rename
        options: [skip, rename, interactive]

jobs:
  call:
    uses: your-org/your-repo/.github/workflows/fork.yml@main
    secrets: inherit
```

> 如果想作为“可复用工作流”在其他仓库调用，建议在本工作流的 `on:` 中添加 `workflow_call:` 并为各输入定义 schema，然后如上通过 `uses:` 语法引用。

## 结果与报告

- 每个仓库生成一份 JSON 结果（包含状态、信息、时间戳、是否重命名等）
- 汇总报告 `results_summary.md` 会：
  - 以 Artifact 形式上传（名称：`fork-sync-results`）
  - 同时追加到 Step Summary，便于直接在页面查看

## 速率限制与稳定性

- 每个批次在开始前按批次编号增加延迟（`batch_id * 15s`）
- 关键 API 操作均设置超时（`timeout`）与最多 3 次重试
- 批次和仓库间穿插固定 sleep，进一步降低被限速概率
- 并发控制通过 `strategy.max-parallel` 实现

## 常见问题

1) 能否只用 `GITHUB_TOKEN` 而不用 `GH_PAT`？
- 不建议。`GITHUB_TOKEN` 是当前仓库作用域，无法在你的用户命名空间创建 fork；故使用具备 `repo` 与 `workflow` 权限的 `GH_PAT` 更可靠。

2) `plugins.json` 中的仓库地址支持哪些形式？
- 支持 `https://github.com/owner/repo[.git]`，会自动去掉 `/tree/...`、`/blob/...` 与 `.git` 后缀并做唯一化。

3) 为什么要分批？
- 降低并发、控制速率、提升成功率；同时便于在失败时部分重试与问题定位。

## 许可

本仓库遵循仓库内 `LICENSE` 文件所述协议。

