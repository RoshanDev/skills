---
name: loop-verify
description: Use this skill for coding tasks that need clarified intent, scope control, acceptance-criteria mapping, verification or repair loops, and anti-overengineering review. Trigger for feature work, bug fixes, refactors, backend logic, Docker/build/deployment changes, public API changes, multi-file changes, or any task where correctness matters. Do not use for pure Q&A or obvious one-line S0 edits unless asked.
---

# Loop Verify

Lightweight loop-engineering workflow. Preserve intent, reduce scope drift, implement minimally, and prove the result with executable evidence.

**Quick start:** For concrete end-to-end examples (S0/S1/S2 walkthroughs and anti-patterns), see [examples.md](examples.md). For detailed gate checklists, reviewer prompt, error recovery, and decision tree, see [reference.md](reference.md).

## Core Philosophy

- **Code is actual system state, not automatic correctness.** The Goal Contract captures intent; acceptance criteria define what must be true; tests and checks are executable evidence. PASS requires evidence mapped to ACs, not just "tests look green".
- **Spec is contract/scaffolding, not a permanent source of truth by default.** Use it to lock important decisions before coding. Persist only reusable invariants, decisions, or pitfalls.
- **More context, less control.** Give rich context (repo structure, existing code, constraints, prior decisions) instead of rigid multi-tool chains.
- **One strong workflow, not stitched tools.** Prefer fewer contexts, fewer subagents, smaller diffs, and stronger gates.
- **Spec is a spectrum.** From a one-line intent to full ACs and risk register — match spec weight to task complexity.
- **Verification must be externalized.** The implementer may run checks, but final PASS must show commands, exit codes, AC coverage, and drift/risk review.

## Workflow Decision Tree

```text
User request arrives
├─ Obviously trivial (typo, copy, config)? → S0: just do it, show diff + exit code if relevant
├─ Not obvious? → Recon first (read code, CLAUDE.md, AGENTS.md, docs)
├─ After recon, important choices open?
│  ├─ YES → Grill (one question at a time, with recommended answer)
│  └─ NO → Draft Goal Contract
├─ Contract approved? → Plan → Implement in slices → Verify (Gates 1-5)
├─ S2/S3 or high risk? → Fresh Review (Gate 6)
├─ Gates pass? → Final Response (PASS/PARTIAL/BLOCKED/FAILED)
└─ New requirement mid-run? → Record as Follow-up unless user explicitly reopens scope
```

## Task Routing

Before doing anything, classify the task and pick the lightest adequate process.

| Level | Description | Process |
|-------|-------------|---------|
| **S0** trivial | One-file, low-risk edit: typo, copy, small config, simple rename | Skip to implementation. No contract needed. |
| **S1** normal | Feature/fix with tests, limited files, low blast radius | Lightweight Goal Contract: intent + scope + ACs + verification. Implement and verify. |
| **S2** risky | Auth, payment, data migration, concurrency, security, public API, Docker/build/deploy, third-party image/platform, multi-service behavior | Full Goal Contract + risk list + explicit test plan + verification loop. |
| **S3** architectural | Changes boundaries, contracts, storage model, service topology, or major subsystem behavior | Design review before implementation. Split into multiple S1/S2 slices — never one big pass. |

**Routing principle:** Most daily tasks should stay S0/S1. Forcing heavy process on them is net-negative ROI. When in doubt and the downside risk is low, go lighter. If the task touches data, security, deploy, Docker/platform, public API, or multi-service behavior, escalate to S2+.

## Phase 0: Recon (Read-Only)

Before asking the user anything, inspect the repository enough to avoid dumb questions. Read existing project context: `CLAUDE.md`, `AGENTS.md`, architecture docs, invariants files, ADRs, and nearby implementation patterns. These are project-level specs — respect them.

Find: repo layout, relevant packages, existing tests, build/lint/test commands, nearby patterns, Docker/CI/deployment files if relevant, and existing constraints around APIs, data, images, or runtime platforms.

Do not edit files. Output a concise summary:

```text
Recon summary:
- Relevant files: [list]
- Existing patterns: [brief]
- Likely test commands: [from Makefile/package.json/go.mod/etc.]
- Risk areas: [what could go wrong]
- Unknowns that need user input: [only genuine unknowns]
```

