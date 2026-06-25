package app

import (
	"context"
	"encoding/json"
	"errors"
	"testing"
	"time"

	"example.com/golang-ddd-skill/order/internal/ordering/domain"
)

type fixedClock struct{ now time.Time }

func (c fixedClock) Now() time.Time { return c.now }

type fixedIDs struct {
	orderID   domain.OrderID
	messageID string
}

func (i fixedIDs) NewOrderID() domain.OrderID { return i.orderID }
func (i fixedIDs) NewMessageID() string       { return i.messageID }

type stagedOrderRepo struct {
	order *domain.Order
	err   error
}

func (r *stagedOrderRepo) Add(_ context.Context, order *domain.Order) error {
	if r.err != nil {
		return r.err
	}
	r.order = order
	return nil
}

type stagedOutbox struct {
	messages []IntegrationMessage
	err      error
}

func (o *stagedOutbox) Append(_ context.Context, messages ...IntegrationMessage) error {
	if o.err != nil {
		return o.err
	}
	o.messages = append(o.messages, messages...)
	return nil
}

type stagedTx struct {
	orders *stagedOrderRepo
	outbox *stagedOutbox
}

func (tx stagedTx) Orders() OrderRepository { return tx.orders }
func (tx stagedTx) Outbox() Outbox          { return tx.outbox }

type fakeUOW struct {
	outboxErr error
	committed bool
	order     *domain.Order
	messages  []IntegrationMessage
}

func (u *fakeUOW) WithinTransaction(ctx context.Context, fn func(context.Context, Tx) error) error {
	orders := &stagedOrderRepo{}
	outbox := &stagedOutbox{err: u.outboxErr}
	if err := fn(ctx, stagedTx{orders: orders, outbox: outbox}); err != nil {
		return err // staged state is discarded: rollback
	}
	u.committed = true
	u.order = orders.order
	u.messages = append([]IntegrationMessage(nil), outbox.messages...)
	return nil
}

func TestPlaceOrderCommitsAggregateAndOutboxTogether(t *testing.T) {
	uow := &fakeUOW{}
	at := time.Date(2026, 6, 25, 10, 0, 0, 0, time.UTC)
	h := NewPlaceOrderHandler(
		uow,
		fixedClock{now: at},
		fixedIDs{orderID: "ord-1", messageID: "evt-1"},
	)

	result, err := h.Handle(context.Background(), PlaceOrder{
		CustomerID: "customer-1",
		Currency:   domain.CurrencyCNY,
		Items: []PlaceOrderItem{{
			ProductID:      "product-1",
			UnitPriceMinor: 1250,
			Quantity:       2,
		}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !uow.committed {
		t.Fatal("transaction was not committed")
	}
	if result.OrderID != "ord-1" || uow.order == nil {
		t.Fatalf("unexpected result/order: %#v %#v", result, uow.order)
	}
	if len(uow.messages) != 1 {
		t.Fatalf("messages = %d, want 1", len(uow.messages))
	}
	message := uow.messages[0]
	if message.EventType != "ordering.order-placed.v1" || message.EventID != "evt-1" {
		t.Fatalf("unexpected message: %#v", message)
	}
	var payload struct {
		OrderID    string          `json:"order_id"`
		TotalMinor int64           `json:"total_minor"`
		Currency   domain.Currency `json:"currency"`
	}
	if err := json.Unmarshal(message.Payload, &payload); err != nil {
		t.Fatal(err)
	}
	if payload.OrderID != "ord-1" || payload.TotalMinor != 2500 || payload.Currency != domain.CurrencyCNY {
		t.Fatalf("unexpected payload: %#v", payload)
	}
}

func TestPlaceOrderRollsBackWhenOutboxFails(t *testing.T) {
	uow := &fakeUOW{outboxErr: errors.New("outbox unavailable")}
	h := NewPlaceOrderHandler(
		uow,
		fixedClock{now: time.Now()},
		fixedIDs{orderID: "ord-1", messageID: "evt-1"},
	)

	_, err := h.Handle(context.Background(), PlaceOrder{
		CustomerID: "customer-1",
		Currency:   domain.CurrencyCNY,
		Items: []PlaceOrderItem{{
			ProductID:      "product-1",
			UnitPriceMinor: 100,
			Quantity:       1,
		}},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	if uow.committed || uow.order != nil || len(uow.messages) != 0 {
		t.Fatal("aggregate write and outbox must roll back together")
	}
}
