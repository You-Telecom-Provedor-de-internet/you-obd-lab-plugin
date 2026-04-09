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

function Get-YouObdAdbWifiHost {
    foreach ($candidate in @($env:YOU_OBD_ADB_WIFI_HOST, $env:YOU_OBD_PHONE_IP, "192.168.1.99")) {
        $text = [string]$candidate
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            return $text.Trim()
        }
    }

    throw "Host Wi-Fi do ADB nao configurado."
}

function Get-YouObdAdbWifiPort {
    $parsed = 0
    if ([int]::TryParse([string]$env:YOU_OBD_ADB_WIFI_PORT, [ref]$parsed) -and $parsed -gt 0) {
        return $parsed
    }

    return 5555
}

function Get-YouObdAdbEndpoint {
    param(
        [string]$AdbWifiHost = "",
        [int]$AdbWifiPort = 0
    )

    if ([string]::IsNullOrWhiteSpace($AdbWifiHost)) {
        $AdbWifiHost = Get-YouObdAdbWifiHost
    }
    if ($AdbWifiPort -le 0) {
        $AdbWifiPort = Get-YouObdAdbWifiPort
    }

    $AdbWifiHost = $AdbWifiHost.Trim()
    if ($AdbWifiHost -match ":\d+$") {
        return $AdbWifiHost
    }

    return "${AdbWifiHost}:$AdbWifiPort"
}

function Test-YouObdNetworkDeviceId {
    param([string]$DeviceId)

    return -not [string]::IsNullOrWhiteSpace($DeviceId) -and $DeviceId -match "^[^:\s]+:\d+$"
}

function Get-YouObdDeviceTransport {
    param([string]$DeviceId)

    if (Test-YouObdNetworkDeviceId -DeviceId $DeviceId) {
        return "wifi"
    }

    return "usb"
}

function Test-YouObdTcpEndpointReachable {
    param(
        [string]$TcpHost,
        [int]$Port,
        [int]$TimeoutMilliseconds = 2500
    )

    if ([string]::IsNullOrWhiteSpace($TcpHost) -or $Port -le 0) {
        return $false
    }

    $client = $null
    $async = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($TcpHost, $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }

        $client.EndConnect($async)
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $async) {
            $async.AsyncWaitHandle.Close()
        }
        if ($null -ne $client) {
            $client.Close()
        }
    }
}

function Find-YouObdAuthorizedDevice {
    param(
        [object[]]$Devices,
        [string]$DeviceId = "",
        [string]$Transport = ""
    )

    $matches = @($Devices)
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        $matches = @($matches | Where-Object { $_.Id -eq $DeviceId })
    }
    if (-not [string]::IsNullOrWhiteSpace($Transport)) {
        $matches = @($matches | Where-Object { $_.Transport -eq $Transport })
    }

    return ($matches | Select-Object -First 1)
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
        User = "youobd-core"
        Password = "YouOBD.RevA@2026#Core"
        Source = "firmware-default"
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

function Get-YouObdAdbDeviceEntries {
    param(
        [switch]$IncludeOffline
    )

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

        if ($text -match "^(?<id>\S+)\s+(?<state>\S+)\b") {
            $state = $matches["state"].Trim().ToLowerInvariant()
            if (-not $IncludeOffline -and $state -ne "device") {
                continue
            }

            $devices += [pscustomobject]@{
                Id = $matches["id"]
                State = $state
                Raw = $text.Trim()
                Transport = Get-YouObdDeviceTransport -DeviceId $matches["id"]
                IsTcp = $matches["id"] -match ":\d+$"
            }
        }
    }

    return @($devices)
}

function Get-YouObdAdbWifiEndpoint {
    param(
        [string]$WifiDeviceIp = "",
        [int]$AdbWifiPort = 0
    )

    if ([string]::IsNullOrWhiteSpace($WifiDeviceIp)) {
        $WifiDeviceIp = Get-YouObdAdbWifiHost
    }
    if ($AdbWifiPort -le 0) {
        $AdbWifiPort = Get-YouObdAdbWifiPort
    }

    $WifiDeviceIp = $WifiDeviceIp.Trim()
    return (Get-YouObdAdbEndpoint -AdbWifiHost $WifiDeviceIp -AdbWifiPort $AdbWifiPort)
}

