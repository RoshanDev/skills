# XSKY CSI Module E2E Testing

XSKY provides iSCSI and NFS CSI drivers as installable system components in GSStack. This document covers the full E2E lifecycle: install, StorageClass/VolumeSnapshotClass creation, data-plane PVC/Pod/VolumeSnapshot testing, uninstall protection, uninstall, and cleanup.

## Overview

| Component | Addon Name | CSI Driver | Namespace |
|---|---|---|---|
| XSKY iSCSI CSI | `xsky-block-csi` | `iscsi.csi.xsky.com` | `extension-xsky-block-csi` |
| XSKY NFS CSI | `xsky-nfs-csi` | `com.nfs.csi.xsky` | `extension-xsky-nfs-csi` |

Both appear as cards under `容器组件 / 系统组件` (Container Components / System Components), path: `/Assets/container/components/custom-system`.

## Prerequisites

- **XMS access**: XSKY management server address, access token (for CSI Secret)
- **Harbor repository prefix**: e.g., `harbor.example.com/kubesphere`
- **Node SSH credentials**: for iSCSI node preflight (can come from KubeKey Lifecycle Profile)
- **iSCSI system packages** (per node): `open-iscsi`/`iscsi-initiator-utils`, `multipath-tools`/`device-mapper-multipath`, `sg3_utils`, `device-mapper`
- **NFS system packages** (per node): `nfs-utils`/`nfs-common`, `rpcbind`
- **Unique initiator names**: `/etc/iscsi/initiatorname.iscsi` `InitiatorName` must be unique across worker nodes (duplicate IQN causes driver pod CrashLoop)
- **Real XSKY pool, share, and access token**: data-plane testing creates resources on the storage backend

**Security**: XMS tokens, SSH passwords, and Harbor passwords must not be logged in docs, screenshots, or committed files. Use `codex-xsky-*` prefix for all test resources.

## Install

### UI Path

`容器组件 / 系统组件` → find `XSKY CSI` card → click `安装` (Install)

The aggregated card `XSKY CSI` (addon name `xsky-csi`) includes both `xsky-block-csi` and `xsky-nfs-csi`.

### Install Parameters

| Parameter | Description | Default |
|---|---|---|
| `repository` | Harbor image prefix (e.g., `harbor.example.com/kubesphere`) | Derived from cluster mirror config |
| `kubeletDir` | Kubelet root directory | `/var/lib/kubelet` (or derived from KubeKey `data_root`) |

**Advanced Helm values** (optional): `driver.attachRequired`, `driver.enableStrictAccessModeCheck` (NFS), `enableMultipath`, `multipathManagementMode`, `noPathRetry`, `enableCleanRemnantDevices` (iSCSI), `autoSyncMultipathConfig`, `multipathVendor`, `multipathProduct`.

### Node Preflight

1. In the install dialog, fill node SSH info (or auto-derived from KubeKey Lifecycle Profile)
2. Click `节点预检` (Node Preflight)
3. If failures are fixable, click `自动修复并复查` (Auto-fix and Recheck)
4. Preflight must pass before install can proceed

### Install Steps

1. Open `容器组件 / 系统组件`
2. Find `XSKY CSI` card, confirm status is `--` or not installed, button shows `安装`
3. Click `安装`
4. Fill `repository` and `kubeletDir`
5. Fill node SSH info, click `节点预检`
6. If preflight fails with fixable issues, click `自动修复并复查`; pass before proceeding
7. Click `确认` (Confirm), confirm the secondary dialog
8. Return to system components list, enable auto-refresh or manually refresh
9. Expected status transition: `安装中` (Installing) → `已安装` (Installed)

### Verify Install

```bash
# NFS CSI
kubectl get installplan xsky-nfs-csi -o jsonpath='{.status.state}{" "}{.status.version}{"\n"}'
# Expected: Installed <version>

kubectl -n extension-xsky-nfs-csi get deploy,ds,job
# Expected: Deployment/DaemonSet Ready, Helm Job Complete

kubectl get csidriver com.nfs.csi.xsky
# Expected: exists

# iSCSI CSI
kubectl get installplan xsky-block-csi -o jsonpath='{.status.state}{" "}{.status.version}{"\n"}'
# Expected: Installed <version>

kubectl -n extension-xsky-block-csi get deploy,ds,job
# Expected: Deployment/DaemonSet Ready, Helm Job Complete

kubectl get csidriver iscsi.csi.xsky.com
# Expected: exists
```

