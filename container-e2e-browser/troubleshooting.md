# Troubleshooting and Error Handling

Common issues during bb-browser E2E testing and their recovery procedures.

## Chrome Crash Recovery

If Chrome crashes or becomes unresponsive:

```bash
# 1. Check if Chrome process is still running
pgrep -f 'remote-debugging-port=9222'

# 2. Kill stale Chrome processes
pkill -f 'remote-debugging-port=9222'
sleep 2

# 3. Restart Chrome
google-chrome --headless --remote-debugging-port=9222 --no-first-run --disable-gpu &
sleep 3

# 4. Reconnect bb-browser daemon (stop old, start new)
bb-browser daemon stop 2>/dev/null
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start
sleep 2

# 5. Re-open the frontend and re-login
TAB_ID=$(bb-browser open http://localhost:18080 | grep -oP 'tabId:\s*\K\S+')
# Follow the Login Flow from SKILL.md
```

## bb-browser Daemon Issues

### Daemon Won't Start

```bash
# Check if port 9222 is in use
lsof -i :9222

# Check if another daemon is already running
bb-browser daemon status

# Force stop and restart
bb-browser daemon stop
sleep 2
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start
```

### CDP Connection Failed

```bash
# Verify Chrome is running with debugging port
curl -s http://127.0.0.1:9222/json/version
# Expected: JSON response with Browser info

# If no response, Chrome is not running or port is wrong
# Restart Chrome with explicit flags
google-chrome --headless --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 --no-first-run --disable-gpu &
```

### WSL2-Specific Issues

On WSL2, Chrome events can be unstable. Prefer Windows Chrome + Windows bb-browser binary:

```bash
# Start Windows Chrome via PowerShell
powershell.exe -NoProfile -Command '
  $p=9331
  $profile="C:\Users\<user>\AppData\Local\Temp\gstack-container-e2e-chrome"
  New-Item -ItemType Directory -Force -Path $profile | Out-Null
  Start-Process -FilePath "C:\Program Files\Google\Chrome\Application\chrome.exe" `
    -ArgumentList @("--remote-debugging-address=0.0.0.0","--remote-debugging-port=$p",
      "--no-proxy-server","--no-first-run","--no-default-browser-check",
      "--user-data-dir=$profile","--new-window","about:blank")
'

# Connect using Windows bb-browser binary
/mnt/c/Users/<user>/AppData/Roaming/npm/node_modules/bb-browser/bin/bb-browser-win32-x64.exe connect 9331
```

## Element Not Found / Invalid ref

### Stale References

After any page navigation (click, goto, form submit), all refs from the previous snapshot are stale. Always re-snapshot:

```bash
# After navigation or click that changes the page
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c
```

### Element Hidden or Not Interactive

If an element exists in the DOM but is not in the interactive snapshot:

```bash
# Increase snapshot depth
bb-browser snap --tab "$TAB_ID" -i -c -d 10

# Or use eval to interact directly
bb-browser eval "document.querySelector('.target-selector').click()" --tab "$TAB_ID"
```

### Element Inside Modal or Drawer

Modals and drawers render in portals. After opening a modal:

```bash
# Wait for modal animation
sleep 1

# Re-snapshot — modal elements should now appear
bb-browser snap --tab "$TAB_ID" -i -c

# If still not visible, use eval
bb-browser eval "
  var modal = document.querySelector('.ant-modal-body');
  if (modal) {
    var input = modal.querySelector('input');
    if (input) { input.focus(); input.value = 'test'; input.dispatchEvent(new Event('input', {bubbles: true})); }
  }
" --tab "$TAB_ID"
```

## Ace Editor Not Ready

If `setValue` fails or the YAML editor is empty after setting:

```bash
# 1. Wait for the editor to initialize
sleep 2

# 2. Check if Ace Editor is present
bb-browser eval "document.querySelectorAll('.ace_editor').length" --tab "$TAB_ID"
# Expected: 1 or more