function Connect-YouObdAdbWifi {
    param(
        [string]$WifiDeviceIp = "",
        [int]$AdbWifiPort = 0,
        [string]$UsbDeviceId = ""
    )

    $adb = Get-YouObdAdbPath
    $endpoint = Get-YouObdAdbWifiEndpoint -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort
    if ($AdbWifiPort -le 0) {
        $AdbWifiPort = Get-YouObdAdbWifiPort
    }

    if (-not [string]::IsNullOrWhiteSpace($UsbDeviceId)) {
        $tcpipResult = Invoke-YouObdExternal -FilePath $adb -Arguments @("-s", $UsbDeviceId, "tcpip", "$AdbWifiPort")
        if ($tcpipResult.ExitCode -ne 0) {
            $joined = ($tcpipResult.Output -join "`n").Trim()
            throw "Falha promovendo USB para ADB Wi-Fi no dispositivo ${UsbDeviceId}: $joined"
        }
        Start-Sleep -Seconds 2
    }

    $existingWifiDevice = Find-YouObdAuthorizedDevice -Devices @(Get-YouObdAdbDeviceEntries) -DeviceId $endpoint
    if ($null -ne $existingWifiDevice) {
        return $existingWifiDevice
    }

    if ($endpoint -match '^(?<host>[^:]+):(?<port>\d+)$') {
        $tcpHost = $matches["host"]
        $tcpPort = [int]$matches["port"]
        if (-not (Test-YouObdTcpEndpointReachable -TcpHost $tcpHost -Port $tcpPort)) {
            throw "Dispositivo Wi-Fi $endpoint nao respondeu na porta ADB."
        }
    }

    $connectResult = Invoke-YouObdExternal -FilePath $adb -Arguments @("connect", $endpoint)
    $joined = ($connectResult.Output -join "`n").Trim()
    $connectOk = $connectResult.ExitCode -eq 0 -or
        $joined -match 'already connected|already connected to|connected to'
    if (-not $connectOk) {
        throw "Falha conectando ADB via Wi-Fi em ${endpoint}: $joined"
    }

    $deadline = (Get-Date).AddSeconds(12)
    do {
        $wifiDevice = Find-YouObdAuthorizedDevice -Devices @(Get-YouObdAdbDeviceEntries) -DeviceId $endpoint
        if ($null -ne $wifiDevice) {
            return $wifiDevice
        }

        Start-Sleep -Milliseconds 700
    } while ((Get-Date) -lt $deadline)

    if ($null -eq $wifiDevice) {
        throw "ADB conectou em $endpoint, mas o dispositivo nao ficou autorizado no estado device."
    }
}

