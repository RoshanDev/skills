# SSH Reuse Troubleshooting

## Permission Denied

Check:

```bash
ssh-add -l
sshx config <host>
ssh -vvv <host> true
```

Common causes:

- Wrong `IdentityFile`
- `IdentitiesOnly yes` with the wrong key path
- Passphrase key not loaded into `ssh-agent`
- Public key missing from remote `authorized_keys`
- Remote user mismatch
- Jump host works, target host does not

## Passphrase Prompt Hangs Codex

Codex should not type passphrases. Load the key once:

```bash
ssh-add ~/.ssh/keys/<key>
ssh-add -l
sshx warm <host>
```

Do not write passphrases to shell history, config files, notes, scripts, repository files, or chat.

## Stale ControlMaster Socket

```bash
sshx close <host>
sshx warm <host>
```

If still broken, list sockets and remove only stale sockets you own:

```bash
find ~/.ssh/cm -maxdepth 1 -type s -print
```

## Jump Host Debugging

```bash
sshx run bastion 'hostname && uptime'
sshx run internal-server 'hostname && uptime'
```

If target access fails, check `ProxyJump`, target `HostName`, target user, and whether the bastion can reach the target network.

## Tunnel Not Working

Start the tunnel:

```bash
sshx tunnel <host> 15432 127.0.0.1:5432
sshx tunnel-stop <host> 15432 127.0.0.1:5432
```

Check the local listener:

```bash
ss -ltnp | grep 15432 || netstat -ltnp | grep 15432
```

Check the service from the remote host:

```bash
sshx run <host> 'ss -ltnp | grep 5432 || netstat -ltnp | grep 5432'
```

## Too Many Server Log Entries

ControlMaster reduces SSH TCP connection and authentication entries, but each `sshx run` may still create a session channel. For one long interactive session, use:

```bash
sshx tmux-start <host> codex-debug
sshx tmux-run <host> codex-debug 'hostname && uptime'
sshx tmux-capture <host> codex-debug 80
```

## rsync Missing

`sync-up` and `sync-down` require local `rsync`:

```bash
command -v rsync
```

Use `upload` / `download` for small files if `rsync` is unavailable.

## Remote tmux Missing

```bash
sshx run <host> 'command -v tmux'
```

Install `tmux` on the remote host or use `sshx shell <host>` for a normal interactive session.

## Server-to-Server Copy Fails

`sshx copy <src-host> <src-path> <dst-host> <dst-path>` runs `scp` from the source host. Check from the source host:

```bash
sshx run <src-host> 'ssh <dst-host> true'
```

Do not enable `ForwardAgent` globally. Prefer preconfigured source-host keys or fall back to `sync-down` then `sync-up`.
