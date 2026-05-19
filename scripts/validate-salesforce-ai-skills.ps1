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
    "AMAZONQ.md",
    "LESSONS.md",
    ".vscode\settings.json",
    "salesforce-ai-skills\SKILL_INDEX.md",
    "salesforce-ai-skills\agent-teams\TEAM_OPERATING_MODEL.md",
    "salesforce-ai-skills\agent-teams\CODEX_AGENT_TEAM_PLAYBOOK.md",
    "salesforce-ai-skills\agent-teams\CLAUDE_AGENT_TEAM_PLAYBOOK.md",
    "salesforce-ai-skills\agent-teams\AMAZONQ_PLAYBOOK.md",
    "salesforce-ai-skills\agent-teams\templates\context-packet.md",
    ".amazonq\rules\salesforce-global-rules.md",
    ".amazonq\rules\salesforce-agent-operating-model.md",
    ".amazonq\rules\salesforce-skill-routing.md",
    ".amazonq\rules\salesforce-safety-gates.md",
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
# Only placeholder examples are allowed here; never add real client, person, org, environment, brand, or project names to this public validation script.
$forbiddenPortableTerms = @(
    "ExampleClientName",
    "ExampleCompanyName",
    "ExampleCustomerName",
    "ExamplePersonName",
    "ExampleEnvironmentAlias",
    "ExampleSandboxAlias",
    "ExampleOrgAlias",
    "ExamplePartnerName",
    "ExampleBrandName",
    "ExampleAirlineName",
    "ExampleHotelBrandName",
    "ExampleProjectName",
    "ExampleProcessName",
    "manifest/package-client-specific-example.xml"
)

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
        if ($text -notmatch "(?m)^name:\s*$([regex]::Escape($dir.Name))\s*$") {
            Add-Error "$($dir.Name)/SKILL.md frontmatter name must match parent directory."
        }

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

        foreach ($term in $forbiddenPortableTerms) {
            if ($text -match [regex]::Escape($term)) {
                Add-Error "$($dir.Name)/SKILL.md contains non-portable term: $term"
            }
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

    foreach ($term in $forbiddenPortableTerms) {
        if ($text -match [regex]::Escape($term)) {
            Add-Error "$doc contains non-portable term: $term"
        }
    }
}

foreach ($removedDoc in @("salesforce-ai-skills\README.md", "salesforce-ai-skills\CLAUDE.md")) {
    if (Test-Path (Join-Path $repo $removedDoc)) {
        Add-Error "Duplicate nested documentation file should not exist: $removedDoc"
    }
}

$vscodeSettingsPath = Join-Path $repo ".vscode\settings.json"
if (Test-Path $vscodeSettingsPath) {
    $settingsText = Get-Content -Raw -LiteralPath $vscodeSettingsPath
    if ($settingsText -notmatch [regex]::Escape('"chat.useAgentSkills"')) {
        Add-Error ".vscode/settings.json must enable chat.useAgentSkills."
    }
    if ($settingsText -notmatch [regex]::Escape('"chat.agentSkillsLocations"')) {
        Add-Error ".vscode/settings.json must define chat.agentSkillsLocations."
    }
    if ($settingsText -notmatch [regex]::Escape('"salesforce-ai-skills/skills"')) {
        Add-Error ".vscode/settings.json must include salesforce-ai-skills/skills for VS Code Copilot discovery."
    }
}

$lessonsPath = Join-Path $repo "LESSONS.md"
if (Test-Path $lessonsPath) {
    $lessonsText = Get-Content -Raw -LiteralPath $lessonsPath
    foreach ($required in @("## Common Mistakes To Avoid", "## Where New Lessons Go")) {
        if ($lessonsText -notmatch [regex]::Escape($required)) {
            Add-Error "LESSONS.md missing required section: $required"
        }
    }
}

$claudeAgents = @("claude-sf-lead.md", "sf-architect.md", "sf-dev.md", "sf-qa.md")
$codexAgents = @("codex-sf-lead.md", "codex-sf-architect.md", "codex-sf-dev.md", "codex-sf-qa.md")

foreach ($agent in $claudeAgents) {
    $path = Join-Path $repo ".claude\agents\$agent"
    if (-not (Test-Path $path)) {
        Add-Error "Missing Claude agent definition: .claude/agents/$agent"
    } else {
        $text = Get-Content -Raw -LiteralPath $path
        if ($text -notmatch [regex]::Escape("LESSONS.md")) {
            Add-Error ".claude/agents/$agent must reference LESSONS.md."
        }
    }
}

foreach ($agent in $codexAgents) {
    $path = Join-Path $repo ".codex\agents\$agent"
    if (-not (Test-Path $path)) {
        Add-Error "Missing Codex agent definition: .codex/agents/$agent"
    } else {
        $text = Get-Content -Raw -LiteralPath $path
        if ($text -notmatch [regex]::Escape("LESSONS.md")) {
            Add-Error ".codex/agents/$agent must reference LESSONS.md."
        }
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

$referenceChecks = @(
    @{ Path = "README.md"; Text = "TEAM_OPERATING_MODEL.md" },
    @{ Path = "README.md"; Text = "AMAZONQ.md" },
    @{ Path = "CODEX.md"; Text = "CODEX_AGENT_TEAM_PLAYBOOK.md" },
    @{ Path = "CLAUDE.md"; Text = "CLAUDE_AGENT_TEAM_PLAYBOOK.md" },
    @{ Path = "AMAZONQ.md"; Text = "AMAZONQ_PLAYBOOK.md" }
)

foreach ($check in $referenceChecks) {
    $path = Join-Path $repo $check.Path
    if (Test-Path $path) {
        $text = Get-Content -Raw -LiteralPath $path
        if ($text -notmatch [regex]::Escape($check.Text)) {
            Add-Error "$($check.Path) must reference $($check.Text)."
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Salesforce AI skills validation failed:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host " - $err" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Salesforce AI skills validation passed." -ForegroundColor Green
