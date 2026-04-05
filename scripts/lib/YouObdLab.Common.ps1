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

    $output = & $FilePath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
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

    $args = @("--silent", "--show-error", "--location", "--max-time", "20")
    if (-not $AllowUnauthenticated) {
        if ([string]::IsNullOrWhiteSpace($User) -or [string]::IsNullOrWhiteSpace($Password)) {
            throw "Credenciais da API nao informadas para $url."
        }
        $args += @("--digest", "-u", "${User}:${Password}")
    }

    $methodUpper = $Method.ToUpperInvariant()
    if ($methodUpper -ne "GET") {
        $args += @("-X", $methodUpper)
    }

    if (-not [string]::IsNullOrWhiteSpace($BodyJson)) {
        $args += @("-H", "Content-Type: application/json", "--data-binary", $BodyJson)
    }

    $args += $url
    $result = Invoke-YouObdExternal -FilePath $curl -Arguments $args
    if ($result.ExitCode -ne 0) {
        $joined = ($result.Output -join "`n").Trim()
        throw "Falha consultando $url (exit $($result.ExitCode)): $joined"
    }

    return (($result.Output -join "`n").Trim())
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

function Start-YouObdApp {
    param(
        [string]$DeviceId,
        [string]$PackageName
    )

    Invoke-YouObdAdb -DeviceId $DeviceId -Arguments @("shell", "monkey", "-p", $PackageName, "-c", "android.intent.category.LAUNCHER", "1") | Out-Null
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

    return @($matches)
}

