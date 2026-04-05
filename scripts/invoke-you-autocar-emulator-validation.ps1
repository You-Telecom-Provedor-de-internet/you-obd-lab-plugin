param(
    [string]$ProjectRoot = "C:\www\YouAutoCarvAPP2",
    [string]$DeviceId = "emulator-5554",
    [string]$Route = "/profile",
    [string[]]$ExpectedText = @(),
    [int]$ScrollCount = 0,
    [string]$TapLabel = "",
    [int]$TapSearchScrollCount = 0,
    [string[]]$PostTapExpectedText = @(),
    [int]$PostTapScrollCount = 0,
    [string]$CapturePrefix = "plugin-mobile-validation",
    [string]$PackageName = "com.youautocar.client2",
    [int]$ReadyTimeoutSeconds = 300,
    [switch]$SkipStaticChecks,
    [switch]$KeepFlutterRun,
    [switch]$StopExistingFlutterProcesses
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$targetScript = Join-Path $ProjectRoot "scripts\mobile-validate.ps1"
if (-not (Test-Path -LiteralPath $targetScript)) {
    throw "Script nao encontrado: $targetScript"
}

$args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $targetScript,
    "-DeviceId", $DeviceId,
    "-Route", $Route,
    "-ScrollCount", "$ScrollCount",
    "-TapLabel", $TapLabel,
    "-TapSearchScrollCount", "$TapSearchScrollCount",
    "-PostTapScrollCount", "$PostTapScrollCount",
    "-CapturePrefix", $CapturePrefix,
    "-PackageName", $PackageName,
    "-ReadyTimeoutSeconds", "$ReadyTimeoutSeconds"
)

foreach ($text in $ExpectedText) {
    $args += @("-ExpectedText", $text)
}

foreach ($text in $PostTapExpectedText) {
    $args += @("-PostTapExpectedText", $text)
}

if ($SkipStaticChecks) {
    $args += "-SkipStaticChecks"
}
if ($KeepFlutterRun) {
    $args += "-KeepFlutterRun"
}
if ($StopExistingFlutterProcesses) {
    $args += "-StopExistingFlutterProcesses"
}

Write-Host "Encaminhando validacao para $targetScript"
& powershell @args
if ($LASTEXITCODE -ne 0) {
    throw "A validacao mobile do YouAutoCarvAPP2 falhou com exit code $LASTEXITCODE."
}

