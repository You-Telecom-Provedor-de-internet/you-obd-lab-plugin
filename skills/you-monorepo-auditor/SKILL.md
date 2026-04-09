---
name: you-monorepo-auditor
description: Audit cross-repo impact across C:\www\YouAutoCarvAPP2, C:\www\YouSimuladorOBD, and C:\www\you-obd-lab-plugin. Use when the task starts with "what changed", "what is affected", "where does this live", "what are the risky consumers", or needs a fast first-pass monorepo inventory before implementation.
---

# You Monorepo Auditor

Use this skill when the first problem is orientation across multiple YOU repos. The goal is to build a fast impact map without confusing ownership.

## Primary Area

- `C:\www\YouAutoCarvAPP2`
- `C:\www\YouSimuladorOBD`
- `C:\www\you-obd-lab-plugin`

## Objective

- Map which repo owns each behavior
- Find downstream consumers before edits start
- Separate first-pass inventory from final technical judgment

## Local Model Assist

For large inventories, use the local profile helper for a draft summary:

- `../../scripts/invoke-you-ollama-profile.ps1 -Profile rapido`
- `../../scripts/invoke-you-ollama-profile.ps1 -Profile analitico`

Keep `gpt-5.4` as the final reviewer for any ownership, risk, or change recommendation.

## What This Skill May Touch

- Repo maps, architecture notes, and change inventories
- Quick ownership summaries and dependency traces
- Plugin routing guidance when a task spans the whole YOU stack

## What This Skill Must Not Do

- Freeze a cross-repo contract without handing off to `$you-orchestrator`
- Treat a local-model draft as final truth
- Claim validation happened when this pass only inspected code and docs

## Workflow

### 1. Inventory the touched systems

- Name each repo or device surface involved
- Find the likely owner for each behavior
- Separate app logic, simulator logic, plugin logic, and tester logic

### 2. Build the dependency map

- Trace producers and consumers
- Note payload boundaries, route boundaries, and test surfaces
- Mark unclear ownership explicitly

### 3. Escalate the right owner

- Route contract work to `$you-orchestrator`
- Route tester-local work to `$youautotester-lab`
- Route Android transport work to `$you-android-gateway`
- Route simulator-state work to `$you-obd-simulator`

## Response Format

Prefer this structure:

1. Systems touched: repos, devices, and surfaces involved
2. Ownership map: which repo owns which behavior
3. Likely consumers: downstream files, modules, or devices at risk
4. Unknowns: gaps that still need direct inspection
5. Recommended handoff: which skill should own the next step
