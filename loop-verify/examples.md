# Loop Verify — Examples

Concrete end-to-end examples showing the workflow in action. The agent should read this file when it needs to see how templates are filled in for real tasks.

---

## Example 1: S1 — Add rate limiting to API endpoint

**User request:** "Add rate limiting to the /api/login endpoint — 5 attempts per minute per IP."

### Step 1: Task Routing

```
Task class: S1 normal
Reason: single endpoint change, limited files, testable with unit tests.
```

### Step 2: Recon Summary

```text
Recon summary:
- Relevant files: handlers/login.go, middleware/ratelimit.go (exists but unused)
- Existing patterns: middleware chain in router.go, existing RateLimiter struct
- Likely test commands: go test ./handlers/... ./middleware/...
- Risk areas: shared state across goroutines (needs mutex or atomic)
- Unknowns that need user input: none — existing middleware covers the pattern
```

No user input needed. Skip grilling. Proceed to contract.

### Step 3: Goal Contract (S1 Lightweight)

```md
# Goal Contract

## Intent
Add per-IP rate limiting to the /api/login endpoint: max 5 requests per 60-second sliding window. Return HTTP 429 with Retry-After header when exceeded.

## Scope
- In: /api/login handler, middleware/ratelimit.go, router registration
- Out: other endpoints, auth logic, session management

## Acceptance Criteria
- AC-001: 5th request within 60s returns 200; 6th returns 429
- AC-002: 429 response includes Retry-After header (seconds until oldest request expires)
- AC-003: Rate limit is per-IP, not global
- AC-004: Rate limiter is safe for concurrent access

## Verification
| AC | Evidence |
|----|----------|
| AC-001 | TestRateLimitBlocksSixthRequest |
| AC-002 | TestRateLimitRetryAfterHeader |
| AC-003 | TestRateLimitPerIP |
| AC-004 | TestRateLimitConcurrentAccess (go test -race) |
```

### Step 4: Implementation Plan

```md
# Plan

## Files to change
- middleware/ratelimit.go — expose NewIPLimiter(maxReqs int, window time.Duration)
- handlers/login.go — wrap handler with limiter middleware
- router.go — register middleware for /api/login route

## Steps
1. Add NewIPLimiter to middleware/ratelimit.go (uses sync.Map + per-IP slice of timestamps)
2. Add RateLimitMiddleware that checks limiter and sets Retry-After on 429
3. Wrap login handler in router.go
4. Write tests for AC-001 through AC-004

## Tests
- AC-001 -> TestRateLimitBlocksSixthRequest
- AC-002 -> TestRateLimitRetryAfterHeader
- AC-003 -> TestRateLimitPerIP (two different IPs, only one rate-limited)
- AC-004 -> TestRateLimitConcurrentAccess (goroutines + race detector)

## Validation commands
- go test -race ./middleware/... ./handlers/...

## Rollback
- Revert middleware registration in router.go (single line change)
```

### Step 5: Verification Loop (sample output)

```text
Gate 1 — Diff scope:
  middleware/ratelimit.go  (+45 lines)
  handlers/login.go        (+3 lines)
  router.go                (+1 line)
  middleware/ratelimit_test.go (new, +120 lines)
  ✓ Only planned files changed.

Gate 2 — Build/Lint/Test:
  go test -race ./middleware/... ./handlers/... → exit 0, 12 tests passed
  go vet ./... → exit 0

Gate 3 — AC coverage:
  AC-001: PASS via TestRateLimitBlocksSixthRequest
  AC-002: PASS via TestRateLimitRetryAfterHeader
  AC-003: PASS via TestRateLimitPerIP
  AC-004: PASS via TestRateLimitConcurrentAccess

Gate 4 — Drift check:
  ✓ Implementation matches intent. No assumptions violated.
  ✓ No out-of-scope changes.

Status: PASS
```

---

## Example 2: S2 — Migrate user table from UUID to bigint primary key

**User request:** "We need to change the users table PK from UUID to bigint for performance. All foreign keys need updating too."

### Step 1: Task Routing

```
Task class: S2 risky
Reason: DB schema migration, foreign key cascade, potential data loss, rollback complexity.
```

### Step 2: Recon Summary

```text
Recon summary:
- Relevant files: migrations/042_create_users.sql, models/user.go, repositories/*.go
- Existing patterns: sequential migration numbering, golang-migrate, existing bigint PKs in other tables
- Likely test commands: make test-integration (uses testcontainers for Postgres)
- Risk areas: FK cascade across 6 dependent tables, application code referencing UUID type
- Unknowns: should we preserve old UUID as a column for backward compat? Ask user.
```

### Step 3: Grill (one question)

```text
Q: Should the old UUID column be preserved (as uuid_legacy) for a deprecation period,
   or dropped entirely in this migration?
Recommended: Preserve as uuid_legacy (nullable, no index). Drop in a separate migration
after all consumers are verified.
Impact: If dropped now, any missed FK or external system referencing UUID breaks permanently.
Reply: A) accept  B) different option  C) defer
```

User replies: A) accept.

### Step 4: Goal Contract (S2 Full)

```md
# Goal Contract

## Intent
Migrate users table PK from UUID to auto-incrementing bigint. Preserve old UUID as
uuid_legacy column (nullable). Update all 6 dependent FK references.

## Scope
- In: users table, orders.user_id, sessions.user_id, profiles.user_id, audit_log.user_id,
  api_keys.user_id, notifications.user_id; models/user.go type change; repository queries
- Out: auth logic, API response format (still serialize UUID from uuid_legacy),
  external integrations, admin panel

## Acceptance Criteria
- AC-001: users.id is bigint GENERATED ALWAYS AS IDENTITY
- AC-002: users.uuid_legacy contains original UUID values (no data loss)
- AC-003: All 6 FK columns updated to bigint, referencing users.id
- AC-004: Application compiles and all integration tests pass
- AC-005: Migration is reversible (DOWN migration restores UUID PK)

## Verification
| AC | Evidence |
|----|----------|
| AC-001 | integration test: query pg_catalog for column type |
| AC-002 | integration test: count(uuid_legacy IS NOT NULL) = count(*) |
| AC-003 | integration test: query information_schema for FK constraints |
| AC-004 | make test-integration |
| AC-005 | Run UP then DOWN migration, verify schema matches original |

## Risk Register
| Risk | Mitigation |
|------|------------|
| Data loss during PK swap | Single transaction, uuid_legacy preserves old values |
| FK cascade failure | Add FK with ON DELETE CASCADE in same migration |
| App code still references UUID type | Grep for uuid.UUID in user-related code, update type assertions |
| Rollback needed in production | DOWN migration tested, backup before deploy |

## Constraints
- Files allowed: migrations/, models/user.go, repositories/*.go
- Forbidden: API response schemas, auth middleware, external integration configs
- Must use existing golang-migrate tooling

## Stop Conditions
- If a dependent table has a trigger or view referencing users.id, stop and report
- If integration tests fail after 3 repair attempts, escalate
```

### Step 5: Final Response (sample)

```md
# Result

Status: PASS

## AC Evidence
| AC | Status | Evidence |
|----|--------|----------|
| AC-001 | PASS | TestUsersPKIsBigint (pg_catalog check) |
| AC-002 | PASS | TestUUIDLegacyNoDataLoss (5000/5000 rows) |
| AC-003 | PASS | TestAllFKsUpdated (6/6 constraints verified) |
| AC-004 | PASS | make test-integration: 87 passed, 0 failed |
| AC-005 | PASS | UP→DOWN roundtrip: schema diff is empty |

## Commands run
| Command | Exit | Notes |
|---------|------|-------|
| migrate -path migrations -database $TEST_DB up | 0 | Applied 043 migration |
| make test-integration | 0 | 87 tests in 12.4s |
| migrate -path migrations -database $TEST_DB down 1 | 0 | DOWN verified |

## Diff scope
- Changed: migrations/043_users_pk_bigint.sql, models/user.go, repositories/user.go,
  repositories/order.go, repositories/session.go
- Out-of-scope: none

## Risks
- Production deploy requires table lock (~2s estimated for 50K rows). Schedule off-peak.
- uuid_legacy column should be dropped in a follow-up migration after 30-day deprecation.

## Follow-ups
- Drop uuid_legacy column after deprecation period
- Update API response to use bigint id instead of UUID
```

---

## Example 3: S0 — Fix typo in error message

**User request:** "The error message says 'sucess' instead of 'success' in the payment handler."

```
Task class: S0 trivial — single string change, zero risk.
Action: Skip to implementation. No contract, no plan.
```

```bash
# One-line fix, run existing test
sed -i 's/sucess/success/' handlers/payment.go
go test ./handlers/ -run TestPaymentErrorMessage
```

```text
Status: PASS
What changed: handlers/payment.go line 142 — typo fix
AC: (none — S0 does not require ACs)
```

---

## Anti-Pattern Examples

### Bad: Over-processing an S0 task

```text
User: "Fix the typo in the README"
Agent: "Let me produce a Goal Contract with Risk Register and Stop Conditions..."
```
Wrong — this is S0. Just fix it.

### Bad: Scope creep mid-execution

```text
User (during S1 implementation): "Oh, also add WebSocket support"
Agent: "Sure, I'll add that to the current contract..."
```
Wrong — record as Follow-up. The current contract is frozen.

### Bad: Self-certifying without evidence

```text
Agent: "All acceptance criteria are met. The implementation looks correct."
```
Wrong — no evidence shown. Must show test output, exit codes, and AC coverage.

### Bad: Silently changing semantics

```text
Agent changes a function from returning error to returning nil to make tests pass.
```
Wrong — this violates "minimal change" and "fail fast". Fix the test or raise the issue.
