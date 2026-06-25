---
name: loop-verify
description: Use this skill for coding tasks that need clarified intent, scope control, acceptance-criteria mapping, outcome rubrics, E2E scope discovery, root-cause repair, persistence of manual/remote changes, user-flow evidence, verification loops, optional external review, and anti-overengineering review. Trigger for feature work, bug fixes, refactors, backend logic, UI/browser flows, Docker/build/deployment changes, public API changes, multi-file changes, or any task where correctness or repeatability matters. Do not use for pure Q&A or obvious one-line S0 edits unless asked.
---

# Loop Verify

Lightweight loop-engineering workflow. Preserve intent, reduce scope drift, implement minimally, fix root causes instead of symptoms, persist repeatable changes, and prove the result with evidence.

**Supporting files:**

- [reference.md](reference.md): detailed gate checklists, root-cause repair, persistence checks, reviewer prompt.
- [e2e-scope-discovery.md](e2e-scope-discovery.md): how to infer upstream/downstream scope and choose a minimal realistic E2E slice.
- [user-flow-evidence.md](user-flow-evidence.md): browser UI / Network / user-path validation gate.
- [external-review.md](external-review.md): optional integration with separate review skills or tools such as code-review-skill and open-code-review.
- [outcomes.md](outcomes.md): outcome/rubric style autonomous loops.
- [long-task-progress.md](long-task-progress.md): persisting task state across sessions/compactions with progress.md and feature_list.json.
- [examples.md](examples.md): filled examples and anti-patterns.

## Core Philosophy

- **Outcome first.** Define what done looks like and how quality will be measured before autonomous work begins.
- **Code is actual system state, not automatic correctness.** The Goal Contract captures intent; ACs define what must be true; tests/checks are evidence. PASS requires evidence mapped to ACs.
- **Discover the E2E slice, do not ask the user to write the whole map.** For feature work, infer upstream prerequisites, changed surface, downstream effects, and user-visible outcomes from code, routes, UI, APIs, docs, and existing tests. Ask only for genuinely missing business decisions or environment access.
- **User path beats programmatic shortcuts.** If a defect came from browser UI, modal, wizard, form, selector, button, screenshot, or browser Network, curl/hooks/Python/API seeding are diagnosis/setup only. Final PASS requires browser-driven evidence from the same user entry path unless the user explicitly waives it.
- **Root cause over band-aids.** A fix that only hides a symptom is incomplete. Reproduce the failure, identify the owning layer, fix the owning layer, and add regression evidence.
- **Repeatability over local heroics.** Temporary scripts, remote-host edits, patch files, YAML/Python changes, deployment tweaks, and copied bundle edits must be captured in the repo or declared as non-repeatable risk.
- **External review is advisory, not a substitute.** Extra reviewers/tools can catch code issues, but they do not replace Goal Contract, E2E scope, user-flow, root-cause, persistence, or mechanical gates.
- **Source truth over patch stacks.** If editable source exists, change the source/template/generator/chart/package input, not only generated output or runtime state.
- **More context, less control.** Give rich context and strong verification instead of rigid multi-tool chains.
- **One strong workflow, not stitched tools.** Prefer fewer contexts, fewer subagents, smaller diffs, and stronger gates.
- **Current authority first.** The current worktree, selected branch, and live external state are the authority. Plans, memory, progress files, and summaries are background until current evidence confirms them.
- **Spec is a spectrum.** Match spec weight to task complexity.

## Efficiency Defaults

- Start solo. Use subagents only for independent parallel research, disjoint write scopes, or isolated review.
- For S0, skip contracts and plans. For S1, keep Goal Contract, Outcome Snapshot, and plan to the minimum needed to avoid drift; if the user explicitly asks to execute, do not pause for ritual approval.
- Keep one durable state surface per task. Use existing progress artifacts when present; otherwise create progress files only for long-running, resumable, or multi-agent work.
- For large artifact development loops, prefer directory handoff with manifests, size checks, and targeted checksums. Full compression, full hashing, and unpack/repack cycles belong at release/export gates or explicit ACs.
- Treat MemOS/project memory as retrieval background. Durable workflow rules belong in the highest applicable AGENTS file or this canonical skill.

