param(
    [string]$SimulatorBaseUrl = "http://192.168.1.11",
    [string]$User = "",
    [string]$Password = "",
    [string]$DeviceId = "",
    [string]$WifiDeviceIp = "192.168.1.99",
    [int]$AdbWifiPort = 5555,
    [switch]$PromoteUsbToWifi = $true,
    [string]$AppPackage = "com.youautocar.client2",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "lib\YouObdLab.Common.ps1")

$apiDefaults = Get-YouObdApiCredentialDefaults
if ([string]::IsNullOrWhiteSpace($User)) { $User = $apiDefaults.User }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $apiDefaults.Password }

$OutputDir = New-YouObdArtifactDir -Prefix "you-obd-lab" -OutputDir $OutputDir

$statusPath = Join-Path $OutputDir "api-status.json"
$diagPath = Join-Path $OutputDir "api-diagnostics.json"
$profilesPath = Join-Path $OutputDir "api-profiles.json"
$devicesPath = Join-Path $OutputDir "adb-devices.txt"
$packageInfoPath = Join-Path $OutputDir "adb-package-info.txt"
$screenPath = Join-Path $OutputDir "phone-screen.png"
$logcatPath = Join-Path $OutputDir "phone-logcat.txt"
$summaryPath = Join-Path $OutputDir "summary.txt"

$deviceConnection = Resolve-YouObdDeviceConnection -DeviceId $DeviceId -AllowWifiFallback -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort -PromoteUsbToWifi:$PromoteUsbToWifi
$resolvedDeviceId = $deviceConnection.Id
$devices = @(Get-YouObdAuthorizedDevices -TryWifiFallback -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort)
($devices | ForEach-Object { $_.Raw }) | Out-File -FilePath $devicesPath -Encoding utf8

$packageInfo = Get-YouObdPackageInfo -DeviceId $resolvedDeviceId -PackageName $AppPackage
$packageInfo.Raw | Out-File -FilePath $packageInfoPath -Encoding utf8

Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusPath -User $User -Password $Password | Out-Null
Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagPath -User $User -Password $Password | Out-Null
Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/profiles" -TargetPath $profilesPath -User $User -Password $Password | Out-Null

Save-YouObdScreenshot -DeviceId $resolvedDeviceId -TargetPath $screenPath
Save-YouObdLogcat -DeviceId $resolvedDeviceId -TargetPath $logcatPath -Lines 500

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
$summary += "ADB device: $resolvedDeviceId"
$summary += "ADB transport: $($deviceConnection.Transport)"
$summary += "ADB strategy: $($deviceConnection.ConnectionStrategy)"
$summary += "ADB Wi-Fi endpoint: $($deviceConnection.WifiEndpoint)"
if (-not [string]::IsNullOrWhiteSpace($deviceConnection.PromotionError)) {
    $summary += "ADB Wi-Fi error: $($deviceConnection.PromotionError)"
}
$summary += "ADB package target: $AppPackage"
if (-not [string]::IsNullOrWhiteSpace($packageInfo.VersionName) -or -not [string]::IsNullOrWhiteSpace($packageInfo.VersionCode)) {
    $summary += "ADB package version: $($packageInfo.VersionName)+$($packageInfo.VersionCode)"
}
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
    $diagScenarioId = Get-YouObdObjectValue -Object $diag -Name "scenario_id" -Default ""
    $diagHealth = Get-YouObdObjectValue -Object $diag -Name "health_score" -Default (Get-YouObdObjectValue -Object $diag -Name "health" -Default "")
    $diagDriveContext = Get-YouObdObjectValue -Object $diag -Name "drive_context" -Default ""
    $diagDtcs = @(Get-YouObdObjectValue -Object $diag -Name "dtcs" -Default @())
    $diagAlerts = @(Get-YouObdObjectValue -Object $diag -Name "alerts" -Default @())

    $summary += "  scenario_id: $diagScenarioId"
    $summary += "  drive_context: $diagDriveContext"
    $summary += "  health_score: $diagHealth"
    $summary += "  alerts_total: $($diagAlerts.Count)"
    $summary += "  dtcs_total: $($diagDtcs.Count)"
} else {
    $summary += "  unable to parse /api/diagnostics"
}
$summary += ""
$summary += "Artifacts:"
$summary += "  $statusPath"
$summary += "  $diagPath"
$summary += "  $profilesPath"
$summary += "  $devicesPath"
$summary += "  $packageInfoPath"
$summary += "  $screenPath"
$summary += "  $logcatPath"

$summary | Out-File -FilePath $summaryPath -Encoding utf8
Write-Host "Snapshot salvo em: $OutputDir"
Write-Host "Resumo: $summaryPath"
