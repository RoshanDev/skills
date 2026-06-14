# Loop Verify — Reference

Detailed checklists, reviewer prompt, and error-handling guidance. The agent reads this file when running verification gates or fresh review on S2/S3 tasks.

---

## Recon Phase Checklist

Before asking the user anything, inspect the repository. Use this checklist to avoid asking questions the code already answers.

```text
□ Repo layout — what are the top-level directories and their purpose?
□ Build system — Makefile, package.json scripts, go.mod, Cargo.toml?
□ Test commands — how does the project run tests? (make test, go test, pytest, npm test, etc.)
□ Lint/format — golangci-lint, eslint, ruff, prettier?
□ CI config — .github/workflows/, .gitlab-ci.yml? What gates exist?
□ Existing project-level specs — CLAUDE.md, AGENTS.md, docs/ai/, CONTRIBUTING.md?
□ Architecture docs — any ADRs, design docs, invariants files?
□ Docker/deployment — Dockerfile, docker-compose, k8s manifests, Terraform?
□ Dependencies — what major frameworks/libs are in use?
□ Existing patterns — how are similar features implemented? (pick one nearby example)
```

Output a concise recon summary (not a novel):

```text
Recon summary:
- Relevant files: [list]
- Existing patterns: [brief description]
- Likely test commands: [commands from Makefile/package.json/etc.]
- Risk areas: [what could go wrong]
- Unknowns that need user input: [only genuine unknowns]
```

---

## Gate 1: Diff Scope — Detailed Checklist

```text
□ Only files listed in "Allowed changes" are modified
□ No files listed in "Forbidden changes" are touched
□ No unrelated refactors (renaming variables in untouched functions)
□ No hidden dependency additions (new imports, require(), go.mod changes)
□ No broad formatting churn (prettier/eslint run across untouched files)
□ No test-only changes without corresponding production code (unless the AC required it)
□ No deleted files unless explicitly planned
□ No Docker base image, vendor image, registry, tag, digest, or platform changes unless approved
□ git diff --stat line count is proportional to task scope
```

**When to flag:** If any unplanned file or unapproved image/dependency change appears in the diff, stop. Either update the contract with user approval or revert the change.

---

## Gate 4: Drift Check — Detailed Questions

Compare the final diff against the Goal Contract. Ask each question:

**Intent alignment:**
- Does the implementation solve the problem described in the Intent section?
- Or did it solve a slightly different (but related) problem?

**Assumption validity:**
- List each assumption from the contract. Is each still true after implementation?
- Did any external dependency change invalidate an assumption?

**Scope integrity:**
- Did any out-of-scope behavior change (even "improvements")?
- Were any "forbidden changes" silently included?

**Semantic drift:**
- Did tests assert implementation details (e.g., specific function calls) instead of business behavior (e.g., observable outcomes)?
- Did the agent silently change error handling, logging, retry behavior, image references, or platform assumptions to make tests pass?
- Were any third-party library or image behaviors replaced with guessed/mock behavior?

**Hidden rules:**
- Did the implementation add business rules not in the contract? (e.g., extra validation, new defaults, magic numbers)

---

## Gate 5: Risk Check — S2/S3 Checklist

For S2/S3 tasks, run through each risk category:

| Risk Category | Check |
|---------------|-------|
| **Data loss** | Can any operation lose user data? Are destructive operations wrapped in transactions? |
| **Compatibility** | Does this break existing API consumers? Are old behaviors preserved for unmodified clients? |
| **Migration/rollback** | Is there a rollback path? Has the DOWN migration been tested? |
| **Security** | Are there new attack surfaces? Auth bypass? SQL injection? Unvalidated input? |
| **Concurrency** | Race conditions? Deadlocks? Shared mutable state without locking? |
| **Performance** | N+1 queries? Unbounded loops? Memory leaks? Missing indexes for new queries? |
| **Deploy/runtime** | Environment-specific assumptions? Missing config? Port conflicts? |
| **Platform** | Docker image architecture? OS-specific paths? Case-sensitive filesystems? |
| **Third-party dependency/image** | Did any registry, tag, digest, base image, or platform support assumption change? |

Only report risks that are concrete and actionable. Do not invent hypothetical risks.

### Docker / Multi-Architecture Checklist

Use this when the task touches Dockerfile, compose, Kubernetes manifests, buildx, CI image publishing, base images, or third-party images.

```text
□ Is this a first-party image or a third-party/vendor image?
□ If first-party: is multi-arch implemented through buildx/buildkit or the repo's existing image pipeline?
□ If Go: are TARGETOS/TARGETARCH or equivalent cross-build settings used where appropriate?
□ If third-party: did you inspect the manifest/platform list before making changes?
□ Did the diff avoid changing third-party registry/tag/digest/platform unless explicitly approved?
□ If a required platform is missing, did you stop and report instead of rewriting/rebuilding/emulating it?
□ Does verification include image manifest/build evidence when the AC requires platform support?
```

Useful evidence commands when available:

```bash
docker buildx imagetools inspect <image>
docker buildx build --platform linux/amd64,linux/arm64 ...
```

If a required third-party image platform is missing, final status must be `BLOCKED` unless the user explicitly approves a mitigation.

---

## Gate 6: Fresh Review Prompt

For S2/S3 tasks (required) and S1 tasks (optional). When spawning a review subagent, use this exact prompt:

