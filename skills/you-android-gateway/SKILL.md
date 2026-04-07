---
name: you-android-gateway
description: Work on Android, ADB, BLE or Bluetooth transport, the IKRO IK2029B capture path, and the gateway that forwards readings into YouAutoTester. Use when the task involves mobile execution, pairing, device logs, transport reliability, or mapping readings from the phone side into the lab stack.
---

# You Android Gateway

Use this skill when the Android device and its transport layers are the critical path. Prioritize observable evidence from `ADB`, logs, pairing state, and real reading flow over assumptions.

## Primary Area

- `C:\www\YouAutoCarvAPP2`
- Attached Android devices reached through `ADB`
- BLE or Bluetooth transport used by the gateway
- IKRO `IK2029B` capture and forwarding into `YouAutoTester`

## Objective

- Keep mobile capture and transport reproducible
- Distinguish app issues from transport, permission, or pairing issues
- Preserve the payload path from Android reading to tester ingestion

## What This Skill May Touch

- Android-side code, scripts, and diagnostics flows
- Pairing, permissions, transport mapping, and gateway payload handling
- ADB-based validation steps, log collection, and device-state diagnostics
- Small plugin docs or scripts directly related to Android gateway validation

## What This Skill Must Not Touch

- Tester-local semantics unless the change is strictly at the Android boundary
- Simulator scenario logic except for contract alignment
- Any claim of device success without evidence from `adb`, logs, screenshots, or captured readings

## Workflow

### 1. Establish device truth

- Run `adb devices` first when a real device is part of the task
- Check authorization, app install state, and log availability
- State clearly when the phone is unavailable and validation is therefore partial

### 2. Separate layers

- Distinguish UI behavior from transport behavior
- Distinguish BLE pairing from payload parsing
- Distinguish gateway forwarding from tester-side ingestion

### 3. Trace the reading path

- Capture where the reading originates
- Confirm how it is serialized, transported, and forwarded
- Compare what Android produced with what the downstream consumer expects

### 4. Report evidence

Always summarize:

- device state
- transport state
- payload or reading shape
- app outcome
- remaining uncertainty

## Response Format

Prefer this structure:

1. Gateway architecture: source, transport, forwarding path, and Android role
2. Modules affected: app layers, gateway code, device tools, or transport adapters touched
3. Contracts used: payloads, BLE messages, local transport shapes, and downstream expectations
4. Bluetooth risks: pairing, permissions, instability, or device-specific uncertainty
5. Test plan: `adb`, logcat, screenshots, capture traces, and real-device validation steps

## Handoff Guidance

- Use `$youautotester-lab` when the bug is inside tester ingestion or local APIs
- Use `$you-obd-simulator` when Android is only exposing a simulator contract mismatch
- Use `$you-orchestrator` when the fix crosses Android, plugin, simulator, or tester boundaries
