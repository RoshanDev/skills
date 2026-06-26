# Loop Verify — Reference

Detailed checklists, reviewer prompt, root-cause repair, persistence checks, and error-handling guidance. Read relevant sections for S2/S3, Docker/platform, deployment, remote-host, review, or repair tasks.

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
□ Remote/deploy state — cloud host scripts, deployment templates, external disk config, generated YAML?
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

## Gate 0: Root-Cause Check

Use this for bugfixes, failed verification, repair loops, flaky tests, deployment failures, and user-reported defects.

### Root-cause template

```text
Failure:
- What failed? Include command, log excerpt, observed behavior, or reproduction steps.

Expected behavior:
- What should have happened according to the Goal Contract or existing behavior?

Root cause:
- What actually caused the failure?

Owning layer:
- caller / callee / config / data / environment / deployment / dependency / test / docs

Durable fix:
- What changed at the owning layer?

Regression evidence:
- Test, command, or check that would fail before and pass after.

Why this is not a band-aid:
- Explain why the fix addresses the cause rather than masking the symptom.
```

### Band-aid smell checklist

Flag and stop if the proposed fix does any of these without explicit approval:

```text
□ Adds catch-all error swallowing
□ Adds arbitrary sleep/retry/timeout without proving the failure mode
□ Weakens or deletes a failing test
□ Changes expected behavior to match current broken behavior
□ Special-cases only the observed bad input when the bug is general
□ Patches generated files but not the generator/template
□ Patches a remote host but not the repo source/runbook
□ Leaves a successful direct remote command, ad hoc script, Helm command, kubectl patch, or copied-bundle edit without a durable source update
□ Creates a patch or overlay layer even though the editable source/template/package input is available and the task is still in development
□ Adds defensive nil/empty/default handling without explaining why invalid state exists
□ Moves the failure elsewhere instead of fixing ownership layer
```

### Root-cause depth rule

Do not run endless analysis. Use this decision rule:

```text
Can the root cause be identified within the current contract and safe scope?
├─ YES → fix the owning layer and add evidence
├─ NO, but a safe workaround is explicitly requested → label it as workaround, add follow-up root-cause task
└─ NO, root-cause fix requires larger/riskier scope → BLOCKED or ask user to reopen scope
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
□ No generated/deployed file changed without changing its durable source/template
□ No live-only remote, Helm, kubectl, generated YAML, or offline-bundle change remains as the only implementation
□ No patch/overlay archive is used as the primary development fix when the source is available
□ git diff --stat line count is proportional to task scope
```

**When to flag:** If any unplanned file, unapproved image/dependency change, or non-durable generated/deploy change appears in the diff, stop. Either update the contract with user approval or revert the change.

---

## Persistence Source-Truth Checklist

Use this when a task touches deployment, remote hosts, Helm, Kubernetes objects, generated YAML, offline artifacts, or copied release bundles.

```text
□ Every successful direct remote command is either productized or recorded as diagnostic-only
□ Every ad hoc Python/shell script has an equivalent checked-in script, template, generator, or runbook
□ Every Helm value/template change is captured in the chart or source defaults, not only in a live release
□ Every kubectl patch is backed by source manifests, controllers, defaults, or a documented replay path
□ Every copied/offline bundle edit is synced back to the package source or accompanied by exact external path and checksum update instructions
□ Image registry, tag, digest, and checksum metadata agree across source, generated artifacts, live runtime, and offline package inputs
□ Frontend UI changes are verified against the deployed artifact/image, not only the source tree or local build output
□ Offline package fixes update the archive/OCI blobs and metadata, image list, digest list, chart/templates, and all affected checksums; a live Harbor push alone is not sufficient
□ Topology belongs in inventory/config; no 1-node, 3-node, or N-node-only fork was introduced for reusable logic
□ Stale blocker/status notes were marked superseded when newer user clarification or newer E2E evidence changed the current truth
```

