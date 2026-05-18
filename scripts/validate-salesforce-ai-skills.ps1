param(
    [string]$Root = (Resolve-Path ".")
)

$ErrorActionPreference = "Stop"

$repo = Resolve-Path $Root
$skillsRoot = Join-Path $repo "salesforce-ai-skills\skills"
$docsToCheck = @(
    "README.md",
    "CODEX.md",
    "CLAUDE.md",
    "salesforce-ai-skills\SKILL_INDEX.md",
    ".claude\agents\claude-sf-lead.md",
    ".claude\agents\sf-architect.md",
    ".claude\agents\sf-dev.md",
    ".claude\agents\sf-qa.md",
    ".codex\agents\codex-sf-lead.md",
    ".codex\agents\codex-sf-architect.md",
    ".codex\agents\codex-sf-dev.md",
    ".codex\agents\codex-sf-qa.md"
)

$errors = New-Object System.Collections.Generic.List[string]
$encodingArtifactPattern = [string]::Concat("([", [char]0x00E2, [char]0x00C2, [char]0xFFFD, "])")

function Add-Error {
    param([string]$Message)
    $script:errors.Add($Message) | Out-Null
}

if (-not (Test-Path $skillsRoot)) {
    Add-Error "Missing skills directory: $skillsRoot"
} else {
    $skillDirs = Get-ChildItem $skillsRoot -Directory | Sort-Object Name

    if ($skillDirs.Count -lt 35) {
        Add-Error "Expected at least 35 skill folders, found $($skillDirs.Count)."
    }

    foreach ($dir in $skillDirs) {
        $skillPath = Join-Path $dir.FullName "SKILL.md"
        $mdFiles = Get-ChildItem $dir.FullName -File -Filter "*.md"

        if (-not (Test-Path $skillPath)) {
            Add-Error "Missing SKILL.md in $($dir.Name)."
            continue
        }

        if ($mdFiles.Count -ne 1 -or $mdFiles[0].Name -ne "SKILL.md") {
            Add-Error "Skill $($dir.Name) must contain exactly one markdown file named SKILL.md."
        }

        $text = Get-Content -Raw -LiteralPath $skillPath

        foreach ($required in @("---", "name:", "description:", "## TRIGGER when", "## DO NOT TRIGGER when", "## Cross-skill routing", "## Output")) {
            if ($text -notmatch [regex]::Escape($required)) {
                Add-Error "$($dir.Name)/SKILL.md missing required marker: $required"
            }
        }

        if ($text -match "GUIDE\.md|REFERENCE\.md|_guidelines\.md|agentforce-agent-script-reference\.md") {
            Add-Error "$($dir.Name)/SKILL.md contains stale guide/reference filename."
        }

        if ($text -match $encodingArtifactPattern) {
            Add-Error "$($dir.Name)/SKILL.md contains likely encoding artifact."
        }
    }
}

foreach ($doc in $docsToCheck) {
    $path = Join-Path $repo $doc
    if (-not (Test-Path $path)) {
        Add-Error "Missing documentation file: $doc"
        continue
    }

    $text = Get-Content -Raw -LiteralPath $path
    if ($text -match $encodingArtifactPattern) {
        Add-Error "$doc contains likely encoding artifact."
    }

    if ($text -match "GUIDE\.md|REFERENCE\.md|_guidelines\.md|agentforce-agent-script-reference\.md") {
        Add-Error "$doc contains stale guide/reference filename."
    }
}

foreach ($removedDoc in @("salesforce-ai-skills\README.md", "salesforce-ai-skills\CLAUDE.md")) {
    if (Test-Path (Join-Path $repo $removedDoc)) {
        Add-Error "Duplicate nested documentation file should not exist: $removedDoc"
    }
}

$claudeAgents = @("claude-sf-lead.md", "sf-architect.md", "sf-dev.md", "sf-qa.md")
$codexAgents = @("codex-sf-lead.md", "codex-sf-architect.md", "codex-sf-dev.md", "codex-sf-qa.md")

foreach ($agent in $claudeAgents) {
    $path = Join-Path $repo ".claude\agents\$agent"
    if (-not (Test-Path $path)) {
        Add-Error "Missing Claude agent definition: .claude/agents/$agent"
    }
}

foreach ($agent in $codexAgents) {
    $path = Join-Path $repo ".codex\agents\$agent"
    if (-not (Test-Path $path)) {
        Add-Error "Missing Codex agent definition: .codex/agents/$agent"
    }
}

$claudeLead = Join-Path $repo ".claude\agents\claude-sf-lead.md"
if (Test-Path $claudeLead) {
    $text = Get-Content -Raw -LiteralPath $claudeLead
    foreach ($worker in @("sf-architect", "sf-dev", "sf-qa")) {
        if ($text -notmatch [regex]::Escape($worker)) {
            Add-Error "claude-sf-lead.md does not reference $worker."
        }
    }
}

$codexLead = Join-Path $repo ".codex\agents\codex-sf-lead.md"
if (Test-Path $codexLead) {
    $text = Get-Content -Raw -LiteralPath $codexLead
    foreach ($worker in @("codex-sf-architect", "codex-sf-dev", "codex-sf-qa")) {
        if ($text -notmatch [regex]::Escape($worker)) {
            Add-Error "codex-sf-lead.md does not reference $worker."
        }
    }
}

if (Test-Path $skillsRoot) {
    $skillNames = Get-ChildItem $skillsRoot -Directory | Sort-Object Name | Select-Object -ExpandProperty Name
    $index = Get-Content -Raw -LiteralPath (Join-Path $repo "salesforce-ai-skills\SKILL_INDEX.md")
    $rootReadme = Get-Content -Raw -LiteralPath (Join-Path $repo "README.md")

    if ($rootReadme -notmatch [regex]::Escape("salesforce-ai-skills/skills/")) {
        Add-Error "README.md does not describe the skills folder."
    }

    foreach ($name in $skillNames) {
        if ($index -notmatch [regex]::Escape($name)) {
            Add-Error "SKILL_INDEX.md does not list $name."
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Salesforce AI skills validation failed:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host " - $error" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Salesforce AI skills validation passed." -ForegroundColor Green
