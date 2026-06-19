---
name: container-e2e-full
description: Use when running full E2E testing across all GSStack container modules. Provides step-by-step test flows for workloads, network, config, storage, components, observability, XSKY, and system messages with functional verification.
metadata:
  short-description: Full container E2E test guide for all modules
---

# Full Container E2E Testing

Use this skill when running comprehensive E2E testing across all GSStack container modules.

## Prerequisites

- **container-e2e-browser skill installed** — provides bb-browser setup, login flow, `<ref>` explanation, form interaction patterns, and error recovery. Verify installation:
  ```bash
  ls ~/.agents/skills/container-e2e-browser/SKILL.md || echo "Install container-e2e-browser skill first"
  ```
- **bb-browser connected to Chrome** — see `container-e2e-browser` skill Setup section
- **Frontend running** at `http://localhost:18080`
- **kubectl access** to target cluster
- **Admin credentials** for frontend login (see `gsstack-local-dev` skill for env file convention)
- **gsstack-local-dev skill** — provides environment file conventions, local dev stack management, and WSL2 port proxy setup

## Pre-flight Checks

Run these before starting E2E tests:

```bash
# Cluster reachable
kubectl cluster-info

# All nodes Ready
kubectl get nodes -o wide

# Frontend accessible
curl -s -o /dev/null -w '%{http_code}' http://localhost:18080
# Expected: 200

# bb-browser daemon running
bb-browser daemon status

# No stuck pods from previous runs
kubectl get pods -A | grep -vE 'Running|Completed' | grep -v NAME
```

## Test Flow Overview

1. Setup: Login, create test namespace
2. Workloads: Deployment, Service (curl test), Job, CronJob (trigger/suspend), Pod
3. Network: IPPool, Gateway (address verify), Route (curl test), EIP (LB test)
4. Config: Secret, ConfigMap, ImageService, ServiceAccount
5. RBAC: Role, RoleBinding
6. Storage: SC, PV, PVC (mount+data test), VSC, VolumeSnapshot
7. Ingress: YAML create, verify routing
8. NetworkPolicy: YAML create, verify isolation
9. HPA: YAML create, verify autoscaling
10. Components: Cluster, Node (cordon/label/taint), SystemComponent, CRD
11. XSKY: CSI install/uninstall, StorageClass, PVC, VolumeSnapshot (see [xsky-module.md](xsky-module.md))
12. Observability: Logs/Events/Audit, Alerting, Notification
13. Messages: System Announcement (create+publish)

## Module Test Procedures

### Setup

1. Login to frontend via bb-browser (see `container-e2e-browser` skill Login Flow)
2. Navigate to `命名空间` (Namespace) page
3. Click `创建命名空间` (Create Namespace)
4. Name: `codex-e2e-<timestamp>`
5. Click `确认` (Confirm)
6. Verify: `kubectl get ns codex-e2e-<timestamp>`

### Workloads

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| Deployment | `容器应用 / 工作负载` → `创建工作负载` → `编辑yaml` | YAML | `kubectl rollout status` + readyReplicas |
| Service | `容器应用 / 服务` → `创建服务` → `编辑yaml` | YAML | `kubectl get svc` + `kubectl get endpoints` + curl inside Pod returns HTTP 200 |
| Job | `容器应用 / 工作负载` → Job tab → `创建` | Form | `kubectl get jobs` condition=complete + logs |
| CronJob | `容器应用 / 工作负载` → CronJob tab → `创建` | Form | `kubectl get cronjob` + trigger/suspend/resume |
| Pod | `容器应用 / 容器组` → `创建Pods` (if available) | YAML | `kubectl get pod` + status=Running |

YAML templates: see [yaml-templates.md](yaml-templates.md)

### Network (KEY FUNCTIONAL TESTS)

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| IPPool | `网络 / 容器组IP池` → `创建容器组IP池` | Form (IP + mask + count) | `kubectl get ippools.crd.projectcalico.org` CIDR matches |
| Gateway | `网络 / 网关` → `创建网关` | Form | `kubectl get gateway` status.addresses + Accepted=True |
| Route | `网络 / 路由` → `创建路由` | Form | `kubectl get httproute` Accepted=True + curl Gateway IP with Host header |
| EIP | `网络 / 弹性公网IP` → `创建` | Form | `kubectl get eip` spec.address + create LB Service |

