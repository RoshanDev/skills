# Loop Verify — External Review Integrations

Use this guide when the user wants an additional code review pass using another review skill or a deterministic review tool.

Core rule:

```text
External review is advisory evidence, not a replacement for the Goal Contract, E2E scope, user-flow evidence, root-cause, persistence, or mechanical gates.
```

---

## When to Use External Review

Use an external review pass when any of these are true:

```text
□ S2/S3 task or large diff
□ Security, data, deployment, concurrency, performance, or public API risk
□ Multi-language or framework-specific review would help
□ Need a fresh review context to reduce implementer self-certification
□ The user explicitly asks for another reviewer/tool
```

Do not use it by default for S0/S1 small changes unless the user asks. Token and latency matter.

---

## What Not To Do

```text
□ Do not let external review override the user's Goal Contract.
□ Do not accept style nits as blocking findings.
□ Do not apply automatic fixes unless the user explicitly asked for review-and-fix.
□ Do not feed the implementer's persuasive summary into the reviewer.
□ Do not treat review comments as PASS evidence for E2E/user-flow behavior.
□ Do not install or configure third-party review tools using hidden credentials.
```

The reviewer should receive only:

```text
- Goal Contract / Outcome Snapshot
- final diff or PR diff
- command outputs and exit codes
- E2E/user-flow evidence when relevant
- persistence status when relevant
- architecture invariants / AGENTS.md / CLAUDE.md constraints
```

---

## Option A: Use `code-review-skill` Separately

`awesome-skills/code-review-skill` is useful as a separate on-demand deep review skill, especially for language/framework-specific review guides.

Recommended use:

```text
Use code-review-skill to review this diff.
Focus only on blocking/important issues against the supplied Goal Contract.
Ignore style nits handled by lint/formatters.
Do not praise or rewrite preference-only suggestions.
```

Best ideas to borrow:

```text
- Progressive disclosure: small core skill + on-demand language/framework guides
- Four-phase review: context → high-level design/test strategy → line-by-line → decision
- Severity labels: blocking / important / nit / suggestion
- Separate human review concerns from linter/formatter concerns
- Language-specific guides, especially for Go, TypeScript, React/Vue, security, performance
```

Do not copy all of it into loop-verify. It is broad and token-heavy by design. Keep it as a separate specialist skill or use only selected patterns.

---

## Option B: Use `open-code-review` CLI (`ocr`) As A Deterministic Fresh Review

`alibaba/open-code-review` is useful when you want deterministic file selection, line-level comments, rule matching, and a purpose-built review CLI.

Prerequisites:

```bash
which ocr
ocr llm test
```

If not installed, the user may install it separately:

```bash
npm install -g @alibaba-group/open-code-review
```

Do not hardcode LLM tokens. Use environment variables or the user's approved config.

### Recommended invocation

Pass business context from the Goal Contract as background:

```bash
ocr review --audience agent --background "<brief Goal Contract / business context>"
```

For branch comparison:

```bash
ocr review --audience agent --background "<context>" --from main --to <branch>
```

Preview first for large diffs:

```bash
ocr review --preview
```

### Classification

After OCR returns comments, classify them for loop-verify:

```text
High     → blocking candidate: clear bug, security issue, data loss, API break, deploy/runtime risk, verified performance regression
Medium   → discuss or fix if in scope: reasonable concern, test gap, maintainability risk
Low      → discard from final unless user asks: style nit, preference, weak context, duplicate, likely false positive
```

### Safety rules

```text
- Do not use OCR as the only review gate for UI/user-flow correctness.
- Do not auto-apply fixes unless the user explicitly asked for review-and-fix.
- If telemetry/content logging is enabled in OCR config, do not pass secrets or private payloads.
- If line positions are wrong, inspect the target file before acting.
- If OCR and loop-verify disagree, the Goal Contract and executable evidence win.
```

---

## Final Report Add-on

```md
## External Review
- Tool/skill used: none / code-review-skill / open-code-review / other
- Scope: working copy / commit / branch diff / PR
- Result summary:
- High findings accepted:
- Medium findings accepted:
- Findings rejected and why:
- Auto-fixes applied: yes/no
- Remaining external-review risks:
```

Status rules:

```text
External review found blocking issue with evidence → NEEDS_REVISION
External review only found nits/suggestions → PASS still possible
External review not run → not a blocker unless required by contract/rubric
External review passed but E2E/user-flow/root-cause/persistence gate missing → not PASS
```