If no user input is needed, proceed directly to the Goal Contract. For the full recon checklist, see [reference.md](reference.md).

## Hard Rules

### 1. Grill Before Building (when needed)

Only for S1+ where important choices remain open. Skip if repo context answers the questions.

- Ask one question at a time; provide your recommended answer.
- Read the repo first — never ask what you can discover yourself.
- Prefer questions about irreversible decisions: business rules, compatibility, failure behavior, security boundary, data lifecycle, API shape, concurrency, rollout, deployment, or verification strategy.
- Push back on vague answers with a concrete strawman.
- Stop grilling once the Goal Contract is implementable.

Question format:

```text
Q: [single decision question]
Recommended: [recommendation and why]
Impact: [what changes depending on the answer]
Reply: A) accept  B) different option  C) defer/out of scope
```

For a question bank organized by category, see [reference.md](reference.md).

### 2. Freeze Scope

Once a Goal Contract is approved: no new requirements mid-run. Record new requests as Follow-ups. Only reopen if the user explicitly changes scope. If a new requirement conflicts with already-implemented work, stop and report.

### 3. Minimal Change

Always prefer the smallest correct change. Do not:

- introduce new architecture or add dependencies without approval
- perform broad refactors or rewrite unrelated code
- change public APIs, DB schema, auth, billing, deployment, Docker base images, or vendor image references unless explicitly required
- "improve" naming/style outside touched code
- silently change semantics to make tests pass

If a larger change is necessary, stop and explain why.

### 4. Docker / Platform Safety

For Docker, build, deployment, or multi-architecture tasks, classify as S2 or higher.

- For first-party images, prefer BuildKit/buildx and explicit platform-aware args such as `TARGETOS` and `TARGETARCH` when appropriate.
- For third-party images, inspect the image manifest/platform support before changing anything.
- If a third-party image lacks a required platform, stop and report:
  - image name
  - required platform
  - platforms found
  - smallest viable options
- Never rewrite, retag, rebuild, emulate, or "convert" a third-party ARM-only image into AMD64 or vice versa.
- Never silently change a third-party image registry, tag, digest, platform, or base image to make verification pass.

### 5. Fail Fast

If required information is missing or unverifiable: stop, state the blocker, give the smallest next decision needed. Never invent business behavior or pretend verification passed.

## Goal Contract

Produce before editing code (S1+). The contract is lightweight scaffolding for this task. Persist it only when the user asks or when it captures reusable project knowledge.

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
| AC-001 | [test/command/manual check] |
```

**S2/S3 — add to S1 contract:**

```md
## Risk Register
| Risk | Mitigation |
|------|------------|

## Constraints
- Files/directories allowed or expected
- Files/directories forbidden
- Dependency restrictions
- API/schema/deployment/Docker/vendor-image restrictions

## Assumptions
- A1: ...

## Stop Conditions
- ...
```

Then ask for approval:

```text
Approve this Goal Contract?
Reply: approve / modify: [changes] / cancel
```

Do not edit code before approval unless task is clearly S0 or user explicitly requests direct execution.

## Implementation Plan

After contract approval (S1+), produce a minimal plan:

```md
# Plan

## Files to change
- ...

## Steps
1. ...
2. ...

## Tests (map to AC IDs)
- AC-001 -> [test name or command]
- AC-002 -> [test name or command]

## Validation commands
- ...