## Mandatory Supporting-File Reads

- For S2/S3, Docker/platform, deployment, remote-host, data, security, or `repair` tasks: read relevant sections of `reference.md` before final verification.
- For feature work with browser/product E2E expectations, changed UI/API integration, or unclear upstream/downstream impact: read `e2e-scope-discovery.md` before finalizing the Goal Contract.
- For any browser UI, modal, wizard, form, selector, button, screenshot, or browser Network request: read `user-flow-evidence.md` before writing the Goal Contract and before final verification.
- For optional external/fresh code review using another skill or tool: read `external-review.md` before running it and before applying any suggested fix.
- For autonomous loops, `execute`, `repair`, `review`, `persist`, or ambiguous done-state: read `outcomes.md` and use an Outcome Snapshot.
- Read `examples.md` when unsure how to fill a template.

## Workflow Decision Tree

```text
User request arrives
├─ Obviously trivial? → S0: just do it, show diff + exit code if relevant
├─ Otherwise → Recon first
├─ Feature or fix has product/user-visible behavior? → discover E2E impact map
├─ Browser/UI/Network/user-path failure? → classify S2; require User-Flow Evidence Gate
├─ Important choices open? → Grill one question at a time
├─ S1+ → Draft Goal Contract + Outcome Snapshot
├─ Contract approved? → Plan → Implement in slices → Verify gates
├─ S2/S3/high risk → Fresh Review / outcome evaluation; optional external review if useful
└─ New requirement mid-run? → Record as Follow-up unless user reopens scope
```

## Task Routing

| Level | Description | Process |
|-------|-------------|---------|
| **S0** trivial | One-file, low-risk edit | Skip to implementation. No contract needed. |
| **S1** normal | Feature/fix with tests, limited files, low blast radius | Lightweight Goal Contract + Outcome Snapshot. If user-visible behavior changes, include a small E2E Impact Map. |
| **S2** risky | Auth, payment, data migration, concurrency, security, public API, Docker/build/deploy, remote host changes, third-party image/platform, multi-service behavior, browser UI/user-path/Network defect | Full Goal Contract + risk list + outcome rubric + verification loop. UI issues require E2E Scope Discovery and User-Flow Evidence Gate. Optional external review can be used for large/risky diffs. |
| **S3** architectural | Changes boundaries, contracts, storage model, service topology, or major subsystem behavior | Design review before implementation. Split into chained S1/S2 outcomes. Use external review only as advisory evidence. |

If the task touches data, security, deploy, Docker/platform, public API, remote hosts, multi-service behavior, or browser user flows, escalate to S2+.

## Phase 0: Recon (Read-Only)

Inspect enough repository context to avoid dumb questions. Read `CLAUDE.md`, `AGENTS.md`, architecture docs, invariants, ADRs, nearby code, tests, build commands, UI/E2E framework, Docker/CI/deploy files, and source-of-truth templates if relevant.

Do not edit files. Output:

```text
Recon summary:
- Relevant files:
- Existing patterns:
- Likely test commands:
- Existing UI/E2E tools:
- Potential entry points:
- Potential upstream prerequisites:
- Potential downstream effects:
- Risk areas:
- Unknowns that need user input:
```

## Hard Rules

### 1. Grill Before Building

For S1+ where important choices remain open:

- Ask one question at a time and provide a recommended answer.
- Read the repo first; do not ask what the repo already answers.
- Prefer questions about irreversible decisions: business rules, compatibility, failure behavior, security boundary, data lifecycle, API shape, concurrency, rollout, deployment, user-path validation, or verification strategy.
- Push back on vague answers with a concrete strawman.

### 2. Freeze Scope

Once a Goal Contract is approved, do not add new requirements mid-run. Record new requests as Follow-ups. Reopen only if the user explicitly changes scope.

### 3. Minimal Change

