# Complete End-to-End Walkthrough

This walkthrough demonstrates a full E2E test cycle: start Chrome, connect bb-browser, login, create a Deployment and Service via the UI, verify with kubectl, and clean up.

## Step 1: Start Chrome and Connect bb-browser

```bash
# Start headless Chrome
google-chrome --headless --remote-debugging-port=9222 --no-first-run --disable-gpu &

# Connect bb-browser daemon
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start

# Verify daemon is running
bb-browser daemon status
```

## Step 2: Open Frontend and Capture tabId

```bash
# Open frontend — capture tabId from output
TAB_ID=$(bb-browser open http://localhost:18080 | grep -oP 'tabId:\s*\K\S+')
echo "Captured tabId: $TAB_ID"
```

## Step 3: Login

```bash
# Snapshot the login page to find form elements
bb-browser snap --tab "$TAB_ID" -i -c
# Output example:
#   [1] input#username  placeholder="Username"
#   [2] input#password  placeholder="Password"  type="password"
#   [3] button.ant-btn-primary  text="Login"

# Fill credentials using `type` (Ant Design controlled inputs)
bb-browser type 1 "admin" --tab "$TAB_ID"
bb-browser type 2 "<admin_password>" --tab "$TAB_ID"

# Click login button
bb-browser click 3 --tab "$TAB_ID"

# Wait for navigation
sleep 3

# Verify login succeeded
bb-browser eval "window.location.pathname" --tab "$TAB_ID"
# Expected: not a login path (e.g., "/" or "/Assets/...")

bb-browser network requests --filter "login" --tab "$TAB_ID"
# Expected: login API returned 200

bb-browser snap --tab "$TAB_ID" -i -c
# Expected: dashboard elements (menu items, navigation, etc.)
```

## Step 4: Create Namespace

```bash
# Navigate to namespace management page
bb-browser goto "http://localhost:18080/#/namespaces" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

# Find and click "Create Namespace" button
# Example: [5] button  text="Create Namespace"
bb-browser click 5 --tab "$TAB_ID"
sleep 1

# Snapshot the create form
bb-browser snap --tab "$TAB_ID" -i -c
# Find the name input field, e.g., [2] input  placeholder="Name"

# Type namespace name
NAMESPACE="codex-e2e-$(date +%s)"
bb-browser type 2 "$NAMESPACE" --tab "$TAB_ID"

# Click confirm button
# Find the confirm/submit button in the snapshot, e.g., [8] button.ant-btn-primary
bb-browser click 8 --tab "$TAB_ID"
sleep 2

# Verify with kubectl
kubectl get ns "$NAMESPACE"
# Expected: namespace exists with STATUS=Active
```

## Step 5: Create Deployment via YAML Editor

```bash
# Navigate to workloads page
bb-browser goto "http://localhost:18080/#/workloads" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

# Click "Create Workload" button
# Find it in the snapshot, e.g., [4] button  text="Create"
bb-browser click 4 --tab "$TAB_ID"
sleep 1

# Click "Edit YAML" to open the YAML editor
bb-browser snap --tab "$TAB_ID" -i -c
# Find the YAML editor toggle, e.g., [3] button  text="Edit YAML"
bb-browser click 3 --tab "$TAB_ID"
sleep 1

# Set YAML content in Ace Editor via JavaScript
DEPLOY_YAML="apiVersion: apps/v1
kind: Deployment
metadata:
  name: codex-e2e-deploy
  namespace: ${NAMESPACE}
  labels:
    app: codex-e2e-deploy
    codex-e2e: e2e
spec:
  replicas: 1
  selector:
    matchLabels:
      app: codex-e2e-deploy
  template:
    metadata:
      labels:
        app: codex-e2e-deploy
        codex-e2e: e2e
    spec:
      containers:
        - name: busybox
          image: harbor.example.com/library/busybox:1.35.0
          imagePullPolicy: Always
          command: ['/bin/sh', '-c', 'while true; do sleep 3600; done']"

bb-browser eval "
var editors = document.querySelectorAll('.ace_editor');
var target = editors[0];
if (target && target.env && target.env.editor) {
  target.env.editor.setValue($(printf '%s\n' "$DEPLOY_YAML" | jq -Rs .), -1);
}
" --tab "$TAB_ID"

sleep 1

# Click "Create" / "Submit" button
bb-browser snap --tab "$TAB_ID" -i -c
# Find the submit button, e.g., [10] button.ant-btn-primary  text="Create"
bb-browser click 10 --tab "$TAB_ID"
sleep 2

# Verify with kubectl
kubectl -n "$NAMESPACE" rollout status deploy/codex-e2e-deploy --timeout=180s
# Expected: "deployment successfully rolled out"

kubectl -n "$NAMESPACE" get deploy codex-e2e-deploy \
  -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
# Expected: 1/1
```

