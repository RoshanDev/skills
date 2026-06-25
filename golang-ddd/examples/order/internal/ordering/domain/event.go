package domain

import "time"

// Event is a domain fact recorded by an aggregate.
type Event interface {
	EventName() string
	OccurredAt() time.Time
	isDomainEvent()
}

// OrderPlaced records that a valid draft became a placed order.
type OrderPlaced struct {
	orderID    OrderID
	customerID CustomerID
	total      Money
	version    int64
	occurredAt time.Time
}

func (OrderPlaced) EventName() string { return "OrderPlaced" }
func (OrderPlaced) isDomainEvent()    {}

func (e OrderPlaced) OrderID() OrderID        { return e.orderID }
func (e OrderPlaced) CustomerID() CustomerID  { return e.customerID }
func (e OrderPlaced) Total() Money            { return e.total }
func (e OrderPlaced) AggregateVersion() int64 { return e.version }
func (e OrderPlaced) OccurredAt() time.Time   { return e.occurredAt }
