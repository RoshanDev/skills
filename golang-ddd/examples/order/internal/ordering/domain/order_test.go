package domain

import (
	"errors"
	"math"
	"testing"
	"time"
)

func TestOrderPlaceRecordsBusinessEvent(t *testing.T) {
	order, err := NewOrder("ord-1", "customer-1", CurrencyCNY)
	if err != nil {
		t.Fatal(err)
	}
	price, err := NewMoney(2500, CurrencyCNY)
	if err != nil {
		t.Fatal(err)
	}
	if err := order.AddItem("product-1", price, 2); err != nil {
		t.Fatal(err)
	}

	at := time.Date(2026, 6, 25, 10, 0, 0, 0, time.UTC)
	if err := order.Place(at); err != nil {
		t.Fatal(err)
	}

	if got, want := order.Status(), OrderStatusPlaced; got != want {
		t.Fatalf("status = %q, want %q", got, want)
	}
	if got, want := order.Total().Minor(), int64(5000); got != want {
		t.Fatalf("total = %d, want %d", got, want)
	}

	events := order.PullEvents()
	if len(events) != 1 {
		t.Fatalf("events = %d, want 1", len(events))
	}
	placed, ok := events[0].(OrderPlaced)
	if !ok {
		t.Fatalf("event type = %T, want OrderPlaced", events[0])
	}
	if placed.OrderID() != "ord-1" || !placed.OccurredAt().Equal(at) {
		t.Fatalf("unexpected event: %#v", placed)
	}
	if len(order.PullEvents()) != 0 {
		t.Fatal("PullEvents must clear pending events")
	}
}

func TestOrderCannotBePlacedWithoutLines(t *testing.T) {
	order, err := NewOrder("ord-1", "customer-1", CurrencyCNY)
	if err != nil {
		t.Fatal(err)
	}

	err = order.Place(time.Now())
	if !errors.Is(err, ErrEmptyOrder) {
		t.Fatalf("error = %v, want ErrEmptyOrder", err)
	}
	if order.Status() != OrderStatusDraft {
		t.Fatal("failed behavior must not partially mutate aggregate")
	}
	if len(order.PullEvents()) != 0 {
		t.Fatal("failed behavior must not record an event")
	}
}

func TestLinesReturnsCopy(t *testing.T) {
	order, err := NewOrder("ord-1", "customer-1", CurrencyCNY)
	if err != nil {
		t.Fatal(err)
	}
	price, _ := NewMoney(100, CurrencyCNY)
	if err := order.AddItem("product-1", price, 1); err != nil {
		t.Fatal(err)
	}

	lines := order.Lines()
	lines[0].quantity = 999
	if got := order.Lines()[0].Quantity(); got != 1 {
		t.Fatalf("aggregate internals were mutated through returned slice: %d", got)
	}
}

func TestMoneyMultiplyDetectsOverflow(t *testing.T) {
	money, err := NewMoney(math.MaxInt64, CurrencyCNY)
	if err != nil {
		t.Fatal(err)
	}
	_, err = money.Multiply(2)
	if !errors.Is(err, ErrMoneyOverflow) {
		t.Fatalf("error = %v, want ErrMoneyOverflow", err)
	}
}
