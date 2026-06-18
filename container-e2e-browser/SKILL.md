---
name: container-e2e-browser
description: Use when performing container module E2E testing with bb-browser automation. Covers bb-browser patterns, Ace/React form interaction, kubectl verification, and common pitfalls for GSStack container UI testing.
metadata:
  short-description: bb-browser container E2E patterns and lessons
---

# Container E2E Browser Testing

Use this skill when performing E2E testing of the GSStack container module UI using bb-browser (Chrome CDP automation).

## Setup

### Prerequisites

bb-browser is a Chrome CDP automation CLI. It may also be available as `agent-browser` depending on installation. Install via npm:

```bash
npm install -g bb-browser
```

Requires Chrome/Chromium installed on the system. The CDP connection needs Chrome started with `--remote-debugging-port`.

### Start Chrome and Connect

```bash
# Start headless Chrome
google-chrome --headless --remote-debugging-port=9222 --no-first-run --disable-gpu &
# Connect bb-browser daemon
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start
# Open frontend in a new tab — output includes a tabId to pass to later commands
bb-browser open http://localhost:18080
```

On WSL2, Chrome events can be unstable. Prefer starting Windows Chrome via PowerShell and connecting with the Windows bb-browser binary (see `container-e2e-sop` convention).

### Teardown

```bash
# Stop bb-browser daemon
bb-browser daemon stop
# Kill Chrome
kill %1  # or pkill -f 'remote-debugging-port=9222'
```

Always clean up test resources before stopping the daemon. See [troubleshooting.md](troubleshooting.md) for crash recovery and error handling.

## Understanding `<ref>`

The `<ref>` parameter is a **numeric reference** from the `snap` output that identifies an interactive element on the page.

### How to Get a `<ref>`

Run `bb-browser snap --tab <tabId> -i -c` to get a compact list of interactive elements. The output format is:

```
[1] input#username  placeholder="Username"
[2] input#password  placeholder="Password"  type="password"
[3] button.ant-btn-primary  text="Login"
[4] a  text="Forgot password?"
```

The number in brackets (`[1]`, `[2]`, etc.) is the `<ref>`. Pass it to `fill`, `click`, `select`, `type`, and other interaction commands:

```bash
bb-browser type 3 "admin" --tab <tabId>      # Types "admin" into element [3]
bb-browser click 5 --tab <tabId>              # Clicks element [5]
```

### When an Element Is Not in the Snapshot

If the element does not appear in the `snap` output (e.g., it is inside a dropdown, modal, or dynamically rendered), use `eval` with a CSS selector as a fallback:

```bash
bb-browser eval "document.querySelector('.ant-dropdown-menu-item:nth-child(2)').click()" --tab <tabId>
```

You can also increase the snapshot depth with `-d <n>` to capture nested elements:

```bash
bb-browser snap --tab <tabId> -i -c -d 10
```

## Login Flow

GSStack frontend at `http://localhost:18080` requires authentication. Follow this flow after opening the frontend:

```bash
# 1. Open frontend and capture tabId
TAB_ID=$(bb-browser open http://localhost:18080 | grep -oP 'tabId:\s*\K\S+')
echo "tabId: $TAB_ID"

# 2. Snapshot the login page to find form elements
bb-browser snap --tab "$TAB_ID" -i -c
# Expected output includes:
#   [n] input#username  (or input[placeholder*="用户名"])
#   [m] input#password  (or input[placeholder*="密码"])
#   [k] button  text="Login" (or text="登录")

# 3. Fill credentials using `type` (Ant Design controlled inputs)
bb-browser type <username_ref> "admin" --tab "$TAB_ID"
bb-browser type <password_ref> "<password>" --tab "$TAB_ID"

# 4. Click login button
bb-browser click <login_button_ref> --tab "$TAB_ID"

# 5. Verify login success
#    a. Check URL changed (no longer on login page)
bb-browser eval "window.location.pathname" --tab "$TAB_ID"
#    b. Check network requests for login API success
bb-browser network requests --filter "login" --tab "$TAB_ID"
#    c. Snapshot to verify dashboard elements loaded
bb-browser snap --tab "$TAB_ID" -i -c
```

