---
name: you-obd-android-lab
description: Use when working across C:\www\YouSimuladorOBD and C:\www\YouAutoCarvAPP2, especially to validate Android OBD flows against the ESP32 simulator, prepare test scenarios through the simulator API, inspect OBD behavior with real adapters, use ADB/logcat/screenshots on the attached phone, and compare app behavior against the simulator's internal oracle.
---

# You OBD Android Lab

Use this skill when the task spans the simulator firmware, the Android app, and the real phone or OBD adapter.

## Repositories

- Simulator firmware: `C:\www\YouSimuladorOBD`
- Android app: `C:\www\YouAutoCarvAPP2`

Read these references when needed:

- Repo map and common commands: [references/repo-map.md](references/repo-map.md)
- Simulator API as oracle: [references/api-oracle.md](references/api-oracle.md)
- Integration validation workflow: [references/validation-playbook.md](references/validation-playbook.md)

## Core Rule

Treat the simulator API as the control plane and oracle, and treat OBD over the real adapter as the compatibility plane.

- `REST/WebSocket` tells you what the simulator believes is happening.
- `OBD` tells you what a real app or scanner actually sees.
- `ADB/logcat/screenshots` tell you what the Android app rendered and how it behaved.

Do not replace real OBD validation with API-only validation when the user is testing scanner compatibility.

## Workflow

### 1. Orient quickly

- Identify whether the task is firmware, Android, or integration.
- Check both repos before assuming behavior.
- Prefer reading existing docs/endpoints before inventing new flows.

### 2. Prepare the simulator

- Use `GET /api/status` and `GET /api/diagnostics` to inspect the active protocol, profile, mode, scenario, DTCs, freeze frame, and control layers.
- Use `POST /api/profile`, `POST /api/protocol`, `POST /api/mode`, `POST /api/scenario`, `POST /api/params`, and DTC routes to prepare repeatable scenarios.
- If firmware changed, rebuild first with `pio run`; upload only when the task requires device validation.

### 3. Validate on Android

- Use `adb devices` first.
- If USB is absent, allow the lab scripts to try `ADB over Wi-Fi` on `192.168.1.99:5555`.
- If USB is present and you need cable-free validation, allow promotion with `adb tcpip 5555` followed by Wi-Fi connect.
- When the phone is attached and authorized, use `logcat`, screenshots, and app relaunches to confirm real behavior.
- Prefer the app's OBD logs over guesswork when comparing protocol or scanner behavior.

### 4. Compare the three truths

For every serious validation, compare:

1. Simulator internal state from API
2. OBD replies seen by the app or scanner
3. UI/log result on the Android device

If they disagree, report the mismatch explicitly.

### 5. Report like a lab notebook

Prefer this structure:

- Setup: protocol, profile, mode, scenario, adapter, phone/app build
- Simulator oracle: what `/api/status` and `/api/diagnostics` said
- External OBD result: what the adapter/app/scanner got
- App outcome: what the user saw
- Gap or conclusion: what matches, what still fails, what to fix next

## Strong Defaults

- For firmware validation, run `pio run` before claiming success.
- For Android validation, use the real phone when available instead of relying only on static reasoning.
- For protocol issues, separate electrical/bus issues from parser/UI issues.
- For regressions, verify whether the problem is in `CAN/K-Line`, `Mode 01/02/03/04/06/09`, or only in presentation.

## Escalation Guidance

Escalate when one of these is still ambiguous:

- The simulator API says one thing but OBD says another.
- The OBD trace is valid but the Android app renders the wrong result.
- The phone is unauthorized or disconnected and real validation cannot be trusted.
- A protocol appears to work only with one scanner and not another.

When escalating, state clearly which layer is still unproven.