function Resolve-YouObdDeviceConnection {
    param(
        [string]$DeviceId = "",
        [switch]$AllowWifiFallback = $true,
        [string]$WifiDeviceIp = "",
        [int]$AdbWifiPort = 0,
        [switch]$PromoteUsbToWifi = $true
    )

    $wifiEndpoint = Get-YouObdAdbWifiEndpoint -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort
    if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
        if (-not (Test-YouObdNetworkDeviceId -DeviceId $DeviceId) -and $PromoteUsbToWifi) {
            try {
                $wifiDevice = Connect-YouObdAdbWifi -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort -UsbDeviceId $DeviceId
                return [pscustomobject]@{
                    Id = $wifiDevice.Id
                    Raw = $wifiDevice.Raw
                    Transport = "wifi"
                    ConnectionStrategy = "explicit-usb-promoted-to-wifi"
                    WifiEndpoint = $wifiEndpoint
                    PromotionError = ""
                }
            }
            catch {
                return [pscustomobject]@{
                    Id = $DeviceId
                    Raw = $DeviceId
                    Transport = "usb"
                    ConnectionStrategy = "explicit-usb-promotion-failed"
                    WifiEndpoint = $wifiEndpoint
                    PromotionError = $_.Exception.Message
                }
            }
        }

        return [pscustomobject]@{
            Id = $DeviceId
            Raw = $DeviceId
            Transport = if (Test-YouObdNetworkDeviceId -DeviceId $DeviceId) { "wifi" } else { "usb" }
            ConnectionStrategy = "explicit-device-id"
            WifiEndpoint = $wifiEndpoint
            PromotionError = ""
        }
    }

    $devices = @(Get-YouObdAuthorizedDevices -TryWifiFallback:$AllowWifiFallback -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort)
    if ($devices.Count -eq 0) {
        throw "Nenhum dispositivo ADB autorizado encontrado (USB ou Wi-Fi em $wifiEndpoint)."
    }

    $usbDevices = @($devices | Where-Object { -not $_.IsTcp })
    $wifiDevices = @($devices | Where-Object { $_.IsTcp })

    if ($usbDevices.Count -gt 0) {
        if ($usbDevices.Count -gt 1) {
            $list = ($usbDevices | ForEach-Object { $_.Raw }) -join "; "
            throw "Mais de um dispositivo USB ADB autorizado encontrado. Informe -DeviceId. Dispositivos: $list"
        }

        $usbDevice = $usbDevices[0]
        if ($PromoteUsbToWifi) {
            try {
                $wifiDevice = Connect-YouObdAdbWifi -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort -UsbDeviceId $usbDevice.Id
                return [pscustomobject]@{
                    Id = $wifiDevice.Id
                    Raw = $wifiDevice.Raw
                    Transport = "wifi"
                    ConnectionStrategy = "usb-promoted-to-wifi"
                    WifiEndpoint = $wifiEndpoint
                    PromotionError = ""
                }
            }
            catch {
                return [pscustomobject]@{
                    Id = $usbDevice.Id
                    Raw = $usbDevice.Raw
                    Transport = "usb"
                    ConnectionStrategy = "usb-promotion-failed"
                    WifiEndpoint = $wifiEndpoint
                    PromotionError = $_.Exception.Message
                }
            }
        }

        return [pscustomobject]@{
            Id = $usbDevice.Id
            Raw = $usbDevice.Raw
            Transport = "usb"
            ConnectionStrategy = "usb-only"
            WifiEndpoint = $wifiEndpoint
            PromotionError = ""
        }
    }

    if ($wifiDevices.Count -gt 1) {
        $preferredWifi = @($wifiDevices | Where-Object { $_.Id -eq $wifiEndpoint } | Select-Object -First 1)
        if ($preferredWifi.Count -eq 1) {
            return [pscustomobject]@{
                Id = $preferredWifi[0].Id
                Raw = $preferredWifi[0].Raw
                Transport = "wifi"
                ConnectionStrategy = "wifi-already-connected"
                WifiEndpoint = $wifiEndpoint
                PromotionError = ""
            }
        }

        $list = ($wifiDevices | ForEach-Object { $_.Raw }) -join "; "
        throw "Mais de um dispositivo ADB Wi-Fi autorizado encontrado. Informe -DeviceId. Dispositivos: $list"
    }

    return [pscustomobject]@{
        Id = $wifiDevices[0].Id
        Raw = $wifiDevices[0].Raw
        Transport = "wifi"
        ConnectionStrategy = if ($wifiDevices[0].Id -eq $wifiEndpoint) { "wifi-fallback" } else { "wifi-existing-session" }
        WifiEndpoint = $wifiEndpoint
        PromotionError = ""
    }
}

