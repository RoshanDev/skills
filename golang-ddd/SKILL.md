---
name: golang-ddd
description: 设计、实现、重构和审查 Go/Golang 领域驱动设计（DDD）后端。用于复杂业务建模、统一语言、限界上下文与模块化单体/微服务边界、实体、值对象、聚合、领域服务、仓储、CQRS、事务、Transactional Outbox、幂等、Clean/Hexagonal Architecture、遗留系统渐进改造和测试；遇到简单 CRUD、代理或数据搬运服务时主动采用轻量方案，避免过度设计。
license: MIT
compatibility: 适用于支持 Agent Skills 的编码代理；运行校验脚本需要 Python 3.10+，运行附带示例需要 Go 1.22+。
metadata:
  version: "1.0.0"
  language: "zh-CN"
---

# Golang DDD

把 DDD 当作管理业务复杂度和语言边界的方法，而不是目录模板、框架或设计模式清单。先理解业务，再写结构；优先产出小而清晰的 Go 代码。

## 不可妥协的原则

1. **业务边界先于技术分层。** 先识别统一语言、限界上下文、命令、事件和不变量，再决定包、表和服务。
2. **复杂度必须买单。** 简单 CRUD、API 代理、报表或数据搬运任务不强行引入聚合、CQRS、事件总线和仓储抽象。
3. **默认模块化单体。** 只有在独立发布、团队自治、容量、隔离或数据所有权确有需求时才拆微服务。
4. **领域包保持纯净。** 不依赖 HTTP、RPC、ORM、SQL、消息队列、缓存、配置和具体框架；不放数据库或序列化标签。
5. **对象始终处于有效状态。** 构造函数建立初始不变量；行为方法执行状态迁移并再次保护相关不变量；字段尽量私有。
6. **聚合是事务一致性边界。** 聚合保持小；外部只通过根修改内部实体；跨聚合只保存 ID，默认最终一致。
7. **应用层负责编排而非决策。** 它处理鉴权、事务、端口调用、幂等和事件交付，业务分支留在领域模型。
8. **接口由消费者定义。** 只在真实替换点定义小接口；实现包返回具体类型。`context.Context` 是跨边界调用的第一个参数，不进入纯领域行为。
9. **可靠事件需要原子落盘。** 业务写与 Outbox 同事务；消费者按至少一次投递设计并幂等。不要把 `go publish(...)` 当可靠交付。
10. **所有规则都可被测试和解释。** 为边界、不变量、事务、并发和失败路径写测试，并记录关键取舍。

## 工作流

### 1. 侦察现有代码

先读取 `go.mod`、入口、包结构、API/事件契约、迁移、关键测试和 ADR。保留项目现有命名与工具链，除非它们阻碍业务边界。不要先重写框架。

输出当前事实：业务能力、外部依赖、事务边界、数据所有者、已有约束、风险和未知项。

### 2. 判断 DDD 强度

使用 [战略设计与复杂度门槛](references/01-strategic-design.md)：

- **简单：** 包按功能组织，应用服务 + 直接数据访问即可。
- **中等：** 使用 DDD-lite：值对象、行为丰富的实体、小接口、清晰模块。
- **复杂：** 补齐限界上下文、聚合、领域事件、策略/领域服务、事务与集成模式。

先写明选择及原因；不要以“最佳实践”为由增加仪式。

### 3. 建立语言和边界

与需求文本、领域专家或现有行为对齐，产出：

- 统一语言表：业务术语、定义、反例、所属上下文。
- 命令与事件：使用业务动词，如 `PlaceOrder` / `OrderPlaced`，避免 `CreateOrderRecord`。
- 不变量：必须在一次事务中始终成立的业务规则。
- 限界上下文与上下文映射：所有权、输入/输出契约、同步/异步关系。
- 聚合候选：依据并发和一致性，而非数据库外键图。

### 4. 选择 Go 结构

默认按业务模块组织，在模块内部再分领域、应用和适配器：

```text
cmd/api/main.go
internal/
  ordering/
    domain/
    app/
    adapters/
      postgres/
      http/
      messaging/
    module.go
  billing/
    ...
  platform/        # 仅真正跨模块的技术能力
```

避免全局 `model`、`entity`、`repository`、`service`、`utils`、`common`、`events` 大包。可按现有项目采用 `biz/data/service` 等命名，但依赖方向不变。详见 [Go 架构与包设计](references/03-go-architecture.md)。

### 5. 实现领域模型

按 [战术建模](references/02-tactical-modeling.md) 执行：

