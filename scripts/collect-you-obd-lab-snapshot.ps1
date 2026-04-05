param(
    [string]$SimulatorBaseUrl = "http://192.168.1.11",
    [string]$User = "admin",
    [string]$Password = "obd12345",
    [string]$AppPackage = "com.youautocar.client2",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "lib\YouObdLab.Common.ps1")

$OutputDir = New-YouObdArtifactDir -Prefix "you-obd-lab" -OutputDir $OutputDir

$statusPath = Join-Path $OutputDir "api-status.json"
$diagPath = Join-Path $OutputDir "api-diagnostics.json"
$profilesPath = Join-Path $OutputDir "api-profiles.json"
$devicesPath = Join-Path $OutputDir "adb-devices.txt"
$packagesPath = Join-Path $OutputDir "adb-packages.txt"
$screenPath = Join-Path $OutputDir "phone-screen.png"
$logcatPath = Join-Path $OutputDir "phone-logcat.txt"
$summaryPath = Join-Path $OutputDir "summary.txt"

$devices = @(Get-YouObdAuthorizedDevices)
($devices | ForEach-Object { $_.Raw }) | Out-File -FilePath $devicesPath -Encoding utf8
$authorized = $devices

if (-not $authorized) {
    throw "Nenhum dispositivo ADB autorizado encontrado."
}

Invoke-YouObdAdb -DeviceId $authorized[0].Id -Arguments @("shell", "pm", "list", "packages") | Out-File -FilePath $packagesPath -Encoding utf8

Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusPath -User $User -Password $Password | Out-Null
Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagPath -User $User -Password $Password | Out-Null
Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/profiles" -TargetPath $profilesPath -User $User -Password $Password | Out-Null

Save-YouObdScreenshot -DeviceId $authorized[0].Id -TargetPath $screenPath
Save-YouObdLogcat -DeviceId $authorized[0].Id -TargetPath $logcatPath -Lines 500

$statusJson = Get-Content $statusPath -Raw
$diagJson = Get-Content $diagPath -Raw

$status = $null
$diag = $null
try { $status = $statusJson | ConvertFrom-Json } catch {}
try { $diag = $diagJson | ConvertFrom-Json } catch {}

$summary = @()
$summary += "YOU OBD Lab snapshot"
$summary += "Timestamp: $(Get-Date -Format s)"
$summary += "Simulator: $SimulatorBaseUrl"
$summary += "ADB device: $($authorized[0].Id)"
$summary += "ADB package target: $AppPackage"
$summary += ""
$summary += "API status:"
if ($status) {
    $summary += "  protocol: $($status.protocol)"
    $summary += "  profile_id: $($status.profile_id)"
    $summary += "  rpm: $($status.rpm)"
    $summary += "  speed: $($status.speed)"
    $summary += "  vin: $($status.vin)"
} else {
    $summary += "  unable to parse /api/status"
}
$summary += ""
$summary += "Diagnostics:"
if ($diag) {
    $summary += "  active_scenario: $($diag.active_scenario)"
    $summary += "  health: $($diag.health)"
    $summary += "  alert: $($diag.primary_alert)"
    $summary += "  dtcs_total: $($diag.dtcs_total)"
} else {
    $summary += "  unable to parse /api/diagnostics"
}
$summary += ""
$summary += "Artifacts:"
$summary += "  $statusPath"
$summary += "  $diagPath"
$summary += "  $profilesPath"
$summary += "  $devicesPath"
$summary += "  $packagesPath"
$summary += "  $screenPath"
$summary += "  $logcatPath"

$summary | Out-File -FilePath $summaryPath -Encoding utf8
Write-Host "Snapshot salvo em: $OutputDir"
Write-Host "Resumo: $summaryPath"