### Config Management

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| Secret | `配置管理 / 保密字典` → `创建保密字典` | YAML or Form | `kubectl get secret` type=Opaque |
| ConfigMap | `配置管理 / 配置字典` → `创建配置字典` | YAML or Form | `kubectl get configmap` data matches |
| ImageService | `配置管理 / 镜像服务管理` → `创建镜像服务地址` | Form (address + credentials) | `kubectl get secret` dockerconfigjson in namespace |
| ServiceAccount | `配置管理 / 服务账号` → `创建` | Form | `kubectl get sa` exists with auto-generated token secret |

### RBAC

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| Role | `配置管理 / 角色` → `创建角色` | Form (rules) | `kubectl get role` rules match |
| RoleBinding | `配置管理 / 角色绑定` → `创建角色绑定` | Form (role + subjects) | `kubectl get rolebinding` roleRef + subjects match |

Verify RBAC enforcement: create a Pod with the bound ServiceAccount and test API access matches the Role rules.

### Storage (KEY FUNCTIONAL TEST)

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| StorageClass | `数据卷 / 存储类型` → `创建存储类型` → `编辑YAML` | YAML | `kubectl get sc` provisioner matches |
| PersistentVolume | `数据卷 / 存储卷` → `创建存储卷` → YAML | YAML | `kubectl get pv` status=Available |
| PVC | `数据卷 / 存储卷声明` → `创建存储卷声明` | Form | `kubectl get pvc` status=Bound |
| Pod+PVC mount | `容器应用 / 工作负载` → `创建工作负载` → YAML | YAML | Write data to mount, read back from another Pod |
| VolumeSnapshotClass | `数据卷 / 卷快照类` → `创建卷快照类` | Wizard (2 steps) | `kubectl get volumesnapshotclass` driver matches |
| VolumeSnapshot | `数据卷 / 卷快照` → `创建卷快照` | Form (select PVC + VSC) | `kubectl get volumesnapshot` readyToUse=true |

#### VSC Wizard Create (2 Steps)

- **Step 1**: Select provisioner/driver from dropdown (e.g., `kubernetes.io/no-provisioner`, `iscsi.csi.xsky.com`, `com.nfs.csi.xsky`)
- **Step 2**: Fill name, select deletion policy (`Delete` or `Retain`), submit

YAML templates: see [yaml-templates.md](yaml-templates.md)

### Ingress

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| Ingress | `网络 / 应用路由` → `创建` → `编辑YAML` | YAML | `kubectl get ingress` rules match + curl with Host header |

YAML template: see [yaml-templates.md](yaml-templates.md)

### NetworkPolicy

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| NetworkPolicy | `网络 / 网络策略` → `创建` → `编辑YAML` | YAML | `kubectl get networkpolicy` + verify Pod traffic isolation |

YAML template: see [yaml-templates.md](yaml-templates.md)

### HPA (Horizontal Pod Autoscaler)

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| HPA | `容器应用 / 工作负载` → select Deployment → `更多 / 弹性伸缩` | Form | `kubectl get hpa` + verify scaling behavior under load |

YAML template: see [yaml-templates.md](yaml-templates.md)

### Container Components

| Resource | UI Path | Verification |
|---|---|---|
| Cluster | `容器组件 / 集群管理` | Host cluster listed; imported cluster shows version + node count |
| Node | `容器组件 / 集群节点` → select cluster → `更多` on node row | Cordon: `kubectl get node -o jsonpath='{.spec.unschedulable}'` = true; Uncordon: false; Label add/verify; Taint add/verify |
| SystemComponent | `容器组件 / 系统组件` | Verify cards with install/uninstall buttons; disabled uninstall when resources depend on component |
| CRD | `容器组件 / 自定义资源` | Verify list (Accessor, AccessPath, etc.); detail view works |

### XSKY CSI Module

XSKY provides iSCSI and NFS CSI drivers as installable system components. Full testing procedures including install, StorageClass/VSC creation, data-plane PVC/Pod/VolumeSnapshot testing, uninstall protection, and cleanup are in:

→ [xsky-module.md](xsky-module.md)

### Observability

#### Logs / Events / Audit

