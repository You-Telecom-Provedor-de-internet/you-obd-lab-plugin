Set-StrictMode -Version Latest

function Get-YouObdAdbPath {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"),
        "C:\Android\platform-tools\adb.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "adb nao encontrado. Instale Android platform-tools ou ajuste o PATH."
}

function Get-YouObdCurlPath {
    $command = Get-Command "curl.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "curl.exe nao encontrado."
}

function Get-YouObdApiCredentialDefaults {
    $defaults = @{
        User = "api"
        Password = "obdapi2026"
        Source = "factory"
    }

    $localCredentialsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "local-api-credentials.json"
    if (Test-Path -LiteralPath $localCredentialsPath) {
        try {
            $local = Get-Content -LiteralPath $localCredentialsPath -Raw | ConvertFrom-Json
            $localUser = [string]$local.user
            $localPassword = [string]$local.password
            if (-not [string]::IsNullOrWhiteSpace($localUser) -and -not [string]::IsNullOrWhiteSpace($localPassword)) {
                return @{
                    User = $localUser
                    Password = $localPassword
                    Source = "local-file"
                }
            }
        }
        catch {
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:YOU_OBD_API_USER) -and -not [string]::IsNullOrWhiteSpace($env:YOU_OBD_API_PASSWORD)) {
        return @{
            User = $env:YOU_OBD_API_USER
            Password = $env:YOU_OBD_API_PASSWORD
            Source = "environment"
        }
    }

    return $defaults
}

function Resolve-YouObdSimulatorBaseUrl {
    param([string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        throw "BaseUrl do simulador nao informada."
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $normalized = $BaseUrl.TrimEnd("/")
    $candidates.Add($normalized)

    foreach ($fallback in @("http://youobd2.local", "http://192.168.1.11")) {
        $normalizedFallback = $fallback.TrimEnd("/")
        if (-not $candidates.Contains($normalizedFallback)) {
            $candidates.Add($normalizedFallback)
        }
    }

    foreach ($candidate in $candidates) {
        try {
            Invoke-YouObdApiRaw -BaseUrl $candidate -Path "/ping-json" -AllowUnauthenticated | Out-Null
            return $candidate
        }
        catch {
        }
    }

    throw "Nao foi possivel alcançar o simulador por nenhum endpoint conhecido."
}

function New-YouObdArtifactDir {
    param(
        [string]$Prefix = "you-obd-lab",
        [string]$OutputDir = ""
    )

    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $OutputDir = Join-Path $env:TEMP "$Prefix-$stamp"
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    return (Resolve-Path $OutputDir).Path
}

function Invoke-YouObdExternal {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $output = @()
    $exitCode = 0
    $hadNativePref = Test-Path variable:PSNativeCommandUseErrorActionPreference
    $previousNativePref = $null

    try {
        if ($hadNativePref) {
            $previousNativePref = $PSNativeCommandUseErrorActionPreference
        }
        $script:PSNativeCommandUseErrorActionPreference = $false
        $global:LASTEXITCODE = 0
        $output = & $FilePath @Arguments 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.ToString()
            } else {
                [string]$_
            }
        }
        $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    }
    catch {
        $output = @($_.Exception.Message)
        $exitCode = 1
    }
    finally {
        if ($hadNativePref) {
            $script:PSNativeCommandUseErrorActionPreference = $previousNativePref
        }
    }

    return @{
        Output = @($output)
        ExitCode = $exitCode
    }
}

