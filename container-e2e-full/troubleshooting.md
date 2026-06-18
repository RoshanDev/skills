# Troubleshooting E2E Test Failures

Common failures encountered during GSStack container module E2E testing and their diagnosis procedures.

## Pod CrashLoopBackOff

**Symptom**: Pod repeatedly crashes and restarts.

```bash
# 1. Check Pod status and restart count
kubectl -n <ns> get pod <name> -o jsonpath='{.status.phase} restarts={.status.containerStatuses[0].restartCount}'

# 2. Check Pod events for scheduling/pull issues
kubectl -n <ns> describe pod <name> | tail -30

# 3. Check container logs from the previous (crashed) run
kubectl -n <ns> logs <name> --previous

# 4. Check current logs
kubectl -n <ns> logs <name>
```

**Common causes**:
- **Image pull failure**: Check image name/tag, registry credentials (ImageService Secret). Look for `ImagePullBackOff` in events.
- **Command error**: Check `command`/`args` in YAML. Missing binary or wrong path.
- **Missing dependencies**: Pod expects ConfigMap/Secret/volume that doesn't exist.
- **Resource limits**: OOMKilled — check `resources.limits.memory` vs actual usage.
- **Liveness probe failure**: Probe path/port incorrect or app not ready before probe timeout.

**Fix**: Correct the YAML, delete and recreate the Pod/Deployment.

## PVC Stuck Pending

**Symptom**: PVC status stays `Pending` and never binds to a PV.

```bash
# 1. Check PVC status and events
kubectl -n <ns> describe pvc <name>

# 2. Check if StorageClass exists
kubectl get sc <sc-name>

# 3. For static provisioning: check if matching PV exists
kubectl get pv -o wide | grep <sc-name>

# 4. Check StorageClass binding mode
kubectl get sc <sc-name> -o jsonpath='{.volumeBindingMode}'
```

**Common causes**:
- **No matching PV**: PV `storageClassName`, `accessModes`, `capacity` must match PVC. For `WaitForFirstConsumer` binding mode, PV won't bind until a Pod schedules.
- **Access mode mismatch**: PV is `ReadWriteOnce` but PVC requests `ReadWriteMany`.
- **Storage capacity**: PV capacity is smaller than PVC request.
- **No StorageClass**: `storageClassName` in PVC doesn't match any existing SC.
- **Dynamic provisioning failure**: CSI driver not installed or provisioner not running. Check provisioner logs: `kubectl -n <csi-namespace> logs <provisioner-pod>`.

**Fix**: Create matching PV, fix access modes, or install/configure the CSI driver.

## Deployment Rollout Timeout

**Symptom**: `kubectl rollout status` times out; Pods not becoming Ready.

```bash
# 1. Check Deployment status
kubectl -n <ns> get deploy <name> -o jsonpath='{.status.readyReplicas}/{.status.replicas}'

# 2. Check Pod status
kubectl -n <ns> get pods -l app=<label>

# 3. Check Pod events
kubectl -n <ns> describe pod <pod-name> | tail -30

# 4. Check if Pods are scheduling
kubectl -n <ns> get pods -o wide
```

**Common causes**:
- **Insufficient resources**: Node doesn't have enough CPU/memory. Look for `FailedScheduling` in events.
- **Node taints/tolerations**: Pod can't schedule on any node. Check `kubectl describe node <name>` for taints.
- **Image pull failure**: Registry not accessible or credentials missing.
- **Readiness probe failure**: App doesn't respond to readiness probe. Check probe path/port.

**Fix**: Adjust resource requests, add tolerations, fix image reference, or correct probe configuration.

## Gateway No Address

**Symptom**: Gateway created but `status.addresses` is empty.

```bash
# 1. Check Gateway status
kubectl -n <ns> get gateway <name> -o yaml | grep -A 10 status

# 2. Check Gateway conditions
kubectl -n <ns> get gateway <name> -o jsonpath='{.status.conditions}'

# 3. Check if GatewayClass controller is running
kubectl get gatewayclass

# 4. Check controller pods
kubectl get pods -A | grep -i gateway
```

**Common causes**:
- **GatewayClass controller not installed**: Install the Gateway API controller (e.g., Envoy Gateway).
- **Controller not reconciling**: Check controller logs for errors.
- **Waiting for allocation**: Some controllers need 10-30s to allocate addresses. Wait and recheck.

**Fix**: Install/configure the Gateway API controller, or wait longer.

## Service Has No Endpoints

**Symptom**: Service exists but `kubectl get endpoints` shows empty/no endpoints.

```bash
# 1. Check Service selector
kubectl -n <ns> get svc <name> -o jsonpath='{.spec.selector}'

# 2. Check Pod labels match selector
kubectl -n <ns> get pods --show-labels

# 3. Check Pod readiness
kubectl -n <ns> get pods -o wide

# 4. Check Service ports
kubectl -n <ns> get svc <name> -o jsonpath='{.spec.ports}'
```

**Common causes**:
- **Selector mismatch**: Service `selector` labels don't match any Pod labels. Verify exact key-value match.
- **Pods not Ready**: Endpoints are only populated for Ready Pods. Check Pod readiness.
- **Port mismatch**: Service `targetPort` doesn't match container exposed port.

**Fix**: Align selector labels, fix Pod readiness issues, or correct port configuration.

## VolumeSnapshot Stuck Pending

**Symptom**: VolumeSnapshot `readyToUse` stays `false`.

