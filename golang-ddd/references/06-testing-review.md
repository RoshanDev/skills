# 测试与代码评审

## 1. 测试矩阵

| 层/能力 | 首选测试 | 要证明什么 |
|---|---|---|
| 值对象 | 表驱动 + fuzz | 边界、等价、舍入、解析、不可变性 |
| 实体/聚合 | 单元测试 | 不变量、状态迁移、非法路径、事件 |
| 领域服务/策略 | 单元测试 | 规则组合和业务案例 |
| 应用用例 | 手写 fake | 编排、事务、端口调用、失败传播 |
| Repository | 真实数据库集成测试 | mapping、约束、锁、事务、迁移 |
| HTTP/gRPC | handler/contract test | DTO、错误映射、兼容性 |
| Outbox/Inbox | 集成 + 故障注入 | 原子性、重复、崩溃恢复、顺序 |
| 模块 | component test | 模块公开契约和边界 |
| 关键流程 | 少量端到端 | 最重要用户旅程 |

## 2. 领域测试

测试业务语言，不测试私有实现：

```go
func TestOrderCannotBePlacedWithoutLines(t *testing.T) { ... }
func TestCanceledOrderCannotAcceptNewItems(t *testing.T) { ... }
```

建议：

- Arrange 使用合法 fixture，再只改变当前规则相关参数。
- Assert 可见状态、返回错误和领域事件。
- 为每个状态迁移覆盖允许与禁止路径。
- 确认失败后聚合没有部分变更；先验证后 mutate，或提供安全回滚。
- 使用固定 clock/ID，不靠 sleep 和真实时间。
- 对 slice/map getter 验证调用方不能修改内部状态。

### Fuzz 候选

- Money 加减乘和溢出边界；
- Email/Phone/ID parser；
- 日期区间和时区；
- 状态反序列化/rehydration；
- 事件 schema parser。

## 3. 应用测试

手写最小 fake 通常比 mock framework 更清楚：

```go
type fakeOrders struct {
    added *domain.Order
    err   error
}

func (f *fakeOrders) Add(ctx context.Context, order *domain.Order) error {
    f.added = order
    return f.err
}
```

覆盖：

- 正确端口按正确顺序调用；
- 领域错误不被吞掉或误映射；
- transaction closure 返回错误时 rollback；
- commit 后才执行非原子动作；
- 同幂等键重复请求不重复写入；
- 同 key 不同 payload 冲突；
- context 取消和 deadline 传播；
- 未知领域事件或 mapping 失败不会提交半成品。

不要通过“每个方法调用次数”过度锁定实现；重点断言业务效果和关键原子边界。

## 4. Repository 集成测试

使用真实目标数据库或 testcontainers，避免 SQLite 代替 PostgreSQL 后漏掉行为差异。

至少覆盖：

- migration 从空库成功；
- domain -> row -> domain round trip；
- 唯一约束和错误映射；
- not found 语义；
- transaction commit/rollback；
- optimistic version conflict；
- `FOR UPDATE`/隔离级别的并发行为；
- nullable、时区、decimal、JSON 和枚举；
- soft delete/归档过滤（若采用）；
- historical row rehydration 与 schema 演进。

并行测试要隔离 schema/数据库，不能互相污染。

## 5. Outbox 与故障测试

构造以下崩溃窗口：

1. 业务写前失败：无业务数据、无消息。
2. 业务写和 Outbox 事务中失败：全部 rollback。
3. commit 后、relay 前崩溃：消息仍待发布。
4. broker 接收后、mark published 前崩溃：消息重复但业务效果一次。
5. 消费者本地写后、ack 前崩溃：重投后 inbox 去重。
6. poison message：有限重试后 DLQ，并有告警。

同时测试多 relay 实例竞争、lease 过期、批量大小、顺序和积压恢复。

## 6. 并发与 race

- 对同一聚合并发提交两个命令，验证一个成功、一个版本冲突或按业务串行。
- 对业务唯一键并发创建，验证数据库唯一约束和可理解错误。
- 对幂等 key 并发请求，验证只有一个业务写。
- 对 in-memory adapter/aggregate 测 `go test -race ./...`。
- 不把 race detector 当数据库并发测试的替代品。

## 7. 架构评审清单

### 战略层

- [ ] 术语来自业务并在代码/API/事件中一致。
- [ ] 限界上下文有清晰所有者和契约。
- [ ] 微服务拆分有独立发布/容量/隔离等明确理由。
- [ ] 被省略的 DDD 模式有说明，未过度设计。

### 领域层

- [ ] 值对象不可变，金额不使用 `float64`。
- [ ] 实体字段受保护，行为方法表达业务意图。
- [ ] 聚合小且不变量可陈述；跨聚合用 ID。
- [ ] 领域无 HTTP、ORM、SQL、broker、配置依赖。
- [ ] 时间/ID/随机性作为输入注入。
- [ ] 领域事件是业务过去式，不直接发布。

### 应用层

- [ ] 用例只编排，业务条件不散落在 handler。
- [ ] 命令名不是机械 CRUD。
- [ ] 接口在消费者侧且足够小。
- [ ] `ctx` 被完整传播，未存进 struct 或被 `Background()` 替换。
- [ ] 事务边界覆盖所有必须原子的数据。
- [ ] 外部调用不意外地延长数据库事务。

### 持久化

- [ ] 领域对象与 DB model 分离并显式映射。
- [ ] Repository 围绕聚合/用例，不是通用 CRUD。
- [ ] 并发更新有 version/锁/唯一约束策略。
- [ ] 写后回读和软删除是有依据的条件选择。
- [ ] 历史数据可恢复，但损坏数据不会静默进入有效模型。

### 消息与幂等

- [ ] 业务写与 Outbox 同事务。
- [ ] 消费者按重复投递设计，Inbox 与本地写原子。
- [ ] 幂等 key 有 scope、request hash 和唯一约束。
- [ ] 事件 schema 版本化并有契约测试。
- [ ] 有 retry、backoff、DLQ、积压指标和恢复工具。

### Go 质量

- [ ] 包名清楚，无 `utils/common/model/interfaces` 垃圾桶。
- [ ] 错误保留 `%w` 链并在边界映射。
- [ ] 无无意义 interface/base abstraction。
- [ ] `gofmt`、`go vet`、`go test -race` 通过。
- [ ] 测试覆盖失败、并发和迁移，而不仅是 happy path。

## 8. 评审输出格式

对每个问题按以下格式，避免只讲理论：

```text
[严重度] 问题标题
证据：文件:行号 / 当前行为
风险：会破坏哪个不变量、边界或可靠性承诺
建议：最小可行修改
测试：如何证明修复有效
替代：何时可以保留当前设计
```

严重度建议：

- **Blocker：** 数据丢失、重复扣款、越权、不可恢复不一致。
- **High：** 不变量可绕过、事务错误、领域耦合阻碍演进。
- **Medium：** 边界模糊、测试困难、接口/包设计恶化。
- **Low：** 命名、可读性或局部惯用法问题。