function Get-YouObdAuthorizedDevices {
    param(
        [switch]$TryWifiFallback,
        [string]$WifiDeviceIp = "",
        [int]$AdbWifiPort = 0
    )

    $devices = @(Get-YouObdAdbDeviceEntries)
    if ($devices.Count -gt 0 -or -not $TryWifiFallback) {
        return $devices
    }

    try {
        Connect-YouObdAdbWifi -WifiDeviceIp $WifiDeviceIp -AdbWifiPort $AdbWifiPort | Out-Null
    }
    catch {
    }

    return @(Get-YouObdAdbDeviceEntries)
}

function Resolve-YouObdDeviceId {
    param(
        [string]$DeviceId = "",
        [switch]$AllowWifiFallback = $true,
        [string]$WifiDeviceIp = "",
        [int]$AdbWifiPort = 0,
        [switch]$PromoteUsbToWifi = $true
    )

    return (
        Resolve-YouObdDeviceConnection `
            -DeviceId $DeviceId `
            -AllowWifiFallback:$AllowWifiFallback `
            -WifiDeviceIp $WifiDeviceIp `
            -AdbWifiPort $AdbWifiPort `
            -PromoteUsbToWifi:$PromoteUsbToWifi
    ).Id
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
    Wait-YouObdForegroundPackage -DeviceId $DeviceId -PackageName $PackageName -TimeoutSeconds 10 | Out-Null
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

function Grant-YouObdRuntimePermissions {
    param(
        [string]$DeviceId,
        [string]$PackageName,
        [string[]]$Permissions = @(
            'android.permission.POST_NOTIFICATIONS',
            'android.permission.BLUETOOTH_CONNECT',
            'android.permission.BLUETOOTH_SCAN',
            'android.permission.ACCESS_FINE_LOCATION',
            'android.permission.ACCESS_COARSE_LOCATION'
        )
    )

    foreach ($permission in $Permissions) {
        try {
            Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @(
                'shell',
                'pm',
                'grant',
                $PackageName,
                $permission
            ) | Out-Null
        }
        catch {
            # Ignore permissions not requested by this build/device combination.
        }
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

function Get-YouObdForegroundPackage {
    param([string]$DeviceId)

    $patterns = @(
        "mCurrentFocus.+?\s([A-Za-z0-9._$-]+)/[A-Za-z0-9._$-]+",
        "topResumedActivity.+?\s([A-Za-z0-9._$-]+)/[A-Za-z0-9._$-]+"
    )
    $commands = @(
        @("shell", "dumpsys", "window", "windows"),
        @("shell", "dumpsys", "activity", "activities")
    )

    foreach ($arguments in $commands) {
        $output = Invoke-YouObdAdb -DeviceId $DeviceId -Arguments $arguments
        foreach ($line in $output) {
            $text = [string]$line
            foreach ($pattern in $patterns) {
                if ($text -match $pattern) {
                    return $matches[1].Trim()
                }
            }
        }
    }

    return ""
}

function Wait-YouObdForegroundPackage {
    param(
        [string]$DeviceId,
        [string]$PackageName,
        [int]$TimeoutSeconds = 12,
        [int]$PollMilliseconds = 700
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $foregroundPackage = Get-YouObdForegroundPackage -DeviceId $DeviceId
        if ($foregroundPackage -eq $PackageName) {
            return $foregroundPackage
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ((Get-Date) -lt $deadline)

    return ""
}

function Handle-YouObdPermissionPrompt {
    param(
        [string]$DeviceId,
        [int]$TimeoutSeconds = 8
    )

    $allowNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern 'Permitir|Allow|Enquanto.*uso|While using|Continuar|OK' -TimeoutSeconds $TimeoutSeconds -PollMilliseconds 600
    if ($null -eq $allowNode) {
        return $false
    }

    $center = Get-YouObdBoundsCenter -Bounds $allowNode.Bounds
    Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
    Start-Sleep -Seconds 2
    return $true
}

function Ensure-YouObdForegroundApp {
    param(
        [string]$DeviceId,
        [string]$PackageName,
        [int]$MaxAttempts = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $foregroundPackage = Get-YouObdForegroundPackage -DeviceId $DeviceId
        if ($foregroundPackage -eq $PackageName) {
            return
        }

        if ($foregroundPackage -eq "com.android.settings") {
            Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "input", "keyevent", "4") | Out-Null
            Start-Sleep -Seconds 2
            $foregroundPackage = Wait-YouObdForegroundPackage -DeviceId $DeviceId -PackageName $PackageName -TimeoutSeconds 4
            if ($foregroundPackage -eq $PackageName) {
                return
            }
        }

        if ($foregroundPackage -eq "com.google.android.permissioncontroller" -or
            $foregroundPackage -eq "com.android.permissioncontroller") {
            if (Handle-YouObdPermissionPrompt -DeviceId $DeviceId) {
                $foregroundPackage = Wait-YouObdForegroundPackage -DeviceId $DeviceId -PackageName $PackageName -TimeoutSeconds 6
                if ($foregroundPackage -eq $PackageName) {
                    return
                }
            }
        }

        Start-YouObdApp -DeviceId $DeviceId -PackageName $PackageName
        Start-Sleep -Seconds 2
        $foregroundPackage = Get-YouObdForegroundPackage -DeviceId $DeviceId
        if ($foregroundPackage -eq "com.google.android.permissioncontroller" -or
            $foregroundPackage -eq "com.android.permissioncontroller") {
            Handle-YouObdPermissionPrompt -DeviceId $DeviceId | Out-Null
        }
        $foregroundPackage = Wait-YouObdForegroundPackage -DeviceId $DeviceId -PackageName $PackageName -TimeoutSeconds 6
        if ($foregroundPackage -eq $PackageName) {
            return
        }
    }

    throw "Nao foi possivel colocar $PackageName em primeiro plano no dispositivo."
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

function Open-YouAutoCarScannerTecnico {
    param(
        [string]$DeviceId,
        [string]$PackageName = "com.youautocar.client2"
    )

    $retryAttempts = 0
    $size = Get-YouObdDisplaySize -DeviceId $DeviceId

    for ($attempt = 1; $attempt -le 8; $attempt++) {
        Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName

        $tempPath = Join-Path $env:TEMP ("youobd-scanner-" + [guid]::NewGuid().ToString("N") + ".xml")
        try {
            Save-YouObdUiDump -DeviceId $DeviceId -TargetPath $tempPath
            $uiRaw = Get-Content -LiteralPath $tempPath -Raw -Encoding utf8

            if ($uiRaw -match 'LAB_SCANNER|Leitura ativa|Persistencia|Persistência') {
                return
            }

            $scannerNode = Find-YouObdUiNode -UiDumpPath $tempPath -Pattern 'Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico'
            if ($null -ne $scannerNode) {
                $center = Get-YouObdBoundsCenter -Bounds $scannerNode.Bounds
                Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
                Start-Sleep -Seconds 4
                Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName
                $readyNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern 'LAB_SCANNER|Leitura ativa|Persistencia|Persistência|Scanner Tecnico|Scanner T..cnico' -TimeoutSeconds 12 -PollMilliseconds 800
                if ($null -ne $readyNode) {
                    return
                }
            }

            $retryNode = Find-YouObdUiNode -UiDumpPath $tempPath -Pattern 'Tentar Novamente'
            if ($null -ne $retryNode -and $retryAttempts -lt 2) {
                $center = Get-YouObdBoundsCenter -Bounds $retryNode.Bounds
                Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
                $retryAttempts++
                Start-Sleep -Seconds 18
                continue
            }

            if ($uiRaw -match 'Conectando|Despertando rede do carro|ELM327 v1.4b|PIDs suportados|Auto-conectado|ECU Pronta') {
                Start-Sleep -Seconds 8
                continue
            }

            Invoke-YouObdSwipe -DeviceId $DeviceId -X1 ([int]($size.Width * 0.50)) -Y1 ([int]($size.Height * 0.82)) -X2 ([int]($size.Width * 0.50)) -Y2 ([int]($size.Height * 0.48)) -DurationMs 300
            Start-Sleep -Seconds 2
        }
        finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -ErrorAction SilentlyContinue
            }
        }
    }

    throw "O Scanner Tecnico nao abriu corretamente."
}

function Open-YouAutoCarDiagnosticsTab {
    param(
        [string]$DeviceId,
        [string]$PackageName = "com.youautocar.client2"
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName
        Start-Sleep -Seconds 2

        $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "^Diagn" -TimeoutSeconds 12 -PollMilliseconds 900
        if ($null -eq $node) {
            $size = Get-YouObdDisplaySize -DeviceId $DeviceId
            $fallbackX = [int]($size.Width * 0.30)
            $fallbackY = [int]($size.Height * 0.90)
            Invoke-YouObdTap -DeviceId $DeviceId -X $fallbackX -Y $fallbackY
            Start-Sleep -Seconds 2
        }
        else {
            $center = Get-YouObdBoundsCenter -Bounds $node.Bounds
            Invoke-YouObdTap -DeviceId $DeviceId -X $center.X -Y $center.Y
            Start-Sleep -Seconds 3
        }

        Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName
        $readyNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "LAB_DIAGNOSTICS|Conectar ao OBD|Configura[cÃ§][oÃµ]es Bluetooth|Conectando|Ve[iÃ­]culo|Diagn[oÃ³]stico" -TimeoutSeconds 8 -PollMilliseconds 700
        if ($null -ne $readyNode) {
            return
        }
    }

    throw "Nao foi possivel localizar a aba Diagnostico do YouAutoCar."
}

function Open-YouAutoCarScannerTecnico {
    param(
        [string]$DeviceId,
        [string]$PackageName = "com.youautocar.client2"
    )

    Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName

    $readyNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Auto-conectado|ECU Pronta|Scanner ao vivo conectado|OBDLink MX\\+" -TimeoutSeconds 18 -PollMilliseconds 900
    if ($null -eq $readyNode) {
        Start-Sleep -Seconds 4
    }

    $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico" -TimeoutSeconds 8 -PollMilliseconds 700
    if ($null -eq $node) {
        $size = Get-YouObdDisplaySize -DeviceId $DeviceId
        Invoke-YouObdTap -DeviceId $DeviceId -X ([int]($size.Width * 0.82)) -Y ([int]($size.Height * 0.07))
        Start-Sleep -Seconds 2
        Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName

        $node = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 6 -PollMilliseconds 700
        if ($null -ne $node) {
            return
        }

        Invoke-YouObdSwipe -DeviceId $DeviceId -X1 ([int]($size.Width * 0.5)) -Y1 ([int]($size.Height * 0.78)) -X2 ([int]($size.Width * 0.5)) -Y2 ([int]($size.Height * 0.48)) -DurationMs 300
        Start-Sleep -Seconds 1
        Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName

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

    Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName
    $scannerNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 12 -PollMilliseconds 800
    if ($null -eq $scannerNode) {
        $retryNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Abrir Scanner Tecnico|Abrir Scanner T..cnico|Scanner Tecnico|Scanner T..cnico" -TimeoutSeconds 4 -PollMilliseconds 700
        if ($null -ne $retryNode) {
            $retryCenter = Get-YouObdBoundsCenter -Bounds $retryNode.Bounds
            Invoke-YouObdTap -DeviceId $DeviceId -X $retryCenter.X -Y $retryCenter.Y
            Start-Sleep -Seconds 4
            Ensure-YouObdForegroundApp -DeviceId $DeviceId -PackageName $PackageName
            $scannerNode = Wait-YouObdUiNode -DeviceId $DeviceId -Pattern "Leitura ativa|Sessao|Sensores|Persistencia|Scanner Tecnico" -TimeoutSeconds 12 -PollMilliseconds 800
        }
    }
    if ($null -eq $scannerNode) {
        throw "O Scanner Tecnico nao abriu corretamente."
    }
}
