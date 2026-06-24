# Agent Skills

A collection of installable Agent Skills for AI coding CLIs (Codex, Claude Code, QoderWork, Qoder CLI). Each skill is a self-contained directory with a `SKILL.md` manifest and optional supporting files that are loaded on demand.

## Skills

| Skill | Description | Install path examples |
|-------|-------------|----------------------|
| **[loop-verify](loop-verify/)** | Lightweight outcome/rubric verification-loop coding workflow with E2E scope discovery, long-task progress artifacts, root-cause, persistence, user-flow evidence, and optional external review gates | Codex project skill: `.agents/skills/loop-verify`<br>Claude user skill: `~/.claude/skills/loop-verify` |
| **[md2docx](md2docx/)** | Markdown to Word (DOCX) converter with tables, images, CJK fonts, Mermaid | `~/.claude/skills/md2docx` or project skill directory |
| **[zstack-gsstack-ops](zstack-gsstack-ops/)** | Sanitized GSStack/ZStack lab operations workflow for snapshot recovery, KubeKey replayability, and safe E2E verification | Codex user skill: `~/.agents/skills/zstack-gsstack-ops` |
| **[ssh-reuse](ssh-reuse/)** | Reusable OpenSSH operations with ControlMaster/ControlPersist, ssh-agent key auth, ProxyJump, tmux sessions, resumable transfer, batch commands, server-to-server copy, and tunnels | Codex user skill: `~/.agents/skills/ssh-reuse` |
| **[container-e2e-browser](container-e2e-browser/)** | bb-browser automation patterns for GSStack container module E2E testing: login flow, navigation, form interaction, kubectl verification, error recovery, and a complete end-to-end walkthrough | Codex user skill: `~/.agents/skills/container-e2e-browser` |
| **[container-e2e-full](container-e2e-full/)** | Step-by-step full E2E test flows for all GSStack container modules (workloads, network, storage, RBAC, Ingress, NetworkPolicy, HPA, XSKY CSI, components, observability) with YAML templates, troubleshooting, and functional verification | Codex user skill: `~/.agents/skills/container-e2e-full` |

## Quick Install

Clone this repository first:

```bash
git clone https://github.com/RoshanDev/skills.git
cd skills
```

### Preferred symlink install

Keep this repository as the canonical source and link user/project skill paths to it. This avoids silent drift between root-level, user-level, and project-level copies.

Replace `/path/to/skills` with your local clone path, for example `$HOME/Developer/skills`.

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /path/to/skills/loop-verify ~/.agents/skills/loop-verify
ln -sfn /path/to/skills/loop-verify ~/.codex/skills/loop-verify
ln -sfn /path/to/skills/zstack-gsstack-ops ~/.agents/skills/zstack-gsstack-ops
ln -sfn /path/to/skills/zstack-gsstack-ops ~/.codex/skills/zstack-gsstack-ops
ln -sfn /path/to/skills/ssh-reuse ~/.agents/skills/ssh-reuse
ln -sfn /path/to/skills/ssh-reuse ~/.codex/skills/ssh-reuse
ln -sfn /path/to/skills/container-e2e-browser ~/.agents/skills/container-e2e-browser
ln -sfn /path/to/skills/container-e2e-browser ~/.codex/skills/container-e2e-browser
ln -sfn /path/to/skills/container-e2e-full ~/.agents/skills/container-e2e-full
ln -sfn /path/to/skills/container-e2e-full ~/.codex/skills/container-e2e-full
```

For a project-local skill path, prefer the same symlink unless the project has a genuinely different contract. If a project copy is modified, merge the reusable part back here before relying on it.

### loop-verify

Install the whole skill directory, not only `SKILL.md`. The skill links to `examples.md`, `reference.md`, `e2e-scope-discovery.md`, `user-flow-evidence.md`, `external-review.md`, `long-task-progress.md`, and `outcomes.md`, so copying only the manifest will break progressive disclosure.

#### Codex project skill

From your target project root:

```bash
mkdir -p .agents/skills
ln -sfn /path/to/skills/loop-verify .agents/skills/loop-verify
```

Then invoke it in Codex with:

```text
$loop-verify contract
$loop-verify outcome
$loop-verify e2e-scope
$loop-verify user-flow
$loop-verify execute
$loop-verify review
```

#### Claude Code user skill

```bash
mkdir -p ~/.claude/skills
ln -sfn /path/to/skills/loop-verify ~/.claude/skills/loop-verify
```

#### QoderWork

```bash
mkdir -p ~/.qoderwork/skills
ln -sfn /path/to/skills/loop-verify ~/.qoderwork/skills/loop-verify
```

### zstack-gsstack-ops

The public skill is intentionally sanitized. Keep lab endpoints, private IDs, credentials, and private environment details in ignored local files or project-private documentation only.

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /path/to/skills/zstack-gsstack-ops ~/.agents/skills/zstack-gsstack-ops
ln -sfn /path/to/skills/zstack-gsstack-ops ~/.codex/skills/zstack-gsstack-ops
```

