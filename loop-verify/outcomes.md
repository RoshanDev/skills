# Loop Verify — Outcome Rubrics

This file adapts the managed-agent outcome pattern to local coding agents.

Claude Managed Agents describe an outcome as the end result plus the quality rubric used to evaluate it. Their managed harness evaluates the artifact with a separate grader context and returns feedback for the next iteration. In this skill, the same idea becomes a local pattern:

```text
Outcome = description + rubric + max iterations + terminal status
Rubric = AC evidence + root-cause evidence + persistence evidence + risk gates
Evaluator = fresh review or mechanical CI gate with only contract, diff, and outputs
```

Use this file when:

- running S2/S3 tasks
- using `execute`, `repair`, `review`, or `persist`
- the user asks for autonomous loop work
- the task has ambiguous "done" criteria
- the task touches deployment, remote hosts, Docker/platform, secrets, data, or multi-service behavior
- the task may span context compaction, multiple sessions, or long-running autonomous loops

For long-running or resumable work, also use [long-task-progress.md](long-task-progress.md).

---

## Outcome Snapshot

Before implementation for S1+ tasks, compress the Goal Contract into a short Outcome Snapshot.

```md
# Outcome Snapshot

## Description
[one paragraph: what artifact or system state should exist when done]

## Rubric
- R-001 / AC-001: [observable criterion and required evidence]
- R-002 / AC-002: [observable criterion and required evidence]
- R-RC: For repair tasks, root cause is identified, owning layer fixed, and regression evidence exists.
- R-PERSIST: Temporary/manual/remote/deployment changes are repo-tracked or explicitly documented as one-off risk.
- R-LONGTASK: If progress artifacts are used, feature_list.json and progress.md are current and consistent with git/test evidence.
- R-SCOPE: Diff stays within approved boundaries.
- R-RISK: S2/S3 risk gates have no unhandled blocking risk.

## Max iterations
3 unless the user explicitly chooses another limit.

## Terminal statuses
- PASS: all required rubric criteria satisfied with evidence
- NEEDS_REVISION: a bounded repair loop is safe and in scope
- PARTIAL: useful work exists, but at least one non-blocking criterion lacks evidence
- BLOCKED: missing decision, missing environment, forbidden change, or non-repeatable remote/temp-only state
- FAILED: rubric contradicts the task or repeated repair failed
```

Keep this short. Do not create a second long spec. The Outcome Snapshot is a compressed grading target.

---

## Rubric Writing Rules

Good rubric criteria are:

- observable from test output, command output, diff, logs, screenshots, or runbook evidence
- tied to AC IDs when possible
- strict enough to catch silent drift
- focused on behavior, not implementation preference
- explicit about persistence/repeatability for deploy or remote tasks
- explicit about root cause for repair tasks
- explicit about progress artifacts when the task spans multiple sessions

Bad rubric criteria are:

- "code looks good"
- "implementation is robust"
- "handle edge cases" without naming the edge cases
- "make it production ready"
- "ensure compatibility" without naming the compatibility contract
- "fix the root cause" without requiring reproduction and owning-layer evidence
- "continue from last time" without naming the progress artifact to read

---

## Local Outcome Loop

Use this loop instead of free-form self-certification:

```text
1. Define Outcome Snapshot
2. If the task is long-running, initialize or read progress artifacts
3. Implement minimal slice
4. Run mechanical gates
5. Evaluate rubric using only:
   - Goal Contract / Outcome Snapshot
   - progress.md / feature_list.json when used
   - final diff
   - command outputs and exit codes
   - AC/root-cause/persistence evidence
   - relevant invariants
6. If NEEDS_REVISION and attempts remain: repair root cause, rerun relevant gates
7. If PASS/PARTIAL/BLOCKED/FAILED: stop and report status
```

The evaluator must not receive the implementer's persuasive summary. Use evidence, not vibes.

---

## Long-Task Resume Pattern

For tasks that may run across context compactions or multiple sessions:

```text
1. At start: read progress.md, feature_list.json, recent git log, and run a minimal health check.
2. Pick the next feature whose status is failing.
3. Work only until a logical milestone.
4. Update feature_list.json with passing/failing/blocked/superseded plus evidence.
5. Update progress.md with current state and next action.
6. Commit or persist progress artifacts when appropriate.
```

Every feature starts as `failing`, not `todo`. It becomes `passing` only with evidence. See [long-task-progress.md](long-task-progress.md).

---

## Mapping to Managed-Agent Outcomes

When using Claude Managed Agents, map fields as follows:

```text
user.define_outcome.description = Outcome Snapshot / Description
user.define_outcome.rubric      = Outcome Snapshot / Rubric
max_iterations                  = Outcome Snapshot / Max iterations
span.outcome_evaluation_end     = local final status mapping
```

Recommended defaults:

- S1: max_iterations = 2 or 3
- S2/S3: max_iterations = 3
- emergency workaround: max_iterations = 1, status must disclose workaround risk
- exploratory task: do not use outcome mode until the artifact and rubric are clear

---

## Reviewer Rubric Prompt

Use this when a fresh review is required.

```text
You are an outcome evaluator, not a co-implementer.

Evaluate only the supplied Goal Contract, Outcome Snapshot, progress artifacts if used, final diff, command outputs, AC evidence, root-cause note, persistence status, and relevant invariants.

Do not use the implementer's self-justification.
Do not infer success without evidence.
Do not report style nits.

Return:
1. Result: PASS / NEEDS_REVISION / PARTIAL / BLOCKED / FAILED
2. Rubric table:
   - criterion:
   - status:
   - evidence:
   - minimal revision if not satisfied:
3. Missing evidence:
4. Scope drift:
5. Root-cause or persistence gaps:
6. Progress artifact gaps:
7. Risk notes:
```

---

## Status Mapping

```text
All rubric criteria satisfied with evidence
→ PASS

A criterion fails, but the fix is safe, scoped, and attempts remain
→ NEEDS_REVISION

Useful artifact exists, but optional/manual evidence is missing or environment prevented full verification
→ PARTIAL

Required user decision, forbidden change, missing environment, missing platform, or remote-only state prevents repeatable success
→ BLOCKED

Rubric contradicts task, tests cannot represent desired behavior, progress files are inconsistent with evidence, or max repair attempts failed
→ FAILED
```

A task with required untracked remote/temp/manual state cannot be PASS.
A repair without root-cause evidence cannot be PASS unless the user explicitly requested a bounded workaround.
A long-running task whose progress artifacts are stale or inconsistent cannot be PASS.
