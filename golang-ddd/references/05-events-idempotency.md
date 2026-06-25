# 领域事件、集成事件、Outbox 与幂等

## 1. 区分三种东西

| 类型 | 作用域 | 示例 | 可靠性要求 |
|---|---|---|---|
| Domain Event | 同一领域模型/上下文 | `OrderPlaced` | 记录业务事实 |
| Integration Event | 跨模块/进程契约 | `ordering.order-placed.v1` | 版本化、可重试、可观测 |
| Technical Event | 基础设施事实 | `cache_entry_evicted` | 由技术组件定义 |

领域事件不应直接携带 broker topic、HTTP DTO 或 ORM model。应用层把领域事件映射为稳定的集成消息。

## 2. 领域事件设计

推荐字段：

```go
type OrderPlaced struct {
    OrderID    OrderID
    CustomerID CustomerID
    Total      Money
    OccurredAt time.Time
}
```

规则：

- 使用过去式和业务语言。
- 事件是不可变事实，不提供 setter。
- 只包含事件发生时成立的信息；不要让消费者回调生产者才能理解最基本语义。
- 不塞入整个聚合快照，除非明确采用 state transfer 且接受耦合。
- 聚合记录 pending events；它不知道 Kafka、RabbitMQ 或 JSON。

## 3. 集成事件 Envelope

```json
{
  "event_id": "01J...",
  "event_type": "ordering.order-placed.v1",
  "aggregate_id": "ord_123",
  "aggregate_version": 7,
  "occurred_at": "2026-06-25T10:00:00Z",
  "producer": "ordering",
  "correlation_id": "req_456",
  "causation_id": "cmd_789",
  "payload": {}
}
```

- `event_id` 全局唯一，用于去重和追踪。
- `event_type` 带稳定版本；schema 的兼容性要自动测试。
- `aggregate_version` 可帮助同聚合排序和检测缺口，但不能假设全局顺序。
- correlation/causation 便于串联业务流程。
- 不在 payload 中泄露内部数据库列和敏感信息。

## 4. Transactional Outbox

错误做法：

```text
1. COMMIT order
2. publish message  <-- 进程在此崩溃会丢事件
```

正确结构：

```text
DB transaction:
  save aggregate
  insert outbox message
COMMIT

relay:
  claim pending rows
  publish
  mark published / schedule retry
```

业务数据和 Outbox 必须使用同一数据库事务。relay 通常只能保证至少一次，因此重复发布是正常情况。

### Relay 要点

- 批量 claim，PostgreSQL 可用 `FOR UPDATE SKIP LOCKED`。
- 设置最大尝试、指数退避、抖动和 dead-letter 状态。
- 发布成功后标记；若“发布成功但标记失败”，消息会重复，消费者必须幂等。
- 指标：pending 数、最老消息年龄、失败率、重试次数和 publish latency。
- 明确保留和清理策略，不让 Outbox 无限增长。
- 多实例时测试锁、租约过期和崩溃恢复。

模板见 `assets/outbox-postgres.sql`。

## 5. Inbox 与幂等消费者

消费者的基本协议：

```text
begin transaction
  insert inbox(event_id) on conflict -> already processed
  apply local business change
commit
ack message
```

要求：

- inbox 去重记录和本地业务写同事务。
- 重复事件返回成功/ack，而不是重新执行副作用。
- 外部副作用也需要自己的幂等键，例如支付 provider request ID。
- 对同聚合顺序敏感时，检查 `aggregate_version`，将缺口暂存/重试。
- poison message 进入 DLQ，并保留重放工具和审计。

“exactly once”通常是端到端业务效果，而不是 broker 单项承诺；依靠原子本地事务、唯一键和幂等协议组合实现。

## 6. HTTP/命令幂等

幂等记录至少包含：

```text
scope             operation + tenant/actor
idempotency_key   客户端提供或稳定业务键
request_hash      规范化请求指纹
status            processing/succeeded/failed
response          可重放的结果或资源 ID
expires_at        业务定义的保留期
```

处理算法：

1. 对 `(scope, key)` 建唯一约束。
2. 首次请求在业务事务中 claim 该 key。
3. 同 key、同 request hash：返回处理中或已缓存结果。
4. 同 key、不同 hash：返回冲突，禁止把不同命令当重试。
5. 业务写、Outbox 和成功结果尽量同事务提交。
6. 对卡死的 `processing` 记录定义 lease/恢复协议。

只做“先查 key，执行，再插入记录”存在竞争窗口；必须有唯一约束和原子事务。

## 7. 提交前与提交后副作用

### 事务内

- 聚合持久化；
- Outbox；
- Inbox/幂等记录；
- 同数据库内需要原子的投影。

### 提交后/异步

- 发邮件、短信；
- 调第三方 API；
- 发布 broker 消息（由 relay）；
- 搜索索引和缓存更新。

非原子副作用必须可重试、幂等并可观测。不要在 DB transaction closure 中启动 goroutine；closure rollback 后 goroutine 无法被撤销。

## 8. Saga / Process Manager

跨上下文长流程用显式状态机：

```text
OrderPendingPayment
  -> PaymentAuthorized
  -> InventoryReserved
  -> OrderConfirmed
```

并定义失败路径：

```text
InventoryRejected
  -> VoidPaymentAuthorization
  -> OrderRejected
```

设计时写清：

- 每一步命令、成功事件和失败事件；
- 状态、超时、重试和最大时长；
- 补偿是否真正可逆；
- 重复和乱序处理；
- 人工介入与审计；
- 流程版本升级时在途实例如何处理。

Saga 不是隐藏分布式事务。它把中间状态和业务补偿显式化，代价是复杂度和最终一致。

## 9. 事件演进

- 优先向后兼容新增可选字段。
- 不复用旧字段表达新语义。
- 破坏性变化发布新版本，并在迁移期双读/双发或使用转换器。
- schema registry/契约测试验证生产者与消费者兼容。
- 事件名表达业务事实，不表达当前消费者，例如 `OrderPlaced` 优于 `SendWarehouseMessage`。
- 对删除、隐私和敏感字段制定事件保留及脱敏策略。

## 10. 常见失败模式

- 聚合直接依赖 publisher。
- 提交 DB 后同步 publish，失败只写日志。
- `go func(){ publish(...) }()` 后立即返回成功。
- Outbox 记录与业务写不在同一事务。
- 认为 broker 不重复，不写消费者幂等。
- 幂等键不绑定调用者/请求指纹。
- 事件 payload 等于数据库 row 或整个领域对象。
- 依赖全局消息顺序。
- 无限重试，没有 DLQ、指标或人工恢复。
