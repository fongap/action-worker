# ⚙️ Action Worker | 自动化全能工坊

这是整个系统的**控制面 (Control Plane)**。它是一个纯粹的算力壳，负责执行来自“源码仓库”的指令。

## 🧠 运行机制：模块化调度

本工坊不持有任何业务逻辑，它只是一组**原子化能力 (Atomic Capabilities)** 的集合。

1. **入口 (Router)**：`processor.yml` 接收到 Webhook 信号。
2. **编排 (Orchestrator)**：根据信号中的 `tasks` 数组，利用 GitHub Actions 的 `needs` 逻辑并行或串行调度子任务。
3. **执行 (Execution)**：调用对应的 `tmpl-*.yml` 模块，执行具体的构建、部署或同步操作。

## 🛠️ 原子模块注册表


| **模块 ID**           | **文件路径**              | **核心职能描述**                                      |  |  |  |
| ----------------------------- | --------------------------------- | ------------------------------------------------------------- | -- | -- | -- |
| **`hugo-build`**       | `tmpl-hugo-build.yml`       | 执行环境自动化编排、站点核心编译及构建产物 (Artifacts) 归档 |
| **`hugo-deploy`**      | `tmpl-hugo-deploy.yml`      | 站点发布至 Cloudflare Pages 与部署版本生命周期管理          |
| **`algolia-sync`**     | `tmpl-algolia-sync.yml`     | 内容差异化特征分析与 Algolia 全球索引高并发同步             |
| **`cfworkers-deploy`** | `tmpl-cfworkers-deploy.yml` | Cloudflare Workers 脚本分发、Secrets 注入及版本冗余清理     |
| **`cfpages-deploy`**   | `tmpl-cfpages-deploy.yml`   | 静态资产 (Assets) 边缘分发与版本冗余自动化清理              |

## 🛡️ 安全特性

* **SHA 锁定**：所有使用的第三方 Action 均通过 Commit SHA 锁定版本，防止供应链攻击。
* **稀疏检出**：仅拉取指定的项目子目录，不接触金库全貌。
* **隔离运行**：每个任务模块在独立的虚拟机中运行，产物通过 Artifact 安全传递。

<<<<<<< HEAD
=======
---
© 2026 Fongap | Managed via GitHub Actions
>>>>>>> b941e9b2eb23cc34d2a491866ed41d3aabbbb21c
