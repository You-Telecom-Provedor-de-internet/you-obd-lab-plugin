param(
    [ValidateSet('rapido', 'analitico', 'pesado')]
    [string]$Profile = 'rapido',
    [string]$Model,
    [string]$Prompt,
    [string]$PromptFile,
    [string]$System,
    [string]$OllamaHost = 'http://127.0.0.1:11434',
    [switch]$AsJson,
    [switch]$ListProfiles,
    [switch]$HealthCheck
)

$profiles = @{
    rapido = @{
        model = 'qwen2.5-coder:7b'
        purpose = 'Fast code triage and operational scratchpads'
        num_ctx = 4096
    }
    analitico = @{
        model = 'deepseek-r1:8b'
        purpose = 'Comparison-heavy first-pass analysis'
        num_ctx = 8192
    }
    pesado = @{
        model = 'gpt-oss:20b'
        purpose = 'Large-log or broad-scope condensation'
        num_ctx = 8192
    }
}

function Get-OllamaResponse {
    param(
        [string]$Uri
    )

    try {
        return Invoke-RestMethod -Method Get -Uri $Uri -TimeoutSec 15
    } catch {
        throw "Ollama endpoint is unavailable at $Uri. Start Ollama first and verify the local server."
    }
}

if ($ListProfiles) {
    $profiles.GetEnumerator() |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                profile = $_.Key
                model = $_.Value.model
                purpose = $_.Value.purpose
                num_ctx = $_.Value.num_ctx
            }
        } |
        Format-Table -AutoSize
    exit 0
}

$tags = Get-OllamaResponse -Uri "$OllamaHost/api/tags"
$installedModels = @($tags.models | ForEach-Object { $_.name })

if (-not $Model) {
    $Model = $profiles[$Profile].model
}

if ($HealthCheck) {
    $result = [PSCustomObject]@{
        host = $OllamaHost
        selected_profile = $Profile
        selected_model = $Model
        model_installed = $installedModels -contains $Model
        installed_models = $installedModels
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 5
    } else {
        $result | Format-List
    }
    exit 0
}

if (-not $Prompt -and $PromptFile) {
    if (-not (Test-Path -LiteralPath $PromptFile)) {
        throw "Prompt file not found: $PromptFile"
    }
    $Prompt = Get-Content -LiteralPath $PromptFile -Raw
}

if (-not $Prompt) {
    if ([Console]::IsInputRedirected) {
        $Prompt = [Console]::In.ReadToEnd()
    } else {
        throw "Provide -Prompt, -PromptFile, or pipe text to stdin."
    }
}

if (-not ($installedModels -contains $Model)) {
    throw "Model '$Model' is not installed in Ollama. Installed models: $($installedModels -join ', ')"
}

$body = @{
    model = $Model
    prompt = $Prompt
    stream = $false
    keep_alive = '5m'
    options = @{
        num_ctx = $profiles[$Profile].num_ctx
    }
}

if ($System) {
    $body.system = $System
}

$response = Invoke-RestMethod -Method Post -Uri "$OllamaHost/api/generate" -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 10)

if ($AsJson) {
    $response | ConvertTo-Json -Depth 10
} else {
    $response.response
}
