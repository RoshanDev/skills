# Loop Verify — User-Flow Evidence Gate

Use this gate when the issue or feature is observed through a browser UI, modal, wizard, form, selector, button, screenshot, or browser Network panel.

Core rule:

```text
Programmatic checks are not user-flow evidence.
```

`curl`, hooks, Python scripts, API seeding, direct backend/KAPI calls, mocks, fake upstreams, direct DB edits, and generated-state shortcuts are useful for diagnosis and setup. They do not prove the user-facing path works unless the product being validated is itself an API or CLI.

---

## Evidence Levels

| Level | Evidence | Can support PASS for UI defect? |
|-------|----------|----------------------------------|
| E0 | Source diff, config diff | No |
| E1 | Unit test, build, lint | No |
| E2 | curl, Python script, hook, direct API call, API seeding | No, diagnosis/setup only |
| E3 | Browser Network request captured from the real UI path | Required when the failure involved Network |
| E4 | Browser-driven user interaction from the same entry point | Required |

Final PASS for a browser-reported issue requires E3/E4 when applicable. E0/E1/E2 can only support PARTIAL unless the user explicitly waives browser validation.

---

## When This Gate Is Required

Run this gate if any of these are true:

```text
□ User reported failure from a browser page, modal, wizard, form, selector, button, or page screenshot
□ User provided a browser Network request, status code, payload shape, or response body
□ The target behavior is selecting, creating, editing, deleting, searching, filtering, continuing to next step, or submitting from UI
□ The fix claims a frontend/backing API integration works
□ The workflow can be bypassed by API seeding, fake upstream, direct backend call, or pre-created resource
```

If the failure was reported from UI but this gate cannot run because login/session/environment is missing, final status is PARTIAL or BLOCKED, not PASS.

## Internal-Lab Credential Path

When the selected Evidence Profile is `internal-lab` or `trusted-lab-unredacted`, do not treat local credentials as unavailable just because they cannot be printed. Prefer these session sources, in order:

1. Existing Chrome profile already logged into the target environment.
2. Playwright/Cypress storage state or cookie/session file kept in an ignored local path.
3. Ignored local env file or approved secret store with test account credentials.
4. Manual login in the controlled browser when automation would cost more than it saves.

`internal-lab` allows the agent to use real accounts, cookies, sessions, kubeconfigs, and test credentials for E2E setup inside the private lab, while still redacting copied evidence. `trusted-lab-unredacted` additionally allows raw values in private local evidence, screenshots, HAR request bodies, durable task notes, private commits, and final chat answers when the user explicitly says that is acceptable. Avoid writing Python/API token-fetch-and-inject helpers unless they are already the repo convention or the auth mechanism itself is under test.

---

## Goal Contract Add-on

Add this section to the Goal Contract for UI/browser/user-path defects:

```md
## Failed User Path
- Entry point: <page/modal/wizard/form/button>
- User action sequence: <click/type/select/submit steps>
- Failed request or visible symptom: <Network request/status or UI error>
- Required environment/session: <login role, cluster, namespace, workspace, feature flag>

## User-Flow Acceptance Criteria
- AC-UF-001: The same UI entry point is exercised after the fix.
- AC-UF-002: The same user-visible controls are interacted with; no API-only shortcut satisfies this AC.
- AC-UF-003: The relevant browser Network request is captured from the UI path and has the expected status/result.
- AC-UF-004: The UI shows the expected result or error state.
- AC-UF-005: The next user action is possible when the scenario is supposed to proceed.
- AC-UF-006: curl/hooks/Python/API seeding are reported only as diagnosis/setup evidence.
```

---

## Implementation Plan Add-on

For UI/browser issues, the plan must include:

```md
## User-flow validation plan
- Tool: Playwright / Cypress / manual browser / existing E2E framework
- Entry point: <where the user starts>
- Actions: <click/type/select/submit sequence>
- Network capture: <request URL/action to wait for>
- Assertions:
  - request status/result
  - visible UI result or error state
  - next user action possible
- Programmatic setup allowed:
  - <namespace/project/login fixture/etc.>
- Programmatic setup not allowed as PASS evidence:
  - <direct object creation, fake upstream, direct backend-only call, etc.>
```

---

## Gate Checklist

```text
□ Did validation start from the same UI entry point where the user failed?
□ Were user-visible controls clicked/typed/selected/submitted?
□ Was the relevant Network request captured from the browser, not only reproduced with curl?
□ Was the status/result asserted?
□ Was the UI result/error state asserted?
□ Was the next user action verified when applicable?
□ Were programmatic shortcuts limited to setup/diagnosis?
□ If API seeding was used, did it avoid satisfying the main user-path AC?
□ If a fake upstream/mock was used, was real/default upstream behavior also covered or explicitly waived?
□ If real login/session/environment was missing, was the result marked PARTIAL/BLOCKED instead of PASS?
```

---

## Anti-patterns

### Bad: API seeding replaces creation wizard

```text
User bug: creation wizard cannot add a container.
Agent validation: call backend API to create the workload, then screenshot the workload list.
```

Wrong. This proves the list can render an existing object. It does not prove the wizard path works.

### Bad: curl replaces browser Network

```text
User bug: browser Network request returns 500.
Agent validation: curl a similar backend endpoint with a simplified payload and gets 200.
```

Wrong. The browser path may include different cookies, app-code, headers, default values, proxy routing, or payload shape.

### Bad: fake upstream replaces default upstream

```text
User bug: default image registry search fails.
Agent validation: test against fake Harbor and declare PASS.
```

Wrong. Fake upstream can test ideal handling, but cannot prove the default integration works.

### Bad: hook observes state but not user action

```text
Agent adds a hook to log that the API handler was called, but never clicks through the UI path.
```

Wrong. Observability helps diagnosis; it is not user-flow evidence.

---

## Final Report Add-on

For UI/browser/user-path issues, final response must include:

```md
## User-Flow Evidence
- Required: yes/no
- Entry point:
- Action sequence:
- Browser Network request:
- Request status/result:
- UI result/error state:
- Next user action possible: yes/no/N/A
- Tool used: Playwright/Cypress/manual/other
- Programmatic shortcuts used: none / setup only / diagnosis only
- Missing evidence: none / list
```

Status rules:

```text
E3/E4 required and present → PASS eligible
Only E0/E1/E2 present → PARTIAL
Cannot run browser path due missing session/environment → BLOCKED or PARTIAL
Programmatic shortcut used as main proof → FAILED verification
```

---

## Example: Deployment image search

Failure shape:

```text
Create Workload modal
→ Add Container
→ Search image
→ POST mirrorList
→ choose image tag
→ continue
```

Correct ACs:

```text
AC-UF-001: Open Create Workload from the UI and reach Add Container.
AC-UF-002: Type the image keyword in the image selector.
AC-UF-003: Capture the browser POST mirrorList request triggered by that UI action.
AC-UF-004: Assert the request does not return 500.
AC-UF-005: Assert the UI either lists selectable image tags or shows a controlled, user-readable error.
AC-UF-006: If tags are returned, select a tag and verify the Next/Continue action becomes possible.
```

Allowed supporting checks:

```text
- curl the same request for diagnosis
- add backend unit tests for error mapping
- test unreachable/non-compatible upstreams
- use API seeding for prerequisite namespace/workspace only
```

Not allowed as PASS evidence:

```text
- direct API-created deployment followed by list-page screenshot
- fake registry only
- backend health check only
- unit/build success only
- hook log showing the handler was called without UI path validation
```
