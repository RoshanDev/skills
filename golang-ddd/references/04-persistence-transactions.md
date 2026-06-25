# 持久化、事务与并发

## 1. 仓储的边界

仓储围绕聚合和业务意图，而非表：

```go
type OrderRepository interface {
    Get(ctx context.Context, id domain.OrderID) (*domain.Order, error)
    Add(ctx context.Context, order *domain.Order) error
    Save(ctx context.Context, order *domain.Order, expectedVersion int64) error
}
```

不要默认生成：

```go
type Repository[T any] interface {
    Create(T) error
    Read(string) (T, error)
    Update(T) error
    Delete(string) error
}
```

泛型 CRUD 会把不同聚合的语义、并发策略和查询需求压平，并诱导应用层做字段式更新。

### 仓储、Gateway 与 Read Store

- **Repository：** 读写聚合。
- **Gateway/Client：** 调用支付、库存、风控等远程系统。
- **Read Store/Queries：** 返回列表、报表、搜索投影。
- **Cache decorator：** 包装某端口，不成为领域事实源。

名称要反映语义，不把所有 I/O 都叫 Repository。

## 2. 显式映射

持久化 model 可以包含 DB 需要的字段和标签：

```go
type orderRow struct {
    ID        string
    Customer  string
    Status    string
    Version   int64
    DeletedAt sql.NullTime
}
```

适配器负责：

- domain -> SQL 参数/row；
- row + child rows -> domain rehydration；
- DB constraint/driver error -> 应用可识别错误；
- null、时区、精度、枚举和 schema 版本转换。

不要让 ORM 自动 materialize 一个可被任意字段修改的领域实体。

## 3. Rehydration 与历史数据

创建新对象和从持久化恢复对象是不同意图：

- `NewOrder` 应执行当前创建规则。
- `RestoreOrder`/mapper 应验证结构完整性、枚举合法性和数据未损坏。
- 不应盲目把今天的新建规则重新施加到所有历史记录，否则规则演进后可能无法读取旧数据。
- 但“读时完全不校验”同样危险；损坏或不兼容数据必须被显式发现、迁移或隔离。

可使用内部 snapshot：

```go
type OrderSnapshot struct {
    ID       OrderID
    Status   OrderStatus
    Lines    []OrderLineSnapshot
    Version  int64
}

func RestoreOrder(s OrderSnapshot) (*Order, error) { ... }
```

把该 API 保持在领域包最小公开面，并只由可信适配器调用。

## 4. Unit of Work

当一个用例需要让聚合写入、Outbox 和幂等记录原子提交时，在应用边界使用 Unit of Work：

```go
type UnitOfWork interface {
    WithinTransaction(
        ctx context.Context,
        fn func(ctx context.Context, tx Tx) error,
    ) error
}

type Tx interface {
    Orders() OrderRepository
    Outbox() Outbox
    Idempotency() IdempotencyStore
}
```

处理器：

```go
err := h.uow.WithinTransaction(ctx, func(ctx context.Context, tx Tx) error {
    order, err := tx.Orders().Get(ctx, cmd.OrderID)
    if err != nil { return err }

    if err := order.Place(h.clock.Now()); err != nil { return err }
    if err := tx.Orders().Save(ctx, order, expectedVersion); err != nil { return err }

    return tx.Outbox().Append(ctx, mapEvents(order.PullEvents())...)
})
```

实现注意：

- `fn` 返回 error 必须 rollback；panic 也应 rollback 后继续抛出。
- 不在 transaction closure 中做慢网络调用，除非业务明确接受长事务。
- repository 必须共享同一 transaction handle；不要各自偷偷开启独立事务。
- 事务重试只适用于可安全重放的 closure；避免在 closure 中发送邮件、发布消息或写外部系统。
- 若只写一个聚合和一张 Outbox 表，也可以提供更窄的原子存储端口，避免过度通用 UoW。

## 5. 乐观并发控制

聚合表保存 `version`：

```sql
UPDATE orders
SET status = $1, version = version + 1, updated_at = $2
WHERE id = $3 AND version = $4;
```

受影响行数为 0 时区分：

- 聚合不存在；
- 已被并发更新，返回 `ErrVersionConflict`。

应用可：

- 向调用者返回冲突并要求重新读取；
- 对明确可重放的命令有限次重试；
- 使用幂等键防止重试造成重复业务操作。

不要在冲突时静默 last-write-wins，除非该字段确实允许这种语义。

## 6. 锁与隔离级别

根据不变量选择：

- 乐观锁：冲突少、读多写少的聚合。
- `SELECT ... FOR UPDATE`：热点资源、需要串行决策，但要控制锁顺序和事务时长。
- 唯一约束：业务唯一性应尽量由 DB 作为最终防线，例如 `(tenant_id, external_order_no)`。
- Serializable：只在充分测试吞吐和重试后使用。

应用层判断不能替代数据库约束；数据库约束也不能替代领域错误语义。两者组合使用。

## 7. ID 与数据库默认值

可选策略：

### 应用生成

优点：提交前即可引用、测试确定、Outbox 可共享 ID。注入 generator，避免领域深处调用全局 UUID。

### 数据库生成

适合 sequence、数据库时间或强依赖 DB 的场景。使用 `RETURNING` 获取生成值，并承认持久化参与了创建协议。

不要把“所有默认值必须在领域”或“所有默认值必须在 DB”当绝对规则。决定应基于事实源、并发、迁移和测试需求。

## 8. 写后回读

**需要回读：**

- DB 生成 ID、时间、版本或计算列；
- trigger/constraint 会规范化结果；
- API 契约必须返回数据库最终表示。

**通常不需要：**

- 所有写入值已知且 `RETURNING` 足够；
- 聚合已是权威内存状态；
- 额外查询只增加延迟和负载。

写成功由事务和受影响行数保证，不需要用“总是回读”证明数据库写对了。

## 9. 删除、归档和保留

先问业务含义：

- **Cancel/Archive/Deactivate：** 业务可见状态，应进入领域模型和事件。
- **Soft delete：** 基础设施保留策略，适合恢复、审计或延迟清理，但会影响唯一约束、查询和隐私删除。
- **Hard delete：** 适合无恢复需求、合规删除或清理派生数据。
- **Tombstone：** 分布式同步/事件场景用于传播删除事实。

不要全局“永远软删”。每类数据明确恢复、审计、保留期限、唯一性和 GDPR/隐私要求，并测试所有查询是否正确处理隐藏记录。

## 10. 跨聚合与跨服务事务

- 同数据库、同上下文且业务必须原子：可用本地事务，但重新检查聚合边界。
- 跨聚合可短暂不一致：提交一个聚合 + Outbox，异步驱动后续动作。
- 跨服务：不共享数据库事务；使用 Saga/Process Manager、幂等和补偿。
- 对不可补偿动作（例如真实资金划拨）使用明确状态机、授权/捕获等领域协议，而非假设“回滚一切”。

## 11. 数据迁移

采用 expand/contract：

1. 添加兼容字段/表；
2. 新旧代码可同时运行；
3. 回填并监控；
4. 切换读写；
5. 移除旧 schema。

领域规则变更需考虑历史数据、旧事件和正在执行的长流程。迁移脚本和 mapper 都要有测试。
