<div align="center">

# Action Worker

[![Worker CI](https://github.com/fongap/action-worker/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/fongap/action-worker/actions/workflows/ci.yml)
[![Task Handler](https://github.com/fongap/action-worker/actions/workflows/task-handler.yml/badge.svg?event=repository_dispatch)](https://github.com/fongap/action-worker/actions/workflows/task-handler.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

Action Worker 是一个轻量、公开的 CI/CD 执行中继：接收 `repository_dispatch` 请求，校验协议，获取固定版本的 `bootstrap.sh`，再把具体项目执行交给下游执行仓。

它不维护项目白名单、不包含业务构建逻辑，也不应知道任何项目级 Secret 键名。

## 执行链

```text
调用方
  ↓ repository_dispatch: run-task
Action Worker
  ↓ validate-payload.sh
GitHub Runner
  ↓ 获取 bootstrap_ref 对应的 bootstrap.sh
执行仓 bootstrap
  ↓
项目检出 / 构建 / 发布 / 同步
```

Action Worker 只负责四件事：

1. 校验 `client_payload`；
2. 将同一 `project` 的任务串行化；
3. 从 `GH_EXECUTION_REPO` 获取指定 commit SHA 的 `bootstrap.sh`；
4. 把 GitHub Secrets 作为通用执行环境交给 bootstrap，由执行仓决定当前项目实际允许使用哪些 Secret。

## 请求协议

`event_type` 固定为 `run-task`，`client_payload` 只允许以下字段：

| 字段 | 约束 |
|---|---|
| `schema_version` | 必填字符串；当前仅支持 `"1"` |
| `request_id` | `^[A-Za-z0-9_.-]{1,128}$` |
| `project` | 以字母或数字开头，最长 64 字符 |
| `bootstrap_ref` | 完整 40 位十六进制 Commit SHA |

缺失字段、错误类型、空值、未知字段或不支持的协议版本均在 Validate 阶段拒绝。

示例：

```bash
curl -X POST \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/fongap/action-worker/dispatches \
  -d '{
    "event_type": "run-task",
    "client_payload": {
      "schema_version": "1",
      "request_id": "20260910-001",
      "project": "my-project",
      "bootstrap_ref": "<40 位 commit SHA>"
    }
  }'
```

## 配置

| 名称 | 类型 | 用途 |
|---|---|---|
| `GH_EXECUTION_REPO` | Variable | 执行仓，格式 `owner/repo` |
| `GH_EXECUTION_REPO_PAT` | Secret | 读取执行仓固定 SHA 下的 `bootstrap.sh` |

## Secret 边界

Action Worker 的核心约束是：**知道 Secret 环境，不知道业务 Secret 语义。**

- workflow 不枚举任何业务 Secret 键名；
- 禁止 `${{ secrets.<name> }}` 形式的项目级命名引用；
- 禁止 `toJSON(secrets)`；
- Execute 阶段仅使用通用 `env: ${{ secrets }}` 注入；
- 基础环境快照只记录变量名，不记录值；
- dispatch payload 不包含 Secret、task 内容或业务配置；
- Secret 的项目级筛选、mask、清理和实际使用由执行仓负责。

`GH_EXECUTION_REPO_PAT` 只用于获取固定版本的执行入口。bootstrap 执行结束后，Runner 临时脚本和基础环境快照都会清理。

## 执行保证

- `bootstrap_ref` 必须是完整 Commit SHA，不接受分支名；
- 下载失败区分网络错误、鉴权失败、文件不存在和 GitHub 上游异常；
- 下载后的 `bootstrap.sh` 必须非空并通过 `bash -n`；
- 同一 `project` 使用 `concurrency` 串行执行，且不取消进行中的任务；
- bootstrap 的真实退出码原样作为 Task Handler 结果返回。

## 仓库结构

```text
.github/workflows/
  ci.yml
  task-handler.yml
scripts/
  validate-payload.sh
tests/
  test-payload-validation.sh
  test-secret-env.sh
```

当前协议和安全边界以 workflow、校验脚本和测试为准，README 不维护运行状态。

## License

[MIT](LICENSE)