## Step 6: Create Service via YAML Editor

```bash
# Navigate to services page
bb-browser goto "http://localhost:18080/#/services" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

# Click "Create Service" button
bb-browser click <create_button_ref> --tab "$TAB_ID"
sleep 1

# Click "Edit YAML"
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <yaml_toggle_ref> --tab "$TAB_ID"
sleep 1

# Set Service YAML in Ace Editor
SVC_YAML="apiVersion: v1
kind: Service
metadata:
  name: codex-e2e-svc
  namespace: ${NAMESPACE}
  labels:
    codex-e2e: e2e
spec:
  type: ClusterIP
  selector:
    app: codex-e2e-deploy
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80"

bb-browser eval "
var editors = document.querySelectorAll('.ace_editor');
var target = editors[0];
if (target && target.env && target.env.editor) {
  target.env.editor.setValue($(printf '%s\n' "$SVC_YAML" | jq -Rs .), -1);
}
" --tab "$TAB_ID"

sleep 1

# Click "Create" button
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <submit_button_ref> --tab "$TAB_ID"
sleep 2

# Verify with kubectl
kubectl -n "$NAMESPACE" get svc codex-e2e-svc
# Expected: service exists with ClusterIP

kubectl -n "$NAMESPACE" get endpoints codex-e2e-svc
# Expected: endpoints listed with Pod IP:port

# Curl test inside Pod
POD_NAME=$(kubectl -n "$NAMESPACE" get pod -l app=codex-e2e-deploy -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NAMESPACE" exec "$POD_NAME" -- \
  curl -s -o /dev/null -w '%{http_code}' http://codex-e2e-svc:80/
# Expected: HTTP 200 (or expected response code from the app)
```

## Step 7: Verify Network Requests

```bash
# Check that the create API calls were successful
bb-browser network requests --filter "deployments" --tab "$TAB_ID"
# Expected: POST returned 200/201

bb-browser network requests --filter "services" --tab "$TAB_ID"
# Expected: POST returned 200/201
```

## Step 8: Cleanup

```bash
# Delete Service via UI
bb-browser goto "http://localhost:18080/#/services" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c
# Find the service row's "More" dropdown, click it
bb-browser click <more_button_ref> --tab "$TAB_ID"
sleep 1
# Find "Delete" in the dropdown menu
bb-browser eval "
var items = document.querySelectorAll('.ant-dropdown-menu-item');
for (var i = 0; i < items.length; i++) {
  if (items[i].textContent.includes('Delete')) { items[i].click(); break; }
}
" --tab "$TAB_ID"
sleep 1
# Confirm deletion
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <confirm_button_ref> --tab "$TAB_ID"
sleep 2

# Delete Deployment via UI (same pattern)

# Verify cleanup with kubectl
kubectl -n "$NAMESPACE" get svc codex-e2e-svc 2>&1 | grep -q "NotFound" && echo "Service deleted" || echo "Service still exists"
kubectl -n "$NAMESPACE" get deploy codex-e2e-deploy 2>&1 | grep -q "NotFound" && echo "Deployment deleted" || echo "Deployment still exists"

# Delete namespace
kubectl delete ns "$NAMESPACE" --ignore-not-found
```

## Step 9: Teardown

```bash
# Stop bb-browser daemon
bb-browser daemon stop

# Kill Chrome
pkill -f 'remote-debugging-port=9222'

echo "E2E walkthrough complete. All resources cleaned up."
```

## Key Takeaways

1. **Always capture tabId** from `open` output — every subsequent command needs it.
2. **Use `type` for Ant Design forms** — `fill` does not trigger React onChange.
3. **Set Ace Editor YAML via `eval`** — `setValue` with `-1` cursor position is the reliable method.
4. **Re-snapshot after every navigation** — the DOM changes and refs become stale.
5. **Verify both UI and kubectl** — UI shows the product perspective, kubectl confirms the cluster state.
6. **Clean up in reverse order** — Service → Deployment → Namespace. PV and SC are cluster-scoped and need separate cleanup.