function Invoke-YouObdApiRaw {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [string]$Method = "GET",
        [string]$BodyJson = "",
        [string]$User = "",
        [string]$Password = "",
        [switch]$AllowUnauthenticated
    )

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
        throw "BaseUrl do simulador nao informado."
    }

    $curl = Get-YouObdCurlPath
    $normalizedBase = $BaseUrl.TrimEnd("/")
    $normalizedPath = if ($Path.StartsWith("/")) { $Path } else { "/$Path" }
    $url = "$normalizedBase$normalizedPath"

    $args = @("--silent", "--show-error", "--fail-with-body", "--location", "--max-time", "20")
    if (-not $AllowUnauthenticated) {
        if ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw "Credenciais da API nao informadas para $url."
        }
        $args += @("--basic", "-u", "${User}:${Password}")
    }

    $methodUpper = $Method.ToUpperInvariant()
    if ($methodUpper -ne "GET") {
        $args += @("-X", $methodUpper)
    }

    $bodyTempPath = $null
    try {
        if (-not [string]::IsNullOrWhiteSpace($BodyJson)) {
            $bodyTempPath = Join-Path $env:TEMP ("you-obd-api-body-" + [guid]::NewGuid().ToString("N") + ".json")
            [System.IO.File]::WriteAllText($bodyTempPath, $BodyJson, (New-Object System.Text.UTF8Encoding($false)))
            $args += @("-H", "Content-Type: application/json", "--data-binary", "@$bodyTempPath")
        }

        $args += $url
        $result = Invoke-YouObdExternal -FilePath $curl -Arguments $args
    }
    finally {
        if ($bodyTempPath -and (Test-Path -LiteralPath $bodyTempPath)) {
            Remove-Item -LiteralPath $bodyTempPath -ErrorAction SilentlyContinue
        }
    }

    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join "`n").Trim()
        throw "Falha consultando $url (exit $($result.ExitCode)): $joined"
    }

    $text = (($result.Output -join "`n").Trim())
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Resposta vazia recebida de $url."
    }

    return $text
}

function Invoke-YouObdApiJson {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [string]$Method = "GET",
        [string]$BodyJson = "",
        [string]$User = "",
        [string]$Password = "",
        [switch]$AllowUnauthenticated
    )

    $raw = Invoke-YouObdApiRaw -BaseUrl $BaseUrl -Path $Path -Method $Method -BodyJson $BodyJson -User $User -Password $Password -AllowUnauthenticated:$AllowUnauthenticated
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Resposta vazia em $Path."
    }

    return ($raw | ConvertFrom-Json)
}

function Save-YouObdApiPayload {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [string]$TargetPath,
        [string]$Method = "GET",
        [string]$BodyJson = "",
        [string]$User = "",
        [string]$Password = "",
        [switch]$AllowUnauthenticated
    )

    $raw = Invoke-YouObdApiRaw -BaseUrl $BaseUrl -Path $Path -Method $Method -BodyJson $BodyJson -User $User -Password $Password -AllowUnauthenticated:$AllowUnauthenticated
    $raw | Out-File -FilePath $TargetPath -Encoding utf8
    return $raw
}

function Get-YouObdObjectValue {
    param(
        $Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function Get-YouObdAuthorizedDevices {
    $adb = Get-YouObdAdbPath
    $result = Invoke-YouObdExternal -FilePath $adb -Arguments @("devices", "-l")
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join "`n").Trim()
        throw "Falha executando adb devices: $joined"
    }

    $devices = @()
    foreach ($line in $result.Output) {
        $text = [string]$line
        if ($text -match "^\s*$" -or $text -match "^List of devices attached") {
            continue
        }

        if ($text -match "^(?<id>\S+)\s+device\b") {
            $devices += [pscustomobject]@{
                Id = $matches["id"]
                Raw = $text.Trim()
            }
        }
    }

    return $devices
}

function Resolve-YouObdDeviceId {
    param([string]$DeviceId = "")

    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        return $DeviceId
    }

    $devices = @(Get-YouObdAuthorizedDevices)
    if ($devices.Count -eq 0) {
        throw "Nenhum dispositivo ADB autorizado encontrado."
    }

    if ($devices.Count -gt 1) {
        $list = ($devices | ForEach-Object { $_.Raw }) -join "; "
        throw "Mais de um dispositivo ADB autorizado encontrado. Informe -DeviceId. Dispositivos: $list"
    }

    return $devices[0].Id
}

function Invoke-YouObdAdb {
    param(
        [string]$DeviceId,
        [string[]]$Arguments
    )

    $adb = Get-YouObdAdbPath
    $fullArgs = @()
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $fullArgs += @("-s", $DeviceId)
    }
    $fullArgs += $Arguments
    $result = Invoke-YouObdExternal -FilePath $adb -Arguments $fullArgs
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join "`n").Trim()
        throw "Falha executando adb $($Arguments -join ' '): $joined"
    }
    return $result.Output
}

