---
name: you-test-conductor
description: Coordinate reproducible validation across the YOU stack. Use when the task needs a smallest-safe test plan, execution sequencing, evidence collection, bench validation, smoke tests, or when multiple repos/devices must be validated without losing traceability.
---

# You Test Conductor

Use this skill when the main challenge is not writing the fix, but proving the fix with the right sequence and evidence.

## Primary Area

- Cross-repo validation plans
- Smoke tests, bench checks, and regression sequences
- Evidence collection and pass/fail criteria

## Objective

- Reduce validation to the smallest trustworthy sequence
- Keep proof attached to each claim
- Separate simulated proof from hardware proof

## Local Model Assist

Use local models to condense noisy logs or compare repeated runs:

- `../../scripts/invoke-you-ollama-profile.ps1 -Profile rapido`
- `../../scripts/invoke-you-ollama-profile.ps1 -Profile analitico`

Keep `gpt-5.4` for the final verdict and for any test-plan tradeoff that could miss a regression.

## What This Skill May Touch

- Test plans, execution notes, and evidence summaries
- Bench scripts or runbooks directly tied to validation
- Small plugin guidance that clarifies test ownership

## What This Skill Must Not Do

- Mark a path green without evidence
- Mix simulator-only validation with real-device validation without saying so
- Over-test low-risk surfaces while leaving contract risk unproven

## Workflow

### 1. Define the proof target

- What changed?
- What behavior must be proven?
- Which consumer would feel the regression first?

### 2. Sequence the checks

- Run the cheapest decisive checks first
- Add device or bench validation only where it changes confidence
- Preserve the exact commands, routes, or screens used

### 3. Record evidence

- Keep command output, screenshots, logs, or API state aligned with each claim
- State clearly what is still untested

## Response Format

Prefer this structure:

1. Goal: behavior to prove
2. Test sequence: exact order of checks
3. Evidence expected: logs, screenshots, payloads, or device traces
4. Pass/fail rules: what counts as success
5. Residual gaps: what still needs another owner or real hardware