### Post-Install: Verify Storage Pages

1. Open `数据卷 / 存储类型` (Storage / StorageClass), click `创建存储类型` (Create)
2. In the storage system step, confirm `XSKY iSCSI CSI` and `XSKY NFS CSI` are selectable
3. If not installed, the options should be disabled with a link to system components

1. Open `数据卷 / 卷快照类` (Storage / VolumeSnapshotClass), click `创建卷快照类` (Create)
2. Confirm `iscsi.csi.xsky.com` and `com.nfs.csi.xsky` appear in the provider dropdown

## Create StorageClass

### NFS StorageClass (Form Create)

UI Path: `数据卷 / 存储类型` → `创建存储类型` → select `XSKY NFS CSI`

| Field | Value | Notes |
|---|---|---|
| Name | `codex-xsky-nfs-e2e` | |
| Storage product | `GFS`, `EUS`, `XS`, or `G1.9` | |
| Type | `share` or `subpath` | |
| XMS address | `<xms-management-ip>` | |
| Token | XSKY access token | Goes into Kubernetes Secret, not displayed in list |
| Share address | `<gateway-vip>:/data` | Must be DFS gateway VIP, not management IP |
| Client limit | `*` | |
| Client group | V5: `clientGroupName`; V6: `clients` | Do not mix both field sets |

**Verify**:
```bash
kubectl get sc codex-xsky-nfs-e2e -o jsonpath='{.provisioner}{" "}{.parameters.shares}{"\n"}'
# Expected: com.nfs.csi.xsky <share-address>

kubectl -n default get secret codex-xsky-nfs-e2e-secret -o jsonpath='{.metadata.name}{" "}{.type}{"\n"}'
# Expected: codex-xsky-nfs-e2e-secret Opaque
# Do NOT print Secret data content
```

### iSCSI StorageClass (Form Create)

UI Path: `数据卷 / 存储类型` → `创建存储类型` → select `XSKY iSCSI CSI`

| Field | Value | Notes |
|---|---|---|
| Name | `codex-xsky-iscsi-e2e` | |
| Secret name/namespace/token | XSKY credential | |
| AccessPath name | `codex-xsky-iscsi-e2e-ap` | `spec.type` = `Kubernetes` |
| `xmsServers` | `<xms-management-ip>` | |
| Gateway | XMS target name (e.g., `sds1`) | NOT target IP; use `multi_gateway` for multi-network |
| `accessPaths` | existing AccessPath name | If using existing, skip gateway creation |
| `pool` | XSKY pool name | |
| `fsType` | `ext4` or `xfs` | |
| `flatten` | optional | |

**iSCSI Gateway Notes**:
- `gateway` must be the XMS target name (e.g., `sds1`), not the target IP
- For multi-network gateways, use `multi_gateway` with `hostname=ip1,ip2` format
- If using an existing AccessPath, fill `accessPaths` directly instead of creating new

**Verify**:
```bash
kubectl get sc codex-xsky-iscsi-e2e -o jsonpath='{.provisioner}{"\n"}'
# Expected: iscsi.csi.xsky.com

kubectl get accesspaths.sds.xsky.com codex-xsky-iscsi-e2e-ap -o jsonpath='{.spec.type}{"\n"}'
# Expected: Kubernetes
```

## Create VolumeSnapshotClass

UI Path: `数据卷 / 卷快照类` → `创建卷快照类`

| Field | Value |
|---|---|
| Name | `codex-xsky-nfs-vsc-e2e` (or `codex-xsky-iscsi-vsc-e2e`) |
| Provider | `com.nfs.csi.xsky` (or `iscsi.csi.xsky.com`) |
| Deletion policy | `Delete` |

**Verify**:
```bash
kubectl get volumesnapshotclass codex-xsky-nfs-vsc-e2e -o jsonpath='{.driver}{" "}{.deletionPolicy}{"\n"}'
# Expected: com.nfs.csi.xsky Delete
```

## Data-Plane Test (PVC → Pod → VolumeSnapshot)

Data-plane testing requires real XSKY pool, share, and access token. It creates resources on the storage backend. Use a dedicated namespace with `codex-xsky-*` prefix and temporary token.

### 1. Create PVC

UI Path: `数据卷 / 存储卷声明` → `创建存储卷声明`

