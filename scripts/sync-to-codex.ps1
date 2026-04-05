param(
    [string]$WorkspaceRoot = "C:\www\you-obd-lab-plugin",
    [string]$CodexPluginRoot = "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $WorkspaceRoot)) {
    throw "Workspace nao encontrado: $WorkspaceRoot"
}

New-Item -ItemType Directory -Force -Path $CodexPluginRoot | Out-Null

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

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$stamp] sync-to-codex OK -> $CodexPluginRoot" | Out-File -FilePath (Join-Path $WorkspaceRoot ".codex-sync-log.txt") -Encoding utf8 -Append
Write-Host "Plugin sincronizado para o Codex: $CodexPluginRoot"
