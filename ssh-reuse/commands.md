# SSH Reuse Command Patterns

Use quoted remote commands so the local shell does not split pipelines or expansions.

## Health Check

```bash
sshx run <host> 'hostname; uptime; free -m; df -h'
```

## Systemd Service

```bash
sshx run <host> 'systemctl status <service> --no-pager'
sshx run <host> 'journalctl -u <service> -n 100 --no-pager'
```

## Docker

```bash
sshx run <host> 'docker ps'
sshx run <host> 'docker logs --tail=100 <container>'
```

## Kubernetes Node

```bash
sshx run <host> 'crictl ps || docker ps'
sshx run <host> 'systemctl status kubelet --no-pager'
sshx run <host> 'journalctl -u kubelet -n 100 --no-pager'
```

## Upload Diagnostic Script

```bash
sshx upload <host> ./scripts/diag.sh /tmp/diag.sh
sshx run <host> 'chmod +x /tmp/diag.sh && /tmp/diag.sh'
```

If the script becomes reusable, move it into the local repository and document the runbook.

## Resumable Transfer

```bash
sshx sync-up <host> ./large.tar /tmp/
sshx sync-down <host> /var/log/app.log ./app.log
```

These use `rsync -azP --partial` over the same OpenSSH config. Use plain `upload` / `download` for small files when `rsync` is unavailable.

## Server-to-Server Copy

```bash
sshx copy <src-host> /tmp/file <dst-host> /tmp/file
```

The source host must be able to resolve and authenticate to the destination host. Do not enable agent forwarding just to make this work.

## Batch Hosts

Create a local host file:

```text
# comments and blank lines are ignored
host-a
host-b
```

Run one command sequentially:

```bash
sshx batch ./hosts.txt 'hostname && uptime'
```

## Tunnel

```bash
sshx tunnel <host> 15432 127.0.0.1:5432
sshx tunnel-stop <host> 15432 127.0.0.1:5432
```

Check the local listener:

```bash
ss -ltnp | grep 15432 || netstat -ltnp | grep 15432
```

## Remote tmux Session

```bash
sshx tmux-start <host> codex-debug
sshx tmux-run <host> codex-debug 'journalctl -u kubelet -f'
sshx tmux-capture <host> codex-debug 120
```

Use this when ControlMaster reduces login noise but session-open/session-close logs are still too noisy.