Do not introduce new architecture, dependencies, broad refactors, public API changes, DB schema changes, deployment changes, Docker base image changes, vendor image changes, or unrelated style churn unless explicitly required.

### 4. E2E Scope Discovery

For S1+ feature/fix work with user-visible behavior or product E2E expectation:

- Infer the E2E Impact Map from code and docs: entry points, upstream prerequisites, changed surface, downstream effects, existing verification, and proposed E2E slice.
- The user does not need to list all upstream/downstream dependencies. Ask only when recon cannot answer a business decision or environment requirement.
- Choose the smallest realistic vertical slice that crosses the changed surface and at least one meaningful downstream effect.
- Do not validate only the component you changed when the product behavior crosses component/API/backend boundaries.
- If no realistic E2E slice can be identified, mark verification as NEEDS_REVISION or BLOCKED instead of claiming PASS.

### 5. User-Flow Evidence

For browser/UI/user-path issues:

- Treat curl, hooks, Python scripts, API seeding, mocks, fake upstreams, direct DB edits, and direct backend calls as diagnosis/setup evidence only.
- They cannot satisfy the main AC unless the user-facing product is itself an API/CLI or the user explicitly waives UI validation.
- Final PASS requires browser-driven evidence from the same user entry point.
- Evidence must include user-visible controls interacted with, captured Network request/status when relevant, UI result/error state, and whether the next user action is possible.
- If real login/session/environment is unavailable, final status is PARTIAL or BLOCKED, not PASS.

### 6. Outcome / Rubric Discipline

For S1+ tasks, define an Outcome Snapshot before implementation:

```md
# Outcome Snapshot

## Description
[what artifact or system state should exist when done]

## Rubric
- R-001 / AC-001: [observable criterion and required evidence]
- R-E2E: For user-visible changes, a representative E2E slice crosses the changed surface and verifies a downstream effect.
- R-USERFLOW: For UI/browser defects, user path evidence exists from the same entry point.
- R-RC: For repair tasks, root cause is identified, owning layer fixed, and regression evidence exists.
- R-PERSIST: Temporary/manual/remote/deployment changes are repo-tracked or documented as one-off risk.
- R-EXTREVIEW: External review findings, if run, are classified and only evidence-backed blocking findings affect PASS.
- R-SCOPE: Diff stays within approved boundaries.

## Max iterations
3 unless the user chooses another limit.
```

### 7. Root-Cause Repair

When fixing a problem:

1. Reproduce or describe the failure.
2. Identify the owning layer: caller, callee, config, data, environment, deployment, dependency, UI, proxy, or test.
3. Fix the owning layer, not a downstream symptom, unless the contract explicitly asks for a workaround.
4. Add/update regression evidence when practical.
5. If the root-cause fix is too large/risky/uncertain, stop and ask.

Forbidden repair patterns:

- catch-and-ignore errors to make a failing path pass
- arbitrary sleep/retry/timeout without proving the failure mode
- weaken tests or change expected behavior to match buggy code
- replace a real user flow with a fake/setup-only shortcut
- patch generated/remote files without persisting the source template
- leave successful `ssh`, ad hoc script, Helm, `kubectl patch`, or copied-bundle edit as the only implementation
- special-case only the observed input when the bug is general

### 8. Persistence / Repeatability

A workflow is not fixed if it only works because of untracked local or remote state.

If you create or modify any temporary script, patch, Python file, YAML file, generated config, deployment manifest, remote host file, environment setting, copied bundle, or external deployment file:

- Capture the durable source in the local repository when possible.
- Prefer the repo's existing convention, otherwise `scripts/`, `deploy/`, `config/`, `docs/runbooks/`, `patches/`, or `templates/`.
- If the durable source lives outside this repo, record the exact external path, reason, and sync command/template.
- Final status cannot be PASS if required changes exist only on a remote host, temp directory, external disk, or live cluster with no repo-tracked source or documented handoff.
- Treat direct remote commands, ad hoc scripts, one-off Helm commands, `kubectl patch`, generated YAML edits, and copied offline-bundle edits as diagnostics until their source/template/package input is updated.
- Treat a frontend source/build success as source evidence only. If the task claims a live UI change, verify that the deployed frontend/console artifact or image was rebuilt, published, rolled out, and observed in the target UI or deployed static assets.
- Treat a live registry push as runtime evidence only. If the task claims an offline package fix, verify the package image archive or OCI layout, image list, digest list, chart/manifests, and checksum files all reference the intended artifact.

