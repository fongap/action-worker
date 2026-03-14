# 🚀 Action Worker

![构建状态](https://img.shields.io/github/actions/workflow/status/fongap/action-worker/executor.yml?label=构建状态&logo=githubactions&logoColor=white&color=28a745)
![最近更新](https://img.shields.io/github/last-commit/fongap/action-worker?label=最近更新&logo=git&logoColor=white&color=007acc)
![核心语言](https://img.shields.io/github/languages/top/fongap/action-worker?label=核心语言&logo=github&logoColor=white&color=6f42c1&cacheSeconds=0)
![数据规模](https://img.shields.io/github/repo-size/fongap/action-worker?label=数据规模&logo=databricks&logoColor=white&color=4682b4)
![开源许可](https://img.shields.io/badge/开源许可-MIT%20License-d97706?logo=opensourceinitiative&logoColor=white)


**Action Worker** 是一个基于 GitHub Actions 构建的 CI/CD 执行中心。它遵循**算力与资产分离**原则，仅作为执行载体，不承载业务逻辑。

## 🎯 核心定位

在现代平台工程实践中，本项目扮演 **执行调度层** 的角色：

-   **解耦执行**：本仓库不存储任何业务代码，仅负责环境初始化与任务路由。
-   **动态拉取**：核心构建逻辑与资源在运行时从加密的“资产仓库”动态挂载。
-   **无痕运行**：工作流执行结束后，计算环境立即销毁，不留存任何持久化数据。

---

## 🏗 架构设计

本项目将 CI/CD 流程分为两个维度：

| 维度 | 角色 | 职能 |
| :--- | :--- | :--- |
| **算力层** | **本仓库** | 运行环境准备、安全策略校验、Task 调度引擎。 |
| **资产层** | **源仓库** | 业务源码、核心配置、原子脚本、任务清单等。 |

---

## 🔒 安全机制 (Security Hardening)

1. **零硬编码**：源仓库地址与工作目录均通过 GitHub Secrets 动态注入，对本仓库完全隐身。
2. **安全机制**：严校传入的 Payload 路径，禁止 `../` 目录穿越，强制限定只读特定前缀的目录。
3. **静默执行**：全局禁用 `set -x` 调试输出模式，防止 Token 或敏感环境变量在 Logs 中意外泄露。

---

## ⚙️ 运行逻辑

Action Worker 按照以下生命周期执行任务

1. ​**事件监听**​：接收类型为 `project_trigger` 的调度事件，通过 `repository_dispatch` 接口激活自动化流水线。
2. ​**载荷解析**​：提取 `client_payload` 中的路径信息，校验并锁定 `project_path` 以确定本次任务的执行目标。
3. ​**资产挂载**​：利用私密凭证动态克隆资产仓库，将其检出至本地脱敏目录，完成“计算”与“数据”的即时组装。
4. ​**指令路由**​：检索目标项目内的 `task.json` 配置文件，精确解析并生成本次构建流程所需的原子化任务执行清单。
5. ​**原子执行**​：按序调用资产仓库内的 `.scripts/` 脚本，在受控的静默环境下完成最终的代码构建、测试与部署任务。

---

## 🛠 配置要求

### GitHub Secrets 注入
为保证工作流正常运行，请在仓库设置中配置以下 Secrets：

| Secret 名称 | 说明 |
| :--- | :--- |
| `SOURCE_VAULT_PAT` | 具备访问私有资产仓库权限的 Personal Access Token。 |
| `SOURCE_VAULT_REPO` | 资产仓库的完整路径 (例如 `org/private-vault`)。 |
| `VAULT_DIR_NAME` | 运行时本地脱敏目录的伪装名称。 |

> [!TIP]
> 部分原子脚本可能需要额外的运行时参数（如云服务凭证），建议同样通过本仓库的 Secrets 集中管理。

---

## 🚀 触发示例 (Dispatch Trigger)

可以通过以下 API 调用来触发 Worker 执行：

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_PAT" \
  [https://api.github.com/repos/](https://api.github.com/repos/){owner}/{repo}/dispatches \
  -d '{
    "event_type": "project_trigger",
    "client_payload": {
      "project_path": "Project-Awesome-App"
    }
  }'
