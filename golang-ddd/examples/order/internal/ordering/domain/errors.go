package domain

import "errors"

var (
	ErrMissingCurrency   = errors.New("currency is required")
	ErrNegativeMoney     = errors.New("money cannot be negative")
	ErrCurrencyMismatch  = errors.New("currencies do not match")
	ErrMoneyOverflow     = errors.New("money arithmetic overflow")
	ErrInvalidQuantity   = errors.New("quantity must be positive")
	ErrMissingOrderID    = errors.New("order ID is required")
	ErrMissingCustomerID = errors.New("customer ID is required")
	ErrMissingProductID  = errors.New("product ID is required")
	ErrNonPositivePrice  = errors.New("unit price must be positive")
	ErrDuplicateProduct  = errors.New("product is already present in order")
	ErrOrderNotDraft     = errors.New("order is not draft")
	ErrEmptyOrder        = errors.New("order must contain at least one line")
	ErrMissingEventTime  = errors.New("event time is required")
)