### 9. Docker / Platform Safety

For Docker/build/deployment/multi-architecture tasks, classify as S2+.

- For first-party images, prefer BuildKit/buildx and explicit platform-aware args when appropriate.
- For third-party images, inspect manifest/platform support before changing anything.
- If a third-party image lacks a required platform, stop and report image name, required platform, platforms found, and options.
- Never rewrite, retag, rebuild, emulate, or convert a third-party image to pretend it supports another architecture.
- Never silently change third-party registry, tag, digest, platform, or base image to make verification pass.

### 10. External Review Discipline

External review skills/tools can be used for S2/S3, large diffs, security/data/deploy/concurrency/performance risks, or when the user asks.

- External review is advisory evidence; loop-verify gates remain authoritative.
- Do not auto-apply external review fixes unless the user explicitly asked for review-and-fix.
- Classify findings as High/Medium/Low and discard weak nits from final blocking status.
- If using a CLI review tool, avoid passing secrets or private request bodies into prompts, logs, telemetry, or artifacts.

### 11. Fail Fast

If required information is missing or unverifiable: stop, state the blocker, give the smallest next decision needed. Never invent business behavior, patch around unknowns, or pretend verification passed.

## Goal Contract

Produce before editing code (S1+):

```md
# Goal Contract

## Intent
[one paragraph: user-visible outcome]

## Scope
- In: ...
- Out: ...

## Change Boundaries
- Allowed changes: ...
- Forbidden changes: ...

## Assumptions
- A1: ...

## E2E Impact Map
- Entry points:
- Upstream prerequisites:
- Changed surface:
- Downstream effects:
- Existing verification:
- Proposed E2E slice:

## Acceptance Criteria
- AC-001: ...
- AC-E2E-001: [when user-visible behavior changes]

## Outcome Rubric
- R-001 / AC-001: [required evidence]
- R-E2E / AC-E2E-001: [representative E2E slice evidence]
- R-SCOPE: [diff boundary evidence]

## Verification
| AC/Rubric | Evidence |
|-----------|----------|
| AC-001 / R-001 | [test/command/manual check] |
| AC-E2E-001 / R-E2E | [browser/product E2E slice or reason N/A] |

## Stop Conditions
- ...
```

For UI/browser/user-path defects, add:

```md
## Failed User Path
- Entry point: [page/modal/wizard/form/button]
- User action: [click/type/select/submit sequence]
- Failed request or visible symptom: [Network request/status or UI error]

## User-Flow Evidence Required
- E3: Browser Network evidence from the same UI path
- E4: Browser-driven interaction evidence from the same entry point
- Programmatic checks allowed only as setup/diagnosis, not final PASS evidence
```

For S2/S3, also add risk register, constraints, and rollback/recovery.

Ask for approval:

```text
Approve this Goal Contract?
Reply: approve / modify: [changes] / cancel
```

Do not edit code before approval unless task is clearly S0 or user explicitly requests direct execution.

## Implementation Plan

After approval, produce:

```md
# Plan

## Files to change
- ...

## Steps
1. ...
2. ...

## Tests / AC mapping
- AC-001 -> [test name or command]

## E2E validation plan
- Impact map source: [files/routes/components/APIs inspected]
- E2E slice: [entry point -> action -> downstream effect -> assertion]
- Skipped dependencies and why: [none/list]

## User-flow validation plan
- [browser path / Playwright / Cypress / manual browser path, or N/A]

## External review plan
- [none / code-review-skill / open-code-review / other; why]

## Validation commands
- ...

## Persistence plan
- [where scripts/configs/remote changes will be captured, or none]

## Rollback
- ...
```