## Rollback
- ...
```

Keep each slice small. Do not touch files outside the plan. If the plan turns out wrong, stop and update the contract/plan — do not quietly expand scope.

## Small-Step Implementation

Implement in slices. For each slice:

1. Make the smallest code change.
2. Add/update tests tied to AC IDs when practical.
3. Run the narrowest relevant test.
4. Fix failures.
5. Continue.

**Test naming:** embed AC ID in test names when possible.

```go
func TestAC001RejectsExpiredToken(t *testing.T) {}
func TestAC002AllowsRefreshWithinGraceWindow(t *testing.T) {}
```

```python
def test_ac001_rejects_expired_token(): ...
def test_ac002_allows_refresh_within_grace_window(): ...
```

If test names cannot include AC IDs, record the mapping in the final evidence table.

## Verification Loop

After implementation, run gates. Max 3 repair attempts. For detailed gate checklists and error recovery guidance, see [reference.md](reference.md).

### Gate 1: Diff Scope

```bash
git diff --name-only
git diff --stat
```

Check: only planned/allowed files changed, no forbidden files, no unrelated refactor, no hidden dependency changes, no broad formatting churn, no unapproved Docker/vendor-image changes.

### Gate 2: Build/Lint/Test

Run project-appropriate commands discovered during recon. Do not invent success. Capture exit codes.

Examples:

```bash
go test ./... && go vet ./...
npm test && npm run lint
make test && make lint
pytest -v
```

### Gate 3: AC Coverage

For every AC, identify evidence. Mark pass/fail/not verified:

```text
AC-001: PASS via TestRateLimitBlocksSixthRequest
AC-002: PASS via TestRateLimitRetryAfterHeader
AC-003: NOT VERIFIED because [reason]
```

If any AC lacks evidence, final status cannot be PASS.

### Gate 4: Drift Check

Compare final diff against the Goal Contract:

- Does implementation still match intent?
- Did any assumption become false?
- Did out-of-scope behavior change?
- Did tests assert implementation details instead of business behavior?
- Did implementation add hidden business rules?
- Did Docker/vendor-image/platform behavior change outside the contract?

### Gate 5: Risk Check (S2/S3 only)

Explicitly check: data loss, compatibility break, migration/rollback, security regression, concurrency/race, performance, deploy/runtime risk, Docker image/platform risk, and third-party dependency/image risk.

For Docker/platform tasks, include manifest or build evidence when applicable, for example:

```bash
docker buildx imagetools inspect <image>
docker buildx build --platform linux/amd64,linux/arm64 ...
```

### Gate 6: Fresh Review (S2/S3 required, S1 optional)

Use a fresh review pass with ONLY the contract, final diff, verification output, and relevant architecture constraints. The reviewer must not see the implementer's self-justification or previous reviewer conclusions. For the exact reviewer prompt, see [reference.md](reference.md).

## Error Recovery

When a gate fails:

1. **Identify root cause** — code bug, test bug, contract bug, environment issue, or missing information?
2. **Fix the root cause** — never delete a failing test, weaken assertions, or change expected behavior just to pass.
3. **Rerun the failing gate** and all subsequent gates.
4. **Max 3 repair loops.** After 3 failures: stop, report what failed, what was tried, and the smallest next decision needed.

**Escalate immediately if:** the fix requires forbidden files, unapproved dependencies, Docker/vendor-image changes, or conflicts with architecture invariants.

For common failure patterns and resolution, see [reference.md](reference.md).

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
| ... | 0/1/NOT RUN | ... |

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
| `review` | Review uncommitted diff against contract + verification output. Report only blocking issues. No style nits. |
| `repair` | Fix failed verification. Requires: failing output, diff, contract. Fix root cause — not just test expectations. Rerun AC coverage + drift check. Do not expand scope. |

## Token Economy

- Do not spawn multiple subagents by default.
- Do not repeatedly reread the whole repository.
- Do not create long speculative design docs.
- Do not duplicate the same intent into multiple documents.
- Keep contracts concise; reuse discovered repo commands.
- For small tasks, keep the whole workflow short.
- For large tasks, split into multiple Goal Contracts instead of one massive session.
- Prefer AC evidence and targeted diffs over long narrative summaries.

**Context budget:** when context grows large, summarize only confirmed contract + ACs + changed files + commands + failures. Drop exploration chatter. Keep raw failing output if still relevant. Keep exact AC IDs.

## Repository Knowledge

If the task reveals durable knowledge, propose adding to small files — not a giant spec system:

```text
docs/ai/invariants.md
docs/ai/known-pitfalls.md
docs/ai/verification.md
```

Only with user approval. Good durable knowledge: architecture invariants, business rules tests depend on, deployment constraints, Docker image/platform constraints, production incidents. Bad: verbose narration, temporary debug notes, duplicate design docs, stale wishlists.
