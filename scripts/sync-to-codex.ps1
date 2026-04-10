param(
    [string]$WorkspaceRoot = "C:\www\you-obd-lab-plugin",
    [string]$CodexCompatPluginRoot = "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab",
    [string]$TmpMarketplacePath = "C:\Users\haise\.codex\.tmp\plugins\.agents\plugins\marketplace.json",
    [string]$CodexPluginHome = "C:\Users\haise\.codex\plugins\you-obd-lab",
    [string]$CodexCachePluginRoot = "C:\Users\haise\.codex\plugins\cache\haise-local\you-obd-lab\local",
    [string]$LocalMarketplacePath = "C:\Users\haise\.agents\plugins\marketplace.json",
    [string]$CodexAgentsRoot = "C:\Users\haise\.codex\agents",
    [string]$GlobalAgentsMarkdownPath = "C:\Users\haise\.codex\AGENTS.md"
)

$ErrorActionPreference = "Stop"
$pluginName = "you-obd-lab"
$workspaceAgentsRoot = Join-Path $WorkspaceRoot "custom-agents"
$excludeDirs = @(".git", "tmp")
$excludeFiles = @(
    ".codex-sync-log.txt",
    "local-api-credentials.backup-*.json"
)

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

function Write-Step {
    param([string]$Message)
    Write-Host "[you-obd-lab] $Message"
}

function Invoke-YouObdMirror {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null

    $robocopyArgs = @(
        $Source,
        $Destination,
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
        throw "Falha no robocopy ao sincronizar para '$Destination'. Codigo: $exitCode"
    }
}

function Set-YouObdMarketplaceEntry {
    param(
        [string]$MarketplacePath,
        [string]$PluginRelativePath,
        [string]$MarketplaceName,
        [string]$MarketplaceDisplayName
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $MarketplacePath) | Out-Null

    $pluginEntry = [pscustomobject][ordered]@{
        name = $pluginName
        source = [pscustomobject][ordered]@{
            source = "local"
            path = $PluginRelativePath
        }
        policy = [pscustomobject][ordered]@{
            installation = "AVAILABLE"
            authentication = "ON_INSTALL"
        }
        category = "Developer Tools"
    }

    if (Test-Path $MarketplacePath) {
        $marketplace = Get-Content -Raw $MarketplacePath | ConvertFrom-Json
    } else {
        $marketplace = [pscustomobject][ordered]@{
            name = $MarketplaceName
            interface = [pscustomobject][ordered]@{
                displayName = $MarketplaceDisplayName
            }
            plugins = @()
        }
    }

    if (-not $marketplace.interface) {
        $marketplace | Add-Member -NotePropertyName interface -NotePropertyValue ([pscustomobject][ordered]@{
            displayName = $MarketplaceDisplayName
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
        } else {
            $updatedPlugins += $existingPlugin
        }
    }

    if (-not $foundPlugin) {
        $updatedPlugins += $pluginEntry
    }

    $marketplace.plugins = $updatedPlugins
    $marketplace | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 $MarketplacePath
}

if (-not (Test-Path $WorkspaceRoot)) {
    throw "Workspace nao encontrado: $WorkspaceRoot"
}

Write-Step "Workspace root: $WorkspaceRoot"
Write-Step "Syncing compatibility tree: $CodexCompatPluginRoot"
Invoke-YouObdMirror -Source $WorkspaceRoot -Destination $CodexCompatPluginRoot

Write-Step "Syncing plugin home: $CodexPluginHome"
Invoke-YouObdMirror -Source $WorkspaceRoot -Destination $CodexPluginHome

Write-Step "Syncing active cache: $CodexCachePluginRoot"
Invoke-YouObdMirror -Source $WorkspaceRoot -Destination $CodexCachePluginRoot

Set-YouObdMarketplaceEntry `
    -MarketplacePath $TmpMarketplacePath `
    -PluginRelativePath "./plugins/$pluginName" `
    -MarketplaceName "openai-curated" `
    -MarketplaceDisplayName "Codex official"

Set-YouObdMarketplaceEntry `
    -MarketplacePath $LocalMarketplacePath `
    -PluginRelativePath "./.codex/plugins/$pluginName" `
    -MarketplaceName "haise-local" `
    -MarketplaceDisplayName "Plugins Locais"

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
"[$stamp] sync-to-codex OK -> compat=$CodexCompatPluginRoot ; home=$CodexPluginHome ; cache=$CodexCachePluginRoot" |
    Out-File -FilePath (Join-Path $WorkspaceRoot ".codex-sync-log.txt") -Encoding utf8 -Append

Write-Step "Plugin sincronizado para a arvore de compatibilidade: $CodexCompatPluginRoot"
Write-Step "Plugin sincronizado para o plugin home: $CodexPluginHome"
Write-Step "Plugin sincronizado para o cache ativo: $CodexCachePluginRoot"
Write-Step "Marketplace de compatibilidade atualizado: $TmpMarketplacePath"
Write-Step "Marketplace local atualizado: $LocalMarketplacePath"
if (Test-Path $workspaceAgentsRoot) {
    Write-Step "Perfis globais de agentes instalados em: $CodexAgentsRoot"
}
Write-Step "Regra global do Codex atualizada em: $GlobalAgentsMarkdownPath"
