param(
    [string]$FixtureId = "",
    [string]$FixtureManifestPath = "",
    [string]$SimulatorBaseUrl = "http://192.168.1.11",
    [string]$User = "",
    [string]$Password = "",
    [string]$DeviceId = "",
    [string]$WifiDeviceIp = "192.168.1.99",
    [int]$AdbWifiPort = 5555,
    [switch]$PromoteUsbToWifi = $true,
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
    [switch]$NavigateToDiagnostics,
    [switch]$OpenScannerTecnico,
    [switch]$DryRun,
    [int]$WarmupSeconds = 10,
    [int]$LogcatLines = 1000,
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "lib\YouObdLab.Common.ps1")

$successPatterns = @(
    "ECU_READY",
    "Auto-conexao bem-sucedida",
    "Auto-conexão bem-sucedida",
    "Ligado a ECU",
    "Ligado à ECU",
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

function ConvertTo-YouObdStringArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [string]) {
        return @([string]$Value)
    }

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($Value)) {
        if ($null -ne $entry) {
            $items.Add([string]$entry)
        }
    }
    return @($items.ToArray())
}

function Throw-YouObdBenchFailure {
    param(
        [string]$Category,
        [string]$Message
    )

    throw "BENCH_FAIL::$Category::$Message"
}

function Initialize-YouObdFixture {
    param(
        [string]$RequestedFixtureId,
        [string]$RequestedManifestPath
    )

    if ([string]::IsNullOrWhiteSpace($RequestedFixtureId)) {
        return $null
    }

    $manifestPath = $RequestedManifestPath
    if ([string]::IsNullOrWhiteSpace($manifestPath)) {
        $manifestPath = Join-Path (Split-Path $PSScriptRoot -Parent) "fixtures\lab-fixtures.json"
    }
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "Manifesto de fixtures nao encontrado: $manifestPath"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $fixture = @($manifest.fixtures) | Where-Object { $_.fixture_id -eq $RequestedFixtureId } | Select-Object -First 1
    if ($null -eq $fixture) {
        throw "Fixture '$RequestedFixtureId' nao encontrada em $manifestPath"
    }

    return [pscustomobject]@{
        ManifestPath = $manifestPath
        Manifest = $manifest
        Fixture = $fixture
    }
}

function Get-YouObdExpectedOracleValue {
    param(
        $Status,
        $Diagnostics,
        $Dtcs,
        [string]$Name
    )

    switch ($Name) {
        "profile_id" {
            return Get-YouObdObjectValue -Object $Status -Name "profile_id" -Default (Get-YouObdObjectValue -Object (Get-YouObdObjectValue -Object $Diagnostics -Name "vehicle" -Default $null) -Name "profile_id" -Default "")
        }
        "protocol_id" {
            return Get-YouObdObjectValue -Object $Status -Name "protocol_id" -Default (Get-YouObdObjectValue -Object (Get-YouObdObjectValue -Object $Diagnostics -Name "vehicle" -Default $null) -Name "protocol_id" -Default "")
        }
        "protocol" {
            return Get-YouObdObjectValue -Object $Status -Name "protocol" -Default (Get-YouObdObjectValue -Object (Get-YouObdObjectValue -Object $Diagnostics -Name "vehicle" -Default $null) -Name "protocol" -Default "")
        }
        "profile_turbo" {
            return Get-YouObdObjectValue -Object $Status -Name "profile_turbo" -Default (Get-YouObdObjectValue -Object (Get-YouObdObjectValue -Object $Diagnostics -Name "vehicle" -Default $null) -Name "profile_turbo" -Default $false)
        }
        "dtcs_total" {
            $dtcList = Get-YouObdObjectValue -Object $Dtcs -Name "dtcs" -Default @()
            return @($dtcList).Count
        }
        "scenario_id" {
            return Get-YouObdObjectValue -Object $Diagnostics -Name "scenario_id" -Default ""
        }
        default {
            $topLevel = Get-YouObdObjectValue -Object $Status -Name $Name -Default $null
            if ($null -ne $topLevel) {
                return $topLevel
            }
            $diagValue = Get-YouObdObjectValue -Object $Diagnostics -Name $Name -Default $null
            if ($null -ne $diagValue) {
                return $diagValue
            }
            return Get-YouObdObjectValue -Object $Dtcs -Name $Name -Default $null
        }
    }
}

