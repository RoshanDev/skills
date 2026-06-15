---
name: zstack-gsstack-ops
description: Safe GSStack/ZStack development-cluster operations workflow for snapshot restore, real install/uninstall E2E checks, KubeKey/offline artifact persistence, node lifecycle tests, and secret-safe evidence. Trigger when working on ZStack-backed GSStack labs, destructive restore, KubeKey deployment bundles, Harbor/offline images, member-cluster add-node/import E2E, or observability component install/uninstall flows.
---

# ZStack GSStack Ops

Use this skill for GSStack development clusters that are recoverable through ZStack snapshots. The goal is not just to make the current lab pass once; the fix must survive the next KubeKey/offline redeploy and must not leak ZStack or cluster secrets.

## Non-Negotiables

- Do not commit ZStack UI/API endpoints, account names, access keys, secret keys, session tokens, VM UUIDs, node passwords, registry passwords, kubeconfigs, cookies, or HAR request bodies.
- Keep lab inventory in project-private docs, ignored local env files, secure memory, or the user's approved secret store. Public skills must use placeholders only.
- Destructive restore authority may come from the user or the project AGENTS. Once approved, restore the intended cluster unit directly; do not keep asking for approval inside the same approved operation.
- Snapshot restore is recovery setup, not acceptance evidence. A dry-run is only preflight. If the dev cluster is recoverable and a component is absent, run the real install/uninstall or E2E path and verify live behavior.
- Every successful shell, remote heredoc, ad hoc Python, Helm, kubectl patch, copied-bundle edit, or manual node edit is diagnostic until the corresponding source, template, KubeKey default, offline artifact, or runbook is updated.
- If the source is available during active development, change the source directly. Do not add customer-facing patch archives, overlay scripts, or patch stacks unless the user explicitly asks for a released-version hotfix.

## Required Inputs

Before operating, locate these from project-private context or ignored local configuration:

- ZStack endpoint and credentials or AK/SK.
- Snapshot names/IDs and VM membership for each cluster unit.
- Node inventory, roles, architecture, data root, registry domain, and spare-node status.
- Active KubeKey/offline package path, source repo path, and artifact checksum files.
- Product acceptance path: API, UI, E2E test, workload readiness, and cleanup expectations.

If any secret or endpoint is missing, do not invent it and do not ask the user to paste it into a public transcript. Ask for a secure local path or use the approved secret store.

## Workflow

1. **Classify the operation.**
   - Restore: identify the whole cluster unit, not a flat node list.
   - Install/uninstall/E2E: identify the product component and live acceptance checks.
   - KubeKey/offline artifact work: identify source, generated bundle, image archive, image lists, digests, and checksums.
   - Node lifecycle: identify whether the target is an imported endpoint, existing member cluster, or clean spare node.

2. **Protect secrets before commands.**
   - Use ignored env files, stdin JSON, Kubernetes Secret material, or redacted summaries.
   - Avoid secrets in CLI argv, shell history, logs, screenshots, HAR files, plans, commits, and final answers.
   - When browser/API payloads legitimately include node passwords, verify status and behavior without printing request bodies.

3. **Restore or prepare the environment for real.**
   - Restore all nodes that belong to the target cluster unit when a restore is required.
   - Do not restore a spare node if project/user context says it is already clean and can be used directly.
   - After restore, verify machine identity, SSH, OS architecture, time, container runtime, kubelet state, and cluster readiness before product testing.

4. **Run product behavior, not only preflight.**
   - If observability/notification-manager is not installed on a recoverable dev cluster, install it and test the live uninstall path.
   - If member-cluster import/add-node is under test, use the real product API/UI path and verify the resulting cluster/node/workload state.
   - Duplicate endpoint import must be rejected at the API/product boundary; do not accept duplicate registration because an internal object already exists.

5. **Persist the fix.**
   - Source changes belong in the owning repo, generator, Helm chart, KubeKey defaults/templates, or deployment assets.
   - Active offline packages must be updated together with image lists, digest files, OCI/archive metadata, and checksums.
   - External bundle-only changes need exact path, sync command, reason, checksum update, and redeploy risk recorded.

6. **Verify and report.**
   - Map evidence to acceptance criteria: command, exit code, live object state, API result, UI/E2E result, and artifact consistency.
   - Report any live-only action as not solidified, with the expected next-redeploy failure.
   - Do not claim PASS while old blocker notes remain current; mark superseded records when new evidence or user clarification changes the truth.

## ZStack Restore Rules

- Restore by cluster unit. A multi-node cluster restore must keep node snapshots consistent with each other.
- A spare VM marked clean by the user is restore-exempt, not test-exempt. It can be used directly for add-node or replacement-node E2E.
- After cloning/restoring, regenerate duplicated machine identity when required by the project runbook before joining Kubernetes.
- Confirm the recovered cluster is healthy before product-level tests; unhealthy recovery is a blocker for the product test, not evidence against the product.

## KubeKey And Offline Artifact Rules

- Deployment logic must be topology-agnostic. Node count belongs in inventory/config; avoid reusable 1-node, 3-node, or N-node-only forks.
- Keep source registry references on the company canonical registry or the configured registry variable. Do not bake raw lab-IP registry prefixes into source, YAML, Helm values/templates, image lists, digest files, OCI/archive refs, generated binaries, or runbooks that are deployment inputs.
- Target/customer registries are injected by configuration such as `REGISTRY_HOST` or image prefix fields. Raw node IPs are only for host mapping, certificate/trust wiring, or explicit node inventory.
- Registry audits must include tracked and ignored generated text, offline package metadata, image archive metadata, and checksum files.
- When modifying a generated/offline bundle, update and verify checksum files in the same change.
- Remote executor work directories must match the KubeKey contract: parent workdir outside the internally appended artifact subdirectory.
- If runner/fallback images are referenced by defaults or profiles, the active offline package must contain those images even if the current path does not launch the runner.

## Node Lifecycle Rules

- Clean spare nodes may be used directly when the user marks them clean.
- Duplicate import of the same endpoint must be rejected before creating duplicate member-cluster state.
- Agent image provenance must be verified before member import/add-node: registry, tag, digest, architecture, and offline package presence.
- If OS package initialization fails on an offline clean node, prefer the bundled repository/ISO path documented by the project before using network repos.
- Browser/API flows may carry node passwords in internal-network deployments, but the agent must redact all evidence and avoid persistent request-body capture.

## Evidence Template

```text
Operation:
- Restore/install/uninstall/E2E/artifact/node lifecycle

Inputs:
- Inventory source: <private path or project doc, redacted>
- Secret source: <ignored local path or secret store, redacted>
- Package/source path: <path, no secrets>

Actions:
- <command or API path, redacted>

Durability:
- Source updated: <yes/no/path>
- Offline artifact updated: <yes/no/path>
- Checksums updated: <yes/no/path>
- Live-only actions remaining: <none or explicit risk>

Verification:
- AC-001: <command/result>
- AC-002: <live/API/UI/E2E evidence>

Secrets review:
- No endpoints/AK/SK/passwords/kubeconfigs/HAR request bodies committed or printed.
```
