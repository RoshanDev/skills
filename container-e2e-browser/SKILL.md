---
name: container-e2e-browser
description: Use when performing container module E2E testing with bb-browser automation. Covers bb-browser patterns, Ace/React form interaction, kubectl verification, and common pitfalls for GSStack container UI testing.
metadata:
  short-description: bb-browser container E2E patterns and lessons
---

# Container E2E Browser Testing

Use this skill when performing E2E testing of the GSStack container module UI using bb-browser (Chrome CDP automation).

## Setup

```bash
# Start headless Chrome
google-chrome --headless --remote-debugging-port=9222 --no-first-run --disable-gpu &
# Connect bb-browser
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start
# Open frontend in a new tab — output includes a tabId to pass to later commands
bb-browser open http://localhost:18080
```

## bb-browser Core Patterns

### Navigation
```bash
bb-browser open <url>                    # Open URL in a NEW tab, prints tabId
bb-browser goto <url> --tab <tabId>      # Navigate EXISTING tab to URL
bb-browser snap --tab <tabId> -i -c      # Compact interactive snapshot
bb-browser snap --tab <tabId> -i -c -d <n>  # With depth limit
```

`open` creates a new tab and returns its `tabId`; `goto` navigates an already-open tab. Capture the `tabId` from `open` output and pass it as `--tab <tabId>` to every subsequent command.

### Form Interaction
```bash
bb-browser fill <ref> <text> --tab <tabId>   # Fill input (CAUTION: appends to existing value!)
bb-browser type <ref> <text> --tab <tabId>   # Type char-by-char (use for React controlled inputs/textareas)
bb-browser click <ref> --tab <tabId>          # Click element
bb-browser select <ref> <val> --tab <tabId>   # Select dropdown
bb-browser press <key> --tab <tabId>          # Press key
```

`fill` is faster but appends rather than replaces, and does not trigger React `onChange` on Ant Design controlled components. Use `type` for `<Input.TextArea>` and any controlled field. To replace a value with `fill`, clear first: `bb-browser press Control+a --tab <tabId>` then `Backspace`, then `fill`.

### Verification
```bash
bb-browser network requests --filter <pattern> --tab <tabId>  # Check API calls
bb-browser eval "<js>" --tab <tabId>                           # Execute JavaScript
bb-browser screenshot <path> --tab <tabId>                     # Take screenshot
bb-browser console --tab <tabId>                               # Console logs
bb-browser errors --tab <tabId>                                # JS errors
```

## Critical Lessons Learned

### 1. Ace Editor YAML Setting (RELIABLE)
Ace editors (used in YAML editors) can be set via JavaScript:
```javascript
var e = document.querySelector('.ace_editor');
if (e && e.env && e.env.editor) {
  e.env.editor.setValue('yaml content here\n', -1);
}
```
This is the most reliable way to set YAML content in create/edit forms.

### 2. Dropdown Menu Items Not in Snapshot
Ant Design TableDropdown items may not appear in compact snapshots. Use JS eval to find them.

### 3. Form Validation Silent Failures
When submit doesn't trigger API call, check all required fields via JS eval.

### 4. Network Request Verification
Always verify API calls: `bb-browser network requests --filter "<pattern>" --tab <tabId>`

## kubectl Verification Patterns

### Workload
```bash
kubectl -n <ns> get deploy <name> -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
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
