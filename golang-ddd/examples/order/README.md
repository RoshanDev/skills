# Order example

A dependency-free, compilable example of a small Go DDD write use case.

It demonstrates:

- immutable `Money` value object using minor units;
- an `Order` aggregate with private state and behavior-oriented methods;
- domain events recorded by the aggregate, not published by it;
- consumer-owned application ports;
- an application-level Unit of Work that atomically saves the aggregate and Outbox messages;
- injected clock and ID generators;
- table/unit tests with no mock framework.

Run:

```bash
go test -race ./...
```

The example intentionally omits HTTP, a concrete database adapter, a broker and command idempotency. Production retryable write endpoints should add the idempotency protocol described in `../../../references/05-events-idempotency.md`.
