# Loop Verify — E2E Scope Discovery

Use this guide when the user asks the agent to develop a feature or fix and then validate it with agent-browser, Playwright, Cypress, or manual browser E2E.

The user should not have to enumerate every upstream and downstream dependency. The agent must infer the minimum useful E2E scope from the repository and then ask only for genuinely missing business decisions.

Core rule:

```text
Do not ask the user to write the whole E2E map. Discover it from code, routes, UI, APIs, docs, and existing tests.
```

---

## What to Discover

Before finalizing the Goal Contract or E2E plan, produce a compact Impact Map.

```md
# E2E Impact Map

## Trigger / entry points
- UI pages, modals, forms, buttons, API endpoints, CLI commands, jobs, webhooks, scheduled tasks

## Upstream prerequisites
- login/session/role
- workspace/project/cluster/namespace
- seed data or config
- feature flags
- external services or default endpoints

## Changed surface
- files/modules/components/handlers/services touched by this task

## Downstream effects
- API requests
- DB writes/reads
- Kubernetes/cloud resources
- messages/events/jobs
- generated files/manifests
- visible UI state
- next user action

## Existing verification
- unit tests
- integration tests
- E2E tests
- runbooks
- curl examples

## Proposed E2E slice
- the smallest realistic vertical path that proves the user-visible outcome
```

Keep it short. The map is a planning tool, not a new spec system.

---

## Discovery Checklist

Look for these sources before asking the user:

```text
□ Route definitions / router tables / menu config
□ Page component / modal / wizard / form component
□ API client call used by the UI
□ Backend route / controller / handler / service
□ Request/response type definitions
□ Store/state management / hooks / composables
□ Existing E2E tests for nearby flows
□ Existing unit/integration tests for touched modules
□ Default values and config files
□ Role/workspace/cluster/namespace assumptions
□ Downstream resource creation or side effects
□ Error handling path and user-visible error state
```

Only ask the user about choices that the code and docs cannot answer.

---

## E2E Slice Selection

Choose one or more slices based on risk.

| Slice | Use when | Example |
|-------|----------|---------|
| Smoke path | Low-risk UI/display feature | page opens, value visible, no console/network error |
| Thin vertical path | Normal feature/fix | UI action → request → backend → visible result |
| Critical business path | risky business logic | create workload → add container → image search → next step |
| Failure path | error handling changed | upstream unavailable → controlled UI error, not raw 500 |
| Regression path | bug fix | exact previous failure shape no longer fails |

Default for new UI-facing features: run at least a thin vertical path. For user-reported defects: include the regression path. For risky deployment/backend proxy changes: include failure paths.

---

## What the Agent Must Not Do

```text
□ Do not validate only the component you changed when the user-visible path crosses component/API/backend boundaries.
□ Do not stop at unit/build success for a UI-facing change.
□ Do not use API seeding or direct backend calls as the main proof for a UI creation/edit/search workflow.
□ Do not validate only the final list/detail page if the change is in a wizard/form/selector.
□ Do not test only ideal fake upstreams when default/real upstream behavior matters.
□ Do not ask the user to manually list all upstream/downstream dependencies before doing recon.
```

---

## Goal Contract Add-on

Add this to S1+ tasks when E2E validation is expected:

```md
## E2E Impact Map
- Entry points:
- Upstream prerequisites:
- Changed surface:
- Downstream effects:
- Existing verification:
- Proposed E2E slice:

## E2E Acceptance Criteria
- AC-E2E-001: The proposed E2E slice starts from the real user/product entry point.
- AC-E2E-002: The slice crosses the changed surface and its main downstream effect.
- AC-E2E-003: The assertion checks user-visible outcome or externally observable effect.
- AC-E2E-004: Programmatic setup is limited to prerequisites and is not the main proof.
- AC-E2E-005: Any skipped upstream/downstream dependency is listed with reason.
```

---

## Final Report Add-on

```md
## E2E Scope Discovery
- Entry points discovered:
- Upstream prerequisites covered:
- Downstream effects covered:
- E2E slice run:
- Skipped dependencies and why:
- Programmatic setup used:
- Result: PASS/PARTIAL/BLOCKED
```

Status rules:

```text
Impact map produced + representative slice passed → PASS eligible
Only unit/API/component checks passed → PARTIAL
Cannot identify or run any representative slice → BLOCKED or NEEDS_REVISION
Skipped critical downstream effect without reason → FAILED verification
```

---

## Example: Workload container image search

Feature/change area:

```text
Frontend image selector + mirrorList backend integration
```

Impact map should discover:

```text
Entry point:
- Create Workload modal / Add Container step

Upstream prerequisites:
- logged-in session
- workspace, cluster, namespace
- default image registry address

Changed surface:
- image selector component
- API client action for mirrorList
- backend controller/service/proxy for image search

Downstream effects:
- browser POST mirrorList
- registry/proxy response mapping
- selectable repository:tag list
- Next/Continue button enabled after selection

Proposed E2E slice:
- open Create Workload
- reach Add Container
- type image keyword
- wait for browser mirrorList request
- assert not 500
- select returned tag or assert controlled empty/error state
- verify Next/Continue state
```

The user does not need to write this map. The agent should infer it from routes, components, API clients, and existing tests, then ask for missing credentials/environment only if needed.
