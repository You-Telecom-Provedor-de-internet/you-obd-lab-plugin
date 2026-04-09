---
name: you-obd-simulator
description: Work on C:\www\YouSimuladorOBD with focus on profiles, modes, scenarios, DTCs, freeze frame behavior, and consistency between the simulator API and real OBD flows. Use when the task changes simulator state, diagnostic replies, oracle endpoints, or the composition of repeatable validation scenarios.
---

# You OBD Simulator

Use this skill when the simulator is the source of truth for setup and oracle behavior. Keep the API, diagnostic internals, and emitted OBD behavior coherent.

## Primary Area

- `C:\www\YouSimuladorOBD`
- Profiles, modes, scenarios, DTC injection, freeze frame, and oracle routes
- Bench validation assets that exist specifically to configure or inspect the simulator

## Objective

- Keep scenario setup repeatable
- Keep simulator API and diagnostic behavior internally coherent
- Avoid drift between simulator state, emitted OBD behavior, and downstream expectations

## What This Skill May Touch

- Profile, mode, scenario, parameter, and DTC definitions
- API endpoints or payloads that expose simulator state
- Diagnostic reply generation, freeze frame logic, and validation helpers
- Plugin docs or scripts that prepare or inspect simulator state

## What This Skill Must Not Touch

- Android or tester implementation details unless they are direct consumers of a simulator contract
- Claims of scanner compatibility based only on API success when the user asked for real OBD validation
- Cross-project contract changes without surfacing downstream impact

## Workflow

### 1. Inspect the oracle first

- Use the simulator state and diagnostic surfaces to understand the active setup
- Confirm profile, mode, scenario, DTCs, and protocol before changing behavior

### 2. Preserve consistency

- Keep API payloads aligned with emitted diagnostic behavior
- Keep scenario composition reproducible and scriptable
- Treat DTCs and freeze frame payloads as externally visible contracts

### 3. Separate internal truth from external proof

- The API is the simulator oracle
- Real OBD traffic is the compatibility proof
- Do not conflate the two when reporting results

### 4. Report the validation boundary

Always say whether the result was verified by:

- simulator API only
- simulated diagnostic flow
- external OBD consumer
- Android app or tester downstream

## Response Format

Prefer this structure:

1. Scenario proposed: profile, mode, scenario, DTCs, protocol, and intended behavior
2. Modules impacted: simulator files, APIs, diagnostic generators, or helpers touched
3. Contracts: API payloads, DTC shapes, freeze frame, and externally visible behavior
4. How to validate: oracle checks, simulated diagnostics, OBD validation, and downstream checks
5. Limitations: what is still unproven outside the simulator or depends on external consumers

## Handoff Guidance

- Use `$you-obd-android-lab` for full bench validation with Android and real adapters
- Use `$you-orchestrator` when the simulator change breaks or extends shared contracts
- Use `$you-reviewer` when the change needs regression or risk-focused review
