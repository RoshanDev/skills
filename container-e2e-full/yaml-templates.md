# YAML Templates for E2E Testing

All templates use `codex-e2e-` prefix and `harbor.example.com` placeholder. Replace `<timestamp>` with `$(date +%s)` and `<namespace>` with your test namespace. Real registry configured in ignored local env file.

## Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: codex-e2e-<timestamp>
  labels:
    codex-e2e: e2e
```

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: codex-e2e-deploy
  namespace: <namespace>
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
          command:
            - /bin/sh
            - -c
            - while true; do sleep 3600; done
```

## Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: codex-e2e-svc
  namespace: <namespace>
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
      targetPort: 80
```

## Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: codex-e2e-job
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  template:
    metadata:
      labels:
        codex-e2e: e2e
    spec:
      restartPolicy: Never
      containers:
        - name: busybox
          image: harbor.example.com/library/busybox:1.35.0
          imagePullPolicy: Always
          command:
            - /bin/sh
            - -c
            - echo "E2E job completed" && exit 0
```

## CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: codex-e2e-cronjob
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            codex-e2e: e2e
        spec:
          restartPolicy: Never
          containers:
            - name: busybox
              image: harbor.example.com/library/busybox:1.35.0
              imagePullPolicy: Always
              command:
                - /bin/sh
                - -c
                - echo "CronJob tick $(date)" && exit 0
```

## Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: codex-e2e-pod
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  restartPolicy: Never
  containers:
    - name: busybox
      image: harbor.example.com/library/busybox:1.35.0
      imagePullPolicy: Always
      command:
        - /bin/sh
        - -c
        - echo "Pod running" && sleep 3600
```

## Secret (Opaque)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: codex-e2e-secret
  namespace: <namespace>
  labels:
    codex-e2e: e2e
type: Opaque
stringData:
  username: codex-e2e-user
  password: codex-e2e-pass
```

## ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: codex-e2e-configmap
  namespace: <namespace>
  labels:
    codex-e2e: e2e
data:
  app.properties: |
    environment=test
    log_level=debug
  config.yaml: |
    server:
      port: 8080
      timeout: 30s
```

## StorageClass (no-provisioner)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: codex-e2e-sc
  labels:
    codex-e2e: e2e
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

## PersistentVolume (hostPath)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: codex-e2e-pv
  labels:
    codex-e2e: e2e
spec:
  capacity:
    storage: 1Mi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: codex-e2e-sc
  hostPath:
    path: /tmp/codex-e2e-pv
    type: DirectoryOrCreate
```

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: codex-e2e-pvc
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: codex-e2e-sc
  resources:
    requests:
      storage: 1Mi
```

## Pod with PVC Mount (Write + Read Test)

**Writer Pod** — writes test data to the mounted volume:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: codex-e2e-pvc-writer
  namespace: <namespace>
  labels:
    codex-e2e: e2e
    codex-e2e-role: writer
spec:
  restartPolicy: Never
  containers:
    - name: busybox
      image: harbor.example.com/library/busybox:1.35.0
      imagePullPolicy: Always
      command:
        - /bin/sh
        - -c
        - |
          echo "E2E test data $(date)" > /data/test.txt
          echo "Data written successfully"
          cat /data/test.txt
          sleep 3600
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: codex-e2e-pvc
```

**Reader Pod** — reads data back from the same volume (run after writer is Running):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: codex-e2e-pvc-reader
  namespace: <namespace>
  labels:
    codex-e2e: e2e
    codex-e2e-role: reader
spec:
  restartPolicy: Never
  containers:
    - name: busybox
      image: harbor.example.com/library/busybox:1.35.0
      imagePullPolicy: Always
      command:
        - /bin/sh
        - -c
        - |
          echo "Reading data from volume:"
          cat /data/test.txt
          echo "Read complete"
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: codex-e2e-pvc
```

**Verification**:
```bash
# Writer writes data
kubectl -n <namespace> logs codex-e2e-pvc-writer
# Expected: "Data written successfully" + file content

# Reader reads data back
kubectl -n <namespace> logs codex-e2e-pvc-reader
# Expected: same file content as writer

# Or exec into Pod and read directly
kubectl -n <namespace> exec codex-e2e-pvc-writer -- cat /data/test.txt
```

## VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: codex-e2e-vsc
  labels:
    codex-e2e: e2e
driver: kubernetes.io/no-provisioner
deletionPolicy: Delete
```

For XSKY CSI VolumeSnapshotClass, replace `driver` with `iscsi.csi.xsky.com` or `com.nfs.csi.xsky`. See [xsky-module.md](xsky-module.md).

## PrometheusRule (Alerting)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: codex-e2e-alert
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  groups:
    - name: codex-e2e-rules
      rules:
        - alert: CodexE2ETestAlert
          expr: vector(1)
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "E2E test alert"
            description: "This is a test alert for E2E verification"
```

**Note**: `expr: vector(1)` always triggers immediately. For production-safe testing, use a realistic expression. When using the `type` command to fill this YAML in a textarea, see `container-e2e-browser` skill Ace Editor pattern.

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: codex-e2e-ingress
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  rules:
    - host: codex-e2e.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: codex-e2e-svc
                port:
                  number: 80
```

**Verification**:
```bash
kubectl -n <namespace> get ingress codex-e2e-ingress
# Check address is assigned

# Curl with Host header (if Ingress controller is accessible)
curl -s -o /dev/null -w '%{http_code}' -H 'Host: codex-e2e.example.com' http://<ingress-controller-ip>/
```

## NetworkPolicy

**Deny all ingress to test Pods** (isolation test):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: codex-e2e-deny-all
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  podSelector:
    matchLabels:
      codex-e2e: e2e
  policyTypes:
    - Ingress
  ingress: []
```

**Allow specific namespace ingress**:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: codex-e2e-allow-namespace
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  podSelector:
    matchLabels:
      codex-e2e: e2e
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <namespace>
```

**Verification**:
```bash
# Before policy: curl from another Pod should succeed
kubectl -n <namespace> exec <other-pod> -- curl -s -o /dev/null -w '%{http_code}' http://codex-e2e-svc:80/

# After deny-all policy: curl should timeout or fail
kubectl -n <namespace> exec <other-pod> -- curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://codex-e2e-svc:80/
# Expected: 000 (timeout) or non-200
```

## HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: codex-e2e-hpa
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: codex-e2e-deploy
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

**Verification**:
```bash
kubectl -n <namespace> get hpa codex-e2e-hpa
# Check TARGETS column shows current/target utilization

# Generate load to trigger scaling (if metrics server is running)
kubectl -n <namespace> run load-generator --image=harbor.example.com/library/busybox:1.35.0 \
  --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://codex-e2e-svc:80/; done"

# Watch HPA scale up
kubectl -n <namespace> get hpa codex-e2e-hpa --watch

# Clean up load generator
kubectl -n <namespace> delete pod load-generator --ignore-not-found
```

## Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: codex-e2e-role
  namespace: <namespace>
  labels:
    codex-e2e: e2e
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
```

## RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: codex-e2e-rolebinding
  namespace: <namespace>
  labels:
    codex-e2e: e2e
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: codex-e2e-role
subjects:
  - kind: ServiceAccount
    name: codex-e2e-sa
    namespace: <namespace>
```

**RBAC Verification**:
```bash
# Create a Pod with the bound ServiceAccount
kubectl -n <namespace> run codex-e2e-rbac-test --image=harbor.example.com/library/busybox:1.35.0 \
  --serviceaccount=codex-e2e-sa --restart=Never -- /bin/sh -c "sleep 3600"

# Test allowed access (should succeed)
kubectl -n <namespace> exec codex-e2e-rbac-test -- /bin/sh -c \
  "wget -q -O- http://kubernetes.default.svc/api/v1/namespaces/<namespace>/pods" 2>&1 | head -5

# Test denied access (should fail)
kubectl -n <namespace> exec codex-e2e-rbac-test -- /bin/sh -c \
  "wget -q -O- http://kubernetes.default.svc/api/v1/namespaces/<namespace>/deployments" 2>&1 | head -5
# Expected: 403 Forbidden
```