Keep each slice small. If the plan is wrong, stop and update the contract/plan instead of quietly expanding scope.

## Verification / Outcome Loop

Run relevant gates. Max 3 repair attempts unless approved otherwise.

### Gate 0: Root-Cause Check

Required for bugfix/repair tasks.

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

Only planned/allowed files changed; no forbidden files, unrelated refactor, hidden dependency, broad formatting churn, or unapproved image/deploy changes.

### Gate 2: Build / Lint / Test

Run project-appropriate commands discovered during recon. Capture exit codes.

### Gate 3: AC / Rubric Coverage

Every AC and rubric criterion must have evidence. Missing required evidence means final status cannot be PASS.

### Gate 4: E2E Scope Coverage

For user-visible changes, verify:

```text
E2E Impact Map produced: yes/no/N/A
Representative slice crosses changed surface: yes/no/N/A
At least one downstream effect verified: yes/no/N/A
Skipped upstream/downstream dependencies listed: yes/no/N/A
Programmatic setup limited to prerequisites: yes/no/N/A
```

If this gate is applicable but missing, final status cannot be PASS.

### Gate 5: Drift Check

Check intent alignment, assumptions, out-of-scope behavior, hidden business rules, defensive shortcuts, and whether validation downgraded a user path to programmatic evidence.

### Gate 6: Risk Check

For S2/S3, check data loss, compatibility, rollback, security, concurrency, performance, deploy/runtime, Docker/platform, third-party dependency, remote/external state, and user-flow false-positive risk.

### Gate 7: Persistence / Reproducibility Check

```text
Temporary scripts captured: yes/no/N/A
Remote host changes captured: yes/no/N/A
External deploy files captured or documented: yes/no/N/A
Patch/YAML/Python/config changes captured: yes/no/N/A
Re-run command or runbook exists: yes/no/N/A
```

If required changes exist only in runtime/manual state, final status cannot be PASS.

### Gate 8: User-Flow Evidence Check

Required for UI/browser/user-path tasks. Read `user-flow-evidence.md`.

```text
Failed user entry point reproduced: yes/no/N/A
Same UI path exercised after fix: yes/no/N/A
User-visible controls interacted with: yes/no/N/A
Relevant Network request captured: yes/no/N/A
Status/result verified in browser: yes/no/N/A
Next user action possible: yes/no/N/A
Programmatic shortcuts used only for setup/diagnosis: yes/no/N/A
```

If this gate is required but missing, final status is PARTIAL or BLOCKED, not PASS.

### Gate 9: Optional External Review

Use only when required by the contract/rubric, useful for risk, or requested by the user. Read `external-review.md` first.

```text
External tool/skill used: none/code-review-skill/open-code-review/other
Scope reviewed: working copy/commit/branch/PR
High findings accepted: [list]
Medium findings accepted: [list]
Findings rejected and why: [list]
Auto-fixes applied: yes/no
```

External review can move status to NEEDS_REVISION if it finds evidence-backed blocking issues. External review cannot make a task PASS when E2E/user-flow/root-cause/persistence gates are missing.

### Gate 10: Fresh Review / Outcome Evaluation

Use a fresh evaluator with ONLY the contract, Outcome Snapshot, final diff, verification output, E2E impact map/evidence, user-flow evidence if relevant, external review summary if any, persistence status, and relevant architecture constraints. Do not include implementer self-justification or previous reviewer conclusions.

## Error Recovery

When a gate fails:

1. Identify root cause: code bug, test bug, contract bug, rubric bug, missing E2E slice, environment issue, user-flow evidence gap, stale remote state, external-review blocker, or missing information.
2. Classify status: PASS / NEEDS_REVISION / PARTIAL / BLOCKED / FAILED.
3. Fix the root cause; do not weaken tests, patch symptoms, or replace user flow with a diagnostic shortcut.
4. Persist the durable fix.
5. Rerun the failing gate and subsequent gates.
6. After max loops, stop and ask for the smallest next decision.

## Final Response

