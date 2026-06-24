---
name: ssh-reuse
description: Use for safe reusable SSH operations with OpenSSH ControlMaster and ControlPersist, ssh-agent key auth, ProxyJump jump hosts, remote commands, tmux sessions, resumable rsync transfer, server-to-server copy, batch host commands, tunnels, and SSH debugging. Prefer sshx wrappers over raw ssh, scp, or rsync. Never store secrets in repo.
---

# SSH Reuse

Use OpenSSH host aliases as the source of truth and run repeat remote work through `scripts/sshx`.

## Core Rules

- Use host aliases from `~/.ssh/config` or `~/.ssh/servers.d/*.conf`; do not mix aliases with raw `user@ip` commands.
- Prefer `scripts/sshx` over raw `ssh`, `scp`, or `rsync`.
- Reuse connections through `ControlMaster auto`, `ControlPersist`, and `ControlPath ~/.ssh/cm/%C`.
- Use `ssh-agent` and `ssh-add` for passphrase-protected keys.
- Never ask the user to paste private keys, key passphrases, passwords, kubeconfigs, cookies, or tokens into chat.
- Never commit real server IPs, usernames, passwords, private keys, kubeconfigs, cookies, tokens, or host-specific secrets.
- Run `sshx warm <host>` before repeated debugging commands.
- Use `ProxyJump` in SSH config for jump hosts.
- For noninteractive commands, fail fast instead of waiting for password or passphrase prompts.
- If remote commands change durable state, record the source-of-truth update or runbook.

## Quick Commands

```bash
ssh-reuse/scripts/sshx list
ssh-reuse/scripts/sshx config <host>
ssh-reuse/scripts/sshx warm <host>
ssh-reuse/scripts/sshx check <host>
ssh-reuse/scripts/sshx run <host> 'hostname && uptime'
ssh-reuse/scripts/sshx shell <host>
ssh-reuse/scripts/sshx upload <host> ./local.file /tmp/
ssh-reuse/scripts/sshx download <host> /var/log/app.log ./app.log
ssh-reuse/scripts/sshx sync-up <host> ./large.tar /tmp/
ssh-reuse/scripts/sshx sync-down <host> /var/log/app.log ./app.log
ssh-reuse/scripts/sshx copy <src-host> /tmp/file <dst-host> /tmp/file
ssh-reuse/scripts/sshx batch ./hosts.txt 'hostname && uptime'
ssh-reuse/scripts/sshx tunnel <host> 15432 127.0.0.1:5432
ssh-reuse/scripts/sshx tunnel-stop <host> 15432 127.0.0.1:5432
ssh-reuse/scripts/sshx tmux-start <host> codex-debug
ssh-reuse/scripts/sshx tmux-run <host> codex-debug 'journalctl -u kubelet -f'
ssh-reuse/scripts/sshx tmux-capture <host> codex-debug 120
ssh-reuse/scripts/sshx agent-check
ssh-reuse/scripts/sshx close <host>
```

If `sshx` is on `PATH`, use `sshx ...` directly.

## Before Use

```text
[ ] Host alias exists in ~/.ssh/config or ~/.ssh/servers.d/*.conf
[ ] ~/.ssh/cm exists and is chmod 700
[ ] Private key exists and is chmod 600
[ ] Passphrase key is loaded with ssh-add
[ ] sshx config <host> shows the intended HostName/User/IdentityFile/ProxyJump
[ ] sshx warm <host> succeeds
[ ] sshx run <host> 'true' succeeds
```

## References

- Read `config-guide.md` when setting up local SSH config, ssh-agent, or ProxyJump.
- Read `commands.md` for common remote debugging command patterns.
- Read `troubleshooting.md` when auth, stale socket, jump host, or tunnel issues appear.

## Failure Handling

- `Permission denied`: run `ssh-add -l`, verify `IdentityFile`, `IdentitiesOnly`, remote user, and remote `authorized_keys`.
- `Host key verification failed`: do not disable checking globally; ask whether this is a new or rebuilt host.
- Missing or stale control socket: run `sshx close <host>`, then `sshx warm <host>`.
- Jump host failure: verify the bastion alias first, then the target alias.
- Large transfer: use `sync-up` or `sync-down`; it requires local `rsync` and reuses SSH config.
- Server-to-server copy: use `copy` only when the source host can resolve and authenticate to the destination host.
- One long remote session: use `tmux-start`, `tmux-run`, and `tmux-capture`; it requires remote `tmux`.

## Session Noise

ControlMaster reduces TCP connection and authentication noise. It can still open a new SSH session channel for each `sshx run` command. If server logs must show one long interactive session, use `tmux-start` once and then `tmux-run` / `tmux-capture`.