- Select XSKY StorageClass (`codex-xsky-nfs-e2e` or `codex-xsky-iscsi-e2e`)
- Capacity: small test value (e.g., `1Gi`)
- Access mode: per driver capability (NFS: `ReadWriteMany`; iSCSI: `ReadWriteOnce`)

```bash
kubectl -n <namespace> get pvc codex-xsky-e2e-pvc -o jsonpath='{.status.phase}{"\n"}'
# Expected: Bound
```

### 2. Create Pod with PVC Mount and Write Data

Use the Pod-with-PVC template from [yaml-templates.md](yaml-templates.md), replacing the StorageClass and PVC name with XSKY test resources.

```bash
# Wait for Pod to be Running
kubectl -n <namespace> wait pod/codex-xsky-e2e-pod --for=condition=Ready --timeout=120s

# Verify data was written
kubectl -n <namespace> exec codex-xsky-e2e-pod -- cat /data/test.txt
# Expected: test data content
```

### 3. Read Data from Another Pod (NFS only — same PVC, multiple readers)

For NFS (`ReadWriteMany`), create a second Pod mounting the same PVC and read the data back:

```bash
kubectl -n <namespace> exec codex-xsky-e2e-reader-pod -- cat /data/test.txt
# Expected: same data as writer
```

### 4. Create VolumeSnapshot

UI Path: `数据卷 / 卷快照` → `创建卷快照`

- Name: `codex-xsky-e2e-snapshot`
- PVC: `codex-xsky-e2e-pvc`
- VolumeSnapshotClass: `codex-xsky-nfs-vsc-e2e` (or iSCSI equivalent)

```bash
kubectl -n <namespace> get volumesnapshot codex-xsky-e2e-snapshot -o jsonpath='{.status.readyToUse}{"\n"}'
# Expected: true
```

### 5. (Optional) Restore from Snapshot

Create a new PVC with `dataSource` pointing to the VolumeSnapshot:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: codex-xsky-e2e-restore-pvc
  namespace: <namespace>
  labels:
    codex-e2e: e2e
spec:
  accessModes:
    - ReadWriteOnce  # or ReadWriteMany for NFS
  storageClassName: codex-xsky-nfs-e2e  # or iSCSI equivalent
  resources:
    requests:
      storage: 1Gi
  dataSource:
    name: codex-xsky-e2e-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

```bash
kubectl -n <namespace> get pvc codex-xsky-e2e-restore-pvc -o jsonpath='{.status.phase}{"\n"}'
# Expected: Bound (may take longer than fresh PVC)
```

**Known limitation**: NFS CSI `3.1.000.5` may return `volume content source missing` for restore PVC. Record as known limitation if encountered; do not block iSCSI/NFS non-restore verification.

### 6. Verify VolumeSnapshotContent

```bash
kubectl get volumesnapshotcontent -o wide | grep codex-xsky-e2e-snapshot
# Expected: exists with READY=true
```

## Uninstall Protection Verification

**Purpose**: Verify the system prevents uninstalling XSKY CSI while StorageClass/VSC still reference the driver.

1. Keep `codex-xsky-nfs-e2e` StorageClass and/or `codex-xsky-nfs-vsc-e2e` VolumeSnapshotClass
2. Open `容器组件 / 系统组件`
3. Attempt to uninstall `XSKY NFS CSI`
4. Expected: page still shows installed; cluster-side `InstallPlan` stays `Installed`; workload not deleted
5. The uninstall should be blocked or show a warning about dependent resources

## Uninstall

### Prerequisites

All StorageClasses, PVCs, PVs, VolumeSnapshotClasses, and VolumeSnapshots referencing the XSKY driver must be deleted first.

### Steps

1. Open `容器组件 / 系统组件`
2. In `XSKY CSI` card, click `卸载` (Uninstall)
3. Confirm the dialog
4. Expected status transition: `卸载中` (Uninstalling) → uninstalled, button shows `安装` (Install)
5. Open `数据卷 / 存储类型` create wizard — verify XSKY options are disabled or prompt to install component first
6. Open `数据卷 / 卷快照类` create wizard — verify XSKY driver not in provider dropdown

## Cleanup

### Data-Plane Resource Cleanup Order

Delete in this exact order to avoid stuck resources:

