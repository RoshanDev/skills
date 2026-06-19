# Complete End-to-End Walkthrough

This walkthrough demonstrates a full E2E test cycle: start Chrome, connect bb-browser, login, create a Namespace, create an HTTP Deployment and Service via the UI, verify with kubectl and browser Network evidence, and clean up.

The workload intentionally uses an HTTP-serving container. Do not pair a sleeping BusyBox pod with a Service curl check; BusyBox sleep has no HTTP listener.

For the standalone HTTP workload + Service template, see [container-e2e-full/http-workload-service.md](../container-e2e-full/http-workload-service.md).

## Step 1: Start Chrome and Connect bb-browser

```bash
google-chrome --headless --remote-debugging-port=9222 --no-first-run --disable-gpu &
BB_BROWSER_CDP_URL=http://127.0.0.1:9222 bb-browser daemon start
bb-browser daemon status
```

## Step 2: Open Frontend and Capture tabId

```bash
TAB_ID=$(bb-browser open http://localhost:18080 | grep -oP 'tabId:\s*\K\S+')
echo "Captured tabId: $TAB_ID"
```

## Step 3: Login

```bash
bb-browser snap --tab "$TAB_ID" -i -c
# Find username/password/login refs from the snapshot.
bb-browser type <username_ref> "admin" --tab "$TAB_ID"
bb-browser type <password_ref> "<admin_password>" --tab "$TAB_ID"
bb-browser click <login_button_ref> --tab "$TAB_ID"
sleep 3

bb-browser eval "window.location.pathname" --tab "$TAB_ID"
bb-browser network requests --filter "login" --tab "$TAB_ID"
bb-browser snap --tab "$TAB_ID" -i -c
```

Expected: no longer on login page, login API returned success, dashboard/menu elements loaded.

## Step 4: Create Namespace

```bash
bb-browser goto "http://localhost:18080/#/namespaces" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

NAMESPACE="codex-e2e-$(date +%s)"

# Click Create Namespace, type the namespace name, submit.
bb-browser click <create_namespace_ref> --tab "$TAB_ID"
sleep 1
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser type <namespace_name_ref> "$NAMESPACE" --tab "$TAB_ID"
bb-browser click <confirm_button_ref> --tab "$TAB_ID"
sleep 2

kubectl get ns "$NAMESPACE"
```

## Step 5: Create HTTP Deployment via YAML Editor

Use an HTTP-serving image, for example `harbor.example.com/nginxinc/nginx-unprivileged:<tag>` on port 8080. Replace the image tag with one present in your registry/offline package.

```bash
bb-browser goto "http://localhost:18080/#/workloads" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

# Click Create Workload, then Edit YAML.
bb-browser click <create_workload_ref> --tab "$TAB_ID"
sleep 1
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <edit_yaml_ref> --tab "$TAB_ID"
sleep 1

DEPLOY_YAML="apiVersion: apps/v1
kind: Deployment
metadata:
  name: codex-e2e-http
  namespace: ${NAMESPACE}
  labels:
    app: codex-e2e-http
    codex-e2e: e2e
spec:
  replicas: 1
  selector:
    matchLabels:
      app: codex-e2e-http
  template:
    metadata:
      labels:
        app: codex-e2e-http
        codex-e2e: e2e
    spec:
      containers:
        - name: nginx
          image: harbor.example.com/nginxinc/nginx-unprivileged:stable
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080"

bb-browser eval "
var editors = document.querySelectorAll('.ace_editor');
var target = editors[0];
if (target && target.env && target.env.editor) {
  target.env.editor.setValue($(printf '%s\n' "$DEPLOY_YAML" | jq -Rs .), -1);
}
" --tab "$TAB_ID"

sleep 1
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <submit_button_ref> --tab "$TAB_ID"
sleep 2

kubectl -n "$NAMESPACE" rollout status deploy/codex-e2e-http --timeout=180s
kubectl -n "$NAMESPACE" get deploy codex-e2e-http -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
```

Expected: `1/1` ready.

## Step 6: Create Service via YAML Editor

```bash
bb-browser goto "http://localhost:18080/#/services" --tab "$TAB_ID"
sleep 2
bb-browser snap --tab "$TAB_ID" -i -c

bb-browser click <create_service_ref> --tab "$TAB_ID"
sleep 1
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <edit_yaml_ref> --tab "$TAB_ID"
sleep 1

SVC_YAML="apiVersion: v1
kind: Service
metadata:
  name: codex-e2e-http-svc
  namespace: ${NAMESPACE}
  labels:
    codex-e2e: e2e
spec:
  type: ClusterIP
  selector:
    app: codex-e2e-http
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 8080"

bb-browser eval "
var editors = document.querySelectorAll('.ace_editor');
var target = editors[0];
if (target && target.env && target.env.editor) {
  target.env.editor.setValue($(printf '%s\n' "$SVC_YAML" | jq -Rs .), -1);
}
" --tab "$TAB_ID"

sleep 1
bb-browser snap --tab "$TAB_ID" -i -c
bb-browser click <submit_button_ref> --tab "$TAB_ID"
sleep 2

kubectl -n "$NAMESPACE" get svc codex-e2e-http-svc
kubectl -n "$NAMESPACE" get endpoints codex-e2e-http-svc

POD_NAME=$(kubectl -n "$NAMESPACE" get pod -l app=codex-e2e-http -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NAMESPACE" exec "$POD_NAME" -- \
  curl -s -o /dev/null -w '%{http_code}' http://codex-e2e-http-svc:80/
# Expected: 200
```

## Step 7: Verify Browser Network Requests

```bash
bb-browser network requests --filter "deployments" --tab "$TAB_ID"
bb-browser network requests --filter "services" --tab "$TAB_ID"
bb-browser errors --tab "$TAB_ID"
bb-browser console --tab "$TAB_ID"
```

Expected: create API calls returned success and there are no blocking frontend errors.

## Step 8: Cleanup

Delete in reverse dependency order. Prefer UI cleanup when testing UI delete flows; use kubectl cleanup as a safety net.

For the UI delete flow pattern (dropdown → eval click Delete → confirm), see [troubleshooting.md](troubleshooting.md) Dropdown Menu Items section.

```bash
# Safety-net cleanup
kubectl -n "$NAMESPACE" delete svc codex-e2e-http-svc --ignore-not-found
kubectl -n "$NAMESPACE" delete deploy codex-e2e-http --ignore-not-found
kubectl delete ns "$NAMESPACE" --ignore-not-found
```

If you tested UI delete paths, still verify cluster state afterward:

```bash
kubectl -n "$NAMESPACE" get svc codex-e2e-http-svc 2>&1 | grep -q "NotFound" && echo "Service deleted" || true
kubectl -n "$NAMESPACE" get deploy codex-e2e-http 2>&1 | grep -q "NotFound" && echo "Deployment deleted" || true
```

## Step 9: Teardown

```bash
bb-browser daemon stop
pkill -f 'remote-debugging-port=9222'
echo "E2E walkthrough complete. All resources cleaned up."
```

## Key Takeaways

1. Capture `tabId` from `open`; every later command needs it.
2. Use `type` for Ant Design forms; `fill` can skip React onChange.
3. Set Ace Editor YAML via `eval` and `setValue(..., -1)`.
4. Re-snapshot after every navigation; refs become stale.
5. Verify both browser Network/UI state and kubectl state.
6. For Service routing tests, use a workload that actually listens on the target port.
7. Clean up in reverse order; cluster-scoped resources require explicit cleanup.
