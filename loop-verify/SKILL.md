---
name: loop-verify
description: Use this skill for coding tasks that need clarified intent, scope control, acceptance-criteria mapping, root-cause repair, persistence of manual/remote changes, verification loops, and anti-overengineering review. Trigger for feature work, bug fixes, refactors, backend logic, Docker/build/deployment changes, public API changes, multi-file changes, or any task where correctness or repeatability matters. Do not use for pure Q&A or obvious one-line S0 edits unless asked.
---

# Loop Verify

Lightweight loop-engineering workflow. Preserve intent, reduce scope drift, implement minimally, fix root causes instead of symptoms, persist repeatable changes, and prove the result with executable evidence.

**Quick start:** For concrete end-to-end examples (S0/S1/S2 walkthroughs and anti-patterns), see [examples.md](examples.md). For detailed gate checklists, reviewer prompt, error recovery, root-cause analysis, persistence checks, and decision tree, see [reference.md](reference.md).

## Core Philosophy

- **Code is actual system state, not automatic correctness.** The Goal Contract captures intent; acceptance criteria define what must be true; tests and checks are executable evidence. PASS requires evidence mapped to ACs, not just "tests look green".
- **Spec is contract/scaffolding, not a permanent source of truth by default.** Use it to lock important decisions before coding. Persist only reusable invariants, decisions, or pitfalls.
- **Root cause over band-aids.** A fix that only hides a symptom is incomplete. Reproduce the failure, identify the ownership layer, add durable correction, and verify with a regression check.
- **Repeatability over local heroics.** Temporary scripts, remote-host edits, patch files, YAML/Python changes, and deployment tweaks must be captured in the local repo or declared as non-repeatable risk.
- **Source truth over patch stacks.** If the source is available during active development, edit the source, template, generator, Helm chart, or offline package input directly. Patch archives and overlay scripts are for explicit released-version hotfixes, not default development work.
- **More context, less control.** Give rich context (repo structure, existing code, constraints, prior decisions) instead of rigid multi-tool chains.
- **One strong workflow, not stitched tools.** Prefer fewer contexts, fewer subagents, smaller diffs, and stronger gates.
- **Spec is a spectrum.** From a one-line intent to full ACs and risk register — match spec weight to task complexity.
- **Verification must be externalized.** The implementer may run checks, but final PASS must show commands, exit codes, AC coverage, drift/risk review, and persistence status when relevant.

## Mandatory Supporting-File Reads

Progressive disclosure is allowed, but do not skip critical references:

- For S0/S1: read `reference.md` only if a gate fails, the task is unclear, or review/repair is requested.
- For S2/S3, Docker/platform, deployment, remote-host, data, security, or `repair` tasks: read the relevant `reference.md` sections before final verification.
- Read `examples.md` only when unsure how to fill a template or when the user asks for examples.

## Workflow Decision Tree

```text
User request arrives
├─ Obviously trivial (typo, copy, config)? → S0: just do it, show diff + exit code if relevant
├─ Not obvious? → Recon first (read code, CLAUDE.md, AGENTS.md, docs)
├─ After recon, important choices open?
│  ├─ YES → Grill (one question at a time, with recommended answer)
│  └─ NO → Draft Goal Contract
├─ Contract approved? → Plan → Implement in slices → Verify (Gates 0-7)
├─ S2/S3 or high risk? → Fresh Review (Gate 7)
├─ Gates pass? → Final Response (PASS/PARTIAL/BLOCKED/FAILED)
└─ New requirement mid-run? → Record as Follow-up unless user explicitly reopens scope
```

## Task Routing

Before doing anything, classify the task and pick the lightest adequate process.

| Level | Description | Process |
|-------|-------------|---------|
| **S0** trivial | One-file, low-risk edit: typo, copy, small config, simple rename | Skip to implementation. No contract needed. |
| **S1** normal | Feature/fix with tests, limited files, low blast radius | Lightweight Goal Contract: intent + scope + boundaries + ACs + verification. Implement and verify. |
| **S2** risky | Auth, payment, data migration, concurrency, security, public API, Docker/build/deploy, remote host changes, third-party image/platform, multi-service behavior | Full Goal Contract + risk list + explicit test plan + verification loop. |
| **S3** architectural | Changes boundaries, contracts, storage model, service topology, or major subsystem behavior | Design review before implementation. Split into multiple S1/S2 slices — never one big pass. |

**Routing principle:** Most daily tasks should stay S0/S1. Forcing heavy process on them is net-negative ROI. When in doubt and the downside risk is low, go lighter. If the task touches data, security, deploy, Docker/platform, public API, remote hosts, or multi-service behavior, escalate to S2+.

