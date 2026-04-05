param(
    [string]$SimulatorBaseUrl = "http://192.168.1.11",
    [string]$User = "admin",
    [string]$Password = "obd12345",
    [string]$DeviceId = "",
    [string]$AppPackage = "com.youautocar.client2",
    [string]$ProfileId = "",
    [int]$ProtocolId = -1,
    [int]$ModeId = -1,
    [string]$ScenarioId = "",
    [string[]]$DtcCodes = @(),
    [switch]$ClearDtcs,
    [switch]$SkipSimulatorWrites,
    [switch]$SkipPhone,
    [switch]$SkipAppLaunch,
    [switch]$KeepAppRunning,
    [switch]$DryRun,
    [int]$WarmupSeconds = 10,
    [int]$LogcatLines = 1000,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "lib\YouObdLab.Common.ps1")

$outputDir = New-YouObdArtifactDir -Prefix "you-obd-bench" -OutputDir $OutputDir
$reportJsonPath = Join-Path $outputDir "report.json"
$reportMdPath = Join-Path $outputDir "report.md"
$adbDevicesPath = Join-Path $outputDir "adb-devices.txt"
$devicePropsPath = Join-Path $outputDir "device-props.txt"
$packageInfoPath = Join-Path $outputDir "package-info.txt"
$statusBeforePath = Join-Path $outputDir "api-status-before.json"
$statusAfterPath = Join-Path $outputDir "api-status-after.json"
$diagBeforePath = Join-Path $outputDir "api-diagnostics-before.json"
$diagAfterPath = Join-Path $outputDir "api-diagnostics-after.json"
$dtcsBeforePath = Join-Path $outputDir "api-dtcs-before.json"
$dtcsAfterPath = Join-Path $outputDir "api-dtcs-after.json"
$pingPath = Join-Path $outputDir "ping-json.json"
$logcatPath = Join-Path $outputDir "phone-logcat.txt"
$filteredLogPath = Join-Path $outputDir "phone-logcat-filtered.txt"
$screenPath = Join-Path $outputDir "phone-screen.png"

$successPatterns = @(
    "ECU_READY",
    "Auto-conexao bem-sucedida",
    "Auto-conexão bem-sucedida",
    "Ligado à ECU",
    "Ligado a ECU",
    "AUTO, ISO 9141-2",
    "AUTO, KWP2000",
    "KWP Fast",
    "OBDLink MX+",
    "41 00",
    "49 02"
)
$errorPatterns = @(
    "ECU_NOT_FOUND",
    "UNABLE TO CONNECT",
    "CAN ERROR",
    "BUS INIT",
    "FB ERROR",
    "Nao conectado",
    "Não conectado",
    "incapaz de conectar ao veiculo",
    "incapaz de conectar ao veículo"
)

function Convert-ToPrettyJsonString {
    param($Value)
    return ($Value | ConvertTo-Json -Depth 20)
}

function Write-ReportArtifacts {
    param(
        [hashtable]$Report,
        [string]$JsonPath,
        [string]$MarkdownPath
    )

    ($Report | ConvertTo-Json -Depth 20) | Out-File -FilePath $JsonPath -Encoding utf8

    $lines = @()
    $lines += "# YOU OBD Lab bench validation"
    $lines += ""
    $lines += "- Timestamp: $($Report.timestamp)"
    $lines += "- Verdict: $($Report.verdict)"
    $lines += "- Simulator: $($Report.setup.simulator_base_url)"
    $lines += "- App package: $($Report.setup.app_package)"
    $lines += "- Device: $($Report.setup.device_id)"
    $lines += ""
    $lines += "## Requested setup"
    $lines += ""
    $lines += "- profile_id: $($Report.setup.requested.profile_id)"
    $lines += "- protocol_id: $($Report.setup.requested.protocol_id)"
    $lines += "- mode_id: $($Report.setup.requested.mode_id)"
    $lines += "- scenario_id: $($Report.setup.requested.scenario_id)"
    $lines += "- dtcs: $(([string[]]$Report.setup.requested.dtcs) -join ', ')"
    $lines += ""
    $lines += "## Oracle before"
    $lines += ""
    $lines += "- protocol: $($Report.oracle.before.protocol)"
    $lines += "- profile_id: $($Report.oracle.before.profile_id)"
    $lines += "- sim_mode: $($Report.oracle.before.sim_mode)"
    $lines += "- dtcs_total: $($Report.oracle.before.dtcs_total)"
    $lines += ""
    $lines += "## Oracle after"
    $lines += ""
    $lines += "- protocol: $($Report.oracle.after.protocol)"
    $lines += "- profile_id: $($Report.oracle.after.profile_id)"
    $lines += "- sim_mode: $($Report.oracle.after.sim_mode)"
    $lines += "- dtcs_total: $($Report.oracle.after.dtcs_total)"
    $lines += "- active_scenario: $($Report.oracle.after.active_scenario)"
    $lines += ""
    $lines += "## Android"
    $lines += ""
    $lines += "- app_installed: $($Report.android.app_installed)"
    $lines += "- launched: $($Report.android.launched)"
    $lines += "- version_name: $($Report.android.version_name)"
    $lines += "- version_code: $($Report.android.version_code)"
    $lines += ""
    $lines += "## Logcat signals"
    $lines += ""
    $lines += "- success_matches: $($Report.logcat.success_count)"
    $lines += "- error_matches: $($Report.logcat.error_count)"
    $lines += ""
    if ($Report.logcat.success_lines.Count -gt 0) {
        $lines += "### Success lines"
        $lines += ""
        foreach ($line in $Report.logcat.success_lines) {
            $lines += "- $line"
        }
        $lines += ""
    }
    if ($Report.logcat.error_lines.Count -gt 0) {
        $lines += "### Error lines"
        $lines += ""
        foreach ($line in $Report.logcat.error_lines) {
            $lines += "- $line"
        }
        $lines += ""
    }
    $lines += "## Artifacts"
    $lines += ""
    foreach ($artifact in $Report.artifacts) {
        $lines += "- $artifact"
    }

    $lines | Out-File -FilePath $MarkdownPath -Encoding utf8
}

