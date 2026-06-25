# Go 架构与包设计

## 1. 依赖方向

依赖指向稳定的业务核心：

```text
transport ─┐
postgres  ─┼─> app ─> domain
messaging ─┘
```

- `domain` 不导入 `app` 或适配器。
- `app` 可导入 `domain`，并声明自己需要的端口。
- 适配器实现端口并负责技术转换。
- 入口/`module.go` 组装具体实现。

不要把“基础设施在最底层”理解为领域必须导入数据库接口包。依赖反转依靠消费者侧接口完成。

## 2. 推荐结构

### 业务模块优先

```text
cmd/
  api/main.go
  worker/main.go
internal/
  ordering/
    domain/
      order.go
      money.go
      event.go
    app/
      place_order.go
      get_order.go
      ports.go
    adapters/
      http/
      postgres/
      messaging/
    module.go
  inventory/
    ...
  platform/
    clock/
    observability/
```

优点：

- 改一个业务能力时，大部分文件相邻。
- 模块所有权和未来抽取边界清楚。
- 避免全局层目录演变成耦合中心。

### 已采用 Kratos 等框架时

`internal/service`、`internal/biz`、`internal/data` 可以保留，但需明确：

- `service` 只做 transport DTO 与应用调用转换；
- `biz` 内可继续按业务能力拆包，避免单一巨型包；
- `data` 实现 `biz/app` 声明的端口并映射领域对象；
- 不因模板结构而把所有业务塞进 usecase service。

### 小服务

小型服务可以更扁平：

```text
internal/order/
  order.go
  place.go
  postgres.go
  http.go
```

只要文件依赖清楚、领域规则不被框架污染，不必为了 DDD 建空目录。

## 3. 包命名

- 使用简短、小写、单数且有业务意义的名称：`order`、`billing`、`pricing`。
- 避免 `util`、`common`、`misc`、`types`、`interfaces`、全局 `model`。
- 不把包名重复进类型：`order.Order` 优于 `order.OrderEntity`。
- 包公开 API 越小越好。模块内部实现可放 `internal` 或保持未导出。
- `cmd/<binary>` 只负责配置、组装、启动和优雅关闭，不承载业务逻辑。

## 4. 接口

Go 接口通常由消费者声明，并保持最小：

```go
// app/place_order.go
type OrderRepository interface {
    Add(ctx context.Context, order *domain.Order) error
}
```

```go
// adapters/postgres/order_repository.go
type OrderRepository struct { /* concrete dependencies */ }

func NewOrderRepository(...) *OrderRepository { ... }
```

规则：

- 不为“可 mock”而在实现包提前创建接口。
- 不要求每个 struct 有对应接口。
- 只有一个真实实现也可以有接口，但必须由用例的替换点驱动。
- 接口方法数量小，按用例拆分；调用方可组合多个窄接口。
- 构造函数返回具体类型，调用方按需要接收为接口。

## 5. Context

`context.Context` 用于跨进程/资源边界传递取消、deadline、认证和 tracing：

```go
func (h Handler) Handle(ctx context.Context, cmd Command) error
func (r Repository) Get(ctx context.Context, id OrderID) (*Order, error)
```

规则：

- 作为第一个参数显式传递。
- 不存进长期 struct 字段。
- 不放进领域实体或值对象；纯业务计算不应依赖请求生命周期。
- 仓储、HTTP、RPC、消息、数据库必须继续传递调用方的 `ctx`。
- 不在仓储内部用 `context.Background()` 偷换调用者上下文。
- 真正独立于请求的 worker 应在入口创建自己的根 context，并负责关闭。

## 6. 错误

### 领域错误

表达稳定、可预期的业务失败：

```go
var ErrOrderNotDraft = errors.New("order is not draft")

type CreditLimitExceeded struct {
    Limit     Money
    Requested Money
}
```

- 调用方需要分支时，提供 sentinel、类型化错误或稳定错误码。
- 错误文本用于人读，控制流使用 `errors.Is` / `errors.As`。
- 不在领域层生成 HTTP status、gRPC code 或数据库错误。

### 适配器错误

添加操作上下文并保留错误链：

```go
return fmt.Errorf("load order %s: %w", id, err)
```

统一在 transport 边界把领域/应用错误映射为协议响应。避免每层重复日志；通常在拥有请求上下文和最终处置责任的边界记录一次。

## 7. DTO、领域对象和持久化模型

三者职责不同：

```text
HTTP/protobuf DTO <-> application input/output <-> domain model
                                            ^
                                            |
                                  persistence model
```

- DTO 适配外部契约、可选字段、版本和序列化。
- 领域对象维护不变量和行为。
- persistence model 适配列、null、join、扫描和迁移。
- 显式 mapper 放在对应适配器，避免反射“自动映射”掩盖语义变化。
- 不把领域对象直接 JSON 编码成公共 API；否则内部重构会破坏契约。

## 8. 构造与依赖注入

优先手工构造：

```go
func NewModule(db *sql.DB, publisher Publisher, clock Clock) *Module {
    repo := postgres.NewOrderRepository(db)
    uow := postgres.NewUnitOfWork(db)
    place := app.NewPlaceOrder(uow, clock)
    handler := httpapi.NewHandler(place)
    return &Module{Handler: handler}
}
```

- 依赖从入口向内显式传递。
- 构造函数验证必需依赖，避免运行时 nil panic。
- Wire 等代码生成适合依赖图很大、构造重复明显的项目；不要使用 service locator 或全局容器隐藏依赖。
- 领域对象的创建参数不是 DI 容器依赖。

## 9. 时间、ID 和随机性

让测试可确定：

```go
type Clock interface { Now() time.Time }
type OrderIDGenerator interface { NewOrderID() domain.OrderID }
```

- 在应用/工厂边界调用并把值传给领域行为。
- 不在实体方法深处调用 `time.Now()`、`uuid.New()`、`rand.Intn()`。
- 数据库生成 ID 或时间也可以，但要把它作为明确架构选择，并处理回读和测试代价。

## 10. 写侧和读侧

写侧围绕业务意图、聚合和不变量；读侧围绕消费者需要：

```go
type PlaceOrder struct { ... }        // command
func (h PlaceOrderHandler) Handle(...) ...

type OrderDetailsQuery struct { ... } // query input
func (q PostgresQueries) OrderDetails(...) (OrderView, error)
```

- 读侧可直接查询 join/view，不必加载聚合。
- CQRS 不等于必须两套数据库、总线或框架。
- 简单 `Get`/`List` 可直接方法调用。
- 命令名使用业务动词，避免所有操作都是 `Create/Update/Delete`。

## 11. 架构守护

可执行本技能的：

```bash
python3 scripts/check_domain_imports.py /path/to/repo
```

再结合项目 lint/CI：

- 禁止领域包导入 transport、数据库和消息客户端；
- 禁止跨业务模块导入对方 `domain`/`adapters` 内部；
- 检查循环依赖和公开 API 膨胀；
- 对关键规则写架构测试或静态检查，避免只靠文档。
