# Loop Verify — Long Task Progress Artifacts

Use this pattern for work that may run across multiple sessions, agent restarts, handoffs, or long autonomous loops.

Core rule:

```text
Do not rely on chat context as the task's memory. Persist long-task state as repo artifacts.
```

This is adapted from the Initializer Agent + Progress file pattern: initialize durable state once, then let coding sessions resume from that state.

---

## When To Use

Use this pattern when any of these are true:

```text
□ Task is expected to take more than one session
□ Session state may be lost due to restart, interruption, or handoff
□ Multiple features/subtasks must be completed and verified
□ Agent may crash/restart or be replaced by another agent
□ User wants sleep-after-work / autonomous loop behavior
□ Work needs resumable E2E or deployment verification
```

Do not force this on S0/S1 small tasks.

---

## Artifacts

Recommended files under an ignored or task-specific directory, for example `.agent-progress/<task-id>/` or `docs/ai/progress/<task-id>/`.

```text
progress.md          # human-readable current state and next action
feature_list.json    # machine-stable checklist, all items start failing
baseline_commit.txt  # commit SHA used as starting baseline
session_log.md       # optional short append-only summaries
```

Add the progress directory to `.gitignore` if it contains environment-specific or transient state. If the artifacts should be tracked (e.g., for audit), use `docs/ai/progress/` and commit them.

If the repo has a convention, use it. Do not create a giant spec system.

---

## Initializer Phase

Run once before a long task starts.

```text
1. Run environment init/preflight.
2. Create progress.md with task goal, constraints, current state, and next action.
3. Create feature_list.json with stable schema.
4. Mark every feature initially as "failing".
5. Record baseline git commit.
6. Commit or otherwise persist the progress artifacts if allowed.
```

### feature_list.json Schema

Use JSON because the schema is less likely to be casually rewritten than Markdown.

```json
{
  "task_id": "container-e2e-2026-06-18",
  "baseline_commit": "<sha>",
  "features": [
    {
      "id": "F-001",
      "description": "Create workload wizard can search image and continue",
      "status": "failing",
      "evidence": [],
      "blocking_reason": "not implemented or not verified"
    }
  ]
}
```

Allowed status values:

```text
failing     # not done or verification currently fails
passing     # verified with evidence
blocked     # cannot proceed without decision/env/access
superseded  # no longer current due scope change or newer evidence
```

Do not use vague values such as todo/done/unknown.

---

## Coding Session Resume Protocol

At the start of every resumed session:

```text
1. Read progress.md.
2. Read feature_list.json.
3. Read recent git log.
4. Run a minimal health check or baseline test.
5. Pick the next failing feature.
6. Continue from the stored state, not from memory.
```

At the end of every session:

```text
1. Update feature_list.json statuses and evidence.
2. Update progress.md with completed work, current blockers, and next action.
3. Commit code/progress changes when appropriate.
4. If a feature is not verified, keep it failing or blocked. Do not mark passing from narrative confidence.
```

---

## Verification Rules

```text
□ Every passing feature has evidence: command, exit code, E2E result, screenshot, Network result, or runbook output.
□ Every blocked feature has a minimal next decision or missing environment/access listed.
□ No feature is marked passing only because build/unit tests passed if the feature requires E2E.
□ If newer evidence supersedes old blockers, mark old entries superseded instead of leaving stale blocked truth.
□ If the task uses user-flow evidence, link the relevant E3/E4 evidence from user-flow-evidence.md.
```

---

## Session Handoff Boundaries

Do not trigger or request context shrinking, reset, or summarization from this skill. When a session naturally ends, restarts, or hands off, write durable state at logical boundaries:

```text
□ After recon/research, before implementation
□ After a feature reaches passing, before the next feature
□ After a debugging detour is resolved
□ After abandoning one approach and before trying another
□ Before handing off to another agent/session
```

Before ending or handing off, write durable state to progress artifacts. After restart or handoff, resume from artifacts.

---

## Final Report Add-on

```md
## Long-Task Progress
- Progress artifacts used: yes/no
- Baseline commit:
- Failing features remaining:
- Passing features and evidence:
- Blocked features and next decision:
- Progress files updated: yes/no
```

Status rules:

```text
All required features passing with evidence → PASS eligible
Some features passing, remaining failing or unverified → PARTIAL / NEEDS_REVISION
Blocked feature needs user decision/env/access → BLOCKED
Progress files stale or inconsistent with git/test evidence → FAILED verification
```