- 值对象按值相等、不可变，构造时校验；金额使用最小货币单位整数或可靠 decimal，不用 `float64`。
- 实体按身份连续，暴露业务行为而非字段式 setter。
- 聚合根封装内部集合，返回副本或只读视图；一次命令只修改一个聚合是默认值。
- 领域服务只承载无法自然归属某个实体/值对象的无状态业务规则；简单函数优先。
- Factory 仅用于复杂创建；普通创建使用 `NewX`。
- Specification/Policy 仅在规则需要命名、复用或组合时使用，不把 SQL 表达式塞进领域层。
- 时间、ID、随机数和汇率等不确定输入从应用边界注入，不在深层逻辑中直接调用全局函数。

### 6. 实现用例和端口

一个用例处理一个业务意图。命令处理器通常按以下顺序：

1. 校验调用级输入、鉴权和幂等键。
2. 在需要时开启应用层 Unit of Work。
3. 通过端口加载聚合或外部事实。
4. 调用领域行为做决定。
5. 持久化聚合并写入 Outbox。
6. 提交后返回结果；非原子副作用在提交后或异步执行。

查询可直接使用专用 read model，不必重建写聚合。只有读写模型确实不同或演进速度不同才采用 CQRS；简单查询不需要空的 Query 对象。

### 7. 处理持久化、事务和并发

遵循 [持久化与事务](references/04-persistence-transactions.md)：

- 仓储表达聚合集合或用例所需能力，不做万能泛型 CRUD。
- 领域对象与数据库行、API DTO、protobuf 分离并显式映射。
- 跨多个仓储的原子操作由应用层 Unit of Work 包住。
- 使用调用者传入的 `ctx`；仓储内部不得用 `context.Background()` 替代它。
- 对并发写使用版本号/乐观锁，并把冲突映射为可识别领域或应用错误。
- “写后回读”“软删除”“读时重新校验创建规则”均是条件策略，不是全局默认。

### 8. 处理事件、Outbox 和幂等

遵循 [事件、Outbox 与幂等](references/05-events-idempotency.md)：

- 领域事件为过去式、不可变，描述业务事实；数据库行变化不是领域事件。
- 在应用层将内部领域事件映射成版本化集成事件。
- 业务状态和 Outbox 消息在同一事务提交；独立 relay 重试发布。
- 消息可能重复，消费者用 `event_id`/业务键去重并保证处理与 inbox 状态原子。
- HTTP/命令幂等键要绑定操作、调用者和请求指纹；同键不同请求必须冲突。
- 跨上下文长流程需要显式 Saga/Process Manager、超时和补偿，而不是分布式大事务。

### 9. 测试与评审

使用 [测试与评审](references/06-testing-review.md)：

- 领域：表驱动测试不变量、状态机和错误；对解析、金额和边界值做 fuzz。
- 应用：手写 fake 验证编排、事务、幂等和失败路径。
- 适配器：真实数据库/容器集成测试、迁移测试和契约测试。
- 可靠性：并发写、乐观锁、Outbox 重试、重复消息和崩溃窗口测试。
- 运行 `gofmt`、`go vet ./...`、`go test -race ./...`，并执行本技能的边界检查脚本。

## 输出要求

每次设计、实现或评审至少给出：

1. 业务假设与统一语言。
2. 限界上下文、聚合和事务边界决策。
3. 选择的 DDD 强度及被主动省略的模式。
4. 包结构和依赖方向。
5. 可编译实现与关键测试，或最小渐进迁移步骤。
6. 并发、幂等、事件交付、可观测性和数据迁移风险。
7. 替代方案、代价与需要领域专家确认的问题。

优先小 diff、渐进替换和可回滚迁移。不要为了展示架构而生成大量空接口、基类、总线或目录。

## 按需读取

- 战略设计、限界上下文和微服务判断：[references/01-strategic-design.md](references/01-strategic-design.md)
- 九类战术模式和 Go 写法：[references/02-tactical-modeling.md](references/02-tactical-modeling.md)
- 包结构、接口、Context、错误和依赖注入：[references/03-go-architecture.md](references/03-go-architecture.md)
- 仓储、Unit of Work、映射、并发和删除策略：[references/04-persistence-transactions.md](references/04-persistence-transactions.md)
- 领域事件、集成事件、Outbox、Inbox、幂等和 Saga：[references/05-events-idempotency.md](references/05-events-idempotency.md)
- 测试矩阵和代码评审清单：[references/06-testing-review.md](references/06-testing-review.md)
- 对指定文章和社区实践的逐项取舍：[references/07-source-synthesis.md](references/07-source-synthesis.md)
- 可编译最小示例：[examples/order](examples/order)
- PostgreSQL Outbox 模板：[assets/outbox-postgres.sql](assets/outbox-postgres.sql)
- ADR 模板：[assets/ddd-decision-record.md](assets/ddd-decision-record.md)