Final PASS is not allowed if a required fix survives only in shell history, a temp file, a live cluster, or an untracked external bundle.

---

## Secret Evidence Checklist

Use this when browser/API/internal-network flows include passwords, tokens, access keys, kubeconfigs, registry credentials, or SSH credentials.

```text
□ Evidence profile selected: public-safe / internal-lab / trusted-lab-unredacted
□ For internal-lab, secrets came from approved local private sources: ignored env file, secret store, kubeconfig path, existing browser profile, Playwright storage state, cookie/session file, or private project doc
□ For internal-lab, the agent used real login/session state when practical instead of building extra API-token injection scripts
□ For trusted-lab-unredacted, user/project context explicitly allows raw values in private local evidence, final chat answers, screenshots, logs, HARs, or private commits
□ The product contract actually requires the secret in the payload, or the secret was moved to a safer mechanism
□ Under public-safe/internal-lab, request bodies containing secrets were not printed, screenshot, HAR-captured, committed, or copied into notes/finals
□ Under public-safe/internal-lab, shell commands did not pass secrets as visible argv flags, except narrowly scoped internal-lab browser form entry when the tool has no stdin/session alternative and the raw value is not persisted or reported
□ Under public-safe/internal-lab, evidence uses redacted summaries, status codes, resource names, or Secret existence checks instead of raw secret values
□ Under trusted-lab-unredacted, raw values may be preserved in the trusted lab context when useful; do not spend extra effort redacting evidence unless it will leave that context
□ Logs and telemetry added by the change do not persist secrets outside the selected profile's allowed context
□ Public repos and public skills contain placeholders, not lab endpoints, account names, access keys, secret keys, passwords, kubeconfigs, or tokens
```

---

## Gate 4: Drift Check — Detailed Questions

Compare the final diff against the Goal Contract. Ask each question:

**Intent alignment:**
- Does the implementation solve the problem described in the Intent section?
- Or did it solve a slightly different (but related) problem?

**Assumption validity:**
- List each assumption from the contract. Is each still true after implementation?
- Did any external dependency or environment state invalidate an assumption?

**Scope integrity:**
- Did any out-of-scope behavior change (even "improvements")?
- Were any "forbidden changes" silently included?

**Semantic drift:**
- Did tests assert implementation details instead of business behavior?
- Did the agent silently change error handling, logging, retry behavior, image references, environment state, or platform assumptions to make tests pass?
- Were any third-party library or image behaviors replaced with guessed/mock behavior?

**Hidden rules:**
- Did the implementation add business rules not in the contract? (extra validation, new defaults, magic numbers)

**Repair drift:**
- Did the fix address the owning layer or only patch the failure site?
- Did the fix introduce defensive behavior that hides invalid upstream state?

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
| **Remote/external state** | Does success depend on a manual cloud-host edit, external disk file, or untracked temp script? |

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

## Gate 6: Persistence / Reproducibility Check

Use this whenever the agent creates or changes scripts, configs, YAML, Python helpers, patches, remote host files, deployment files, or external disk files.

### Persistence checklist

```text
□ Can a fresh checkout reproduce the fix or workflow?
□ Are temporary scripts moved into repo-tracked scripts/ or tools/ if reusable?
□ Are YAML/config/deploy changes made in source templates, not only generated output?
□ Are remote cloud-host edits represented in Ansible/Terraform/Kubernetes/Helm/KubeKey/config templates or a runbook?
□ Are patch files stored under patches/ or documented with apply commands?
□ Are external disk deployment files synced back or documented with exact source-of-truth path?
□ Are one-off manual commands captured in docs/runbooks/ or Makefile/task scripts when they must be repeated?
□ Does final response list any remaining non-repeatable state?
```

### Recommended landing zones

Use the repo's existing convention first. If none exists:

