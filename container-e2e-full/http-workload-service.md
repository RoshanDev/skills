# HTTP Workload + Service Template

Use this template when an E2E test must prove that a Service can route traffic to a workload.

Do not pair a sleeping BusyBox Deployment with a Service curl check. A BusyBox sleep container has no HTTP listener, so a Service targeting port 80 will not prove Service routing and will usually fail or hang.

This template uses `nginx-unprivileged` on port `8080`.

Replace:

```text
<namespace>   test namespace
<tag>         image tag available in your registry/offline package
```

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: codex-e2e-http
  namespace: <namespace>
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
          image: harbor.example.com/nginxinc/nginx-unprivileged:<tag>
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
```

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: codex-e2e-http-svc
  namespace: <namespace>
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
      targetPort: 8080
```

## Verification

```bash
kubectl -n <namespace> rollout status deploy/codex-e2e-http --timeout=180s
kubectl -n <namespace> get endpoints codex-e2e-http-svc

POD_NAME=$(kubectl -n <namespace> get pod -l app=codex-e2e-http -o jsonpath='{.items[0].metadata.name}')
kubectl -n <namespace> exec "$POD_NAME" -- \
  curl -s -o /dev/null -w '%{http_code}' http://codex-e2e-http-svc:80/
# Expected: 200
```

If the image is not present in the offline package or registry, the correct result is BLOCKED or NEEDS_REVISION, not a fake pass. Use the Docker/platform and persistence rules from `loop-verify`.
