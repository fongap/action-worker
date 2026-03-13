# ⚙️ action-worker (自动化工坊)

> 高效 CI/CD 执行中心：专为私有源代码库设计的密集型构建与部署任务处理枢纽。

---

## 🛠 核心功能 (Core Capabilities)

作为整个架构的执行层，本仓库承担以下任务：

* **SSG 编译**: Hugo / Hexo 静态站点构建。
* **部署分发**: 自动部署至 Cloudflare Pages, Vercel 或远程服务器。
* **容器化**: Docker 镜像构建与推送。
* **算力优化**: 利用公开仓库的无限 Action 时长，完全规避私有额度消耗。

## 📡 任务流 (Workflow)

1.  **接收信号**: 监听来自 `源码仓库` 的 `repository_dispatch` 事件。
2.  **即时拉取**: 使用加密 Token 临时拉取私有源码。
3.  **云端构建**: 在公开虚拟机环境中执行高强度编译任务。
4.  **安全推送**: 完成任务后清除缓存，确保源码不落地、不泄露。

## 🔒 安全性声明 (Security)

- **无源码存储**: 本仓库不存储任何项目源代码，所有代码仅在运行期间可见。
- **凭据加密**: 所有 API Token 和密钥均存储在 **GitHub Secrets** 中，并在日志中自动脱敏。
- **权限隔离**: 采用 Fine-grained PAT，严格限制跨仓库访问权限。

---
© 2026 Fongap | Managed via GitHub Actions
