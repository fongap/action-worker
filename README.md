# Action Worker

轻量级 GitHub Actions 任务执行入口。仅负责任务调度、参数校验、执行入口拉取与启动，不承载业务逻辑。

## 核心定位

```
repository_dispatch
        │
        ▼
参数校验
        │
        ▼
项目校验
        │
        ▼
获取执行脚本
        │
        ▼
执行任务
        │
        ▼
返回结果
```

业务逻辑、构建逻辑、项目配置继续留在私有执行仓。

## 架构边界

| 层级 | 仓库 | 职责 |
|------|------|------|
| 公开执行层 | `action-worker` | 接收任务、参数校验、项目白名单、Runner 调度、拉取 bootstrap.sh、启动任务、返回结果 |
| 私有执行层 | 私有仓库 | 环境检测、项目配置、依赖安装、构建、发布、同步、清理 |

## 触发方式

```json
{
  "event_type": "run-task",
  "client_payload": {
    "project": "FongapBlog",
    "bootstrap_ref": "40位Git提交SHA或显式tag/ref"
  }
}
```

- `project`：项目目录名（需在白名单内）
- `bootstrap_ref`：私有仓中 `bootstrap.sh` 的版本引用。生产环境**强烈建议**使用完整 40 位 Commit SHA；兼容显式 tag/ref；未提供时默认 `main`

## 所需 Secrets

| Secret | 用途 |
|--------|------|
| `GH_SOURCE_REPO_PRIMARY` | 私有执行仓地址（如 `owner/repo`） |
| `GH_SOURCE_REPO_PAT_PRIMARY` | 访问私有执行仓的 PAT（需 `repo` 读取权限） |

> 项目运行所需的额外凭证由 GitHub Actions Secrets 管理，并按任务最小化提供。Action Worker 不再全量注入 `secrets`。

## 安全机制

- **最小权限**：Workflow 顶层 `permissions: {}`，仅显式注入执行所需的两个 PAT
- **无全量 Secret 注入**：移除 `toJSON(secrets)`，单个项目泄露 ≠ 全部 Secret 泄露
- **参数校验**：`project` 与 `bootstrap_ref` 双重校验（格式 + 白名单）
- **固定版本执行**：支持并推荐 40 位 Commit SHA，避免 `@main` 漂移
- **安全下载**：下载脚本至临时文件、校验 HTTP 状态、执行后自动清理，禁止 `curl \| bash`
- **固定 Runner**：`ubuntu-24.04` 避免环境漂移
- **并发控制**：同一项目顺序执行，不同项目可并行

## 执行流程

1. 接收 `repository_dispatch` 事件
2. 格式校验 `project` 与 `bootstrap_ref`（仅允许 `[a-zA-Z0-9_.-]+`）
3. 业务白名单校验 `project`
4. 从私有仓下载 `bootstrap.sh@${bootstrap_ref}`
5. 执行 `bash bootstrap.sh "${project}"`
6. 输出任务信息与结果摘要

## 本地验收测试

| Case | 输入 | 预期 |
|------|------|------|
| 正常 | 合法 project + 合法 bootstrap_ref | 成功执行，exit 0 |
| 非法 project | `../../xxx` | 参数阶段拒绝 |
| 非法 ref | `main;curl...` | 参数阶段拒绝 |
| bootstrap 不存在 | 不存在的 ref | curl 失败，Workflow failure |
| bootstrap 失败 | 脚本 `exit 1` | Workflow failure |
| 项目不在白名单 | 未知 project | 明确失败 |

## 许可证

MIT License