Never say "done" unless verification passed or limitations are explicit.

```md
# Result

Status: PASS / NEEDS_REVISION / PARTIAL / BLOCKED / FAILED

## What changed
- ...

## Outcome / Rubric Evidence
| Criterion | Status | Evidence |
|-----------|--------|----------|
| R-001 / AC-001 | PASS/FAIL/NOT VERIFIED | ... |

## E2E Scope Discovery
- Entry points discovered:
- Upstream prerequisites covered:
- Downstream effects covered:
- E2E slice run:
- Skipped dependencies and why:
- Programmatic setup used:

## Root Cause (for fixes/repairs)
- Failure:
- Root cause:
- Durable fix:
- Regression evidence:

## Commands run
| Command | Exit | Notes |
|---------|------|-------|
| ... | 0/1/NOT RUN | ... |

## User-Flow Evidence (when applicable)
- Entry point:
- Controls/actions:
- Network request/status:
- UI result/error state:
- Next user action possible: yes/no/N/A
- Programmatic shortcuts used only for setup/diagnosis: yes/no/N/A

## External Review (when applicable)
- Tool/skill used:
- High findings accepted:
- Medium findings accepted:
- Findings rejected and why:
- Auto-fixes applied:

## Diff scope
- Changed files:
- Out-of-scope:

## Persistence
- Temporary/remote/manual changes captured: yes/no/N/A
- Where captured:
- Remaining non-repeatable state:

## Risks
- Remaining:

## Follow-ups
- ...
```

If any required command, E2E slice, user-flow evidence, or required external review was not obtained, say `NOT RUN` / `NOT VERIFIED` and explain why.

## Special Modes

| Mode | Effect |
|------|--------|
| `grill` | Clarify requirements. Output Decision Log + draft ACs. No code edits. |
| `contract` | Produce only Goal Contract and Outcome Snapshot. No code edits. |
| `plan` | Produce only implementation plan. No code edits. |
| `e2e-scope` | Discover entry points, upstream prerequisites, downstream effects, and proposed E2E slice. No unrelated code edits. |
| `user-flow` | Produce or verify browser/user-path evidence plan. No unrelated code edits. |
| `external-review` | Plan or run optional external review using a separate review skill/tool. No auto-fixes unless requested. |
| `execute` | Execute against an approved contract/outcome. If none exists, create one first. |
| `outcome` | Produce or refine Outcome Snapshot and rubric only. No code edits. |
| `review` | Evaluate diff against contract + rubric + evidence. Blocking issues only. |
| `repair` | Fix failed verification. Fix root cause, rerun relevant gates, do not expand scope. |
| `persist` | Audit temporary/manual/remote changes and convert them into repo-tracked scripts/config/templates/runbooks. |

## Token Economy

- Do not spawn multiple subagents by default.
- Do not repeatedly reread the whole repository.
- Do not create long speculative design docs.
- Keep contracts concise; reuse discovered repo commands.
- Do not create progress artifacts for small tasks that fit in one session.
- Do not repeat expensive large-artifact compression, full hashing, or unpack/repack checks inside the development loop when targeted evidence proves the changed surface.
- For large tasks, split into chained contracts/outcomes.
- Prefer rubric evidence, E2E scope evidence, root-cause notes, user-flow evidence, persistence status, external-review summary, and targeted diffs over narrative summaries.

When context grows large, keep only confirmed contract + rubric + ACs + changed files + commands + failures + E2E scope + root cause + user-flow evidence + persistence status + accepted external-review findings.

## Repository Knowledge

If the task reveals durable knowledge, propose adding to small files — not a giant spec system:

```text
docs/ai/invariants.md
docs/ai/known-pitfalls.md
docs/ai/verification.md
docs/runbooks/
```

Only with user approval. Good durable knowledge: architecture invariants, business rules tests depend on, deployment constraints, Docker image/platform constraints, production incidents, repeatable deployment/runbook steps, and stable E2E/user-flow validation commands. Bad: verbose narration, temporary debug notes, duplicate design docs, stale wishlists.
