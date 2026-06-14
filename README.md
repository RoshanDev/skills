# Agent Skills

A collection of installable Agent Skills for AI coding CLIs (Codex, Claude Code, QoderWork, Qoder CLI). Each skill is a self-contained directory with a `SKILL.md` manifest and optional supporting files that are loaded on demand.

## Skills

| Skill | Description | Install path examples |
|-------|-------------|----------------------|
| **[loop-verify](loop-verify/)** | Lightweight verification-loop coding workflow | Codex project skill: `.agents/skills/loop-verify`<br>Claude user skill: `~/.claude/skills/loop-verify` |
| **[md2docx](md2docx/)** | Markdown to Word (DOCX) converter with tables, images, CJK fonts, Mermaid | `~/.claude/skills/md2docx` or project skill directory |

## Quick Install

Clone this repository first:

```bash
git clone https://github.com/RoshanDev/skills.git
cd skills
```

### loop-verify

Install the whole skill directory, not only `SKILL.md`. The skill links to `examples.md` and `reference.md`, so copying only the manifest will break progressive disclosure.

#### Codex project skill

From your target project root:

```bash
mkdir -p .agents/skills
cp -R /path/to/skills/loop-verify .agents/skills/loop-verify
```

Then invoke it in Codex with:

```text
$loop-verify contract
$loop-verify execute
$loop-verify review
```

#### Claude Code user skill

```bash
mkdir -p ~/.claude/skills
cp -R loop-verify ~/.claude/skills/loop-verify
```

#### QoderWork

```bash
mkdir -p ~/.qoderwork/skills
cp -R loop-verify ~/.qoderwork/skills/loop-verify
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
│   └── reference.md
└── md2docx/
    ├── SKILL.md
    ├── converter-template.md
    ├── install.sh / install.ps1
    └── examples/
```

## Design Notes

- Keep the main `SKILL.md` under control and push detailed examples/checklists into supporting files.
- Do not duplicate the same workflow across multiple tools. Prefer one owner for intent, one owner for evidence, and explicit gates for verification.
- For coding workflows, use acceptance criteria as the contract and tests/checks as executable evidence. Do not let the implementing agent self-certify without command output and AC coverage.

## License

MIT - see [LICENSE](LICENSE).