function Save-YouObdScreenshot {
    param(
        [string]$DeviceId,
        [string]$TargetPath
    )

    $adb = Get-YouObdAdbPath
    $command = "`"$adb`" -s $DeviceId exec-out screencap -p > `"$TargetPath`""
    cmd /c $command | Out-Null
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Falha ao salvar screenshot em $TargetPath"
    }
}

function Stop-YouObdApp {
    param(
        [string]$DeviceId,
        [string]$PackageName
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "am", "force-stop", $PackageName) | Out-Null
}

function Get-YouObdLauncherActivity {
    param(
        [string]$DeviceId,
        [string]$PackageName
    )

    $output = Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "cmd", "package", "resolve-activity", "--brief", $PackageName)
    foreach ($line in $output) {
        $text = [string]$line
        if ($text -match "^[A-Za-z0-9._$-]+/[A-Za-z0-9._$-]+$") {
            return $text.Trim()
        }
    }

    throw "Nao foi possivel resolver a activity principal de $PackageName."
}

function Start-YouObdApp {
    param(
        [string]$DeviceId,
        [string]$PackageName
    )

    $activity = Get-YouObdLauncherActivity -DeviceId $DeviceId -PackageName $PackageName
    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "am", "start", "-W", "-n", $activity) | Out-Null
}

function Clear-YouObdLogcat {
    param([string]$DeviceId)
    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("logcat", "-c") | Out-Null
}

function Save-YouObdLogcat {
    param(
        [string]$DeviceId,
        [string]$TargetPath,
        [int]$Lines = 800
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("logcat", "-d", "-t", "$Lines") | Out-File -FilePath $TargetPath -Encoding utf8
}

function Get-YouObdPackageInfo {
    param(
        [string]$DeviceId,
        [string]$PackageName
    )

    $output = Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "dumpsys", "package", $PackageName)
    $joined = $output -join "`n"
    $versionName = ""
    $versionCode = ""

    if ($joined -match "versionName=(.+)") {
        $versionName = $matches[1].Trim()
    }

    if ($joined -match "versionCode=(\d+)") {
        $versionCode = $matches[1].Trim()
    }

    return [pscustomobject]@{
        Package = $PackageName
        VersionName = $versionName
        VersionCode = $versionCode
        Raw = $joined
    }
}

function Save-YouObdDeviceProps {
    param(
        [string]$DeviceId,
        [string]$TargetPath
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "getprop") | Out-File -FilePath $TargetPath -Encoding utf8
}

function Save-YouObdUiDump {
    param(
        [string]$DeviceId,
        [string]$TargetPath
    )

    $adb = Get-YouObdAdbPath
    $remotePath = "/sdcard/youobd-ui-dump.xml"
    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "uiautomator", "dump", $remotePath) | Out-Null
    $command = "`"$adb`" -s $DeviceId exec-out cat $remotePath > `"$TargetPath`""
    cmd /c $command | Out-Null
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Falha ao salvar UI dump em $TargetPath"
    }
}

function Get-YouObdBoundsCenter {
    param([string]$Bounds)

    if ($Bounds -notmatch "^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$") {
        throw "Bounds invalidos: $Bounds"
    }

    $left = [int]$matches[1]
    $top = [int]$matches[2]
    $right = [int]$matches[3]
    $bottom = [int]$matches[4]

    return [pscustomobject]@{
        X = [int](($left + $right) / 2)
        Y = [int](($top + $bottom) / 2)
    }
}

function Find-YouObdUiNodeByContentDesc {
    param(
        [string]$UiDumpPath,
        [string]$Pattern
    )

    [xml]$xml = Get-Content -LiteralPath $UiDumpPath -Encoding utf8
    $nodes = $xml.SelectNodes('//node')
    foreach ($node in $nodes) {
        $desc = [string]$node.GetAttribute("content-desc")
        $clickable = [string]$node.GetAttribute("clickable")
        if (-not [string]::IsNullOrWhiteSpace($desc) -and $desc -match $Pattern -and $clickable -eq "true") {
            return [pscustomobject]@{
                ContentDesc = $desc
                Bounds = [string]$node.GetAttribute("bounds")
                Class = [string]$node.GetAttribute("class")
            }
        }
    }

    return $null
}