## Phase 0: Recon (Read-Only)

Before asking the user anything, inspect the repository enough to avoid dumb questions. Read existing project context: `CLAUDE.md`, `AGENTS.md`, architecture docs, invariants files, ADRs, and nearby implementation patterns. These are project-level specs — respect them.

Find: repo layout, relevant packages, existing tests, build/lint/test commands, nearby patterns, Docker/CI/deployment files if relevant, and existing constraints around APIs, data, images, runtime platforms, remote environments, or deployment templates.

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

### 4. Root-Cause Repair

When fixing a problem, do not optimize for the quickest visible patch. Use root-cause repair:

1. Reproduce or clearly describe the failure.
2. Identify the ownership layer: caller, callee, config, data, environment, deployment, dependency, or test.
3. Fix the owning layer, not a downstream symptom, unless the contract explicitly asks for a workaround.
4. Add or update a regression test/check when practical.
5. If the root-cause fix is too large, risky, or uncertain, stop and ask. Do not silently apply a band-aid.

Forbidden repair patterns:

- catch-and-ignore errors to make a failing path pass
- add broad retries/sleeps/timeouts without proving the failure mode
- weaken tests or change expected behavior to match buggy code
- patch generated/remote files without persisting the source template
- leave a successful `ssh`, ad hoc Python, Helm, `kubectl patch`, or copied-bundle edit as the only implementation
- special-case only the observed input when the bug is general

### 5. Persistence / Repeatability

A workflow is not fixed if it only works because of untracked local or remote state.

If you create or modify any temporary script, patch, Python file, YAML file, generated config, Helm value/template, deployment manifest, remote cloud host file, environment setting, copied bundle, or external disk deployment file:

- Capture the durable source in the local repository when possible.
- Prefer `scripts/`, `deploy/`, `config/`, `docs/runbooks/`, `patches/`, `templates/`, or the repo's existing convention.
- If the durable source lives outside this repo, record the exact external path, reason, and sync command/template.
- Final status cannot be PASS if required changes exist only on a remote host, local temp directory, or external disk with no repo-tracked source or documented handoff.
- Treat direct remote heredocs, ad hoc Python, one-off Helm commands, `kubectl patch`, generated YAML edits, and copied offline-bundle edits as diagnostics until their equivalent source/template/package input is updated.
- When source is available and the work is still in development, do not create customer-facing patch layers or overlay archives as the durable fix unless the user explicitly asks for a released-version hotfix.
- If later user clarification or newer E2E evidence supersedes an older blocker, update the task notes/status so stale "blocked" records do not survive as current truth.

### 5.1 Secret Payload Handling

Some internal products legitimately send passwords, tokens, or keys in API payloads. That does not make the values safe to expose.

- It is acceptable for the product/browser/API call to carry a secret when that is the documented contract.
- Do not log, screenshot, echo, HAR-capture, telemetry-capture, final-answer, or commit request bodies containing secrets.
- Do not pass secrets through command-line arguments that appear in shell history or process listings; prefer stdin JSON, files outside git, Kubernetes Secret material, or redacted summaries.
- Keep "payload may include a secret" separate from "the agent may print or persist that secret"; the latter remains forbidden.

### 6. Docker / Platform Safety

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

### 7. Fail Fast

If required information is missing or unverifiable: stop, state the blocker, give the smallest next decision needed. Never invent business behavior, patch around unknowns, or pretend verification passed.

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

## Change Boundaries
- Allowed changes: [files/directories or behavior areas]
- Forbidden changes: [files/directories/behaviors/dependencies that must not change]

## Assumptions
- A1: [optional but preferred when assumptions exist]

## Acceptance Criteria
- AC-001: ...
- AC-002: ...

## Verification
| AC | Evidence |
|----|----------|
| AC-001 | [test/command/manual check] |

## Stop Conditions
- [optional: when to stop instead of guessing]
```

**S2/S3 — add to S1 contract:**

```md
## Risk Register
| Risk | Mitigation |
|------|------------|

## Constraints
- Dependency restrictions
- API/schema/deployment/Docker/vendor-image restrictions
- Remote-host or external-file restrictions

## Rollback / Recovery
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

## Persistence plan
- [where scripts/configs/remote changes will be captured, or "none"]