### Login Failure Handling

If login fails:
- Check `bb-browser errors --tab "$TAB_ID"` for JS errors
- Check `bb-browser console --tab "$TAB_ID"` for error messages
- Verify credentials are correct (check with `gsstack-local-dev` skill convention)
- Check if a CAPTCHA or 2FA challenge appeared (snapshot to verify)
- Ensure the frontend is running and accessible

## bb-browser Core Patterns

### Navigation

```bash
bb-browser open <url>                    # Open URL in a NEW tab, prints tabId
bb-browser goto <url> --tab <tabId>      # Navigate EXISTING tab to URL
bb-browser snap --tab <tabId> -i -c      # Compact interactive snapshot
bb-browser snap --tab <tabId> -i -c -d <n>  # With depth limit
```

`open` creates a new tab and returns its `tabId`; `goto` navigates an already-open tab. The `open` output looks like:

```
tabId: tab-a1b2c3d4
url: http://localhost:18080
title: GSStack
```

Extract the tabId in shell:

```bash
TAB_ID=$(bb-browser open http://localhost:18080 | grep -oP 'tabId:\s*\K\S+')
```

All subsequent commands must pass `--tab <tabId>`.

### Form Interaction

```bash
bb-browser fill <ref> <text> --tab <tabId>   # Fill input (CAUTION: appends to existing value!)
bb-browser type <ref> <text> --tab <tabId>   # Type char-by-char (use for React controlled inputs/textareas)
bb-browser click <ref> --tab <tabId>          # Click element
bb-browser select <ref> <val> --tab <tabId>   # Select dropdown
bb-browser press <key> --tab <tabId>          # Press key
```

#### `fill` vs `type` Decision

```
Default: use `type`
  - Works with Ant Design controlled components
  - Triggers React onChange properly
  - Use for <Input>, <Input.TextArea>, <Input.Password>, <Select> (via type + Enter)

Use `fill` only when:
  - The input is a native non-controlled <input> and the field is empty
  - Speed matters and onChange is not needed

To replace a value with `fill`:
  1. bb-browser press Control+a --tab <tabId>
  2. bb-browser press Backspace --tab <tabId>
  3. bb-browser fill <ref> <new_text> --tab <tabId>
```

### Verification

```bash
bb-browser network requests --filter <pattern> --tab <tabId>  # Check API calls
bb-browser eval "<js>" --tab <tabId>                           # Execute JavaScript
bb-browser screenshot <path> --tab <tabId>                     # Take screenshot
bb-browser console --tab <tabId>                               # Console logs
bb-browser errors --tab <tabId>                                # JS errors
```

## Waiting and Polling

Browser automation requires explicit waits — there is no built-in auto-wait.

### Wait for Page Navigation

After `goto` or `click` that triggers navigation, re-snapshot to get the updated page:

```bash
bb-browser goto http://localhost:18080/#/workloads --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c
```

### Wait for Element to Appear

Poll with `eval` until the element exists:

```bash
# Wait up to 30s for an element to appear
for i in $(seq 1 15); do
  result=$(bb-browser eval "document.querySelector('.target-element') ? 'found' : 'not_found'" --tab "$TAB_ID")
  if echo "$result" | grep -q 'found'; then break; fi
  sleep 2
done
```

### Wait for API Completion

Check network requests for the expected API call status:

```bash
bb-browser network requests --filter "api/resource" --tab "$TAB_ID"
# Verify the request returned 200
```

### kubectl Wait Patterns

```bash
# Wait for Deployment rollout
kubectl -n <ns> rollout status deploy/<name> --timeout=180s

# Wait for PVC to bind
kubectl -n <ns> wait pvc/<name> --for=jsonpath='{.status.phase}'=Bound --timeout=60s

# Wait for Pod readiness
kubectl -n <ns> wait pod/<name> --for=condition=Ready --timeout=120s
```

