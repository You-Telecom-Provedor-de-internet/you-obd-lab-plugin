---
name: you-orchestrator
description: Coordinate work across C:\www\YouAutoCarvAPP2, C:\www\YouSimuladorOBD, this Codex plugin, Android flows, web surfaces, and bench hardware. Use when the task spans multiple projects or devices, changes JSON payloads or WebSocket events, defines contracts, or needs cross-repo impact analysis before implementation.
---

# You Orchestrator

Use this skill as the coordination layer for the multi-skill hub. Start here when the request is architectural, contractual, or crosses project boundaries.

## Systems In Scope

- Android app: `C:\www\YouAutoCarvAPP2`
- Simulator and bench code: `C:\www\YouSimuladorOBD`
- Plugin workspace: `C:\www\you-obd-lab-plugin`
- Android device, `ADB`, BLE gateway, and bench hardware when the task depends on them
- Web surfaces or local dashboards when they are part of the end-to-end flow

## Objective

- Map end-to-end impact before editing
- Treat JSON payloads, WebSocket events, route contracts, and lab fixtures as versioned interfaces
- Push implementation into the narrowest responsible area without losing cross-project context

## What This Skill May Touch

- Cross-project architecture notes and implementation plans
- Contract definitions, payload examples, event naming, and integration glue
- Plugin routing docs, prompts, and skill guidance when the multi-skill workflow changes
- Test fixtures or validation notes that describe system boundaries

## What This Skill Must Not Touch First

- Deep feature work inside `firmware/YouAutoTester` without handing off to `$youautotester-lab`
- Android-specific execution details without checking `$you-android-gateway`
- Simulator behavior changes without checking `$you-obd-simulator`
- Final regression sign-off without a pass from `$you-reviewer` when risk is non-trivial

## Workflow

### 1. Identify the source of truth

- Name each system touched by the change
- Decide which repo or device owns each behavior
- Separate transport concerns from domain semantics

### 2. Trace the full contract

- Follow the flow from producer to consumer
- List payload fields, event names, timing assumptions, and failure paths
- Call out breaking changes explicitly

### 3. Contain the work

- Keep edits in the smallest responsible surface
- When multiple repos must change, sequence them and document dependencies
- Prefer additive contract changes before destructive ones

### 4. Report cross-impact

Always summarize:

- systems touched
- contracts changed or validated
- downstream consumers at risk
- validation still required on Android, simulator, tester, or hardware

## Response Format

Prefer this structure:

1. Objective: what the user is trying to achieve
2. Modules impacted: repos, device surfaces, services, and integration points involved
3. Contracts involved: payloads JSON, events WebSocket, routes, and ownership
4. Risks: breaking changes, downstream consumers, and validation gaps
5. Plan: recommended sequencing, handoffs, and next implementation steps

## Routing Guidance

- Use `$youautotester-lab` for `firmware/YouAutoTester`, `TestResult`, `Reading`, and tester-local APIs
- Use `$you-android-gateway` for Android, `ADB`, BLE, IKRO capture, and mobile transport issues
- Use `$you-obd-simulator` for `YouSimuladorOBD`, scenarios, DTCs, and oracle consistency
- Use `$you-reviewer` for regression review, technical risk, and QA gaps
