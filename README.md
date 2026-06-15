# Agent Skills

A collection of installable Agent Skills for AI coding CLIs (Codex, Claude Code, QoderWork, Qoder CLI). Each skill is a self-contained directory with a `SKILL.md` manifest and optional supporting files that are loaded on demand.

## Skills

| Skill | Description | Install path examples |
|-------|-------------|----------------------|
| **[loop-verify](loop-verify/)** | Lightweight outcome/rubric verification-loop coding workflow | Codex project skill: `.agents/skills/loop-verify`<br>Claude user skill: `~/.claude/skills/loop-verify` |
| **[md2docx](md2docx/)** | Markdown to Word (DOCX) converter with tables, images, CJK fonts, Mermaid | `~/.claude/skills/md2docx` or project skill directory |
| **[zstack-gsstack-ops](zstack-gsstack-ops/)** | Sanitized GSStack/ZStack lab operations workflow for snapshot recovery, KubeKey replayability, and secret-safe E2E verification | Codex user skill: `~/.agents/skills/zstack-gsstack-ops` |

## Quick Install

Clone this repository first:

```bash
git clone https://github.com/RoshanDev/skills.git
cd skills
```

### Preferred symlink install

Keep this repository as the canonical source and link user/project skill paths to it. This avoids silent drift between root-level, user-level, and project-level copies.

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /home/roshan/Developer/skills/loop-verify ~/.agents/skills/loop-verify
ln -sfn /home/roshan/Developer/skills/loop-verify ~/.codex/skills/loop-verify
ln -sfn /home/roshan/Developer/skills/zstack-gsstack-ops ~/.agents/skills/zstack-gsstack-ops
ln -sfn /home/roshan/Developer/skills/zstack-gsstack-ops ~/.codex/skills/zstack-gsstack-ops
```

For a project-local skill path, prefer the same symlink unless the project has a genuinely different contract. If a project copy is modified, merge the reusable part back here before relying on it.

### loop-verify

Install the whole skill directory, not only `SKILL.md`. The skill links to `examples.md`, `reference.md`, and `outcomes.md`, so copying only the manifest will break progressive disclosure.

#### Codex project skill

From your target project root:

```bash
mkdir -p .agents/skills
ln -sfn /home/roshan/Developer/skills/loop-verify .agents/skills/loop-verify
```

Then invoke it in Codex with:

```text
$loop-verify contract
$loop-verify outcome
$loop-verify execute
$loop-verify review
```

#### Claude Code user skill

```bash
mkdir -p ~/.claude/skills
ln -sfn /home/roshan/Developer/skills/loop-verify ~/.claude/skills/loop-verify
```

#### QoderWork

```bash
mkdir -p ~/.qoderwork/skills
ln -sfn /home/roshan/Developer/skills/loop-verify ~/.qoderwork/skills/loop-verify
```

### zstack-gsstack-ops

The public skill is intentionally sanitized. Keep lab endpoints, VM IDs, access keys, secret keys, node passwords, registry credentials, and kubeconfigs in ignored local files or project-private documentation only.

```bash
mkdir -p ~/.agents/skills ~/.codex/skills
ln -sfn /home/roshan/Developer/skills/zstack-gsstack-ops ~/.agents/skills/zstack-gsstack-ops
ln -sfn /home/roshan/Developer/skills/zstack-gsstack-ops ~/.codex/skills/zstack-gsstack-ops
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
│   ├── examples.md
│   ├── outcomes.md
│   └── reference.md
├── zstack-gsstack-ops/
│   └── SKILL.md
└── md2docx/
    ├── SKILL.md
    ├── converter-template.md
    ├── install.sh / install.ps1
    └── examples/
```

## Design Notes

- Keep the main `SKILL.md` under control and push detailed examples/checklists/rubric patterns into supporting files.
- Do not duplicate the same workflow across multiple tools. Prefer one owner for intent, one owner for evidence, and explicit gates for verification.
- For coding workflows, use acceptance criteria as the contract and tests/checks as executable evidence. Do not let the implementing agent self-certify without command output, AC/rubric coverage, and persistence status when relevant.

## License

MIT - see [LICENSE](LICENSE).