```text
You are a blocking code reviewer.

Review only against the Goal Contract, diff, and verification output.

Report only merge-blocking issues:
- correctness bug
- violated acceptance criterion
- unverified acceptance criterion
- scope creep (changes outside the contract)
- security/data/deployment risk
- compatibility break
- performance regression
- missing rollback for risky change
- unapproved dependency, Docker image, vendor image, or platform change

Do not report:
- style nits (formatting, naming preferences)
- suggestions for improvement that don't block merge
- praise or positive commentary

Do not infer without evidence. If you cannot confirm an issue from the provided materials, do not report it.

Output format:
1. Merge recommendation: yes / no
2. Blocking findings (if any):
   - file/line: [location]
   - violated contract/AC: [which AC or contract section]
   - evidence: [what in the diff or test output shows the problem]
   - minimal fix: [smallest change to resolve]
3. Missing verification:
   - [ACs or scenarios that lack evidence]
4. Risk notes:
   - [residual risks that don't block merge but should be tracked]
```

**Critical:** The reviewer must receive ONLY:
- Goal Contract
- Final diff (`git diff`)
- Verification output (test results, exit codes)
- Relevant architecture constraints from CLAUDE.md/AGENTS.md

The reviewer must NOT receive:
- The implementer's reasoning or self-justification
- Previous reviewer conclusions
- Long narrative summaries
- Hidden chain-of-thought

---

## Error Recovery Guide

### When a gate fails:

1. **Identify root cause** — is it a code bug, a test bug, a contract bug, an environment issue, or missing information?
2. **Fix the root cause** — never fix by:
   - Deleting a failing test
   - Weakening test assertions to make them pass
   - Changing expected behavior to match buggy code
   - Removing an AC from the contract
   - Silently changing deployment/image/platform assumptions
3. **Rerun the failing gate** and all subsequent gates
4. **Max 3 repair loops.** After 3 failures:
   - Stop
   - Report: what failed, what was tried, what remains
   - Escalate to user with the smallest decision needed

### Common failure patterns:

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Test fails, code looks correct | Test asserts implementation detail, not behavior | Rewrite test to assert business outcome |
| Test fails, test looks correct | Code has a logic bug | Fix the code |
| All tests pass but AC says "not verified" | AC has no corresponding test/evidence | Add evidence or mark NOT VERIFIED |
| Diff scope check fails | Agent made "improvements" outside scope | Revert out-of-scope changes |
| Drift check fails | Implementation drifted from intent | Reassess: update contract with approval or fix code |
| Build fails after passing tests | Missing dependency or import | Add dependency only if approved, otherwise fix import |
| Docker platform check fails | Required platform missing or wrong image assumption | Stop and report image/platform facts; do not rewrite vendor images |

### When to escalate immediately (don't attempt repair):

- Required information is missing and cannot be inferred
- The fix requires changes to forbidden files
- The fix requires adding unapproved dependencies
- The fix requires changing third-party image registry, tag, digest, platform, or base image without approval
- A required third-party image platform is missing
- The fix conflicts with an architecture invariant from CLAUDE.md/AGENTS.md
- Three repair attempts have failed

---

## Decision Tree

Quick-reference for common decision points during execution:

```text
User sends a coding request
├─ Can I classify this without reading code?
│  ├─ YES and it's trivial → S0: just do it
│  └─ NO → Read relevant files first (Recon)
├─ After recon, are important choices open?
│  ├─ YES → Grill (one question at a time)
│  └─ NO → Draft Goal Contract
├─ Goal Contract approved?
│  ├─ YES → Produce Implementation Plan, then implement in slices
│  ├─ MODIFY → Update contract, re-ask for approval
│  └─ CANCEL → Stop
├─ Implementation complete?
│  ├─ YES → Run verification loop (Gates 1-5)
│  └─ NO (blocked) → Fail fast: state the blocker
├─ All gates pass?
│  ├─ YES → Produce Final Response (Status: PASS)
│  ├─ PARTIAL → Produce Final Response (Status: PARTIAL, list what's missing)
│  └─ NO (after 3 repair loops) → Escalate (Status: BLOCKED)
└─ User mentions new requirement during execution?
   ├─ Compatible with current contract → Record as Follow-up
   └─ Conflicts with current contract → Stop and report
```

---

## Grill Question Bank

When unsure what to ask, draw from these categories. Only ask if the answer affects irreversible decisions:

| Category | Example Questions |
|----------|-------------------|
| **Business rule** | What happens when balance reaches zero? Is negative allowed? |
| **Compatibility** | Must the old API endpoint keep working? For how long? |
| **Failure behavior** | Retry on timeout? How many times? What if all retries fail? |
| **Data lifecycle** | Soft delete or hard delete? Is there a retention policy? |
| **API shape** | REST or GraphQL? Pagination style? Error response format? |
| **Concurrency** | Optimistic or pessimistic locking? What if two users edit simultaneously? |
| **Security** | Who can access this? Row-level security? Audit logging needed? |
| **Rollout** | Feature flag? Gradual rollout? Kill switch? |
| **Tradeoff** | Consistency vs availability? Speed vs accuracy? |
| **Verification** | How will we know this works in production? Monitoring? Alerts? |
| **Docker/platform** | Which platforms are required? Are third-party images allowed to change? What is the failure policy if a platform is missing? |

**Do NOT ask:**
- Things you can discover by reading the repo
- Preferences that don't affect implementation
- Multiple questions at once (one at a time)
- Permission to read files (just read them)
- The user to restate the whole problem