```bash
# 1. Delete Pods (wait for iSCSI/NFS unmount to complete)
kubectl -n <namespace> delete pod codex-xsky-e2e-pod codex-xsky-e2e-reader-pod --ignore-not-found --wait

# 2. Delete restore PVC (releases snapshot-as-source protection)
kubectl -n <namespace> delete pvc codex-xsky-e2e-restore-pvc --ignore-not-found

# 3. Delete VolumeSnapshot (wait for VolumeSnapshotContent to disappear)
kubectl -n <namespace> delete volumesnapshot codex-xsky-e2e-snapshot --ignore-not-found --wait

# 4. Delete source PVC (wait for PV to disappear)
kubectl -n <namespace> delete pvc codex-xsky-e2e-pvc --ignore-not-found --wait

# 5. Delete StorageClass and VolumeSnapshotClass
kubectl delete sc codex-xsky-nfs-e2e codex-xsky-iscsi-e2e --ignore-not-found
kubectl delete volumesnapshotclass codex-xsky-nfs-vsc-e2e codex-xsky-iscsi-vsc-e2e --ignore-not-found

# 6. Delete AccessPath and Secret (iSCSI)
kubectl delete accesspaths.sds.xsky.com codex-xsky-iscsi-e2e-ap --ignore-not-found
kubectl -n default delete secret codex-xsky-nfs-e2e-secret codex-xsky-iscsi-e2e-secret --ignore-not-found

# 7. Delete XMS temporary token (via xms-cli, not kubectl)
# This is environment-specific; do not log the token value
```

### Post-Uninstall Residual Scan

```bash
# Check for any XSKY residual resources
kubectl get installplan -A | grep -E 'xsky-(block|nfs)-csi' || true
kubectl get csidriver | grep -E 'xsky|nfs.csi' || true
kubectl -n extension-xsky-nfs-csi get all 2>/dev/null || true
kubectl -n extension-xsky-block-csi get all 2>/dev/null || true
kubectl get sc,volumesnapshotclass | grep -E 'codex-xsky|com.nfs.csi.xsky|iscsi.csi.xsky.com' || true
```

**Expected**: No XSKY InstallPlan, CSIDriver, workload, test StorageClass, or test VolumeSnapshotClass residual. `accesspaths.sds.xsky.com` and `volumesnapshot*.snapshot.storage.k8s.io` CRDs remaining is expected behavior.

## Credential Handling

- XSKY CSI requires XMS access token stored in a Kubernetes Secret (`data.token`)
- The StorageClass references the Secret via `csi.storage.k8s.io/provisioner-secret-name/namespace`
- **Do not** paste raw tokens in docs, screenshots, logs, or HAR request bodies
- The UI should use a credential/SecretRef selector, not a raw token input field
- When creating credentials: token input only in a controlled dialog with masked input; submit creates/updates the Secret, then the StorageClass form only references the Secret name

## Reinstall / Configure

1. In `XSKY CSI` installed state, click `配置` (Configure)
2. Modify a non-risky parameter or keep original values
3. Page warns: `参数配置完成后，点击确定会立即重装！` (After parameter config, clicking OK will immediately reinstall!)
4. Confirm submit
5. Expected status: `安装中` or `重装中` (Reinstalling) → `已安装`

If status shows `依赖异常` (Dependency Error), `安装失败` (Install Failed), `需回滚` (Needs Rollback), or `可升级` (Upgrade Available), use `重装` (Reinstall), `重试` (Retry), or `升级` (Upgrade) buttons — all go through the same parameter dialog.

## Verification Command Summary

```bash
# Install status
kubectl get installplan xsky-nfs-csi xsky-block-csi -o jsonpath='{range .items[*]}{.metadata.name}: {.status.state} {.status.version}{"\n"}{end}'

# CSI Drivers
kubectl get csidriver | grep -E 'xsky|nfs.csi'

# Workloads
kubectl -n extension-xsky-nfs-csi get deploy,ds,job
kubectl -n extension-xsky-block-csi get deploy,ds,job

# StorageClass
kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.provisioner}{"\n"}{end}' | grep xsky

# VolumeSnapshotClass
kubectl get volumesnapshotclass -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.driver}{"\n"}{end}' | grep xsky

# PVC status
kubectl -n <namespace> get pvc -l codex-e2e=e2e

# VolumeSnapshot status
kubectl -n <namespace> get volumesnapshot -l codex-e2e=e2e

# VolumeSnapshotContent
kubectl get volumesnapshotcontent -o wide | grep codex-xsky

# Residual scan
kubectl get installplan,csidriver,sc,volumesnapshotclass -A 2>/dev/null | grep -E 'xsky|codex-xsky' || echo "Clean"
```
