package domain

import "math"

// Currency is the ISO-like code understood by this bounded context.
type Currency string

const (
	CurrencyCNY Currency = "CNY"
	CurrencyUSD Currency = "USD"
)

// Money is an immutable value object represented in minor units.
type Money struct {
	minor    int64
	currency Currency
}

func NewMoney(minor int64, currency Currency) (Money, error) {
	if currency == "" {
		return Money{}, ErrMissingCurrency
	}
	if minor < 0 {
		return Money{}, ErrNegativeMoney
	}
	return Money{minor: minor, currency: currency}, nil
}

func (m Money) Minor() int64 {
	return m.minor
}

func (m Money) Currency() Currency {
	return m.currency
}

func (m Money) IsZero() bool {
	return m.minor == 0
}

func (m Money) Add(other Money) (Money, error) {
	if m.currency != other.currency {
		return Money{}, ErrCurrencyMismatch
	}
	if other.minor > math.MaxInt64-m.minor {
		return Money{}, ErrMoneyOverflow
	}
	return NewMoney(m.minor+other.minor, m.currency)
}

func (m Money) Multiply(quantity int) (Money, error) {
	if quantity <= 0 {
		return Money{}, ErrInvalidQuantity
	}
	q := int64(quantity)
	if m.minor > 0 && q > math.MaxInt64/m.minor {
		return Money{}, ErrMoneyOverflow
	}
	return NewMoney(m.minor*q, m.currency)
}
