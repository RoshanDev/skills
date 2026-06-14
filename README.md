# Agent Skills

A collection of installable Agent Skills for AI coding CLIs (QoderWork, Claude Code, Codex, Qoder CLI). Each skill is a self-contained directory with a `SKILL.md` manifest that the agent loads when invoked.

## Skills

| Skill | Description | Install path |
|-------|-------------|-------------|
| **[loop-verify](loop-verify/)** | Lightweight verification-loop coding workflow | `~/.claude/skills/loop-verify` |
| **[md2docx](md2docx/)** | Markdown to Word (DOCX) converter with tables, images, CJK fonts, Mermaid | `~/.claude/skills/md2docx` |

## Quick Install

### loop-verify

```bash
mkdir -p ~/.claude/skills/loop-verify
cp loop-verify/SKILL.md ~/.claude/skills/loop-verify/

# QoderWork
mkdir -p ~/.qoderwork/skills/loop-verify
cp loop-verify/SKILL.md ~/.qoderwork/skills/loop-verify/
```

### md2docx

```bash
cd md2docx
./install.sh
```

## Directory Structure

```
skills/
+-- loop-verify/
|   +-- SKILL.md
+-- md2docx/
    +-- SKILL.md
    +-- converter-template.md
    +-- install.sh / install.ps1
    +-- examples/
```

## License

MIT - see [LICENSE](LICENSE).
