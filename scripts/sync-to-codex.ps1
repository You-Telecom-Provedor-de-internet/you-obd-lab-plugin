param(
    [string]$WorkspaceRoot = "C:\www\you-obd-lab-plugin",
    [string]$CodexPluginRoot = "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab",
    [string]$MarketplacePath = "C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json",
    [string]$CodexAgentsRoot = "C:\Users\haise\.codex\agents",
    [string]$GlobalAgentsMarkdownPath = "C:\Users\haise\.codex\AGENTS.md"
)

$ErrorActionPreference = "Stop"
$pluginName = "you-obd-lab"
$marketplacePluginPath = "./plugins/$pluginName"
$marketplaceCategory = "Developer Tools"
$workspaceAgentsRoot = Join-Path $WorkspaceRoot "custom-agents"
$globalAgentsStart = "<!-- you-obd-lab:start -->"
$globalAgentsEnd = "<!-- you-obd-lab:end -->"
$globalAgentsBlock = @"
<!-- you-obd-lab:start -->
## YOU OBD Lab

When the user explicitly mentions `[@you-obd-lab](plugin://you-obd-lab@haise-local)` or `@you-obd-lab`, default to the plugin's real multi-agent workflow unless the user explicitly asks for single-agent mode.

- Start with `you-orchestrator` to freeze ownership, contracts, risks, and handoffs.
- Spawn only the needed specialists among `youautotester-lab`, `you-android-gateway`, and `you-obd-simulator`.
- Add `you-reviewer` before final sign-off on non-trivial work.
- Prefer `Worktree` for parallel code changes.
- Never let two specialist agents edit the same files at the same time.
- Close each agent with a handoff listing objective, contract, files, risks, and next owner.
<!-- you-obd-lab:end -->
"@

if (-not (Test-Path $WorkspaceRoot)) {
    throw "Workspace nao encontrado: $WorkspaceRoot"
}

New-Item -ItemType Directory -Force -Path $CodexPluginRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarketplacePath) | Out-Null

$excludeDirs = @(".git")
$excludeFiles = @(".codex-sync-log.txt")

$robocopyArgs = @(
    $WorkspaceRoot,
    $CodexPluginRoot,
    "/MIR",
    "/R:1",
    "/W:1",
    "/NFL",
    "/NDL",
    "/NJH",
    "/NJS",
    "/XF"
) + $excludeFiles + @("/XD") + $excludeDirs

& robocopy @robocopyArgs | Out-Null
$exitCode = $LASTEXITCODE
if ($exitCode -ge 8) {
    throw "Falha no robocopy ao sincronizar para o Codex. Codigo: $exitCode"
}

$pluginEntry = [pscustomobject][ordered]@{
    name = $pluginName
    source = [pscustomobject][ordered]@{
        source = "local"
        path = $marketplacePluginPath
    }
    policy = [pscustomobject][ordered]@{
        installation = "AVAILABLE"
        authentication = "ON_INSTALL"
    }
    category = $marketplaceCategory
}

if (Test-Path $MarketplacePath) {
    $marketplace = Get-Content -Raw $MarketplacePath | ConvertFrom-Json
} else {
    $marketplace = [pscustomobject][ordered]@{
        name = "local-marketplace"
        interface = [pscustomobject][ordered]@{
            displayName = "Local Plugins"
        }
        plugins = @()
    }
}

if (-not $marketplace.interface) {
    $marketplace | Add-Member -NotePropertyName interface -NotePropertyValue ([pscustomobject][ordered]@{
        displayName = "Local Plugins"
    })
}

if (-not $marketplace.plugins) {
    $marketplace | Add-Member -NotePropertyName plugins -NotePropertyValue @()
}

$updatedPlugins = @()
$foundPlugin = $false
foreach ($existingPlugin in @($marketplace.plugins)) {
    if ($existingPlugin.name -eq $pluginName) {
        $updatedPlugins += $pluginEntry
        $foundPlugin = $true
        continue
    }

    $updatedPlugins += $existingPlugin
}

if (-not $foundPlugin) {
    $updatedPlugins += $pluginEntry
}

$marketplace.plugins = $updatedPlugins
$marketplace | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 $MarketplacePath

if (Test-Path $workspaceAgentsRoot) {
    New-Item -ItemType Directory -Force -Path $CodexAgentsRoot | Out-Null

    foreach ($agentFile in Get-ChildItem -Path $workspaceAgentsRoot -File -Filter "*.toml") {
        Copy-Item -LiteralPath $agentFile.FullName -Destination (Join-Path $CodexAgentsRoot $agentFile.Name) -Force
    }
}

if (Test-Path $GlobalAgentsMarkdownPath) {
    $globalAgentsText = Get-Content -Raw $GlobalAgentsMarkdownPath
} else {
    $globalAgentsText = ""
}

$pattern = "(?s)" + [regex]::Escape($globalAgentsStart) + ".*?" + [regex]::Escape($globalAgentsEnd)
if ($globalAgentsText -match $pattern) {
    $updatedGlobalAgentsText = [regex]::Replace($globalAgentsText, $pattern, $globalAgentsBlock)
} elseif ([string]::IsNullOrWhiteSpace($globalAgentsText)) {
    $updatedGlobalAgentsText = $globalAgentsBlock
} else {
    $updatedGlobalAgentsText = $globalAgentsText.TrimEnd() + "`r`n`r`n" + $globalAgentsBlock
}

Set-Content -Encoding utf8 $GlobalAgentsMarkdownPath $updatedGlobalAgentsText

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$stamp] sync-to-codex OK -> $CodexPluginRoot" | Out-File -FilePath (Join-Path $WorkspaceRoot ".codex-sync-log.txt") -Encoding utf8 -Append
Write-Host "Plugin sincronizado para o Codex: $CodexPluginRoot"
Write-Host "Plugin registrado no marketplace do Codex: $MarketplacePath"
if (Test-Path $workspaceAgentsRoot) {
    Write-Host "Perfis globais de agentes instalados em: $CodexAgentsRoot"
}
Write-Host "Regra global do Codex atualizada em: $GlobalAgentsMarkdownPath"