## Rollback
- ...
```

Keep each slice small. Do not touch files outside the plan. If the plan turns out wrong, stop and update the contract/plan — do not quietly expand scope.

## Small-Step Implementation

Implement in slices. For each slice:

1. Make the smallest code change.
2. Add/update tests tied to AC IDs when practical.
3. Run the narrowest relevant test.
4. Fix failures with root-cause repair.
5. Capture any temporary/manual/remote changes into durable repo artifacts.
6. Continue.

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

### Gate 0: Root-Cause Check (bugfix/repair tasks)

For fixes and repair loops, record:

```text
Failure:
Root cause:
Owning layer:
Durable fix:
Regression evidence:
Why this is not a band-aid:
```

If root cause is unknown or the fix only masks the symptom, final status cannot be PASS.

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

Explicitly check: data loss, compatibility break, migration/rollback, security regression, concurrency/race, performance, deploy/runtime risk, Docker image/platform risk, third-party dependency/image risk, and remote/external-state risk.

For Docker/platform tasks, include manifest or build evidence when applicable, for example:

```bash
docker buildx imagetools inspect <image>
docker buildx build --platform linux/amd64,linux/arm64 ...
```

### Gate 6: Persistence / Reproducibility Check

Verify that the workflow can be repeated from the repository:

```text
Temporary scripts captured: yes/no/N/A
Remote host changes captured: yes/no/N/A
External disk/deploy files captured or documented: yes/no/N/A
Patch/YAML/Python/config changes captured: yes/no/N/A
Re-run command or runbook exists: yes/no/N/A
```

If a required change exists only in a remote shell, temp file, external disk, or manual patch, final status cannot be PASS.

### Gate 7: Fresh Review (S2/S3 required, S1 optional)

Use a fresh review pass with ONLY the contract, final diff, verification output, persistence status, and relevant architecture constraints. The reviewer must not see the implementer's self-justification or previous reviewer conclusions. For the exact reviewer prompt, see [reference.md](reference.md).

## Error Recovery

When a gate fails:

1. **Identify root cause** — code bug, test bug, contract bug, environment issue, stale remote state, or missing information?
2. **Fix the root cause** — never delete a failing test, weaken assertions, change expected behavior, or patch downstream symptoms just to pass.
3. **Persist the durable fix** — do not leave the only fix in a temp file, remote host, generated artifact, or external disk.
4. **Rerun the failing gate** and all subsequent gates.
5. **Max 3 repair loops.** After 3 failures: stop, report what failed, what was tried, and the smallest next decision needed.

**Escalate immediately if:** the fix requires forbidden files, unapproved dependencies, Docker/vendor-image changes, untracked remote-only changes, or conflicts with architecture invariants.

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

## Root Cause (for fixes/repairs)
- Failure:
- Root cause:
- Durable fix:
- Regression evidence:

## Commands run
| Command | Exit | Notes |
|---------|------|-------|
| ... | 0/1/NOT RUN | ... |

## Diff scope
- Changed files: ...
- Out-of-scope: none / list

## Persistence
- Temporary/remote/manual changes captured: yes/no/N/A
- Where captured: ...
- Remaining non-repeatable state: none / list

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
| `repair` | Fix failed verification. Requires: failing output, diff, contract. Fix root cause — not just test expectations. Rerun AC coverage + drift + persistence checks. Do not expand scope. |
| `persist` | Audit temporary/manual/remote changes and convert them into repo-tracked scripts/config/templates/runbooks. No unrelated code edits. |

### `grill` output template

```md
# Decision Log

## Confirmed decisions
- ...

## Rejected options
- ...

## Open questions
- ...

## Draft Acceptance Criteria
- AC-001: ...

## Follow-ups / out of scope
- ...
```

## Token Economy

- Do not spawn multiple subagents by default.
- Do not repeatedly reread the whole repository.
- Do not create long speculative design docs.
- Do not duplicate the same intent into multiple documents.
- Keep contracts concise; reuse discovered repo commands.
- For small tasks, keep the whole workflow short.
- For large tasks, split into multiple Goal Contracts instead of one massive session.
- Prefer AC evidence, root-cause notes, persistence status, and targeted diffs over long narrative summaries.

**Context budget:** when context grows large, summarize only confirmed contract + ACs + changed files + commands + failures + root cause + persistence status. Drop exploration chatter. Keep raw failing output if still relevant. Keep exact AC IDs.

## Repository Knowledge

If the task reveals durable knowledge, propose adding to small files — not a giant spec system:

```text
docs/ai/invariants.md
docs/ai/known-pitfalls.md
docs/ai/verification.md
docs/runbooks/
```

Only with user approval. Good durable knowledge: architecture invariants, business rules tests depend on, deployment constraints, Docker image/platform constraints, production incidents, repeatable deployment/runbook steps. Bad: verbose narration, temporary debug notes, duplicate design docs, stale wishlists.