| Artifact | Preferred location |
|----------|--------------------|
| Reusable helper script | `scripts/` or `tools/` |
| Deployment/run command | `docs/runbooks/` |
| K8s/Helm/KubeKey YAML | `deploy/`, `k8s/`, `helm/`, or existing infra directory |
| Patch file | `patches/` with apply instructions |
| Environment template | `.env.example`, `config/`, or `deploy/templates/` |
| Verification command | `Makefile`, `Taskfile.yml`, `justfile`, or `docs/ai/verification.md` |

### Final status rule

```text
All required durable changes repo-tracked or documented? → PASS eligible
Some manual state remains but task can still be reviewed? → PARTIAL
Workflow only succeeds due to untracked remote/temp/external state? → BLOCKED
```

---

## Gate 7: Fresh Review Prompt

For S2/S3 tasks (required) and S1 tasks (optional). When spawning a review subagent, use this exact prompt:

```text
You are a blocking code reviewer.

Review only against the Goal Contract, diff, verification output, persistence status, and relevant architecture constraints.

Report only merge-blocking issues:
- correctness bug
- violated acceptance criterion
- unverified acceptance criterion
- scope creep (changes outside the contract)
- symptom patch that does not address the root cause
- non-repeatable fix relying on remote/temp/manual state
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
   - evidence: [what in the diff, root-cause note, persistence status, or test output shows the problem]
   - minimal fix: [smallest change to resolve]
3. Missing verification:
   - [ACs or scenarios that lack evidence]
4. Persistence gaps:
   - [remote/temp/manual state not captured]
5. Risk notes:
   - [residual risks that don't block merge but should be tracked]
```

**Critical:** The reviewer must receive ONLY:
- Goal Contract
- Final diff (`git diff`)
- Verification output (test results, exit codes)
- Root-cause note for fixes/repairs
- Persistence status for remote/manual/deploy tasks
- Relevant architecture constraints from CLAUDE.md/AGENTS.md

The reviewer must NOT receive:
- The implementer's self-justification
- Previous reviewer conclusions
- Long narrative summaries
- Hidden chain-of-thought

---

## Error Recovery Guide

### When a gate fails:

1. **Identify root cause** — is it a code bug, a test bug, a contract bug, an environment issue, missing information, or stale remote/external state?
2. **Fix the root cause** — never fix by:
   - Deleting a failing test
   - Weakening test assertions to make them pass
   - Changing expected behavior to match buggy code
   - Removing an AC from the contract
   - Silently changing deployment/image/platform assumptions
   - Leaving the only fix on a remote host, temp directory, generated file, or external disk
3. **Persist the durable source** — update source templates, repo scripts, runbooks, or config files.
4. **Rerun the failing gate** and all subsequent gates.
5. **Max 3 repair loops.** After 3 failures:
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
| Works only on remote host | Manual remote edit or temp script not captured | Move change into repo source template/script/runbook |
| Same issue returns next run | Durable source not changed, only runtime artifact changed | Patch generator/template/source-of-truth |
| Defensive code hides bad input | Ownership layer is upstream validation/config/data | Fix upstream or stop and ask to expand scope |

### When to escalate immediately (don't attempt repair):

- Required information is missing and cannot be inferred
- The root-cause fix requires scope expansion
- The fix requires changes to forbidden files
- The fix requires adding unapproved dependencies
- The fix requires changing third-party image registry, tag, digest, platform, or base image without approval
- A required third-party image platform is missing
- Required remote/external state cannot be captured or documented
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
│  ├─ YES → Run verification loop (Gates 0-7 as relevant)
│  └─ NO (blocked) → Fail fast: state the blocker
├─ All required gates pass?
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
| **Persistence** | If we change a remote host or generated file, where is the source-of-truth template in the repo? |

**Do NOT ask:**
- Things you can discover by reading the repo
- Preferences that don't affect implementation
- Multiple questions at once (one at a time)
- Permission to read files (just read them)
- The user to restate the whole problem
