# golang-ddd Agent Skill

面向 Go 后端的 DDD 设计、实现、重构和评审技能。内容综合：

- `sklinkert/go-ddd` 的 Onion Architecture、CQRS、幂等、sqlc 与测试实践；
- Ompluscator 的 9 篇 Practical DDD in Golang 系列；
- Go 官方接口、Context、包与 `internal` 约定；
- Three Dots Labs Wild Workouts、Kratos、Microsoft Azure Architecture Center 等工程实践；
- 对常见争议项的条件化修正，例如软删除、写后回读、读时校验、仓储事务和事件发布。

## 安装

把本仓库作为唯一来源，通过软链接安装完整目录，而不是只复制 `SKILL.md`。

Agent/Codex 用户级安装：

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /path/to/skills/golang-ddd ~/.agents/skills/golang-ddd
ln -sfn /path/to/skills/golang-ddd ~/.codex/skills/golang-ddd
```

项目级安装：

```bash
mkdir -p /path/to/project/.agents/skills
ln -sfn /path/to/skills/golang-ddd /path/to/project/.agents/skills/golang-ddd
```

其他支持 Agent Skills 的工具可将同一目录链接到其技能目录，例如 `~/.claude/skills/golang-ddd` 或项目的 `.github/skills/golang-ddd`。

## 校验

从本仓库根目录运行：

```bash
python3 golang-ddd/scripts/validate_skill.py golang-ddd
python3 golang-ddd/scripts/check_domain_imports.py golang-ddd/examples/order
(cd golang-ddd/examples/order && go test -race ./...)
```

## 目录

```text
golang-ddd/
├── SKILL.md
├── references/
├── assets/
├── scripts/
└── examples/order/
```

本技能是原创归纳与示例，不复制上游项目代码。来源和观点取舍记录在 `references/07-source-synthesis.md`。仓库根目录的 MIT License 适用于本目录。