$report = [ordered]@{
    timestamp = (Get-Date -Format s)
    verdict = "UNKNOWN"
    setup = [ordered]@{
        simulator_base_url = $SimulatorBaseUrl
        app_package = $AppPackage
        device_id = ""
        requested = [ordered]@{
            profile_id = $ProfileId
            protocol_id = $ProtocolId
            mode_id = $ModeId
            scenario_id = $ScenarioId
            dtcs = @($DtcCodes)
        }
    }
    oracle = [ordered]@{
        before = [ordered]@{
            protocol = ""
            profile_id = ""
            sim_mode = ""
            dtcs_total = ""
            active_scenario = ""
            dtcs = @()
        }
        after = [ordered]@{
            protocol = ""
            profile_id = ""
            sim_mode = ""
            dtcs_total = ""
            active_scenario = ""
            dtcs = @()
        }
    }
    android = [ordered]@{
        app_installed = $false
        launched = $false
        version_name = ""
        version_code = ""
    }
    logcat = [ordered]@{
        success_count = 0
        error_count = 0
        success_lines = @()
        error_lines = @()
    }
    artifacts = @(
        $reportJsonPath,
        $reportMdPath,
        $pingPath,
        $statusBeforePath,
        $diagBeforePath,
        $dtcsBeforePath,
        $statusAfterPath,
        $diagAfterPath,
        $dtcsAfterPath
    )
}

if ($DryRun) {
    $report.verdict = "DRY_RUN"
    $report.note = "Nenhuma chamada de API, ADB ou app foi executada."
    Write-ReportArtifacts -Report $report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath
    Write-Host "Dry-run concluido."
    Write-Host "Relatorio: $reportMdPath"
    return
}

