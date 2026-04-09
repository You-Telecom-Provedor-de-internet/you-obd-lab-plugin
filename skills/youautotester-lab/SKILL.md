---
name: youautotester-lab
description: Work on firmware/YouAutoTester and its adjacent local lab surfaces, including the WebUI, local HTTP API, local WebSocket flows, instrument integrations, and the TestResult and Reading models. Use when the task is centered on tester firmware or its local control plane rather than the Android app or the simulator as a whole.
---

# YouAutoTester Lab

Use this skill when the tester is the product under investigation. Keep the lab control plane deterministic and preserve the meaning of `TestResult` and `Reading`.

## Primary Area

- `C:\www\YouAutoCarvAPP2\firmware\YouAutoTester`
- Local WebUI and any local HTTP or WebSocket surface owned by the tester
- Instrument adapters and acquisition flows used by the tester

## Objective

- Keep the tester predictable, scriptable, and easy to validate
- Preserve the semantic contract of `TestResult` and `Reading`
- Separate hardware acquisition concerns from presentation and reporting

## What This Skill May Touch

- Firmware code inside `firmware/YouAutoTester`
- Local API routes, local WebSocket messages, and WebUI flows owned by the tester
- Reading capture, aggregation, and reporting models
- Test fixtures or bench helpers directly tied to tester behavior

## What This Skill Must Not Touch

- Android-specific UX or ADB flows beyond contract assumptions
- Simulator-wide scenario logic unless the tester depends on it directly
- Plugin-wide routing changes unless the user explicitly asks for plugin maintenance

## Workflow

### 1. Orient the control plane

- Identify whether the task is firmware, WebUI, local API, WebSocket, or instrument integration
- Find the current shape of `TestResult` and `Reading` before changing them

### 2. Preserve contract stability

- Treat `TestResult`, `Reading`, and local event payloads as contracts
- Prefer additive changes over shape changes
- If a breaking change is necessary, document every consumer

### 3. Separate acquisition from interpretation

- Keep raw measurements distinct from derived status
- Avoid burying calibration or normalization logic inside unrelated UI code
- Preserve traceability from sensor input to stored result

### 4. Validate before claiming success

- Run the relevant build or test flow when available
- For hardware-dependent changes, distinguish simulated validation from bench validation
- If the tester feeds another project, surface the downstream contract impact

## Response Format

Prefer this structure:

1. Files created: new firmware, WebUI, API, or support files added
2. Files changed: existing tester files touched and why
3. Behavior changes: what changed in `YouAutoTester` behavior
4. Payloads/contracts: `TestResult`, `Reading`, local API, or WebSocket shapes affected
5. How to test: build, test, simulation, and bench validation steps

## Handoff Guidance

- Use `$you-orchestrator` when the change crosses repo boundaries
- Use `$you-android-gateway` when the tester depends on Android capture or IKRO transport
- Use `$you-reviewer` for regression-focused review and QA assessment
