package domain

import "time"

type OrderID string
type CustomerID string
type ProductID string

type OrderStatus string

const (
	OrderStatusDraft  OrderStatus = "draft"
	OrderStatusPlaced OrderStatus = "placed"
)

// OrderLine is an entity inside the Order aggregate. ProductID is unique here.
type OrderLine struct {
	productID ProductID
	unitPrice Money
	quantity  int
}

func (l OrderLine) ProductID() ProductID { return l.productID }
func (l OrderLine) UnitPrice() Money     { return l.unitPrice }
func (l OrderLine) Quantity() int        { return l.quantity }

// Order is the aggregate root and the consistency boundary for placing an order.
type Order struct {
	id         OrderID
	customerID CustomerID
	status     OrderStatus
	lines      []OrderLine
	total      Money
	version    int64
	events     []Event
}

func NewOrder(id OrderID, customerID CustomerID, currency Currency) (*Order, error) {
	if id == "" {
		return nil, ErrMissingOrderID
	}
	if customerID == "" {
		return nil, ErrMissingCustomerID
	}
	zero, err := NewMoney(0, currency)
	if err != nil {
		return nil, err
	}
	return &Order{
		id:         id,
		customerID: customerID,
		status:     OrderStatusDraft,
		total:      zero,
	}, nil
}

func (o *Order) AddItem(productID ProductID, unitPrice Money, quantity int) error {
	if o.status != OrderStatusDraft {
		return ErrOrderNotDraft
	}
	if productID == "" {
		return ErrMissingProductID
	}
	if unitPrice.Minor() <= 0 {
		return ErrNonPositivePrice
	}
	if quantity <= 0 {
		return ErrInvalidQuantity
	}
	if unitPrice.Currency() != o.total.Currency() {
		return ErrCurrencyMismatch
	}
	for _, line := range o.lines {
		if line.productID == productID {
			return ErrDuplicateProduct
		}
	}

	lineTotal, err := unitPrice.Multiply(quantity)
	if err != nil {
		return err
	}
	newTotal, err := o.total.Add(lineTotal)
	if err != nil {
		return err
	}

	// Mutate only after every rule and calculation succeeds.
	o.lines = append(o.lines, OrderLine{
		productID: productID,
		unitPrice: unitPrice,
		quantity:  quantity,
	})
	o.total = newTotal
	return nil
}

func (o *Order) Place(at time.Time) error {
	if o.status != OrderStatusDraft {
		return ErrOrderNotDraft
	}
	if len(o.lines) == 0 {
		return ErrEmptyOrder
	}
	if at.IsZero() {
		return ErrMissingEventTime
	}

	o.status = OrderStatusPlaced
	o.version++
	o.events = append(o.events, OrderPlaced{
		orderID:    o.id,
		customerID: o.customerID,
		total:      o.total,
		version:    o.version,
		occurredAt: at,
	})
	return nil
}

func (o *Order) ID() OrderID            { return o.id }
func (o *Order) CustomerID() CustomerID { return o.customerID }
func (o *Order) Status() OrderStatus    { return o.status }
func (o *Order) Total() Money           { return o.total }
func (o *Order) Version() int64         { return o.version }

// Lines returns a copy so callers cannot mutate aggregate internals.
func (o *Order) Lines() []OrderLine {
	return append([]OrderLine(nil), o.lines...)
}

// PullEvents transfers pending events to the application layer.
func (o *Order) PullEvents() []Event {
	events := append([]Event(nil), o.events...)
	o.events = nil
	return events
}
