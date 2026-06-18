---
name: container-e2e-full
description: Use when running full E2E testing across all GSStack container modules. Provides step-by-step test flows for workloads, network, config, storage, components, observability, XSKY, and system messages with functional verification.
metadata:
  short-description: Full container E2E test guide for all modules
---

# Full Container E2E Testing

Use this skill when running comprehensive E2E testing across all GSStack container modules.

## Prerequisites

- bb-browser connected to Chrome (see container-e2e-browser skill)
- Frontend running at http://localhost:18080
- kubectl access to target cluster
- Admin credentials for frontend login

## Test Flow Overview

1. Setup: Login, create test namespace
2. Workloads: Deployment, Service (curl test), Job, CronJob (trigger/suspend), Pod
3. Network: IPPool, Gateway (address verify), Route (curl test), EIP (LB test)
4. Config: Secret, ConfigMap, ImageService, ServiceAccount
5. Storage: SC, PV, PVC (mount+data test), VSC, VolumeSnapshot
6. Components: Cluster, Node (cordon/label/taint), SystemComponent, CRD
7. Observability: Logs/Events/Audit, Alerting, Notification
8. Messages: System Announcement (create+publish)

## Module Test Procedures

### Setup
- Login to frontend via bb-browser
- Create namespace codex-e2e-TIMESTAMP
- Verify: kubectl get ns

### Workloads
- Deployment: YAML create, verify rollout status
- Service: YAML create, verify Endpoints + Pod内curl 200
- Job: Form create, verify condition=complete + logs
- CronJob: Form create, test trigger/suspend/resume
- Pod: YAML create (if button available)

### Network (KEY FUNCTIONAL TESTS)
- IPPool: Form create, verify Calico CIDR
- Gateway: Form create, verify status.addresses + Accepted=True
- Route: Form create, verify Accepted=True + curl Gateway IP with Host header
- EIP: Form create, create LB Service, verify ingress IP

### Config Management
- Secret: YAML create (Opaque/stringData), verify kubectl
- ConfigMap: YAML create, verify data
- ImageService: Form create, verify in list
- ServiceAccount: Form create, verify kubectl

### Storage (KEY FUNCTIONAL TEST)
- SC: YAML create (no-provisioner)
- PV: YAML create (hostPath, match SC)
- PVC: YAML create, create Pod with mount, write+read data
- VSC: Wizard create (2 steps)

### Container Components
- Cluster: Verify host cluster listed
- Node: Cordon (unschedulable=true), uncordon, label add/verify
- SystemComponent: Verify cards with install/uninstall
- CRD: Verify list (Accessor, AccessPath)

### Observability
- Logs/Events/Audit: Tab switch + keyword search
- Alerting: YAML create PrometheusRule (use type command for textarea)
- Notification: Requires gsstack-notification installed

### System Messages
- Announcement: Form create (title/content/type/priority), publish, verify

## Available Test Images
- harbor.example.com/library/busybox:<tag>
- harbor.example.com/nginxinc/nginx-unprivileged:<tag> (port 8080)

Real registry configured in ignored local env file (see gsstack-local-dev skill convention).

## Key Verification Commands
- Service: kubectl -n NS exec POD -- curl -s -o /dev/null -w '%{http_code}' http://SVC:PORT/
- Gateway: kubectl -n NS get gateway NAME -o jsonpath='{.status.addresses[0].value}'
- Route: curl -s -o /dev/null -w '%{http_code}' -H 'Host: HOSTNAME' http://GATEWAY_IP/
- PVC: kubectl -n NS exec POD -- cat /data/test.txt
- Node: kubectl get node NAME -o jsonpath='{.spec.unschedulable}'
- CronJob trigger: kubectl -n NS get jobs (new job appears after trigger)
