# SSH Reuse Config Guide

Keep real server details in local SSH config only. Do not commit host-specific values to this repository.

## Base Config

Create local directories:

```bash
mkdir -p ~/.ssh/cm ~/.ssh/servers.d
chmod 700 ~/.ssh ~/.ssh/cm ~/.ssh/servers.d
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

Add this to `~/.ssh/config`:

```sshconfig
Include ~/.ssh/servers.d/*.conf

Host *
    ServerAliveInterval 30
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPersist 8h
    ControlPath ~/.ssh/cm/%C
    AddKeysToAgent yes
    ForwardAgent no
```

`ControlMaster auto` reuses an existing master connection when possible. `ControlPersist 8h` keeps the master in the background after the last session exits. `ControlPath ~/.ssh/cm/%C` uses a hashed socket name in a user-owned directory.

## Key-Based Host

Put real host entries in files such as `~/.ssh/servers.d/lab.conf`:

```sshconfig
Host lab-server
    HostName <lab-server-ip-or-dns>
    User <remote-user>
    Port 22
    IdentityFile ~/.ssh/keys/lab_ed25519
    IdentitiesOnly yes
```

Use one alias consistently:

```bash
sshx warm lab-server
sshx run lab-server 'hostname && uptime'
```

Do not mix `lab-server`, raw IPs, `user@host`, and ad hoc `-i` flags during one debugging session; that can create separate control sockets.

## Jump Host

```sshconfig
Host bastion
    HostName <bastion-ip-or-dns>
    User <remote-user>
    Port 22
    IdentityFile ~/.ssh/keys/bastion_ed25519
    IdentitiesOnly yes

Host internal-server
    HostName <internal-ip-or-dns>
    User <remote-user>
    Port 22
    IdentityFile ~/.ssh/keys/internal_ed25519
    IdentitiesOnly yes
    ProxyJump bastion
```

Then use only the target alias:

```bash
sshx run internal-server 'hostname && uptime'
```

## Passphrase Keys

Linux or WSL:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/keys/lab_ed25519
ssh-add -l
```

Windows OpenSSH agent:

```powershell
Get-Service ssh-agent
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\keys\lab_ed25519
ssh-add -l
```

Never save passphrases in config files, notes, scripts, repository files, or chat. Codex should not type passwords or passphrases.

Check the current agent state:

```bash
sshx agent-check
```

## Optional Phase Two Tools

`sync-up` and `sync-down` require local `rsync`. `tmux-start`, `tmux-run`, and `tmux-capture` require `tmux` on the remote host. `copy` requires the source host to reach and authenticate to the destination host through its own SSH config or keys.

## Test

```bash
sshx config lab-server
sshx warm lab-server
sshx check lab-server
sshx run lab-server 'hostname && uptime'
```
