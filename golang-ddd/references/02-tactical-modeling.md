# 战术建模：九类模式的 Go 实践

本页覆盖 Value Object、Entity、Domain Service、Domain Event、Module、Aggregate、Factory、Repository、Specification，并给出适用边界。

## 1. Value Object（值对象）

用值对象表达一个有业务意义、按值相等且没有独立身份的概念，例如金额、邮箱、日期区间、地址和数量。

```go
type Money struct {
    minor    int64
    currency Currency
}

func NewMoney(minor int64, currency Currency) (Money, error) {
    if minor < 0 {
        return Money{}, ErrNegativeMoney
    }
    if currency == "" {
        return Money{}, ErrMissingCurrency
    }
    return Money{minor: minor, currency: currency}, nil
}

func (m Money) Add(other Money) (Money, error) {
    if m.currency != other.currency {
        return Money{}, ErrCurrencyMismatch
    }
    return NewMoney(m.minor+other.minor, m.currency)
}
```

规则：

- 字段私有，构造函数验证；零值只有在业务上有效时才允许直接使用。
- 使用值接收者并返回新值，避免共享可变状态。
- 暴露业务操作，而非纯格式化工具集合。
- 金额使用最小货币单位整数或明确舍入规则的 decimal；禁止 `float64` 承担金额不变量。
- 不在值对象内部调用 `time.Now()`、网络或数据库；把“今天”等事实作为参数传入。

当一个对象需要独立追踪、被多个对象共享并随时间变化时，它可能在该上下文中是实体；同一概念在另一个上下文可以仍是值对象。

## 2. Entity（实体）

实体由身份和连续生命周期定义。数据库表或 ORM model 不自动等于领域实体。

```go
type Subscription struct {
    id       SubscriptionID
    status   Status
    renewsAt time.Time
}

func (s *Subscription) Cancel(now time.Time) error {
    if s.status != Active {
        return ErrNotActive
    }
    if now.After(s.renewsAt) {
        return ErrAlreadyExpired
    }
    s.status = Canceled
    return nil
}
```

规则：

- 身份使用领域类型，如 `OrderID`，而不是到处传播裸 `string`。
- 私有字段保护状态；不要生成通用 setter。
- 方法名体现业务意图和状态迁移。
- 构造时保证新实体有效，更新时只检查受影响的不变量。
- `CreatedAt`、`UpdatedAt` 只有在领域确实使用时才属于实体；纯审计字段可留在持久化模型。
- 不带 `gorm`、`db`、`json`、protobuf 等适配器标签。

## 3. Aggregate（聚合）

聚合是一组作为一致性和事务单位修改的实体和值对象；聚合根是唯一外部修改入口。

```go
type Order struct {
    id      OrderID
    status  OrderStatus
    lines   []OrderLine
    total   Money
    version int64
}

func (o *Order) AddItem(productID ProductID, price Money, qty int) error {
    if o.status != Draft {
        return ErrOrderNotDraft
    }
    // 校验重复商品、数量、币种并更新 total。
    return nil
}
```

规则：

- 以不变量和并发冲突定义边界，不以对象关系图定义。
- 通过根修改内部实体；内部集合返回副本，避免调用者绕过不变量。
- 其他聚合只引用 ID；需要外部事实时由应用层先查询并作为参数传入。
- 一个命令默认只保存一个聚合。确需同事务修改多个聚合时，要说明业务不变量和锁冲突代价。
- 使用 `version` 做乐观并发控制，而不是悄悄覆盖并发更新。
- 聚合记录领域事件，不直接发布网络消息。

## 4. Domain Service（领域服务）

领域服务承载“确属业务规则，但无法自然放在单个实体或值对象上”的无状态操作。

```go
type PricingPolicy interface {
    Price(cart CartSnapshot, customer CustomerTier) (Money, error)
}
```

优先顺序：

1. 能放在值对象或实体行为上，就放在那里。
2. 简单纯规则使用包级函数。
3. 需要策略替换时使用小接口或无状态 struct。
4. 涉及数据库、HTTP、消息、事务和鉴权的编排通常属于应用服务，而不是领域服务。

领域服务可以依赖“领域事实端口”，但要谨慎：如果它只是从仓储取数据再调用实体，多半应该移到应用层。不要创建一个装满所有逻辑的 `XxxDomainService` 来重新制造贫血模型。

## 5. Domain Event（领域事件）

领域事件是业务已发生的事实，使用过去式，例如 `OrderPlaced`、`PaymentFailed`。

