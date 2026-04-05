param(
    [string]$SimulatorBaseUrl = "http://youobd.local",
    [string]$User = "",
    [string]$Password = "",
    [int]$IntervalSeconds = 2
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "lib\YouObdLab.Common.ps1")

$apiDefaults = Get-YouObdApiCredentialDefaults
if ([string]::IsNullOrWhiteSpace($User)) { $User = $apiDefaults.User }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $apiDefaults.Password }

if (-not (Get-Command "curl.exe" -ErrorAction SilentlyContinue)) {
    throw "curl.exe nao encontrado."
}

Write-Host "Monitorando $SimulatorBaseUrl/api/status a cada $IntervalSeconds s"
Write-Host "Pressione Ctrl+C para parar."

while ($true) {
    try {
        $json = & curl.exe --silent --show-error --basic -u "${User}:${Password}" "$SimulatorBaseUrl/api/status"
        $data = $json | ConvertFrom-Json
        $line = "[{0}] proto={1} profile={2} rpm={3} speed={4} dtcs={5}" -f (
            (Get-Date -Format "HH:mm:ss"),
            $data.protocol,
            $data.profile_id,
            $data.rpm,
            $data.speed,
            (($data.dtcs | Measure-Object).Count)
        )
        Write-Host $line
    } catch {
        Write-Host ("[{0}] erro consultando status: {1}" -f (Get-Date -Format "HH:mm:ss"), $_.Exception.Message)
    }

    Start-Sleep -Seconds $IntervalSeconds
}
