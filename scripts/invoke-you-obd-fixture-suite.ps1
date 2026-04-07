param(
    [string]$FixtureManifestPath = "",
    [string[]]$FixtureIds = @(),
    [string]$SimulatorBaseUrl = "http://192.168.1.11",
    [string]$User = "",
    [string]$Password = "",
    [string]$DeviceId = "",
    [string]$AppPackage = "com.youautocar.client2",
    [string]$OutputDir = "",
    [switch]$SkipPhone,
    [switch]$KeepAppRunning
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($FixtureIds.Count -gt 0) {
    $normalizedFixtureIds = New-Object System.Collections.Generic.List[string]
    foreach ($fixtureIdEntry in $FixtureIds) {
        foreach ($item in (($fixtureIdEntry -split ',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            $normalizedFixtureIds.Add($item) | Out-Null
        }
    }
    $FixtureIds = @($normalizedFixtureIds.ToArray())
}

if ([string]::IsNullOrWhiteSpace($FixtureManifestPath)) {
    $FixtureManifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) "fixtures\lab-fixtures.json"
}
if (-not (Test-Path -LiteralPath $FixtureManifestPath)) {
    throw "Manifesto de fixtures nao encontrado: $FixtureManifestPath"
}

$manifest = Get-Content -LiteralPath $FixtureManifestPath -Raw | ConvertFrom-Json
$fixtures = @($manifest.fixtures)
if ($FixtureIds.Count -gt 0) {
    $fixtures = @($fixtures | Where-Object { $FixtureIds -contains $_.fixture_id })
}
if ($fixtures.Count -eq 0) {
    throw "Nenhuma fixture selecionada para a suite."
}

$suiteRoot = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $env:TEMP ("you-obd-suite-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
} else {
    $OutputDir
}
New-Item -ItemType Directory -Force -Path $suiteRoot | Out-Null

$results = New-Object System.Collections.Generic.List[object]
foreach ($fixture in $fixtures) {
    $fixtureOutput = Join-Path $suiteRoot $fixture.fixture_id
    New-Item -ItemType Directory -Force -Path $fixtureOutput | Out-Null

    $args = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "invoke-you-obd-bench-validation.ps1"),
        "-FixtureId", [string]$fixture.fixture_id,
        "-FixtureManifestPath", $FixtureManifestPath,
        "-SimulatorBaseUrl", $SimulatorBaseUrl,
        "-AppPackage", $AppPackage,
        "-OutputDir", $fixtureOutput
    )
    if (-not [string]::IsNullOrWhiteSpace($User)) { $args += @("-User", $User) }
    if (-not [string]::IsNullOrWhiteSpace($Password)) { $args += @("-Password", $Password) }
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) { $args += @("-DeviceId", $DeviceId) }
    if ($SkipPhone) { $args += "-SkipPhone" }
    if ($KeepAppRunning) { $args += "-KeepAppRunning" }

    $reportPath = Join-Path $fixtureOutput "report.json"
    try {
        & powershell.exe @args | Out-Host
        $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $results.Add([ordered]@{
            fixture_id = $fixture.fixture_id
            verdict = $report.verdict
            failure_category = $report.failure_category
            report = $reportPath
        }) | Out-Null
    }
    catch {
        if (Test-Path -LiteralPath $reportPath) {
            try {
                $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
                $results.Add([ordered]@{
                    fixture_id = $fixture.fixture_id
                    verdict = $report.verdict
                    failure_category = $report.failure_category
                    report = $reportPath
                }) | Out-Null
                continue
            }
            catch {
            }
        }
        $results.Add([ordered]@{
            fixture_id = $fixture.fixture_id
            verdict = "ERROR"
            failure_category = $_.Exception.Message
            report = $reportPath
        }) | Out-Null
    }
}

$summaryJson = Join-Path $suiteRoot "suite-summary.json"
$summaryMd = Join-Path $suiteRoot "suite-summary.md"

@($results.ToArray()) | ConvertTo-Json -Depth 10 | Out-File -FilePath $summaryJson -Encoding utf8

$lines = @()
$lines += "# YOU OBD Lab fixture suite"
$lines += ""
$lines += "- Manifest: $FixtureManifestPath"
$lines += "- Generated at: $(Get-Date -Format s)"
$lines += ""
foreach ($item in $results) {
    $lines += "- $($item.fixture_id): $($item.verdict) | $($item.failure_category)"
}
$lines += ""
$lines += "## Reports"
$lines += ""
foreach ($item in $results) {
    $lines += "- $($item.fixture_id): $($item.report)"
}
$lines | Out-File -FilePath $summaryMd -Encoding utf8

Write-Host "Suite concluida."
Write-Host "Resumo: $summaryMd"