function Invoke-YouObdTap {
    param(
        [string]$DeviceId,
        [int]$X,
        [int]$Y
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "input", "tap", "$X", "$Y") | Out-Null
}

function Invoke-YouObdSwipe {
    param(
        [string]$DeviceId,
        [int]$X1,
        [int]$Y1,
        [int]$X2,
        [int]$Y2,
        [int]$DurationMs = 350
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "input", "swipe", "$X1", "$Y1", "$X2", "$Y2", "$DurationMs") | Out-Null
}

function Open-YouAutoCarDiagnosticsTab {
    param([string]$DeviceId)

    $tempPath = Join-Path $env:TEMP ("youobd-ui-" + [guid]::NewGuid().ToString("N") + ".xml")
    try {
        Save-YouObdUiDump -DeviceId $DeviceId -TargetPath $tempPath
        $node = Find-YouObdUiNodeByContentDesc -UiDumpPath $tempPath -Pattern "^Diagn[oó]stico"
        if ($null -eq $node) {
            throw "Nao foi possivel localizar a aba Diagnostico do YouAutoCar."
        }

        $center = Get-YouObdBoundsCenter -Bounds $node.Bounds
        Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
        Start-Sleep -Seconds 2
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue
        }
    }
}

function Select-YouObdLogMatches {
    param(
        [string]$LogPath,
        [string[]]$Patterns
    )

    if (-not (Test-Path -LiteralPath $LogPath)) {
        return @()
    }

    $lines = Get-Content -LiteralPath $LogPath
    $matches = New-Object System.Collections.Generic.List[object]

    foreach ($line in $lines) {
        foreach ($pattern in $Patterns) {
            if ([string]::IsNullOrWhiteSpace($pattern)) {
                continue
            }
            if ($line.IndexOf($pattern, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $matches.Add([pscustomobject]@{
                    Pattern = $pattern
                    Line = $line
                })
                break
            }
        }
    }

    return @($matches.ToArray())
}

function Get-YouObdUiDocument {
    param([string]$UiDumpPath)

    [xml]$xml = Get-Content -LiteralPath $UiDumpPath -Encoding utf8
    return $xml
}

function Find-YouObdUiNode {
    param(
        [string]$UiDumpPath,
        [string]$Pattern
    )

    $xml = Get-YouObdUiDocument -UiDumpPath $UiDumpPath
    $nodes = $xml.SelectNodes('//node')
    foreach ($node in $nodes) {
        $desc = [string]$node.GetAttribute("content-desc")
        $text = [string]$node.GetAttribute("text")
        $clickable = [string]$node.GetAttribute("clickable")
        $class = [string]$node.GetAttribute("class")
        $looksClickable = $clickable -eq "true" -or $class -match "Button|ImageView|View"
        if (-not $looksClickable) {
            continue
        }

        if ((-not [string]::IsNullOrWhiteSpace($desc) -and $desc -match $Pattern) -or
            (-not [string]::IsNullOrWhiteSpace($text) -and $text -match $Pattern)) {
            return [pscustomobject]@{
                ContentDesc = $desc
                Text = $text
                Bounds = [string]$node.GetAttribute("bounds")
                Class = $class
            }
        }
    }

    return $null
}

function Wait-YouObdUiNode {
    param(
        [string]$DeviceId,
        [string]$Pattern,
        [int]$TimeoutSeconds = 12,
        [int]$PollMilliseconds = 800
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $tempPath = Join-Path $env:TEMP ("youobd-ui-" + [guid]::NewGuid().ToString("N") + ".xml")
    try {
        do {
            Save-YouObdUiDump -DeviceId $DeviceId -TargetPath $tempPath
            $node = Find-YouObdUiNode -UiDumpPath $tempPath -Pattern $Pattern
            if ($null -ne $node) {
                return $node
            }
            Start-Sleep -Milliseconds $PollMilliseconds
        } while ((Get-Date) -lt $deadline)
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue
        }
    }

    return $null
}

function Get-YouObdDisplaySize {
    param([string]$DeviceId)

    $output = Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "wm", "size")
    foreach ($line in $output) {
        $text = [string]$line
        if ($text -match "(\d+)x(\d+)") {
            return [pscustomobject]@{
                Width = [int]$matches[1]
                Height = [int]$matches[2]
            }
        }
    }

    throw "Nao foi possivel determinar a resolucao da tela do dispositivo."
}