### ssh-reuse

Use this skill for repeated SSH debugging through OpenSSH host aliases, `ssh-agent`, `ControlMaster`, `ControlPersist`, `ProxyJump`, tmux sessions, resumable transfer, batch commands, server-to-server copy, and local tunnels. Keep real server details in `~/.ssh/config` or `~/.ssh/servers.d/*.conf`, not in this public repository.

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /path/to/skills/ssh-reuse ~/.agents/skills/ssh-reuse
ln -sfn /path/to/skills/ssh-reuse ~/.codex/skills/ssh-reuse
```

### container-e2e-browser / container-e2e-full

Both skills are sanitized: image registries use `harbor.example.com` placeholders. Keep the real registry, frontend URL, admin credentials, and kubeconfig in ignored local env files (see `gsstack-local-dev` skill convention).

Install the whole skill directory, not only `SKILL.md`. Each skill links to supporting files for progressive disclosure:

- `container-e2e-browser` references `walkthrough.md` (complete end-to-end example) and `troubleshooting.md` (error recovery)
- `container-e2e-full` references `yaml-templates.md` (all test resource YAMLs), `http-workload-service.md` (known-good HTTP workload + Service for curl verification), `troubleshooting.md` (failure diagnosis), and `xsky-module.md` (XSKY CSI lifecycle testing)

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /path/to/skills/container-e2e-browser ~/.agents/skills/container-e2e-browser
ln -sfn /path/to/skills/container-e2e-browser ~/.codex/skills/container-e2e-browser
ln -sfn /path/to/skills/container-e2e-full ~/.agents/skills/container-e2e-full
ln -sfn /path/to/skills/container-e2e-full ~/.codex/skills/container-e2e-full
```

### md2docx

```bash
cd md2docx
./install.sh
```

## Directory Structure

```text
skills/
├── loop-verify/
│   ├── SKILL.md
│   ├── e2e-scope-discovery.md
│   ├── examples.md
│   ├── external-review.md
│   ├── long-task-progress.md
│   ├── outcomes.md
│   ├── reference.md
│   └── user-flow-evidence.md
├── zstack-gsstack-ops/
│   └── SKILL.md
├── ssh-reuse/
│   ├── SKILL.md
│   ├── config-guide.md
│   ├── commands.md
│   ├── troubleshooting.md
│   └── scripts/
│       └── sshx
├── gsstack-local-dev/
│   └── SKILL.md
├── container-e2e-browser/
│   ├── SKILL.md
│   ├── walkthrough.md
│   └── troubleshooting.md
├── container-e2e-full/
│   ├── SKILL.md
│   ├── http-workload-service.md
│   ├── yaml-templates.md
│   ├── troubleshooting.md
│   └── xsky-module.md
└── md2docx/
    ├── SKILL.md
    ├── converter-template.md
    ├── install.sh / install.ps1
    └── examples/
```

## Design Notes

- Keep the main `SKILL.md` under control and push detailed examples/checklists/rubric patterns into supporting files.
- Do not duplicate the same workflow across multiple tools. Prefer one owner for intent, one owner for evidence, and explicit gates for verification.
- For coding workflows, use acceptance criteria as the contract and tests/checks as executable evidence. Do not let the implementing agent self-certify without command output, AC/rubric coverage, E2E scope evidence when relevant, user-flow evidence when relevant, and persistence status when relevant.
- For long-running work, persist task state outside chat context using progress artifacts such as `progress.md` and `feature_list.json`.
- For feature work, the agent should infer the E2E Impact Map from code/routes/UI/API/tests and ask only for genuinely missing business or environment decisions.
- For UI/browser defects, curl/hooks/Python/direct API checks are diagnosis/setup evidence only. Final PASS needs browser-driven user-path evidence unless explicitly waived.
- External review tools such as language-specific review skills or `open-code-review` are optional advisory/fresh-review inputs. They do not replace loop-verify gates.

## License

MIT - see [LICENSE](LICENSE).
