# Hybrid Local Stack 2026-04-09

## Objective

Prepare the local Windows stack on the Galaxy Book4 Ultra for a hybrid Codex workflow:

- `gpt-5.4` remains the primary reasoning and review model
- local Ollama models support triage, comparison, and first-pass operational audits
- prefer the NVIDIA RTX 4070 when the local model can use GPU offload
- do not depend on the Intel NPU

## Machine Summary

- notebook: `Galaxy Book4 Ultra`
- cpu: `Intel Core Ultra 9`
- gpu: `NVIDIA GeForce RTX 4070 Laptop`
- igpu: `Intel Arc`
- npu: `Intel AI Boost`
- ram: `32 GB`
- os: `Windows`

## Verified Tooling

- `winget`: `v1.28.220`
- `git`: `2.53.0.windows.2`
- `node`: `v24.14.1`
- `python`: `3.12.10`
- `nvidia-smi`: available
- `NVIDIA driver`: `560.94`
- `CUDA`: `12.6`

## Installed In This Round

- `Ollama 0.20.4` via `winget install --id Ollama.Ollama --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements`

Install path:

- `C:\Users\haise\AppData\Local\Programs\Ollama\ollama.exe`

## Local Models Installed

- `qwen2.5-coder:7b`
- `deepseek-r1:8b`
- `gpt-oss:20b`

Installed sizes observed with `ollama list`:

- `qwen2.5-coder:7b`: `4.7 GB`
- `deepseek-r1:8b`: `5.2 GB`
- `gpt-oss:20b`: `13 GB`

## Ollama Endpoint Validation

Validated local endpoint:

- `http://127.0.0.1:11434/api/tags`

Observed result:

- endpoint answered successfully
- installed models were listed through the API

## GPU Validation

Practical validation was executed with real inference plus GPU inspection.

Observed results:

- `qwen2.5-coder:7b` answered successfully
- `ollama ps` reported `100% GPU`
- `nvidia-smi` showed `ollama.exe` resident on the RTX 4070
- `nvidia-smi` showed about `4877 MiB` in use and `35%` GPU utilization during the run

Additional profile checks:

- `deepseek-r1:8b` answered successfully and reported `100% GPU`
- `gpt-oss:20b` answered successfully and reported mixed placement `47%/53% CPU/GPU`

Interpretation:

- `rapido` and `analitico` fit well on the 8 GB RTX 4070 path
- `pesado` works, but uses hybrid CPU/GPU offload on this machine

## Codex App Hybrid Configuration

Kept unchanged on purpose:

- `C:\Users\haise\.codex\config.toml`
  - `model = "gpt-5.4"`
  - `model_reasoning_effort = "xhigh"`

Configured for hybrid use through Codex-local integration points:

- `C:\Users\haise\.codex\AGENTS.md`
  - adds a rule that keeps `gpt-5.4` as the primary model
  - routes local-model usage to Ollama only for draft triage and operational support
- `C:\Users\haise\AppData\Local\OpenAI\Codex\bin\ollama.cmd`
  - makes `ollama` callable from Codex shells already using the Codex `bin` folder in `PATH`
- `C:\Users\haise\AppData\Local\OpenAI\Codex\bin\you-ollama-profile.cmd`
  - exposes profile-based local model calls from Codex shells
- `C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1`
  - profile wrapper for `rapido`, `analitico`, and `pesado`

Note:

- no documented direct local-provider key was found in the current local Codex app configuration files during this round
- hybrid operation was therefore wired safely through Codex shell wrappers plus plugin skills, while preserving the default `gpt-5.4` model selection

## Profile Map

- `rapido` -> `qwen2.5-coder:7b`
- `analitico` -> `deepseek-r1:8b`
- `pesado` -> `gpt-oss:20b`

Example commands:

```powershell
you-ollama-profile analitico -Prompt "Compare these payloads and list contract drift."
```

```powershell
powershell -ExecutionPolicy Bypass -File "C:\www\you-obd-lab-plugin\scripts\invoke-you-ollama-profile.ps1" -Profile rapido -Prompt "Summarize these logs in 5 bullets."
```

## Plugin Changes Introduced

New skills added:

- `you-monorepo-auditor`
- `you-contract-guardian`
- `you-test-conductor`
- `you-telemetry-inspector`

The new skills are designed to stay coherent with:

- `you-orchestrator`
- `you-android-gateway`
- `you-obd-simulator`
- `youautotester-lab`
- `you-reviewer`

## Known Limits

- `gpt-oss:20b` does not fit fully in 8 GB of VRAM on this notebook, so expect mixed CPU/GPU placement
- local-model output must still be reviewed by `gpt-5.4` before risky edits or contract sign-off
