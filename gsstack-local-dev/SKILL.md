---
name: gsstack-local-dev
description: Use when the user asks to start, inspect, restart, or fix the local GSStack development stack on this WSL2 machine, including Docker Desktop containers, WSL2 tmux services, nginx proxying, and local health checks.
metadata:
  short-description: Manage the local GSStack dev stack
---

# GSStack Local Dev

Use this skill when the user asks to start, inspect, restart, or fix the local GSStack development stack on this WSL2 machine.

This stack is split across Docker Desktop and WSL2:
- Docker Desktop containers: `ghscheduler-mysql` on host port `3306`, `ghcloud-local-nginx` on host port `18080`.
- WSL2 tmux processes: Go `ks-apiserver` on `19090`, Java `ghcloud/platform.jar` including UUC on `9000`, Java `gh-udm/ghudm.jar` on `8080`, frontend `ghbf-gstack` dev server on `8000`.
- Nginx in Docker Desktop must proxy back to the current WSL IP, not `127.0.0.1`.
- UDM (gh-udm) requires JDK 11+ (not JDK 8); ghcloud still uses JDK 8.
- UDM uses a separate `ghudm` database (not `ghks`); both share the same MySQL instance.
- Frontend proxy `/udm` → `http://127.0.0.1:8080` is configured in `config/config.ts`.
- Local Redis on `127.0.0.1:6379` is shared by ghcloud, UDM, and Go ks-apiserver.

## Command

Run the helper script instead of rediscovering startup commands:

```bash
/home/roshan/.codex/skills/gsstack-local-dev/scripts/gsstack-local-dev.sh status
/home/roshan/.codex/skills/gsstack-local-dev/scripts/gsstack-local-dev.sh start
/home/roshan/.codex/skills/gsstack-local-dev/scripts/gsstack-local-dev.sh restart
/home/roshan/.codex/skills/gsstack-local-dev/scripts/gsstack-local-dev.sh wsl-portproxy
```

Use `restart` when normalizing a broken stack. Use `status` first when the user only asks what is running.
Use `wsl-portproxy` when a Kubernetes Pod, VM, or cloud host must reach services running inside WSL2 through the Windows LAN IP.

## Rules

- Treat `ghscheduler-mysql` as the canonical local MySQL. It contains `ghks`, `ghlmc`, `ghscheduler`, `ghdsp`, and `ghudm`.
- Do not use `ghlmc-mysql` for this stack. If another running container already owns host port `3306`, report it before changing it.
- Source `/home/roshan/Developer/gsstack-container/.env.local` for local secrets and `KUBECONFIG`; do not print or hardcode those values in user-facing output.
- Before starting or restarting Go, validate the configured `KUBECONFIG` with `kubectl --kubeconfig "$KUBECONFIG" version` and any required CRD/API checks. Do not keep using a stale dev-cluster kubeconfig just because the tmux session already exists.
- Java/UUC runs from `/home/roshan/Developer/ghcloud/platform/target/platform.jar`; WSL currently has Java but not Maven.
- UDM runs from `/home/roshan/Developer/gh-udm/target/ghudm-1.0-SNAPSHOT.jar` on port `8080`; requires JDK 11 (`/usr/lib/jvm/java-11-openjdk-amd64`), uses `ghudm` database.
- Frontend runs from `/home/roshan/Developer/ghbf-gstack` with `npm run dev`.
- WSL2 IPs are dynamic. Do not hardcode the current WSL address in configs; rerun `wsl-portproxy` after WSL restarts or `hostname -I` changes.
- For Pod-to-local development integration, expose Windows `0.0.0.0` portproxy entries to the current WSL IP. The common ports are:
  - `8000` frontend
  - `8080` UDM direct
  - `8091`, `8100`, `3100` auxiliary local development services
  - `18080` local nginx gateway
  - `9000` Java/UUC direct
  - `19090` Go `ks-apiserver` direct
- When configuring a live Pod to authenticate against the local UUC stack, prefer the nginx gateway base URL `http://<windows-lan-ip>:18080`. The Go UUC client appends `/uuc/...`, and local nginx maps `/uuc` to Java `/api/uuc`.
- Use the Windows LAN adapter IP from `ipconfig` when calling from cloud hosts or cluster Pods; do not use `127.0.0.1` or the WSL-only Hyper-V adapter address from cluster Pods.
- If `wsl-portproxy` succeeds but the Pod cannot connect, run PowerShell as Administrator and allow inbound TCP for `8000,8080,8091,8100,3100,18080,9000,19090` in Windows Firewall.

## Verification

A healthy stack has:
- `docker context show` = `default`
- `ghscheduler-mysql` published as `0.0.0.0:3306->3306/tcp`
- `ghcloud-local-nginx` published as `0.0.0.0:18080->80/tcp`
- WSL listeners on `8000`, `8080`, `9000`, `19090`
- `http://127.0.0.1:19090/version` returns JSON
- `http://127.0.0.1:9000/api/uuc/system/userLogin/getCaptcha` returns `200`
- `http://127.0.0.1:18080/` returns frontend HTML
- `http://127.0.0.1:18080/api/uuc/system/userLogin/getCaptcha` returns `200`
- `http://127.0.0.1:18080/kapis/` returns `403` or another non-502 backend response for anonymous access
- `netsh interface portproxy show all` includes the Pod-to-local ports needed for the current task, commonly `8000`, `8080`, `8091`, `8100`, `3100`, `18080`, `9000`, and `19090`, pointing at the current WSL IP
- From a cluster Pod, `http://<windows-lan-ip>:18080/uuc/system/userLogin/getCaptcha` returns `200`
