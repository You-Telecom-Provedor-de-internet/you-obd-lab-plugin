param(
    [string]$WorkspaceRoot = "C:\www\you-obd-lab-plugin",
    [string]$CodexPluginRoot = "C:\Users\haise\.codex\.tmp\plugins\plugins\you-obd-lab"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $CodexPluginRoot)) {
    throw "Plugin ativo do Codex nao encontrado: $CodexPluginRoot"
}

New-Item -ItemType Directory -Force -Path $WorkspaceRoot | Out-Null

$excludeDirs = @(".git")
$excludeFiles = @(".codex-sync-log.txt")

$robocopyArgs = @(
    $CodexPluginRoot,
    $WorkspaceRoot,
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
    throw "Falha no robocopy ao sincronizar do Codex para o workspace. Codigo: $exitCode"
}

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$stamp] sync-from-codex OK <- $CodexPluginRoot" | Out-File -FilePath (Join-Path $WorkspaceRoot ".codex-sync-log.txt") -Encoding utf8 -Append
Write-Host "Workspace atualizado a partir do plugin ativo do Codex."