```go
type OrderPlaced struct {
    OrderID   OrderID
    CustomerID CustomerID
    Total     Money
    OccurredAt time.Time
}
```

规则：

- 不可变，包含消费者理解事实所需的最少业务数据。
- 数据库 `row_inserted`、缓存失效不是领域事件。
- 聚合只记录事件；应用层在事务内保存 Outbox，提交后由 relay 发布。
- 内部领域事件与外部集成事件分离，后者需要稳定 schema、版本和兼容策略。
- 不用裸 goroutine 作为可靠异步机制。

## 6. Module（模块）

模块围绕高内聚的业务能力组织，而不是围绕设计模式名组织。

推荐：

```text
internal/ordering/domain
internal/ordering/app
internal/ordering/adapters/postgres
```

避免：

```text
internal/entities
internal/repositories
internal/services
internal/utils
internal/events
```

规则：

- 模块名来自统一语言，避免 `foo-and-bar`。
- 模块公开面尽量小；`internal` 阻止外部项目误用，但不能替代架构纪律。
- 模块通过应用端口、DTO 或集成事件协作，不共享内部实体。
- `platform` 只容纳真正技术性的共享能力，如 clock、tracing、数据库连接；不要把业务规则放进 `common`。
- 在模块根完成手工构造和依赖注入；依赖图很大时再引入 Wire 等工具。

## 7. Factory（工厂）

普通创建使用惯用的 `NewX`。只有创建过程需要多步骤、多个变体、复杂策略或跨对象一致性时才引入命名工厂。

```go
type OrderFactory struct {
    ids   OrderIDGenerator
    clock Clock
}

func (f OrderFactory) Draft(customerID CustomerID, currency Currency) (*Order, error) {
    return NewOrder(f.ids.NewOrderID(), customerID, currency, f.clock.Now())
}
```

规则：

- ID、时间、随机数由边界注入，以便确定性测试。
- 工厂建立有效初始状态，不执行持久化和网络副作用。
- 数据库行与领域对象的转换是适配器 mapper，不是领域 factory。
- 不为每个 struct 创建 `Factory` 接口。

## 8. Repository（仓储）

仓储让应用把聚合视作集合，隐藏持久化细节。接口放在使用它的包中，通常是应用包；当仓储本身是领域服务直接需要的领域抽象时，才放在领域包。

```go
type OrderRepository interface {
    Get(ctx context.Context, id domain.OrderID) (*domain.Order, error)
    Add(ctx context.Context, order *domain.Order) error
    Save(ctx context.Context, order *domain.Order, expectedVersion int64) error
}
```

规则：

- 每个聚合/用例定义所需方法，不使用 `Repository[T]` 万能 CRUD。
- 查询列表、报表和搜索可走专用 read store，不强行返回聚合。
- 数据库、缓存和外部 API 不都叫 repository：远程系统通常是 gateway/client，缓存可作为 decorator。
- 显式 mapper 转换持久化 model 与领域对象。
- 跨仓储事务由应用层 Unit of Work 管理；仓储内部事务只处理该仓储单次原子实现细节。
- `Get` 未找到返回可用 `errors.Is` 判断的错误；`Find` 可使用 `(value, found, error)` 等明确语义。

## 9. Specification / Policy（规格与策略）

Specification 适合可命名、可复用、可组合的业务判定：

```go
type Eligibility interface {
    IsSatisfiedBy(candidate Candidate) bool
}
```

使用前先问：

- 一个具名函数是否已经足够？
- 规则是否真正需要 `And` / `Or` / `Not` 组合？
- 它表达业务资格，还是只是在拼 SQL？

建议：

- 写侧业务规则可用具名 predicate、policy 或 specification。
- 读侧过滤使用应用层 query/filter DTO，再由适配器翻译为 SQL。
- 不把表名、列名、JOIN、ORM expression 暴露到领域包。
- 复杂规则需要失败原因时返回结构化结果，而非只有 `bool`。

## 模式选择速查

| 需要 | 首选 |
|---|---|
| 有意义的标量/组合值 | Value Object |
| 有身份和生命周期 | Entity |
| 一次事务维护一组不变量 | Aggregate |
| 跨对象的纯业务规则 | 函数或 Domain Service |
| 已发生的业务事实 | Domain Event |
| 高内聚业务能力 | Module |
| 复杂创建 | Factory |
| 聚合持久化抽象 | Repository |
| 可复用/组合判定 | Policy/Specification |