```bash
# 1. Check VolumeSnapshot status
kubectl -n <ns> get volumesnapshot <name> -o yaml | grep -A 10 status

# 2. Check VolumeSnapshotContent
kubectl get volumesnapshotcontent -o wide | grep <snapshot-name>

# 3. Check CSI snapshot controller
kubectl get pods -A | grep snapshot

# 4. Check VolumeSnapshotClass driver matches CSI driver
kubectl get volumesnapshotclass <vsc-name> -o jsonpath='{.driver}'
kubectl get csidriver
```

**Common causes**:
- **CSI driver doesn't support snapshots**: Not all CSI drivers implement the snapshotter sidecar.
- **VSC driver mismatch**: VolumeSnapshotClass `driver` doesn't match the PV's CSI driver.
- **Snapshot controller not installed**: `snapshot-controller` pods not running.
- **Source PVC not Bound**: VolumeSnapshot requires a Bound PVC as source.

**Fix**: Install snapshot controller, fix VSC driver name, or ensure PVC is Bound.

## CronJob Not Triggering

**Symptom**: CronJob exists but no Jobs are created on schedule.

```bash
# 1. Check CronJob schedule and last schedule time
kubectl -n <ns> get cronjob <name> -o jsonpath='{.spec.schedule} lastSchedule={.status.lastScheduleTime}'

# 2. Check if CronJob is suspended
kubectl -n <ns> get cronjob <name> -o jsonpath='{.spec.suspend}'

# 3. Check timezone — Kubernetes CronJobs use UTC by default
date -u

# 4. Manually trigger with a Job from the CronJob template
kubectl -n <ns> create job --from=cronjob/<name> manual-trigger-test
```

**Common causes**:
- **Suspended**: `spec.suspend: true` — resume via UI or `kubectl patch cronjob <name> -p '{"spec":{"suspend":false}}'`
- **Timezone**: Schedule uses server timezone (UTC). Verify the schedule expression matches expected UTC time.
- **Schedule syntax error**: Validate cron expression (5 fields: minute hour day month weekday).

**Fix**: Unsuspend, adjust timezone, or fix schedule syntax.

## XSKY CSI Install Failure

**Symptom**: XSKY CSI component status shows install failed or stuck in installing.

```bash
# 1. Check InstallPlan status
kubectl get installplan xsky-nfs-csi -o jsonpath='{.status.state} {.status.version}'
kubectl get installplan xsky-block-csi -o jsonpath='{.status.state} {.status.version}'

# 2. Check Helm Job status
kubectl -n extension-xsky-nfs-csi get jobs
kubectl -n extension-xsky-block-csi get jobs

# 3. Check Helm Job logs
kubectl -n extension-xsky-nfs-csi logs job/<job-name>

# 4. Check if CSIDriver was created
kubectl get csidriver | grep xsky

# 5. Check node preflight results (from UI: 系统组件 → XSKY CSI → 安装 → 节点预检)
# Common iSCSI preflight failures: missing iscsi-initiator-utils, multipath-tools, sg3_utils
# Common NFS preflight failures: missing nfs-utils/nfs-common, rpcbind
```

**Common causes**:
- **Node dependencies missing**: iSCSI needs `open-iscsi`/`iscsi-initiator-utils`, `multipath-tools`, `sg3_utils`. NFS needs `nfs-utils`/`nfs-common`, `rpcbind`.
- **Image pull failure**: Repository prefix incorrect or Harbor not accessible from nodes.
- **RBAC conflict**: Existing ClusterRole/ClusterRoleBinding with same name. Use advanced install parameters to override names.
- **Helm values error**: Invalid `extraValuesYAML` syntax.

**Fix**: Run node preflight with auto-fix, correct repository prefix, or override RBAC names. See [xsky-module.md](xsky-module.md) for detailed install procedures.

## XSKY CSI Uninstall Blocked

**Symptom**: Cannot uninstall XSKY CSI; status stays installed.

```bash
# Check for resources still using the XSKY driver
kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.provisioner}{"\n"}{end}' | grep xsky
kubectl get pvc -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{" "}{.spec.storageClassName}{"\n"}{end}' | grep -E 'codex-xsky|xsky'
kubectl get volumesnapshotclass -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.driver}{"\n"}{end}' | grep xsky
```

**Fix**: Delete all StorageClasses, PVCs, VolumeSnapshotClasses, and VolumeSnapshots that reference the XSKY driver, then retry uninstall. This is by design — uninstall protection prevents data loss.

## UI Form Submit Does Nothing

**Symptom**: Clicking submit button in the UI does not trigger any API call.

1. Check form validation errors (see `container-e2e-browser` skill, Critical Lessons Learned #3)
2. Check if submit button is disabled
3. Check browser console for JS errors: `bb-browser errors --tab <tabId>`
4. Check network requests: `bb-browser network requests --tab <tabId>`
5. Re-snapshot to verify the correct button ref is being used

## Namespace Deletion Stuck

**Symptom**: `kubectl delete ns` hangs; namespace stays in `Terminating` state.

```bash
# 1. Check what's blocking deletion
kubectl get ns <namespace> -o jsonpath='{.status.conditions}'

# 2. Check for finalizers
kubectl get ns <namespace> -o jsonpath='{.spec.finalizers}'

# 3. Check for remaining resources
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl -n <namespace> get --ignore-not-found 2>/dev/null
```

**Common causes**:
- Resources with finalizers not being cleaned up (e.g., PVCs with `kubernetes.io/pvc-protection`)
- Custom controller not running to process finalizers
- API server issues

**Fix**: Delete remaining resources manually, or in extreme cases, remove finalizers (only if you understand the consequences).