try {
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/ping-json" -TargetPath $pingPath -AllowUnauthenticated | Out-Null

    if (-not $SkipSimulatorWrites) {
        if ($ClearDtcs) {
            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs/clear" -Method "POST" -BodyJson "{}" -User $User -Password $Password | Out-Null
        }
        if (-not [string]::IsNullOrWhiteSpace($ProfileId)) {
            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/profile" -Method "POST" -BodyJson (@{ id = $ProfileId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
        }
        if ($ProtocolId -ge 0) {
            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/protocol" -Method "POST" -BodyJson (@{ protocol = $ProtocolId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
        }
        if ($ModeId -ge 0) {
            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/mode" -Method "POST" -BodyJson (@{ mode = $ModeId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
        }
        if ($PSBoundParameters.ContainsKey("ScenarioId")) {
            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/scenario" -Method "POST" -BodyJson (@{ id = $ScenarioId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
        }
        foreach ($dtc in $DtcCodes) {
            if (-not [string]::IsNullOrWhiteSpace($dtc)) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs/add" -Method "POST" -BodyJson (@{ code = $dtc } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
            }
        }
    }

    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusBeforePath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagBeforePath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs" -TargetPath $dtcsBeforePath -User $User -Password $Password | Out-Null

    $statusBefore = Get-Content -LiteralPath $statusBeforePath -Raw | ConvertFrom-Json
    $diagBefore = Get-Content -LiteralPath $diagBeforePath -Raw | ConvertFrom-Json
    $dtcsBefore = Get-Content -LiteralPath $dtcsBeforePath -Raw | ConvertFrom-Json

    $report.oracle.before = [ordered]@{
        protocol = $statusBefore.protocol
        profile_id = $statusBefore.profile_id
        sim_mode = $statusBefore.sim_mode
        dtcs_total = $diagBefore.dtcs_total
        active_scenario = $diagBefore.active_scenario
        dtcs = @($dtcsBefore.dtcs)
    }

    if (-not $SkipPhone) {
        $resolvedDeviceId = Resolve-YouObdDeviceId -DeviceId $DeviceId
        $report.setup.device_id = $resolvedDeviceId

        @(Get-YouObdAuthorizedDevices) | ForEach-Object { $_.Raw } | Out-File -FilePath $adbDevicesPath -Encoding utf8
        $report.artifacts += @($adbDevicesPath, $devicePropsPath, $packageInfoPath, $screenPath, $logcatPath, $filteredLogPath)

        Save-YouObdDeviceProps -DeviceId $resolvedDeviceId -TargetPath $devicePropsPath
        $packageInfo = Get-YouObdPackageInfo -DeviceId $resolvedDeviceId -PackageName $AppPackage
        $packageInfo.Raw | Out-File -FilePath $packageInfoPath -Encoding utf8
        $report.android.version_name = $packageInfo.VersionName
        $report.android.version_code = $packageInfo.VersionCode
        $report.android.app_installed = -not [string]::IsNullOrWhiteSpace($packageInfo.VersionName) -or -not [string]::IsNullOrWhiteSpace($packageInfo.VersionCode)

        if (-not $report.android.app_installed) {
            throw "O pacote $AppPackage nao parece instalado no dispositivo $resolvedDeviceId."
        }

        Clear-YouObdLogcat -DeviceId $resolvedDeviceId
        Stop-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage

        if (-not $SkipAppLaunch) {
            Start-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage
            $report.android.launched = $true
        }

        if (-not $DryRun) {
            Start-Sleep -Seconds $WarmupSeconds
        }

        Save-YouObdScreenshot -DeviceId $resolvedDeviceId -TargetPath $screenPath
        Save-YouObdLogcat -DeviceId $resolvedDeviceId -TargetPath $logcatPath -Lines $LogcatLines

        if (-not $KeepAppRunning) {
            Stop-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage
        }
    }

    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusAfterPath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagAfterPath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs" -TargetPath $dtcsAfterPath -User $User -Password $Password | Out-Null

    $statusAfter = Get-Content -LiteralPath $statusAfterPath -Raw | ConvertFrom-Json
    $diagAfter = Get-Content -LiteralPath $diagAfterPath -Raw | ConvertFrom-Json
    $dtcsAfter = Get-Content -LiteralPath $dtcsAfterPath -Raw | ConvertFrom-Json

    $report.oracle.after = [ordered]@{
        protocol = $statusAfter.protocol
        profile_id = $statusAfter.profile_id
        sim_mode = $statusAfter.sim_mode
        dtcs_total = $diagAfter.dtcs_total
        active_scenario = $diagAfter.active_scenario
        dtcs = @($dtcsAfter.dtcs)
    }

    if (-not $SkipPhone -and (Test-Path -LiteralPath $logcatPath)) {
        $successMatches = @(Select-YouObdLogMatches -LogPath $logcatPath -Patterns $successPatterns)
        $errorMatches = @(Select-YouObdLogMatches -LogPath $logcatPath -Patterns $errorPatterns)

        $filteredLines = New-Object System.Collections.Generic.List[string]
        foreach ($item in @($successMatches + $errorMatches)) {
            $filteredLines.Add($item.Line)
        }
        $filteredLines | Select-Object -Unique | Out-File -FilePath $filteredLogPath -Encoding utf8

        $report.logcat.success_count = $successMatches.Count
        $report.logcat.error_count = $errorMatches.Count
        $report.logcat.success_lines = @($successMatches | Select-Object -First 12 | ForEach-Object { $_.Line })
        $report.logcat.error_lines = @($errorMatches | Select-Object -First 12 | ForEach-Object { $_.Line })
    }

    if ($SkipPhone) {
        $report.verdict = "SIMULATOR_ONLY"
    } elseif ($report.logcat.success_count -gt 0 -and $report.logcat.error_count -eq 0) {
        $report.verdict = "PASS"
    } elseif ($report.logcat.success_count -gt 0 -and $report.logcat.error_count -gt 0) {
        $report.verdict = "MIXED"
    } elseif ($report.logcat.error_count -gt 0) {
        $report.verdict = "FAIL"
    } else {
        $report.verdict = "UNKNOWN"
    }

    Write-ReportArtifacts -Report $report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath

    Write-Host "Validacao concluida."
    Write-Host "Verdict: $($report.verdict)"
    Write-Host "Relatorio: $reportMdPath"
}
catch {
    $report.verdict = "ERROR"
    $report.error = $_.Exception.Message
    Write-ReportArtifacts -Report $report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath
    throw
}
