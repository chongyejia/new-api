# 宠业家 New API（AIXHub）仓库治理与上游同步规范

> 本仓库 Fork 自 [`QuantumNous/new-api`](https://github.com/QuantumNous/new-api)，是宠业家统一大模型网关（域名 `https://aixhub.engine17.cn`，K8s 命名空间 `one-api`）的代码基线。

## 1. 仓库与分支约定

- **GitHub 远端（`origin`）**：`https://github.com/chongyejia/new-api`
- **上游远端（`upstream`）**：`https://github.com/QuantumNous/new-api`
- **云效 Codeup 私有镜像（`codeup`）**：`https://codeup.aliyun.com/chongyejia/new-api`（国内 CI/CD 构建真源）
- **核心分支与标签**：
  - `upstream-main`：只读镜像 `upstream/main`，禁止人工直接提交。
  - `cyj-internal`：宠业家主发布分支，始终通过 `./deploy/cyj/sync-upstream.sh` 合并 `upstream/main` 跟进社区更新。
  - `v1-cyj-source-20261112`：线上现运行镜像 `registry.cn-shanghai.aliyuncs.com/chongyejia/new-api:v1-cyj-source-20261112` 对应的精确历史提交锚点（`25840921`）。

## 2. 三层“零入侵优先”迭代边界

为避免升级上游时产生 Go/React 源码冲突，所有内部需求按优先级分层落地：

1. **L1 — 官方后台配置与上游插件市场（首选，零代码修改）**
   - 模型定价、渠道分组、倍率、限流优先使用管理后台设置；
   - 请求脱敏、参数覆盖、自动推理强度、图片压缩等功能优先启用上游自带 Plugin Marketplace；
   - 出海节点/API 代理优先通过 K8s 标准 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量或集群出口代理配置注入，不硬编码进源码。
2. **L2 — 外部轻量适配层（次选，仓库外扩展）**
   - 宠业家内部系统（如 `cyjdata-index` 预算账本/定价回写、`casdoor` SSO 对接或特定监控探针）作为外部适配模块维护在消费侧或独立服务中，不侵入 `new-api` 核心代码。
3. **L3 — 极简非入侵补丁（最后手段，仅改必要文件）**
   - 如根目录 `Dockerfile` 为国内构建追加 `--registry=https://registry.npmmirror.com` 与 `GOPROXY=https://goproxy.cn,direct`；
   - 所有 L3 提交必须保持独立、原子化，并带清晰的 `chore/feat` 提交信息，严禁使用 `git push --force` 改写历史。

## 3. 上游同步标准流程

```bash
cd /Users/luban/codebase/new-api
git switch cyj-internal
./deploy/cyj/sync-upstream.sh
git diff upstream/main --stat   # 确认仅保留期望的轻量定制
git push origin upstream-main cyj-internal
git push codeup upstream-main cyj-internal
```

## 4. K8s 非敏感基线与凭据红线

- [`deploy/cyj/k8s/`](./k8s/) 保存从 `one-api` 命名空间导出的非敏感基线（`ConfigMap`、`Deployment`、`Redis`、`Service`、`Ingress`），**严禁**提交任何 Secret（`one-api-secrets` 仅存在于集群侧，禁止落库，提交前依赖全局 `gitleaks` 守卫拦截）。
- 构建生产镜像时应固定 Git Commit SHA 作为镜像 Tag，同步记录 `vcs.revision` 并在更新 [`k8s/deployment.yaml`](./k8s/deployment.yaml) 后经审批变更线上 Deployment。

## 5. 云效流水线（`aixhub-new-api-prod`）与回滚

- 流水线定义文件：[`deploy/cyj/yunxiao-newapi-prod.pipeline.yaml`](./yunxiao-newapi-prod.pipeline.yaml)（云效 `pipelineId: 5406341`，构建 `cyj-internal` 分支并滚动更新集群 `one-api/deployment/one-api`）。
- 触发前须传入 `EXPECTED_SOURCE_COMMIT=<40位SHA>`，流水线会自动生成 `v1.0.0-rc.51+cyj.<shortsha>` 写入 `VERSION`（透传至 `/api/status` 的 `version` 字段）与 ACR tag `v1-cyj-${DATETIME}`。
- **快速回滚**：`kubectl -n one-api rollout undo deploy/one-api`（历史基线锚点镜像 `registry.cn-shanghai.aliyuncs.com/chongyejia/new-api:v1-cyj-source-20261112`，对应源码 tag `v1-cyj-source-20261112`）。
