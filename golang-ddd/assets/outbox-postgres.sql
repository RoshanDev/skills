-- PostgreSQL Transactional Outbox reference template.
-- Adapt identifiers, retention, partitioning and payload rules to the project.
-- Generate event_id in the application and insert this row in the SAME
-- transaction as the aggregate write.

CREATE TABLE IF NOT EXISTS outbox_messages (
    event_id           uuid PRIMARY KEY,
    event_type         text NOT NULL,
    aggregate_type     text NOT NULL,
    aggregate_id       text NOT NULL,
    aggregate_version  bigint NOT NULL CHECK (aggregate_version >= 0),
    occurred_at        timestamptz NOT NULL,
    available_at       timestamptz NOT NULL DEFAULT now(),
    producer            text NOT NULL,
    correlation_id     text,
    causation_id       text,
    headers             jsonb NOT NULL DEFAULT '{}'::jsonb,
    payload             jsonb NOT NULL,

    status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'publishing', 'published', 'dead')),
    attempts            integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    locked_at           timestamptz,
    locked_by           text,
    published_at        timestamptz,
    last_error          text,
    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS outbox_pending_idx
    ON outbox_messages (available_at, occurred_at, event_id)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS outbox_aggregate_order_idx
    ON outbox_messages (aggregate_type, aggregate_id, aggregate_version, occurred_at);

-- Claim a batch. Run inside a short DB transaction.
-- Parameters:
--   $1 = batch size
--   $2 = worker ID
--   $3 = lock timeout interval, e.g. '1 minute'
WITH candidate AS (
    SELECT event_id
    FROM outbox_messages
    WHERE (
        status = 'pending'
        OR (
            status = 'publishing'
            AND locked_at < now() - $3::interval
        )
    )
      AND available_at <= now()
    ORDER BY occurred_at, event_id
    LIMIT $1
    FOR UPDATE SKIP LOCKED
)
UPDATE outbox_messages AS o
SET status = 'publishing',
    locked_at = now(),
    locked_by = $2,
    attempts = o.attempts + 1
FROM candidate
WHERE o.event_id = candidate.event_id
RETURNING o.*;

-- After broker acknowledgement:
-- UPDATE outbox_messages
-- SET status = 'published', published_at = now(), locked_at = NULL,
--     locked_by = NULL, last_error = NULL
-- WHERE event_id = $1 AND status = 'publishing' AND locked_by = $2;

-- On retryable failure, calculate backoff in the worker and pass $3:
-- UPDATE outbox_messages
-- SET status = 'pending', available_at = $3, locked_at = NULL,
--     locked_by = NULL, last_error = $4
-- WHERE event_id = $1 AND status = 'publishing' AND locked_by = $2;

-- On terminal failure:
-- UPDATE outbox_messages
-- SET status = 'dead', locked_at = NULL, locked_by = NULL, last_error = $3
-- WHERE event_id = $1 AND status = 'publishing' AND locked_by = $2;

-- Retention example (run in bounded batches or use partitioning):
-- DELETE FROM outbox_messages
-- WHERE status = 'published' AND published_at < now() - interval '30 days';

-- Consumers should maintain an inbox table in the same DB as their local
-- business state. Insert event_id and apply the business change in one local
-- transaction; a duplicate event_id means the message was already handled.
CREATE TABLE IF NOT EXISTS inbox_messages (
    consumer           text NOT NULL,
    event_id           uuid NOT NULL,
    processed_at       timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer, event_id)
);
