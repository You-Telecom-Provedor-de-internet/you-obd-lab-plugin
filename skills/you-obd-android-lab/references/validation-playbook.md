# Validation Playbook

## Goal

Validate simulator behavior across three planes:

1. internal simulator state
2. external OBD behavior
3. Android app behavior

## Standard Flow

### A. Prepare

- confirm protocol, profile, mode, and scenario
- inject manual DTCs or parameter changes when needed

### B. Capture internal oracle

- read `/api/status`
- read `/api/diagnostics` when testing DTCs, freeze frame, scenarios, or alerts

### C. Validate external OBD

- connect through the real adapter
- capture app OBD logs or scanner behavior
- confirm the modes and PIDs that matter

### D. Validate Android UX

- inspect the real phone via ADB
- prefer USB first, but if the phone is missing on USB use ADB over Wi-Fi on `192.168.1.99:5555`
- use screenshots or logcat when helpful
- confirm what the user actually saw

## Reporting Template

- Protocol:
- Profile:
- Mode:
- Scenario:
- Adapter:
- App build:
- Oracle result:
- OBD result:
- UI result:
- Conclusion:
