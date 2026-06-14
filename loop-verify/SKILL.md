---
name: loop-verify
description: Use this skill for coding tasks that need clarified intent, frozen scope, small-step implementation, acceptance-criteria mapping, verification loops, and anti-overengineering review. Trigger for feature work, bug fixes, refactors, backend logic changes, multi-file changes, or any task where correctness matters. Do not use for pure Q&A or trivial one-line edits unless asked.
---

# Loop Verify

Lightweight loop-engineering workflow. Preserve intent, reduce scope drift, implement minimally, prove with executable evidence.

## Core Philosophy

- **Code is truth.** Tests passing = verified. Spec is a working claim, not a source of truth.
- **Spec is scaffolding.** Helps AI reach 80% on first pass, then its job is done. Do not maintain spec after delivery — stale spec poisons future agents.
- **More context, less control.** Give the agent rich context (repo structure, existing code, constraints), not rigid step-by-step chains. Spec detail is an inverse function of model capability.
- **One strong workflow, not stitched tools.** Prefer fewer contexts, smaller diffs, stronger gates.
- **Spec is a spectrum.** From a one-line intent to full acceptance criteria — match spec weight to task complexity. Plan Mode is lightweight spec-driven development, not "no spec".

## Task Routing

Before doing anything, classify the task and pick the lightest adequate process.

| Level | Description | Process |
|-------|-------------|---------|
| **S0** trivial | One-file, low risk (typo fix, copy change, config tweak) | Skip to implementation. No contract needed. |
| **S1** normal | Feature/fix with tests, limited files | Lightweight Goal Contract (intent + scope + ACs + verification). Implement and verify. |
| **S2** risky | Auth, payment, data migration, concurrency, security, public API, deployment, multi-service | Full Goal Contract + risk list + explicit test plan + verification loop. |
| **S3** architectural | Changes boundaries, contracts, storage model, service topology | Design review before implementation. Split into multiple S1/S2 slices — never one big pass. |

**Routing principle:** ~55% of daily tasks are S0/S1. Forcing heavy process on them is net-negative ROI. Spec intensity should be a function of task complexity, not a toggle. When in doubt, go lighter — you can always escalate.

**Context first:** Before asking the user anything, read existing project context: `CLAUDE.md`, `AGENTS.md`, architecture docs, invariants files. These are project-level specs — respect them and don't re-ask what they already answer.

## Hard Rules

### 1. Grill Before Building (when needed)

Only for S1+ where important choices remain open. Skip if context files answer the questions.

- Ask one question at a time; provide your recommended answer.
- Read the repo first — never ask what you can discover yourself.
- Prefer questions about irreversible decisions: business rules, compatibility, failure behavior, security boundary, data lifecycle, API shape, concurrency, rollout.
- Push back on vague answers with a concrete strawman.
- Stop grilling once the Goal Contract is implementable.

Question format:

```text
Q: [Question]
Recommended: [Recommendation]
Impact: [Consequence]
Reply: A) accept  B) different option  C) defer
```

### 2. Freeze Scope

Once a Goal Contract is approved: no new requirements mid-run. Record new requests as Follow-ups. Only reopen if the user explicitly changes scope.

### 3. Minimal Change

Always prefer the smallest correct change. Do not introduce new architecture, add dependencies, perform broad refactors, rewrite unrelated code, change public APIs, change DB schema/auth/billing/deployment, or "improve" naming/style outside touched code — unless explicitly required.

### 4. Fail Fast

If required information is missing or unverifiable: stop, state the blocker, give the smallest next decision needed. Never invent business behavior or pretend verification passed.

## Goal Contract

Produce before editing code (S1+). Keep as lean as possible — the contract is disposable scaffolding, not a persistent artifact.

**S1 — lightweight (enough for most tasks):**

```md
# Goal Contract

## Intent
[one paragraph: the user-visible outcome]

## Scope
- In: ...
- Out: ...

## Acceptance Criteria
- AC-001: ...
- AC-002: ...

## Verification
| AC | Evidence |
|----|----------|
| AC-001 | [test/command] |
```

**S2/S3 — add to S1 contract:**

```md
## Risk Register
| Risk | Mitigation |
|------|------------|

## Constraints
- Files allowed / forbidden
- Dependency restrictions
- API/schema restrictions

## Stop Conditions
- ...
```

Then ask for approval:

```text
Approve this Goal Contract?
Reply: approve / modify: [changes] / cancel
```

Do not edit code before approval unless task is clearly S0 or user explicitly requests it.

## Implementation Plan

After contract approval (S1+), produce a minimal plan.

```md
# Plan

## Files to change
- ...

## Steps
1. ...
2. ...

## Tests (map to AC IDs)
- AC-001 -> [test name]
- AC-002 -> [test name]

## Validation commands
- ...

## Rollback
- ...
```

Keep each slice small. Do not touch files outside the plan. If the plan turns out wrong, stop and update — do not quietly expand scope.

## Small-Step Implementation

Implement in slices. For each slice:

1. Make the smallest code change.
2. Add/update tests tied to AC IDs.
3. Run the narrowest relevant test.
4. Fix failures. Continue.

**Test naming:** embed AC ID in test names when possible.

```go
func TestAC001RejectsExpiredToken(t *testing.T) {}
func TestAC002AllowsRefreshWithinGraceWindow(t *testing.T) {}
```

If test names cannot include AC IDs, record the mapping in the final evidence table.

## Verification Loop

After implementation, run gates. Max 3 repair attempts.

### Gate 1: Diff Scope

```bash
git diff --name-only
git diff --stat
```

Only allowed files changed, no forbidden files, no unrelated refactor, no hidden dependency changes.

### Gate 2: Build/Lint/Test

Run project-appropriate commands discovered during recon. Do not invent commands. Capture exit codes. Examples:

```bash
go test ./... && go vet ./...
npm test && npm run lint
make test && make lint
pytest -v
```

### Gate 3: AC Coverage

For every AC, identify evidence. Mark pass/fail/not verified.

```text
AC-001: PASS via [test/command]
AC-002: PASS via [test/command]
AC-003: NOT VERIFIED because [reason]
```

If no evidence exists for an AC, either add evidence or mark incomplete. If any AC lacks evidence, final status cannot be PASS.

### Gate 4: Drift Check

Compare final diff against Goal Contract:

- Does implementation still match intent?
- Did any assumption become false?
- Did out-of-scope behavior change?
- Did tests assert implementation details instead of business behavior?

### Gate 5: Risk Check (S2/S3 only)

Explicitly check: data loss, compatibility break, migration/rollback, security regression, concurrency/race, performance, deploy/runtime risk.

## Final Response

Never say "done" unless verification passed or limitations are explicit.

```md
# Result

Status: PASS / PARTIAL / BLOCKED / FAILED

## What changed
- ...

## AC Evidence
| AC | Status | Evidence |
|----|--------|----------|
| AC-001 | PASS/FAIL/NOT VERIFIED | ... |

## Commands run
| Command | Exit | Notes |
|---------|------|-------|
| ... | 0/1 | ... |

## Diff scope
- Changed files: ...
- Out-of-scope: none / list

## Risks
- Remaining: ...

## Follow-ups
- ...
```

If any command was not run, say `NOT RUN` and explain why.

## Special Modes

| Mode | Effect |
|------|--------|
| `grill` | Only clarify requirements. Output Decision Log + draft ACs. No code edits. |
| `contract` | Produce only Goal Contract. No code edits. |
| `plan` | Produce only implementation plan (assumes contract exists). No code edits. |
| `execute` | Execute against an approved contract. If none exists, create one first. |
| `review` | Review uncommitted diff against contract + verification output. Report only blocking issues (correctness, violated AC, scope creep, security risk). No style nits. |
| `repair` | Fix failed verification. Requires: failing output, diff, contract. Fix root cause — not just test expectations. Rerun AC coverage + drift check. Do not expand scope. |

## Token Economy

- Do not spawn multiple subagents by default.
- Do not repeatedly reread the whole repository.
- Do not create long speculative design docs.
- Do not duplicate the same intent into multiple documents.
- Keep contracts concise; reuse discovered repo commands.
- For small tasks, keep the whole workflow short.
- For large tasks, split into multiple Goal Contracts instead of one massive session.

**Context budget:** when context grows large, summarize only confirmed contract + ACs + changed files + commands + failures. Drop exploration chatter. Keep raw failing output if still relevant. Keep exact AC IDs.

## Repository Knowledge

If the task reveals durable knowledge, propose adding to small files — not a giant spec system:

```text
docs/ai/invariants.md
docs/ai/known-pitfalls.md
docs/ai/verification.md
```

Only with user approval. Good durable knowledge: architecture invariants, business rules tests depend on, deployment constraints, production incidents. Bad: verbose narration, temporary debug notes, duplicate design docs, stale wishlists.