**Recommended polling interval**: 2s. **Default timeout**: 60-120s depending on operation (see `container-e2e-full` skill Timeout Reference).

## Critical Lessons Learned

### 1. Ace Editor YAML Setting (RELIABLE)

Ace editors (used in YAML editors) can be set via JavaScript. For multiple editors on the same page, select by index or container:

```javascript
// Select by index (0-based)
var editors = document.querySelectorAll('.ace_editor');
var target = editors[0]; // or editors[1] for the second editor
if (target && target.env && target.env.editor) {
  target.env.editor.setValue('apiVersion: apps/v1\nkind: Deployment\n...\n', -1);
}
```

```javascript
// Select by container (more reliable when multiple editors exist)
var container = document.querySelector('.yaml-editor-drawer .ace_editor');
if (container && container.env && container.env.editor) {
  container.env.editor.setValue('yaml content here\n', -1);
}
```

This is the most reliable way to set YAML content in create/edit forms.

### 2. Dropdown Menu Items Not in Snapshot

Ant Design `TableDropdown` and `Dropdown` items may not appear in compact snapshots because they render in a portal outside the normal DOM tree. Use `eval` to find and interact with them:

```javascript
// List all visible dropdown menu items
document.querySelectorAll('.ant-dropdown-menu-item').forEach(function(el, i) {
  console.log(i, el.textContent.trim(), el.className);
});

// Click a specific dropdown item by text
var items = document.querySelectorAll('.ant-dropdown-menu-item');
for (var i = 0; i < items.length; i++) {
  if (items[i].textContent.includes('Delete')) { items[i].click(); break; }
}
```

### 3. Form Validation Silent Failures

When submit doesn't trigger an API call, Ant Design form validation may have silently failed. Check for validation error messages:

```javascript
// List all form validation errors
document.querySelectorAll('.ant-form-item-explain-error').forEach(function(el) {
  console.log(el.textContent.trim());
});

// Check if any required field is empty
document.querySelectorAll('.ant-form-item-required').forEach(function(label) {
  var item = label.closest('.ant-form-item');
  var input = item && item.querySelector('input, textarea, select');
  if (input && !input.value) {
    console.log('Empty required field:', label.textContent.trim());
  }
});
```

After fixing validation errors, re-snapshot and retry submit.

### 4. Network Request Verification

Always verify API calls after form submission:

```bash
bb-browser network requests --filter "api/resource" --tab <tabId>
```

If no request appears, the submit action did not reach the backend. Check for:
- Silent form validation failures (see lesson #3)
- Button disabled state
- JavaScript errors blocking the submit handler

## kubectl Verification Patterns

### Workload
```bash
kubectl -n <ns> get deploy <name> -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
kubectl -n <ns> rollout status deploy/<name> --timeout=180s
kubectl -n <ns> exec <pod> -- curl -s -o /dev/null -w '%{http_code}' http://<svc>:<port>/
```

### Network (Gateway/Route/EIP)
```bash
kubectl -n <ns> get gateway <name> -o jsonpath='{.status.addresses[0].value}'
curl -s -o /dev/null -w '%{http_code}' -H 'Host: <hostname>' http://<gateway-ip>/
kubectl get eip <name> -o jsonpath='{.spec.address} {.spec.protocol}'
```

### Storage
```bash
kubectl -n <ns> get pvc <name> -o jsonpath='{.status.phase}'
kubectl -n <ns> exec <pod> -- cat /data/test.txt
```

### Node
```bash
kubectl get node <name> -o jsonpath='{.spec.unschedulable}'
kubectl get node <name> --show-labels
```

## Test Resource Naming

- Prefix: `codex-e2e-<timestamp>`
- Labels: `codex-e2e: e2e`
- Available images: `harbor.example.com/library/busybox:<tag>`, `harbor.example.com/nginxinc/nginx-unprivileged:<tag>` (real registry configured in ignored local env file)

## References

- [walkthrough.md](walkthrough.md) — Complete end-to-end example from login to cleanup
- [troubleshooting.md](troubleshooting.md) — Error handling, crash recovery, and common issues