# 3. Retry with a check
bb-browser eval "
  var editors = document.querySelectorAll('.ace_editor');
  var target = editors[0];
  if (!target || !target.env || !target.env.editor) {
    'Editor not ready';
  } else {
    target.env.editor.setValue('yaml content\n', -1);
    'Set successfully';
  }
" --tab "$TAB_ID"

# 4. If still not ready, try clicking inside the editor area first
bb-browser eval "document.querySelector('.ace_editor').click()" --tab "$TAB_ID"
sleep 1
# Then retry setValue
```

## Ant Design Form Validation Failures

### Silent Validation Errors

When clicking submit does not trigger an API call:

```bash
# Check for validation error messages
bb-browser eval "
  var errors = document.querySelectorAll('.ant-form-item-explain-error');
  var msgs = [];
  errors.forEach(function(el) { msgs.push(el.textContent.trim()); });
  msgs.join('; ') || 'No validation errors';
" --tab "$TAB_ID"

# If errors exist, fix the indicated fields and retry
```

### Required Fields Not Filled

```bash
# Find empty required fields
bb-browser eval "
  var missing = [];
  document.querySelectorAll('.ant-form-item-required').forEach(function(label) {
    var item = label.closest('.ant-form-item');
    var input = item && item.querySelector('input, textarea, select');
    if (input && !input.value) {
      missing.push(label.textContent.trim());
    }
  });
  missing.join(', ') || 'All required fields filled';
" --tab "$TAB_ID"
```

## Network Request Issues

### No API Call After Submit

```bash
# Clear previous network logs
bb-browser network requests --clear --tab "$TAB_ID"

# Click submit
bb-browser click <submit_ref> --tab "$TAB_ID"
sleep 2

# Check if any requests were made
bb-browser network requests --tab "$TAB_ID"

# Filter for specific API
bb-browser network requests --filter "api/" --tab "$TAB_ID"
```

If no requests appear:
1. Check form validation errors (see above)
2. Check if the submit button is disabled: `bb-browser eval "document.querySelector('.ant-btn-primary').disabled" --tab "$TAB_ID"`
3. Check for JS errors: `bb-browser errors --tab "$TAB_ID"`

### API Returns Error

```bash
# Check the response status
bb-browser network requests --filter "api/resource" --tab "$TAB_ID"
# Look for non-200 status codes

# Check console for error details
bb-browser console --tab "$TAB_ID"
```

## Teardown and Cleanup

### Proper Teardown Sequence

```bash
# 1. Clean up test resources via kubectl (if UI cleanup failed)
kubectl delete deploy,svc,job,cronjob,pod -l codex-e2e=e2e -n <namespace> --ignore-not-found
kubectl delete pvc -l codex-e2e=e2e -n <namespace> --ignore-not-found
kubectl delete secret,configmap -l codex-e2e=e2e -n <namespace> --ignore-not-found

# 2. Delete cluster-scoped resources (not cleaned by namespace deletion)
kubectl delete pv -l codex-e2e=e2e --ignore-not-found
kubectl delete sc -l codex-e2e=e2e --ignore-not-found

# 3. Delete test namespace
kubectl delete ns <namespace> --ignore-not-found

# 4. Stop bb-browser daemon
bb-browser daemon stop

# 5. Kill Chrome
pkill -f 'remote-debugging-port=9222'
```

### Verify No Residual Resources

```bash
# Check for any remaining test resources
kubectl get all,sc,pvc,pv,vsc,vs -l codex-e2e=e2e -A 2>/dev/null
# Expected: no resources found
```

## Screenshot for Evidence

Always take screenshots at key verification points for audit trails:

```bash
bb-browser screenshot /tmp/e2e-01-login.png --tab "$TAB_ID"
bb-browser screenshot /tmp/e2e-02-namespace-created.png --tab "$TAB_ID"
bb-browser screenshot /tmp/e2e-03-deployment-created.png --tab "$TAB_ID"
bb-browser screenshot /tmp/e2e-04-verify-rollout.png --tab "$TAB_ID"
bb-browser screenshot /tmp/e2e-05-service-created.png --tab "$TAB_ID"
bb-browser screenshot /tmp/e2e-06-cleanup-done.png --tab "$TAB_ID"
```
