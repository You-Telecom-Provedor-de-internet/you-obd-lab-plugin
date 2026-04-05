param(
    [string]$SimulatorBaseUrl = "http://youobd.local",
    [string]$User = "admin",
    [string]$Password = "obd12345",
    [string]$AppPackage = "com.youautocar.client2",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Comando obrigatorio ausente: $Name"
    }
}

Require-Command "adb"
Require-Command "curl.exe"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputDir = Join-Path $env:TEMP "you-obd-lab-$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$statusPath = Join-Path $OutputDir "api-status.json"
$diagPath = Join-Path $OutputDir "api-diagnostics.json"
$profilesPath = Join-Path $OutputDir "api-profiles.json"
$devicesPath = Join-Path $OutputDir "adb-devices.txt"
$packagesPath = Join-Path $OutputDir "adb-packages.txt"
$screenPath = Join-Path $OutputDir "phone-screen.png"
$logcatPath = Join-Path $OutputDir "phone-logcat.txt"
$summaryPath = Join-Path $OutputDir "summary.txt"

adb devices | Out-File -FilePath $devicesPath -Encoding utf8
$deviceLines = Get-Content $devicesPath | Select-Object -Skip 1 | Where-Object { $_.Trim() }
$authorized = $deviceLines | Where-Object { $_ -match "\sdevice$" }

if (-not $authorized) {
    throw "Nenhum dispositivo ADB autorizado encontrado."
}

adb shell pm list packages | Out-File -FilePath $packagesPath -Encoding utf8

& curl.exe --silent --show-error --digest -u "${User}:${Password}" "$SimulatorBaseUrl/api/status" | Out-File -FilePath $statusPath -Encoding utf8
& curl.exe --silent --show-error --digest -u "${User}:${Password}" "$SimulatorBaseUrl/api/diagnostics" | Out-File -FilePath $diagPath -Encoding utf8
& curl.exe --silent --show-error --digest -u "${User}:${Password}" "$SimulatorBaseUrl/api/profiles" | Out-File -FilePath $profilesPath -Encoding utf8

adb shell screencap -p /sdcard/you_obd_lab_screen.png | Out-Null
adb pull /sdcard/you_obd_lab_screen.png $screenPath | Out-Null
adb logcat -d -t 500 | Out-File -FilePath $logcatPath -Encoding utf8

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