function Open-YouAutoCarDiagnosticsTab {
    param([string]$DeviceId)

    Start-Sleep -Seconds 2
    $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "^Diagn" -TimeoutSeconds 15 -PollMilliseconds 900
    if ($null -eq $node) {
        $size = Get-YouObdDisplaySize -DeviceId $DeviceId
        $fallbackX = [int]($size.Width * 0.30)
        $fallbackY = [int]($size.Height * 0.90)
        Invoke-YouObdTap -DeviceId $DeviceId -X $fallbackX -Y $fallbackY
        Start-Sleep -Seconds 2
        $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Conectar ao OBD|Configura[cç][oõ]es Bluetooth|Conectando" -TimeoutSeconds 8 -PollMilliseconds 800
        if ($null -eq $node) {
            throw "Nao foi possivel localizar a aba Diagnostico do YouAutoCar."
        }
        return
    }

    $center = Get-YouObdBoundsCenter -Bounds $node.Bounds
    Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
    Start-Sleep -Seconds 3
}

function Open-YouAutoCarScannerTecnico {
    param([string]$DeviceId)

    $readyNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Auto-conectado|ECU Pronta|Scanner ao vivo conectado|OBDLink MX\\+" -TimeoutSeconds 18 -PollMilliseconds 900
    if ($null -eq $readyNode) {
        Start-Sleep -Seconds 4
    }

    $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico" -TimeoutSeconds 8 -PollMilliseconds 700
    if ($null -eq $node) {
        $size = Get-YouObdDisplaySize -DeviceId $DeviceId
        Invoke-YouObdTap -DeviceId $DeviceId -X ([int]($size.Width * 0.82)) -Y ([int]($size.Height * 0.07))
        Start-Sleep -Seconds 2
        $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 6 -PollMilliseconds 700
        if ($null -ne $node) {
            return
        }

        Invoke-YouObdSwipe -DeviceId $DeviceId -X1 ([int]($size.Width * 0.5)) -Y1 ([int]($size.Height * 0.78)) -X2 ([int]($size.Width * 0.5)) -Y2 ([int]($size.Height * 0.48)) -DurationMs 300
        Start-Sleep -Seconds 1

        $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico" -TimeoutSeconds 5 -PollMilliseconds 700
        if ($null -eq $node) {
            Invoke-YouObdTap -DeviceId $DeviceId -X ([int]($size.Width * 0.5)) -Y ([int]($size.Height * 0.42))
            Start-Sleep -Seconds 2
        } else {
            $center = Get-YouObdBoundsCenter -Bounds $node.Bounds
            Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
            Start-Sleep -Seconds 3
        }
    }
    else {
        $center = Get-YouObdBoundsCenter -Bounds $node.Bounds
        Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
        Start-Sleep -Seconds 4
    }

    $scannerNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 12 -PollMilliseconds 800
    if ($null -eq $scannerNode) {
        $retryNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico" -TimeoutSeconds 4 -PollMilliseconds 700
        if ($null -ne $retryNode) {
            $retryCenter = Get-YouObdBoundsCenter -Bounds $retryNode.Bounds
            Invoke-YouObdTap -DeviceId $DeviceId -X $retryCenter.X -Y $retryCenter.Y
            Start-Sleep -Seconds 4
            $scannerNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 12 -PollMilliseconds 800
        }
    }
    if ($null -eq $scannerNode) {
        throw "O Scanner Tecnico nao abriu corretamente."
    }
}
