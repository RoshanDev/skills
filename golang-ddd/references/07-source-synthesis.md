# 来源综述与规则取舍

检索与复核日期：**2026-06-25**。

本技能不是对单一仓库的照抄，而是把指定材料与 Go 官方约定、成熟社区示例和分布式系统可靠性实践交叉验证。下面明确标记“采纳”“调整”“不设为默认”，便于维护者审计。

## 1. sklinkert/go-ddd

来源：

- [go-ddd repository](https://github.com/sklinkert/go-ddd/tree/main)
- [DDD & CQRS Principles Guide](https://github.com/sklinkert/go-ddd/blob/main/DDD_CQRS_PRINCIPLES.md)

该项目展示了 Onion Architecture、domain/application/infrastructure/interface 分层、CQRS、幂等写路径、PostgreSQL、sqlc、迁移和 Testcontainers。

### 直接采纳

- 领域层不依赖框架和基础设施。
- 应用层编排用例，适配器做持久化映射。
- 领域对象不直接作为外部 API DTO。
- 写侧构造/行为保护不变量；读取历史数据要考虑规则演进。
- 命令和查询可以分开组织，写路径需要考虑幂等。
- 显式 schema migration、sqlc/类型安全访问和真实数据库测试有工程价值。

### 调整后采纳

| 上游观点/示例 | 本技能的处理 |
|---|---|
| Repository 接口统一放领域层 | 遵循 Go 的消费者侧接口原则：多数用例端口放 `app`；只有领域服务真实消费的抽象才放 `domain`。 |
| `ValidatedEntity` wrapper 保证只保存合法对象 | 视为可选技巧，不作为默认。优先用私有字段、构造函数和行为方法让实体无法进入非法状态，避免两套实体类型。 |
| ID、时间由领域 factory 生成 | 保留“不要有隐式双重事实源”的目标，但把 clock/ID generator 从应用或 factory 边界注入，避免深层 `time.Now()`/全局 UUID 导致测试不确定。 |
| 读时不执行当前验证 | 区分创建规则与 rehydration：不盲目重放今天的创建规则，但仍验证结构、枚举、版本和数据完整性。 |
| CQRS | 作为按需组织手段；简单 CRUD/查询不强制 command/query object 或两套存储。 |
| 幂等记录 | 要与业务写尽可能同事务，并增加 scope、request fingerprint、唯一约束和处理中恢复协议。 |

### 不设为全局默认

- **所有写入后都重新查询。** 只有 DB 生成/规范化值或响应契约需要时回读；`RETURNING` 往往足够。
- **永远软删除。** 删除、归档、取消、合规擦除的语义不同，必须按数据类别决定。
- **仓储内部使用 `context.Background()`。** 必须传播调用者 `ctx`，保留取消、deadline 和 tracing。
- **所有实体都需要相同审计字段。** 只有领域使用的时间进入领域实体；纯技术审计可留在 persistence model。

这些不是否定该模板，而是把一个“opinionated template”的选择改写成适用于更多团队的条件规则。

## 2. Ompluscator：Practical DDD in Golang 全系列

系列共 9 篇：

1. [Value Object](https://www.ompluscator.com/article/golang/practical-ddd-value-object/) — 2023-09-16
2. [Entity](https://www.ompluscator.com/article/golang/practical-ddd-entity/) — 2023-09-17
3. [Domain Service](https://www.ompluscator.com/article/golang/practical-ddd-domain-service/) — 2023-09-17
4. [Domain Event](https://www.ompluscator.com/article/golang/practical-ddd-domain-event/) — 2023-09-17
5. [Module](https://www.ompluscator.com/article/golang/practical-ddd-module/) — 2023-09-17
6. [Aggregate](https://www.ompluscator.com/article/golang/practical-ddd-domain-aggregate/) — 2023-09-18
7. [Factory](https://www.ompluscator.com/article/golang/practical-ddd-domain-factory/) — 2023-09-18
8. [Repository](https://www.ompluscator.com/article/golang/practical-ddd-domain-repository/) — 2023-09-18
9. [Specification](https://www.ompluscator.com/article/golang/practical-ddd-domain-specification/) — 2023-09-18

### 逐篇取舍

| 文章 | 采纳 | 调整/补充 |
|---|---|---|
| Value Object | 按值相等、显式类型、不可变、构造校验、丰富行为 | 示例 Money 使用 `float64`；本技能改为最小货币单位整数或可靠 decimal，并要求显式舍入/溢出规则。示例中 `time.Now()` 改为参数化时间。 |
| Entity | 领域实体不是 ORM row；身份与行为是核心；持久化模型分离 | 字段应尽量私有；Repository 放置按消费者决定；审计字段不自动属于领域。 |
| Domain Service | 无状态、表达不能自然归属实体/值对象的业务行为 | 进一步区分 Domain Service 与 Application Service。依赖数据库、HTTP、事务和鉴权的编排默认在应用层；简单规则用函数即可。 |
| Domain Event | 过去式、不可变、能帮助发现模型 | 文章展示 Observer/异步 goroutine 的思路适合进程内通知，不足以保证跨进程交付；本技能要求 Outbox + 幂等消费者。 |
| Module | 业务高内聚、单向依赖、统一语言命名、模块根组装 | 采用“业务模块优先、模块内分层”；手工 DI 默认，Wire 等工具按规模引入；模块不必一一等于微服务。 |
| Aggregate | 不变量定义边界、小聚合、根控制内部对象、跨聚合按 ID | 补充乐观锁、版本冲突和最终一致；“一仓储一聚合”按用例语义实现，不制造泛型仓储。 |
| Factory | 复杂创建、变体和重建可用 factory | 简单创建用 `NewX`；DTO/DAO 到实体的映射放 adapter mapper，不让领域 factory 知道持久化格式。 |
| Repository | 领域与存储隔离、映射、防腐层 | 不把数据库、缓存、外部 API、配置都统一叫 repository；远程系统用 gateway/client，缓存可装饰端口。跨多个仓储的事务放应用 Unit of Work。 |
| Specification | 可复用、组合的业务判定 | 简单规则用具名函数；读侧查询条件用 query DTO；禁止 SQL/ORM 细节渗入领域 specification。 |

## 3. Go 官方与工程风格

### Go 官方

- [Organizing a Go module](https://go.dev/doc/modules/layout)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Fuzzing](https://go.dev/doc/security/fuzz/)

落地规则：

- 简单项目保持简单，不套固定大目录。
- 服务内部实现放 `internal`，入口放 `cmd`。
- 接口通常属于使用者，而非实现者；不要为了 mock 预先定义接口。
- `context.Context` 作为第一个参数贯穿跨边界调用，不存入 struct。
- 避免 `util/common/misc/types/interfaces` 这类无意义包名。
- 对 parser、值对象和边界输入使用 Go 原生 fuzzing。

### Uber Go Style Guide

来源：[uber-go/guide](https://github.com/uber-go/guide/blob/master/style.md)

采用其错误处理建议：需要保留底层原因时使用 `%w`，添加简洁操作上下文，并把导出错误视为公共 API 的一部分。

## 4. Go 社区实践

### Three Dots Labs — Wild Workouts

来源：

- [DDD Lite in Go](https://threedots.tech/post/ddd-lite-in-go-introduction/)
- [Combining DDD, CQRS, and Clean Architecture in Go](https://threedots.tech/post/ddd-cqrs-clean-architecture-combined/)
- [Basic CQRS in Go](https://threedots.tech/post/basic-cqrs-in-go/)
- [wild-workouts-go-ddd-example](https://github.com/ThreeDotsLabs/wild-workouts-go-ddd-example)

采纳：

- 私有字段 + 构造校验，让内存状态始终有效。
- 方法围绕行为而非数据 setter。
- 应用层只做编排，业务决策回到领域。
- 命令名使用业务语言，如 `ScheduleTraining`、`CancelTraining`，而非机械 CRUD。
- CQRS 可以很轻，不要求两套数据库或复杂 command bus。
- 遗留代码应通过逐用例重构而非大爆炸重写。

其 transaction closure repository 是一种有效实现，但本技能把它归为可选 UoW 形态，不要求所有仓储都采用同样 API。

### Kratos

来源：

- [Kratos project layout](https://go-kratos.dev/docs/intro/layout/)
- [Go project layout best practices](https://go-kratos.dev/blog/kratos/go-project-layout/)
- [go-kratos/kratos-layout](https://github.com/go-kratos/kratos-layout)

采纳：

- `service` 类似应用/transport 协调层，不放复杂业务逻辑。
- `biz` 承载业务逻辑并声明 repo 端口，`data` 实现端口和映射。
- `internal` 限制意外导入。
- 避免全局 `model` 和 Java 式 `src` 目录。

调整：Kratos 模板是框架布局，不自动等于 DDD。业务复杂时仍需在 `biz` 内识别聚合和值对象；多个业务能力不应永远堆在一个包。

### Modular Monolith + Hexagonal Go example

来源：[bxcodec/golang-ddd-modular-monolith-with-hexagonal](https://github.com/bxcodec/golang-ddd-modular-monolith-with-hexagonal)

采用其“单部署、多业务模块、Ports & Adapters、模块可独立演进”的方向，作为模块化单体优先的社区佐证。目录名和具体框架不被视为唯一标准。

## 5. Microsoft / 分布式可靠性实践

### Tactical DDD

来源：[Use Tactical DDD to Design Microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/tactical-domain-driven-design)

采用：

- 聚合是事务一致性边界，即使只有一个实体也可以是聚合。
- 聚合要小，外部聚合按 ID 引用。
- 跨聚合默认最终一致。
- Domain Service 承载跨对象业务规则；Application Service 管事务、鉴权和编排。
- 内部领域事件与跨边界集成事件分离，后者在原事务提交后异步传播。

### Transactional Outbox

来源：

- [Microsoft: Transactional Outbox](https://learn.microsoft.com/en-us/azure/architecture/databases/guide/transactional-out-box-cosmos)
- [Microservices.io: Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html)

采用：业务对象和待发送事件原子写入；独立 relay 发布。由于 relay 可能重复发布，消费者必须幂等。具体数据库实现可用关系表、文档内事件或 CDC，但原子性原则不变。

### Saga

来源：[Microsoft: Saga distributed transactions pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/saga)

采用：跨服务流程拆为本地事务，通过消息推进，失败时执行业务补偿；重试步骤必须幂等，并监控在途状态。复杂流程优先显式 orchestrator/process manager，简单少步骤可 choreography。

## 6. Agent Skill 结构

来源：

- [Agent Skills specification](https://agentskills.io/specification)
- [GitHub Docs: Adding agent skills](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/add-skills)

本目录遵守：

- 根目录必有带 YAML frontmatter 的 `SKILL.md`；
- 名称与目录均为 `golang-ddd`；
- 主说明保持可执行，细节拆入 `references/`；
- 脚本放 `scripts/`，模板放 `assets/`，示例按需加载；
- 可放入项目 `.github/skills/golang-ddd`，也可作为个人/技能仓库条目。

## 7. 本技能的总体立场

1. **战略设计高于模式堆叠。** 不知道上下文和语言时，不急着画四层目录。
2. **Go 惯用法约束 DDD 实现。** 小接口、显式依赖、组合优先、少框架魔法。
3. **默认模块化单体和渐进改造。** 微服务与大重写都需要额外证据。
4. **强一致只覆盖真正不变量。** 聚合小、跨聚合最终一致、并发冲突显式。
5. **可靠性不是领域事件接口本身。** Outbox、Inbox、幂等、版本、重试和可观测性共同完成生产级交付。
6. **所谓“最佳实践”必须带适用条件。** 软删、回读、CQRS、Specification、DI 框架和泛化 UoW 都是选择，不是戒律。
