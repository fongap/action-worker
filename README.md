# 🚀 Action Worker

![构建状态](https://img.shields.io/github/actions/workflow/status/fongap/action-worker/badge-updater.yml?label=构建状态&logo=githubactions&logoColor=white&color=28a745)
![最近更新](https://img.shields.io/badge/最近更新-2026--04--21-007acc?logo=git&logoColor=white&color=007acc)
![核心语言](https://img.shields.io/badge/核心语言-YAML-6f42c1?logo=github&logoColor=white&color=6f42c1)
![数据规模](https://img.shields.io/github/repo-size/fongap/action-worker?label=数据规模&logo=databricks&logoColor=white&color=4682b4)
![开源许可](https://img.shields.io/badge/开源许可-MIT%20License-d97706?logo=opensourceinitiative&logoColor=white)


**Action Worker** 是一个基于 GitHub Actions 构建的 CI/CD 执行中心，遵循 **算力与资产分离** 的原则。它作为执行载体，仅负责任务调度和运行，不承载任何业务逻辑。


## 🏗️ 核心架构

本仓库采用「监听 + 执行」模式，通过两个核心处理器响应外部调度指令：

| 工作流文件                  | 触发机制                              | 功能职责                                                                 |
|-----------------------------|---------------------------------------|--------------------------------------------------------------------------|
| `task-handler.yml`          | ` [run-task]`                | **任务执行调度器**：拉取配置、检测环境、执行任务、同步结果、清理 Vault。 |

## ⚙️ 执行流程

所有任务均遵循标准化的五步执行序列，确保环境一致性与操作可追溯：

1. **配置加载**：通过 Sparse Checkout 稀疏检出外部 Vault，合并默认与项目配置。
2. **环境检测**：自动识别运行时栈（Node / Python / Go），按需触发环境初始化。
3. **任务编排**：解析 `task.json` 定义执行步骤，支持 Node 专用缓存 Restore 加速。
4. **结果同步**：根据配置可选执行 Sync & Push 操作，将产出物同步至目标分支。
5. **安全清理**：任务结束后强制 Purge Vault，执行 realpath 校验，杜绝路径风险。

## 🛡️ 安全机制

基于「逻辑隔离」与「最小权限」原则，构建多层防御体系以保障执行安全：

* **逻辑隔离**：业务逻辑与敏感配置存于私密库，本仓公开透明，仅保留执行流程。
* **最小权限**：配置获取采用稀疏检出技术，最小化文件访问范围，降低泄露风险。
* **路径防护**：清理阶段强制进行 realpath 真实路径校验，确保所有操作均在安全域。
* **密钥管理**：所有敏感信息均通过 GitHub Secrets 动态注入，严禁硬编码于工作流中。

## 🔑 变量清单

| 类型 | 变量名 | 用途 | 权限要求 |
|------|--------|------|----------|
| **机密变量** | `GH_SOURCE_REPO_PAT` | 源码仓库访问令牌 | `repo` 读取权限 |
| **机密变量** | `GH_TARGET_REPO_PAT` | 目标仓库推送令牌 | `repo` 写入权限 |

> 💡 **使用提示**：
> 
> 部分任务脚本可能需要额外的运行时参数（如云服务凭证），同样需通过本仓库的 `secrets and variables` 集中管理。
<!-- LAST_SYNC: 2026-04-21 16:55:46 -->
