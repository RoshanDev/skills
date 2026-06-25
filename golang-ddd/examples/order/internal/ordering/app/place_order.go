package app

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"example.com/golang-ddd-skill/order/internal/ordering/domain"
)

var (
	ErrMissingMessageID = errors.New("message ID generator returned an empty ID")
	ErrUnknownEvent     = errors.New("unknown domain event")
)

type PlaceOrderItem struct {
	ProductID      string
	UnitPriceMinor int64
	Quantity       int
}

type PlaceOrder struct {
	CustomerID string
	Currency   domain.Currency
	Items      []PlaceOrderItem
}

type PlaceOrderResult struct {
	OrderID domain.OrderID
}

// Clock and IDGenerator make nondeterministic inputs explicit and testable.
type Clock interface {
	Now() time.Time
}

type IDGenerator interface {
	NewOrderID() domain.OrderID
	NewMessageID() string
}

// These ports are owned by the application package that consumes them.
type OrderRepository interface {
	Add(ctx context.Context, order *domain.Order) error
}

type Outbox interface {
	Append(ctx context.Context, messages ...IntegrationMessage) error
}

type Tx interface {
	Orders() OrderRepository
	Outbox() Outbox
}

type UnitOfWork interface {
	WithinTransaction(ctx context.Context, fn func(context.Context, Tx) error) error
}

type IntegrationMessage struct {
	EventID          string
	EventType        string
	AggregateType    string
	AggregateID      string
	AggregateVersion int64
	OccurredAt       time.Time
	Payload          []byte
}

type PlaceOrderHandler struct {
	uow   UnitOfWork
	clock Clock
	ids   IDGenerator
}

func NewPlaceOrderHandler(uow UnitOfWork, clock Clock, ids IDGenerator) *PlaceOrderHandler {
	if uow == nil || clock == nil || ids == nil {
		panic("PlaceOrderHandler dependencies must not be nil")
	}
	return &PlaceOrderHandler{uow: uow, clock: clock, ids: ids}
}

func (h *PlaceOrderHandler) Handle(ctx context.Context, cmd PlaceOrder) (PlaceOrderResult, error) {
	order, err := domain.NewOrder(
		h.ids.NewOrderID(),
		domain.CustomerID(cmd.CustomerID),
		cmd.Currency,
	)
	if err != nil {
		return PlaceOrderResult{}, fmt.Errorf("new order: %w", err)
	}

	for _, item := range cmd.Items {
		price, err := domain.NewMoney(item.UnitPriceMinor, cmd.Currency)
		if err != nil {
			return PlaceOrderResult{}, fmt.Errorf("new item price: %w", err)
		}
		if err := order.AddItem(
			domain.ProductID(item.ProductID),
			price,
			item.Quantity,
		); err != nil {
			return PlaceOrderResult{}, fmt.Errorf("add item %q: %w", item.ProductID, err)
		}
	}

	if err := order.Place(h.clock.Now()); err != nil {
		return PlaceOrderResult{}, fmt.Errorf("place order: %w", err)
	}

	messages, err := h.toIntegrationMessages(order.PullEvents())
	if err != nil {
		return PlaceOrderResult{}, err
	}

	if err := h.uow.WithinTransaction(ctx, func(ctx context.Context, tx Tx) error {
		if err := tx.Orders().Add(ctx, order); err != nil {
			return fmt.Errorf("add order: %w", err)
		}
		if err := tx.Outbox().Append(ctx, messages...); err != nil {
			return fmt.Errorf("append outbox: %w", err)
		}
		return nil
	}); err != nil {
		return PlaceOrderResult{}, fmt.Errorf("place order transaction: %w", err)
	}

	return PlaceOrderResult{OrderID: order.ID()}, nil
}

func (h *PlaceOrderHandler) toIntegrationMessages(events []domain.Event) ([]IntegrationMessage, error) {
	messages := make([]IntegrationMessage, 0, len(events))
	for _, event := range events {
		switch event := event.(type) {
		case domain.OrderPlaced:
			eventID := h.ids.NewMessageID()
			if eventID == "" {
				return nil, ErrMissingMessageID
			}
			payload, err := json.Marshal(struct {
				OrderID    string          `json:"order_id"`
				CustomerID string          `json:"customer_id"`
				TotalMinor int64           `json:"total_minor"`
				Currency   domain.Currency `json:"currency"`
			}{
				OrderID:    string(event.OrderID()),
				CustomerID: string(event.CustomerID()),
				TotalMinor: event.Total().Minor(),
				Currency:   event.Total().Currency(),
			})
			if err != nil {
				return nil, fmt.Errorf("marshal %s: %w", event.EventName(), err)
			}
			messages = append(messages, IntegrationMessage{
				EventID:          eventID,
				EventType:        "ordering.order-placed.v1",
				AggregateType:    "order",
				AggregateID:      string(event.OrderID()),
				AggregateVersion: event.AggregateVersion(),
				OccurredAt:       event.OccurredAt(),
				Payload:          payload,
			})
		default:
			return nil, fmt.Errorf("%w: %T", ErrUnknownEvent, event)
		}
	}
	return messages, nil
}
