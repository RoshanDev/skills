# md2docx skill installer — Windows (PowerShell)
# Installs SKILL.md and converter-template.md into all detected AI CLI skill directories.
#
# Usage:
#   PowerShell> ./install.ps1

$ErrorActionPreference = 'Stop'

$RepoDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$SrcSkill    = Join-Path $RepoDir 'SKILL.md'
$SrcTemplate = Join-Path $RepoDir 'converter-template.md'

if (-not (Test-Path $SrcSkill) -or -not (Test-Path $SrcTemplate)) {
    Write-Error "SKILL.md or converter-template.md missing in $RepoDir"
    exit 1
}

$Home_ = $env:USERPROFILE

$Targets = @(
    @{ Path = Join-Path $Home_ '.qoderwork\skills\md2docx';  Name = 'QoderWork'    },
    @{ Path = Join-Path $Home_ '.qoder\skills\md2docx';      Name = 'Qoder CLI'    },
    @{ Path = Join-Path $Home_ '.claude\skills\md2docx';     Name = 'Claude Code'  },
    @{ Path = Join-Path $Home_ '.codex\skills\md2docx';      Name = 'Codex'        }
)

$installed = 0
$skipped   = 0

foreach ($t in $Targets) {
    $parent = Split-Path -Parent $t.Path
    if (-not (Test-Path $parent)) {
        Write-Host "  [skip] $($t.Name) — parent directory '$parent' does not exist (CLI not installed?)"
        $skipped++
        continue
    }

    New-Item -ItemType Directory -Force -Path $t.Path | Out-Null
    Copy-Item -Force $SrcSkill    (Join-Path $t.Path 'SKILL.md')
    Copy-Item -Force $SrcTemplate (Join-Path $t.Path 'converter-template.md')
    Write-Host "  [ok]   $($t.Name) -> $($t.Path)"
    $installed++
}

Write-Host ""
Write-Host "Done. Installed: $installed, Skipped: $skipped"
Write-Host "Restart your CLI to pick up the skill."