- **UI Path**: `可观测性 / 日志事件审计`
- **Component**: `gsstack-logging` (must be installed)
- **Steps**:
  1. Open `可观测性 / 日志事件审计`
  2. Tab: `日志检索` (Log Search) — enter keyword or time range, click query
  3. Click a record → verify detail drawer shows raw content
  4. Tab: `事件检索` (Event Search) — same query flow
  5. Tab: `审计检索` (Audit Search) — same query flow
- **Note**: These are collected records, not CRUD objects. Generate test data by creating/deleting resources.

#### Alerting

- **UI Path**: `可观测性 / 告警规则`
- **Component**: `gsstack-alerting` (must be installed)
- **Steps**:
  1. Open `可观测性 / 告警规则`
  2. Search `codex-e2e` to confirm empty or only test resources
  3. Click `创建规则组` (Create Rule Group)
  4. Use YAML editor (use `type` command for textarea per `container-e2e-browser` skill)
  5. YAML must include `labels: severity: warning` for notification routing
  6. Verify: list shows rule group, click name to see detail
  7. Edit: click `编辑`, change annotations, submit, verify
  8. Delete: click `删除`, confirm, verify list empty

PrometheusRule YAML template: see [yaml-templates.md](yaml-templates.md)

**Component install/uninstall verification**:
1. Delete test PrometheusRule
2. Open `容器组件 / 系统组件`, click `告警规则 / 卸载` (Uninstall)
3. Verify status: `卸载中` → uninstalled
4. Open alerting page: menu hidden or page shows component unavailable
5. Click `安装` (Install), verify status: `安装中` → `已安装`
6. Page re-enabled for CRUD

#### Notification

- **UI Path**: `可观测性 / 通知管理`
- **Component**: `gsstack-notification` (must be installed; if not installed, alerting page notification button is disabled)

**Webhook Receiver CRUD**:
1. Open `可观测性 / 通知管理`, tab: `通知对象` (Notification Objects)
2. Verify built-in `system-notification` shows as `内置` (built-in), not editable/deletable
3. Click `创建通知对象` (Create), type: `HTTP 应用` or `Webhook`
4. Name: `codex-e2e-<timestamp>-webhook`, fill webhook URL (must be cluster-reachable, not localhost)
5. Submit, verify list, click name for detail
6. Edit YAML (metadata labels or URL), submit, verify
7. Delete: confirm list empty

**Router CRUD**:
1. Tab: `路由` (Routes)
2. Click `创建路由` (Create Route), name: `codex-e2e-<timestamp>-router`
3. Set `alertSelector` to match `severity: warning`, select receiver
4. Submit, verify list, click name for detail
5. Edit YAML, verify
6. Delete router, then delete webhook receiver

**SMS Receiver** (requires existing Secret):
1. Open `字典管理 / 保密字典` (Config → Secrets)
2. Create Secret `codex-e2e-<timestamp>-sms-secret` in `kubesphere-monitoring-system` namespace
3. Back in Notification, create `短信` (SMS) type receiver
4. Select provider (Aliyun/Tencent), fill Secret name and key
5. Submit, verify list, delete

**Webhook Delivery E2E**:
1. Create webhook receiver and router
2. Create PrometheusRule with `expr: vector(1)`, `for: 1m` (trigger immediately)
3. Wait for alert to fire (~1-2 min)
4. Verify webhook demo received alert payload
5. Delete rule or change expr back to safe value

**Note**: Webhook URL must be reachable from cluster's notification-manager pod. Local `localhost`/`127.0.0.1` will not work. Use NodePort, Ingress, or tunnel.

### System Messages

| Resource | UI Path | Create Method | Verification |
|---|---|---|---|
| Announcement | `系统管理 / 系统通告` → `创建通告` | Form (title/content/type/priority) | Publish, verify via bell icon + `/System/myMessage` page |

**Steps**:
1. Open `系统管理 / 系统通告` (System → Announcements)
2. Click `创建通告` (Create Announcement)
3. Fill title: `codex-e2e-<timestamp>-bell`, content, type: `通知` (Notification)
4. Select target: `Roshan` or all users
5. Save, then click `发布` (Publish) in the list
6. Switch to target user session, click bell icon
7. Verify notification count increased, click message to open detail
8. Click `查看更多` (View More) → verify redirect to `/System/myMessage`
9. Repeat with type: `系统消息` (System Message)

## Cleanup

**Delete in this order** to avoid orphaned resources:

```bash
# 1. Delete namespaced resources
kubectl -n <namespace> delete deploy,svc,job,cronjob,pod -l codex-e2e=e2e --ignore-not-found
kubectl -n <namespace> delete pvc,secret,configmap,sa,role,rolebinding -l codex-e2e=e2e --ignore-not-found
kubectl -n <namespace> delete ingress,networkpolicy,hpa -l codex-e2e=e2e --ignore-not-found
kubectl -n <namespace> delete volumesnapshot -l codex-e2e=e2e --ignore-not-found

# 2. Delete cluster-scoped resources (NOT cleaned by namespace deletion!)
kubectl delete pv -l codex-e2e=e2e --ignore-not-found
kubectl delete sc -l codex-e2e=e2e --ignore-not-found
kubectl delete volumesnapshotclass -l codex-e2e=e2e --ignore-not-found
kubectl delete ippools.crd.projectcalico.org -l codex-e2e=e2e --ignore-not-found
kubectl delete gateway,httproute,eip -l codex-e2e=e2e --ignore-not-found 2>/dev/null

# 3. Delete test namespace
kubectl delete ns <namespace> --ignore-not-found

# 4. Verify no residual resources
kubectl get all,sc,pvc,pv,vsc,vs -l codex-e2e=e2e -A 2>/dev/null
# Expected: no resources found
```

**Important**: PV, SC, VolumeSnapshotClass, IPPool, Gateway, Route, and EIP are cluster-scoped resources. Deleting the namespace does NOT delete them. They must be cleaned up explicitly.

For XSKY test resource cleanup, see [xsky-module.md](xsky-module.md) Cleanup section.

## Timeout Reference

| Operation | Expected Wait | Timeout |
|---|---|---|
| Deployment rollout | 30-60s | 180s |
| Service endpoints populated | 5-10s | 30s |
| PVC binding (static SC) | 5-10s | 60s |
| PVC binding (dynamic CSI) | 30-60s | 120s |
| Gateway address assignment | 10-30s | 60s |
| Job completion | varies by task | 300s |
| CronJob trigger | next schedule | manual trigger |
| VolumeSnapshot ready | 10-30s | 120s |
| XSKY CSI install | 60-120s | 300s |
| Component install/uninstall | 30-60s | 180s |
| Namespace deletion | 10-30s | 60s |

## Available Test Images

- `harbor.example.com/library/busybox:<tag>`
- `harbor.example.com/nginxinc/nginx-unprivileged:<tag>` (port 8080)

Real registry configured in ignored local env file (see `gsstack-local-dev` skill convention).

## Key Verification Commands

```bash
# Service: curl inside Pod returns HTTP 200
kubectl -n <ns> exec <pod> -- curl -s -o /dev/null -w '%{http_code}' http://<svc>:<port>/

# Gateway: get address
kubectl -n <ns> get gateway <name> -o jsonpath='{.status.addresses[0].value}'

# Route: curl with Host header
curl -s -o /dev/null -w '%{http_code}' -H 'Host: <hostname>' http://<gateway-ip>/

# PVC: verify data persistence
kubectl -n <ns> exec <pod> -- cat /data/test.txt

# Node: verify cordon status
kubectl get node <name> -o jsonpath='{.spec.unschedulable}'

# CronJob: verify trigger created a Job
kubectl -n <ns> get jobs --watch

# HPA: verify autoscaling
kubectl -n <ns> get hpa <name> --watch

# VolumeSnapshot: verify ready
kubectl -n <ns> get volumesnapshot <name> -o jsonpath='{.status.readyToUse}'
```

## Error Handling

For troubleshooting common E2E failures (Pod CrashLoopBackOff, PVC stuck Pending, rollout timeout, Gateway no address, etc.), see [troubleshooting.md](troubleshooting.md).

## References

- [yaml-templates.md](yaml-templates.md) — All YAML templates for test resources
- [http-workload-service.md](http-workload-service.md) — Known-good HTTP workload + Service for curl verification
- [troubleshooting.md](troubleshooting.md) — Error handling and diagnosis
- [xsky-module.md](xsky-module.md) — XSKY CSI install/uninstall/data-plane testing
- `container-e2e-browser` skill — bb-browser setup, login flow, form patterns, error recovery
- `gsstack-local-dev` skill — environment file conventions, local dev stack management