function Test-YouObdPattern {
    param(
        [string]$Text,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Pattern)) {
        return $true
    }
    return [regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function Test-YouObdContains {
    param(
        [string]$Text,
        [string]$Needle
    )

    if ([string]::IsNullOrWhiteSpace($Needle)) {
        return $true
    }
    return $Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-YouObdProtocolAlias {
    param([string]$Value)

    $normalized = [string]$Value
    $normalized = $normalized.Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return ""
    }

    if ($normalized.Contains('ISO 9141-2')) {
        return 'ISO9141_2'
    }

    if (($normalized.Contains('CAN STANDARD')) -or
        ($normalized.Contains('CAN 11') -and $normalized.Contains('500')) -or
        ($normalized.Contains('ISO 15765-4') -and $normalized.Contains('11/500'))) {
        return 'CAN11_500'
    }

    return $normalized
}

function Test-YouObdProtocolMatch {
    param(
        [string]$Text,
        [string]$ExpectedLabel
    )

    if (Test-YouObdContains -Text $Text -Needle $ExpectedLabel) {
        return $true
    }

    $expectedAlias = Get-YouObdProtocolAlias -Value $ExpectedLabel
    if ([string]::IsNullOrWhiteSpace($expectedAlias)) {
        return $true
    }

    $textAlias = Get-YouObdProtocolAlias -Value $Text
    if ($textAlias -eq $expectedAlias) {
        return $true
    }

    switch ($expectedAlias) {
        'CAN11_500' { return Test-YouObdPattern -Text $Text -Pattern 'CAN Standard|CAN 11.?500|ISO 15765-4.*11/500' }
        'ISO9141_2' { return Test-YouObdPattern -Text $Text -Pattern 'ISO 9141-2' }
        default { return $false }
    }
}

function Test-YouObdCorePidMatch {
    param(
        [string]$Text,
        [string]$ExpectedLabel
    )

    if (Test-YouObdContains -Text $Text -Needle $ExpectedLabel) {
        return $true
    }

    $candidates = switch -Regex ([string]$ExpectedLabel) {
        'Rota[cç][aã]o|RPM' { @('RPM', 'Rotacao', 'Rotação', 'Revs') ; break }
        'Temperatura|Temp' { @('Temperatura', 'Temp', 'Coolant', 'Coolant Temp', 'Engine Temp') ; break }
        'Bateria|Batt|Battery' { @('Bateria', 'Batt', 'Battery', 'Tensao', 'Tensão') ; break }
        '^MAP$|Vacuo|V[aá]cuo|Boost' { @('MAP', 'Vacuo', 'Vácuo', 'Boost') ; break }
        default { @([string]$ExpectedLabel) }
    }

    foreach ($candidate in $candidates) {
        if (Test-YouObdContains -Text $Text -Needle $candidate) {
            return $true
        }
    }

    return $false
}

function Add-YouObdCheckResult {
    param(
        [string]$Phase,
        [string]$Name,
        $Expected,
        $Actual,
        [bool]$Passed
    )

    $script:checkResults.Add([ordered]@{
        phase = $Phase
        name = $Name
        expected = $Expected
        actual = $Actual
        passed = $Passed
    }) | Out-Null
}

function Set-YouObdPhase {
    param([string]$Phase)
    $script:report.phase.current = $Phase
}

function Complete-YouObdPhase {
    param([string]$Phase)
    if ($script:report.phase.completed -notcontains $Phase) {
        $script:report.phase.completed += $Phase
    }
}

function Write-ReportArtifacts {
    param(
        [hashtable]$Report,
        [string]$JsonPath,
        [string]$MarkdownPath
    )

    $Report["checks"] = @($script:checkResults.ToArray())
    ($Report | ConvertTo-Json -Depth 20) | Out-File -FilePath $JsonPath -Encoding utf8

    $lines = @()
    $lines += "# YOU OBD Lab bench validation"
    $lines += ""
    $lines += "- Timestamp: $($Report.timestamp)"
    $lines += "- Verdict: $($Report.verdict)"
    $lines += "- Failure category: $($Report.failure_category)"
    $lines += "- Current phase: $($Report.phase.current)"
    $lines += "- Completed phases: $(([string[]]$Report.phase.completed) -join ', ')"
    $lines += "- Simulator: $($Report.setup.simulator_base_url)"
    $lines += "- App package: $($Report.setup.app_package)"
    $lines += "- Device: $($Report.setup.device_id)"
    $lines += "- Device transport: $($Report.setup.device_transport)"
    $lines += "- Device strategy: $($Report.setup.device_connection_strategy)"
    $lines += "- Device Wi-Fi endpoint: $($Report.setup.device_wifi_endpoint)"
    if (-not [string]::IsNullOrWhiteSpace($Report.setup.device_promotion_error)) {
        $lines += "- Device Wi-Fi error: $($Report.setup.device_promotion_error)"
    }
    if (-not [string]::IsNullOrWhiteSpace($Report.error)) {
        $lines += "- Error: $($Report.error)"
    }
    $lines += ""
    $lines += "## Fixture"
    $lines += ""
    $lines += "- fixture_id: $($Report.fixture.fixture_id)"
    $lines += "- description: $($Report.fixture.description)"
    $lines += "- manifest_path: $($Report.fixture.manifest_path)"
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
    $lines += "- protocol_id: $($Report.oracle.before.protocol_id)"
    $lines += "- protocol: $($Report.oracle.before.protocol)"
    $lines += "- profile_id: $($Report.oracle.before.profile_id)"
    $lines += "- sim_mode: $($Report.oracle.before.sim_mode)"
    $lines += "- dtcs_total: $($Report.oracle.before.dtcs_total)"
    $lines += "- active_scenario: $($Report.oracle.before.active_scenario)"
    $lines += ""
    $lines += "## Oracle after"
    $lines += ""
    $lines += "- protocol_id: $($Report.oracle.after.protocol_id)"
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
    $lines += "- diagnostics_tab_detected: $($Report.android.diagnostics_tab_detected)"
    $lines += "- diagnostics_marker_present: $($Report.android.diagnostics_marker_present)"
    $lines += "- expected_vehicle_match: $($Report.android.expected_vehicle_match)"
    $lines += "- expected_protocol_match: $($Report.android.expected_protocol_match)"
    $lines += "- scanner_tecnico_opened: $($Report.android.scanner_tecnico_opened)"
    $lines += "- scanner_marker_present: $($Report.android.scanner_marker_present)"
    $lines += "- scanner_session_present: $($Report.android.scanner_session_present)"
    $lines += "- scanner_live_read_present: $($Report.android.scanner_live_read_present)"
    $lines += "- scanner_persistence_present: $($Report.android.scanner_persistence_present)"
    $lines += "- version_name: $($Report.android.version_name)"
    $lines += "- version_code: $($Report.android.version_code)"
    $lines += ""
    $failedChecks = @($Report.checks | Where-Object { -not $_.passed })
    if ($failedChecks.Count -gt 0) {
        $lines += "## Failed checks"
        $lines += ""
        foreach ($check in $failedChecks) {
            $lines += "- [$($check.phase)] $($check.name) | expected=$($check.expected) | actual=$($check.actual)"
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

$fixtureInfo = Initialize-YouObdFixture -RequestedFixtureId $FixtureId -RequestedManifestPath $FixtureManifestPath
if ($null -ne $fixtureInfo) {
    $fixture = $fixtureInfo.Fixture
    if ([string]::IsNullOrWhiteSpace($ProfileId)) { $ProfileId = [string]$fixture.simulator_profile_id }
    if ($ProtocolId -lt 0) { $ProtocolId = [int]$fixture.protocol_id }
    if ($ModeId -lt 0) { $ModeId = [int]$fixture.mode_id }
    if (-not $PSBoundParameters.ContainsKey("ScenarioId")) { $ScenarioId = [string]$fixture.scenario_id }
    if ($DtcCodes.Count -eq 0) { $DtcCodes = ConvertTo-YouObdStringArray $fixture.manual_dtcs }
}

$SimulatorBaseUrl = Resolve-YouObdSimulatorBaseUrl -BaseUrl $SimulatorBaseUrl
$apiDefaults = Get-YouObdApiCredentialDefaults
if ([string]::IsNullOrWhiteSpace($User)) { $User = $apiDefaults.User }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $apiDefaults.Password }

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
$uiDumpPath = Join-Path $outputDir "phone-ui.xml"
$diagnosticsScreenPath = Join-Path $outputDir "phone-diagnostics.png"
$diagnosticsUiPath = Join-Path $outputDir "phone-diagnostics.xml"

$script:checkResults = New-Object System.Collections.Generic.List[object]
$script:report = [ordered]@{
    timestamp = (Get-Date -Format s)
    verdict = "UNKNOWN"
    failure_category = ""
    error = ""
    fixture = [ordered]@{
        fixture_id = if ($null -eq $fixtureInfo) { "" } else { [string]$fixtureInfo.Fixture.fixture_id }
        description = if ($null -eq $fixtureInfo) { "" } else { [string]$fixtureInfo.Fixture.description }
        manifest_path = if ($null -eq $fixtureInfo) { "" } else { [string]$fixtureInfo.ManifestPath }
    }
    phase = [ordered]@{
        current = "initializing"
        completed = @()
    }
    setup = [ordered]@{
        simulator_base_url = $SimulatorBaseUrl
        app_package = $AppPackage
        device_id = ""
        device_transport = ""
        device_connection_strategy = ""
        device_wifi_endpoint = ""
        device_promotion_error = ""
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
            protocol_id = ""
            protocol = ""
            profile_id = ""
            sim_mode = ""
            dtcs_total = ""
            active_scenario = ""
            dtcs = @()
        }
        after = [ordered]@{
            protocol_id = ""
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
        navigated_to_diagnostics = $false
        diagnostics_tab_detected = $false
        diagnostics_marker_present = $false
        expected_vehicle_match = $false
        expected_protocol_match = $false
        scanner_tecnico_opened = $false
        scanner_marker_present = $false
        scanner_card_present = $false
        scanner_button_present = $false
        live_sensor_summary_present = $false
        scanner_session_present = $false
        scanner_live_read_present = $false
        scanner_persistence_present = $false
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
    checks = @()
}

if ($DryRun) {
    $script:report.verdict = "DRY_RUN"
    Write-ReportArtifacts -Report $script:report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath
    Write-Host "Dry-run concluido."
    Write-Host "Relatorio: $reportMdPath"
    return
}

$shouldClearDtcs = $ClearDtcs.IsPresent -or ($null -ne $fixtureInfo)
$shouldNavigateToDiagnostics = $NavigateToDiagnostics.IsPresent -or ($AppPackage -eq "com.youautocar.client2")
$shouldOpenScannerTecnico = $OpenScannerTecnico.IsPresent -or ($AppPackage -eq "com.youautocar.client2")

try {
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/ping-json" -TargetPath $pingPath -AllowUnauthenticated | Out-Null

    Set-YouObdPhase "prepare_simulator"
    if (-not $SkipSimulatorWrites) {
        try {
            if ($shouldClearDtcs) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs/clear" -Method "POST" -BodyJson "{}" -User $User -Password $Password | Out-Null
            }

            Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/scenario" -Method "POST" -BodyJson (@{ id = "" } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null

            if ($ProtocolId -ge 0) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/protocol" -Method "POST" -BodyJson (@{ protocol = $ProtocolId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
            }
            if (-not [string]::IsNullOrWhiteSpace($ProfileId)) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/profile" -Method "POST" -BodyJson (@{ id = $ProfileId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
            }
            if ($ModeId -ge 0) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/mode" -Method "POST" -BodyJson (@{ mode = $ModeId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
            }
            if (-not [string]::IsNullOrWhiteSpace($ScenarioId)) {
                Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/scenario" -Method "POST" -BodyJson (@{ id = $ScenarioId } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
            }
            foreach ($dtc in $DtcCodes) {
                if (-not [string]::IsNullOrWhiteSpace($dtc)) {
                    Invoke-YouObdApiRaw -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs/add" -Method "POST" -BodyJson (@{ code = $dtc } | ConvertTo-Json -Compress) -User $User -Password $Password | Out-Null
                }
            }
        }
        catch {
            $message = $_.Exception.Message
            if ($message -match '401|Unauthorized|Credenciais') {
                Throw-YouObdBenchFailure -Category "simulator_auth_failed" -Message $message
            }
            Throw-YouObdBenchFailure -Category "simulator_write_failed" -Message $message
        }
    }
    Complete-YouObdPhase "prepare_simulator"

    Set-YouObdPhase "capture_oracle_before"
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusBeforePath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagBeforePath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs" -TargetPath $dtcsBeforePath -User $User -Password $Password | Out-Null

    $statusBefore = Get-Content -LiteralPath $statusBeforePath -Raw | ConvertFrom-Json
    $diagBefore = Get-Content -LiteralPath $diagBeforePath -Raw | ConvertFrom-Json
    $dtcsBefore = Get-Content -LiteralPath $dtcsBeforePath -Raw | ConvertFrom-Json

    $script:report.oracle.before = [ordered]@{
        protocol_id = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name "protocol_id"
        protocol = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name "protocol"
        profile_id = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name "profile_id"
        sim_mode = Get-YouObdObjectValue -Object $statusBefore -Name "sim_mode" -Default ""
        dtcs_total = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name "dtcs_total"
        active_scenario = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name "scenario_id"
        dtcs = @((Get-YouObdObjectValue -Object $dtcsBefore -Name "dtcs" -Default @()))
    }

    if ($null -ne $fixtureInfo) {
        foreach ($property in $fixtureInfo.Fixture.expected_oracle_fields.psobject.Properties) {
            $actual = Get-YouObdExpectedOracleValue -Status $statusBefore -Diagnostics $diagBefore -Dtcs $dtcsBefore -Name $property.Name
            $expected = $property.Value
            $passed = "$actual" -eq "$expected"
            Add-YouObdCheckResult -Phase "capture_oracle_before" -Name "oracle_before.$($property.Name)" -Expected $expected -Actual $actual -Passed $passed
            if (-not $passed) {
                Throw-YouObdBenchFailure -Category "simulator_write_failed" -Message "Oracle antes do app nao bate com a fixture para $($property.Name)."
            }
        }
    }
    Complete-YouObdPhase "capture_oracle_before"

    if (-not $SkipPhone) {
        Set-YouObdPhase "open_app"
        $deviceConnection = Resolve-YouObdDeviceConnection -DeviceId $DeviceId -AllowWifiFallback -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort -PromoteUsbToWifi:$PromoteUsbToWifi
        $resolvedDeviceId = $deviceConnection.Id
        $script:report.setup.device_id = $resolvedDeviceId
        $script:report.setup.device_transport = $deviceConnection.Transport
        $script:report.setup.device_connection_strategy = $deviceConnection.ConnectionStrategy
        $script:report.setup.device_wifi_endpoint = $deviceConnection.WifiEndpoint
        $script:report.setup.device_promotion_error = $deviceConnection.PromotionError

        @(Get-YouObdAuthorizedDevices -TryWifiFallback -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort) | ForEach-Object { $_.Raw } | Out-File -FilePath $adbDevicesPath -Encoding utf8
        $script:report.artifacts += @($adbDevicesPath, $devicePropsPath, $packageInfoPath, $screenPath, $uiDumpPath, $logcatPath, $filteredLogPath, $diagnosticsScreenPath, $diagnosticsUiPath)

        Save-YouObdDeviceProps -DeviceId $resolvedDeviceId -TargetPath $devicePropsPath
        $packageInfo = Get-YouObdPackageInfo -DeviceId $resolvedDeviceId -PackageName $AppPackage
        $packageInfo.Raw | Out-File -FilePath $packageInfoPath -Encoding utf8
        $script:report.android.version_name = $packageInfo.VersionName
        $script:report.android.version_code = $packageInfo.VersionCode
        $script:report.android.app_installed = -not [string]::IsNullOrWhiteSpace($packageInfo.VersionName) -or -not [string]::IsNullOrWhiteSpace($packageInfo.VersionCode)

        if (-not $script:report.android.app_installed) {
            Throw-YouObdBenchFailure -Category "ui_marker_missing" -Message "O pacote $AppPackage nao parece instalado no dispositivo $resolvedDeviceId."
        }

        Grant-YouObdRuntimePermissions -DeviceId $resolvedDeviceId -PackageName $AppPackage
        Clear-YouObdLogcat -DeviceId $resolvedDeviceId
        Stop-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage

        if (-not $SkipAppLaunch) {
            Start-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage
            $script:report.android.launched = $true
        }
        Complete-YouObdPhase "open_app"

        if ($shouldNavigateToDiagnostics) {
            Set-YouObdPhase "validate_diagnostics_screen"
            Open-YouAutoCarDiagnosticsTab -DeviceId $resolvedDeviceId -PackageName $AppPackage
            $script:report.android.navigated_to_diagnostics = $true
            Start-Sleep -Seconds 2

            Save-YouObdScreenshot -DeviceId $resolvedDeviceId -TargetPath $diagnosticsScreenPath
            Save-YouObdUiDump -DeviceId $resolvedDeviceId -TargetPath $diagnosticsUiPath

            $diagnosticsUiRaw = Get-Content -LiteralPath $diagnosticsUiPath -Raw -Encoding utf8
            $script:report.android.diagnostics_tab_detected = $diagnosticsUiRaw -match 'Diagnostico|Diagnóstico'
            $script:report.android.diagnostics_marker_present = $diagnosticsUiRaw -match 'LAB_DIAGNOSTICS|Laborat[oó]rio OBD|ID laborat[oó]rio: LAB_DIAGNOSTICS'

            $expectedVehicleLabel = if ($null -eq $fixtureInfo) { "" } else { [string]$fixtureInfo.Fixture.expected_vehicle_label_app }
            $expectedProtocolLabel = if ($null -eq $fixtureInfo) { "" } else { [string]$fixtureInfo.Fixture.expected_protocol_label }
            $awaitingVehicleContext = $diagnosticsUiRaw -match 'Nenhum ve[ií]culo selecionado|Ve[ií]culo n[aã]o selecionado|Sem contexto OBD'
            $script:report.android.expected_vehicle_match = Test-YouObdContains -Text $diagnosticsUiRaw -Needle $expectedVehicleLabel
            $script:report.android.expected_protocol_match = Test-YouObdProtocolMatch -Text $diagnosticsUiRaw -ExpectedLabel $expectedProtocolLabel

            Add-YouObdCheckResult -Phase "validate_diagnostics_screen" -Name "diagnostics.marker" -Expected "LAB_DIAGNOSTICS" -Actual $script:report.android.diagnostics_marker_present -Passed $script:report.android.diagnostics_marker_present
            if (-not [string]::IsNullOrWhiteSpace($expectedVehicleLabel)) {
                Add-YouObdCheckResult -Phase "validate_diagnostics_screen" -Name "diagnostics.vehicle" -Expected $expectedVehicleLabel -Actual $script:report.android.expected_vehicle_match -Passed $script:report.android.expected_vehicle_match
            }
            if (-not [string]::IsNullOrWhiteSpace($expectedProtocolLabel)) {
                Add-YouObdCheckResult -Phase "validate_diagnostics_screen" -Name "diagnostics.protocol" -Expected $expectedProtocolLabel -Actual $script:report.android.expected_protocol_match -Passed $script:report.android.expected_protocol_match
            }

            if (-not $script:report.android.diagnostics_marker_present) {
                Throw-YouObdBenchFailure -Category "ui_marker_missing" -Message "A tela de diagnostico nao expos LAB_DIAGNOSTICS."
            }
            if (-not $script:report.android.expected_vehicle_match -and -not $awaitingVehicleContext) {
                Throw-YouObdBenchFailure -Category "vehicle_context_mismatch" -Message "O veiculo exibido na tela de diagnostico nao bate com a fixture."
            }
            Complete-YouObdPhase "validate_diagnostics_screen"
        }

        if ($shouldOpenScannerTecnico) {
            Set-YouObdPhase "open_scanner_tecnico"
            Open-YouAutoCarScannerTecnico -DeviceId $resolvedDeviceId -PackageName $AppPackage
            $script:report.android.scanner_tecnico_opened = $true
            Complete-YouObdPhase "open_scanner_tecnico"
        }

        Set-YouObdPhase "validate_scanner_session"
        Start-Sleep -Seconds $WarmupSeconds
        Save-YouObdScreenshot -DeviceId $resolvedDeviceId -TargetPath $screenPath
        Save-YouObdUiDump -DeviceId $resolvedDeviceId -TargetPath $uiDumpPath
        Save-YouObdLogcat -DeviceId $resolvedDeviceId -TargetPath $logcatPath -Lines $LogcatLines

        $uiRaw = Get-Content -LiteralPath $uiDumpPath -Raw -Encoding utf8
        $script:report.android.scanner_marker_present = $uiRaw -match 'LAB_SCANNER|Laborat[oó]rio Scanner|ID laborat[oó]rio: LAB_SCANNER'
        $script:report.android.scanner_card_present = $uiRaw -match 'Scanner Tecnico|Scanner Técnico'
        $script:report.android.scanner_button_present = $uiRaw -match 'Abrir Scanner Tecnico|Abrir Scanner Técnico'
        $script:report.android.live_sensor_summary_present = ($uiRaw -match 'RPM|Rotacao|Rotação') -and ($uiRaw -match 'Batt|Bateria') -and ($uiRaw -match 'MAP')
        $script:report.android.scanner_session_present = $uiRaw -match 'Sessao|Sessão'
        $script:report.android.scanner_live_read_present = $uiRaw -match 'Leitura ativa'
        $script:report.android.scanner_persistence_present = $uiRaw -match 'Persistencia|Persistência'

        $script:report.android.scanner_persistence_present = $script:report.android.scanner_persistence_present -or ($uiRaw -match 'persist=on')
        Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.marker" -Expected "LAB_SCANNER" -Actual $script:report.android.scanner_marker_present -Passed $script:report.android.scanner_marker_present
        Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.session" -Expected $true -Actual $script:report.android.scanner_session_present -Passed $script:report.android.scanner_session_present
        Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.live" -Expected $true -Actual $script:report.android.scanner_live_read_present -Passed $script:report.android.scanner_live_read_present
        Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.persistence" -Expected $true -Actual $script:report.android.scanner_persistence_present -Passed $script:report.android.scanner_persistence_present

        if ($null -ne $fixtureInfo) {
            $scannerVehicleMatched = $true
            $scannerProtocolMatched = $true
            if (-not [string]::IsNullOrWhiteSpace([string]$fixtureInfo.Fixture.expected_vehicle_label_app)) {
                $scannerVehicleMatched = Test-YouObdContains -Text $uiRaw -Needle ([string]$fixtureInfo.Fixture.expected_vehicle_label_app)
                Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.vehicle" -Expected ([string]$fixtureInfo.Fixture.expected_vehicle_label_app) -Actual $scannerVehicleMatched -Passed $scannerVehicleMatched
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$fixtureInfo.Fixture.expected_protocol_label)) {
                $scannerProtocolMatched = Test-YouObdProtocolMatch -Text $uiRaw -ExpectedLabel ([string]$fixtureInfo.Fixture.expected_protocol_label)
                Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "scanner.protocol" -Expected ([string]$fixtureInfo.Fixture.expected_protocol_label) -Actual $scannerProtocolMatched -Passed $scannerProtocolMatched
            }

            foreach ($pattern in (ConvertTo-YouObdStringArray $fixtureInfo.Fixture.expected_ui_markers)) {
                $markerText = if ($pattern -match 'LAB_DIAGNOSTICS') { $diagnosticsUiRaw } elseif ($pattern -match 'LAB_SCANNER') { $uiRaw } else { "$diagnosticsUiRaw`n$uiRaw" }
                $matched = Test-YouObdPattern -Text $markerText -Pattern $pattern
                if (-not $matched -and $pattern -match 'Persistencia|Persist.+ncia') {
                    $matched = $script:report.android.scanner_persistence_present
                }
                Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "ui_marker.$pattern" -Expected $pattern -Actual $matched -Passed $matched
                if (-not $matched) {
                    Throw-YouObdBenchFailure -Category "ui_marker_missing" -Message "Marcador obrigatorio ausente no app: $pattern"
                }
            }

            foreach ($label in (ConvertTo-YouObdStringArray $fixtureInfo.Fixture.expected_core_pids)) {
                $matched = Test-YouObdCorePidMatch -Text "$diagnosticsUiRaw`n$uiRaw" -ExpectedLabel $label
                Add-YouObdCheckResult -Phase "validate_scanner_session" -Name "core_pid.$label" -Expected $label -Actual $matched -Passed $matched
                if (-not $matched) {
                    Throw-YouObdBenchFailure -Category "ui_marker_missing" -Message "PID principal ausente na UI: $label"
                }
            }

            if (-not $scannerVehicleMatched) {
                Throw-YouObdBenchFailure -Category "vehicle_context_mismatch" -Message "O Scanner Tecnico nao refletiu o veiculo esperado da fixture."
            }
            if (-not $scannerProtocolMatched) {
                Throw-YouObdBenchFailure -Category "oracle_obd_mismatch" -Message "O Scanner Tecnico nao refletiu o protocolo esperado da fixture."
            }
        }

        if (-not $script:report.android.scanner_tecnico_opened -or -not $script:report.android.scanner_marker_present) {
            Throw-YouObdBenchFailure -Category "scanner_not_opened" -Message "O Scanner Tecnico nao abriu na UI final."
        }
        if (-not $script:report.android.scanner_session_present -or -not $script:report.android.scanner_live_read_present) {
            Throw-YouObdBenchFailure -Category "scanner_session_missing" -Message "A sessao tecnica nao mostrou leitura ativa."
        }

        if (-not $KeepAppRunning) {
            Stop-YouObdApp -DeviceId $resolvedDeviceId -PackageName $AppPackage
        }
        Complete-YouObdPhase "validate_scanner_session"
    }

    Set-YouObdPhase "capture_oracle_after"
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/status" -TargetPath $statusAfterPath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/diagnostics" -TargetPath $diagAfterPath -User $User -Password $Password | Out-Null
    Save-YouObdApiPayload -BaseUrl $SimulatorBaseUrl -Path "/api/dtcs" -TargetPath $dtcsAfterPath -User $User -Password $Password | Out-Null

    $statusAfter = Get-Content -LiteralPath $statusAfterPath -Raw | ConvertFrom-Json
    $diagAfter = Get-Content -LiteralPath $diagAfterPath -Raw | ConvertFrom-Json
    $dtcsAfter = Get-Content -LiteralPath $dtcsAfterPath -Raw | ConvertFrom-Json

    $script:report.oracle.after = [ordered]@{
        protocol_id = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name "protocol_id"
        protocol = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name "protocol"
        profile_id = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name "profile_id"
        sim_mode = Get-YouObdObjectValue -Object $statusAfter -Name "sim_mode" -Default ""
        dtcs_total = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name "dtcs_total"
        active_scenario = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name "scenario_id"
        dtcs = @((Get-YouObdObjectValue -Object $dtcsAfter -Name "dtcs" -Default @()))
    }

    if ($null -ne $fixtureInfo) {
        foreach ($property in $fixtureInfo.Fixture.expected_oracle_fields.psobject.Properties) {
            $actual = Get-YouObdExpectedOracleValue -Status $statusAfter -Diagnostics $diagAfter -Dtcs $dtcsAfter -Name $property.Name
            $expected = $property.Value
            $passed = "$actual" -eq "$expected"
            Add-YouObdCheckResult -Phase "capture_oracle_after" -Name "oracle_after.$($property.Name)" -Expected $expected -Actual $actual -Passed $passed
            if (-not $passed) {
                Throw-YouObdBenchFailure -Category "oracle_obd_mismatch" -Message "Oracle final nao bate com a fixture para $($property.Name)."
            }
        }

        $expectedDtcs = ConvertTo-YouObdStringArray $fixtureInfo.Fixture.manual_dtcs
        if (@($expectedDtcs).Count -gt 0) {
            $actualDtcs = ConvertTo-YouObdStringArray (Get-YouObdObjectValue -Object $dtcsAfter -Name "dtcs" -Default @())
            foreach ($code in $expectedDtcs) {
                $matched = $actualDtcs -contains $code
                Add-YouObdCheckResult -Phase "capture_oracle_after" -Name "oracle_after.dtc.$code" -Expected $code -Actual ($actualDtcs -join ', ') -Passed $matched
                if (-not $matched) {
                    Throw-YouObdBenchFailure -Category "oracle_obd_mismatch" -Message "DTC esperado ausente no oracle final: $code"
                }
            }
        }
    }
    Complete-YouObdPhase "capture_oracle_after"

    if (-not $SkipPhone -and (Test-Path -LiteralPath $logcatPath)) {
        Set-YouObdPhase "logcat_analysis"
        $successMatches = @(Select-YouObdLogMatches -LogPath $logcatPath -Patterns $successPatterns)
        $errorMatches = @(Select-YouObdLogMatches -LogPath $logcatPath -Patterns $errorPatterns)

        $filteredLines = New-Object System.Collections.Generic.List[string]
        foreach ($item in @($successMatches + $errorMatches)) {
            $filteredLines.Add($item.Line)
        }
        $filteredLines | Select-Object -Unique | Out-File -FilePath $filteredLogPath -Encoding utf8

        $script:report.logcat.success_count = $successMatches.Count
        $script:report.logcat.error_count = $errorMatches.Count
        $script:report.logcat.success_lines = @($successMatches | Select-Object -First 12 | ForEach-Object { $_.Line })
        $script:report.logcat.error_lines = @($errorMatches | Select-Object -First 12 | ForEach-Object { $_.Line })
        Complete-YouObdPhase "logcat_analysis"
    }

    $script:report.verdict = if ($SkipPhone) { "SIMULATOR_ONLY" } else { "PASS" }
    $script:report.failure_category = ""
    Set-YouObdPhase "report_ready"
    Complete-YouObdPhase "report_ready"
    Write-ReportArtifacts -Report $script:report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath

    Write-Host "Validacao concluida."
    Write-Host "Verdict: $($script:report.verdict)"
    Write-Host "Relatorio: $reportMdPath"
}
catch {
    $message = "$($_.Exception.Message)".Trim()
    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = ($_ | Out-String).Trim()
    }

    if ($message -match 'BENCH_FAIL::([^:]+)::(.+)$') {
        $script:report.verdict = "FAIL"
        $script:report.failure_category = $matches[1]
        $script:report.error = $matches[2]
    }
    elseif ($message -match '401|Unauthorized|Credenciais') {
        $script:report.verdict = "FAIL"
        $script:report.failure_category = "simulator_auth_failed"
        $script:report.error = $message
    }
    else {
        $script:report.verdict = "ERROR"
        $script:report.failure_category = "unexpected_error"
        $script:report.error = $message
    }
    Write-ReportArtifacts -Report $script:report -JsonPath $reportJsonPath -MarkdownPath $reportMdPath
    throw
}
