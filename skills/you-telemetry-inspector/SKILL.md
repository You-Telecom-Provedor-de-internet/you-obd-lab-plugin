---
name: you-telemetry-inspector
description: Inspect logs, traces, serial output, logcat, WebSocket traffic, and local telemetry across the YOU stack. Use when the task is driven by noisy evidence, timing mismatches, multi-source logs, or when you need to correlate Android, simulator, tester, and plugin events before deciding what is wrong.
---

# You Telemetry Inspector

Use this skill when the source of truth is buried in logs, traces, or timing.

## Primary Area

- `adb logcat`
- serial logs
- local HTTP or WebSocket traces
- tester or simulator telemetry
- plugin execution logs and evidence bundles

## Objective

- Turn noisy telemetry into a usable evidence timeline
- Separate symptom, cause, and coincidence
- Correlate multiple sources without flattening their differences

## Local Model Assist

This skill is the best place to use local models for draft condensation:

- `../../scripts/invoke-you-ollama-profile.ps1 -Profile rapido`
- `../../scripts/invoke-you-ollama-profile.ps1 -Profile analitico`
- `../../scripts/invoke-you-ollama-profile.ps1 -Profile pesado`

Always let `gpt-5.4` write the final diagnosis when the result could trigger code changes.

## What This Skill May Touch

- Log summaries, timing tables, and evidence notes
- Small telemetry helpers or plugin guidance for repeated inspections
- Cross-source comparisons between Android, simulator, tester, and plugin logs

## What This Skill Must Not Do

- Lose timestamps or source labels
- Treat a summary as stronger than the underlying evidence
- Merge simulator truth and external OBD truth into one undifferentiated story

## Workflow

### 1. Normalize the evidence

- Keep source labels
- Keep timestamps or relative ordering
- Keep the triggering action that produced each log burst

### 2. Build the timeline

- Find the first divergence
- Compare producer-side and consumer-side views
- Mark where the evidence becomes inferential

### 3. Report the diagnostic boundary

- State what is proven from logs
- State what still needs runtime or device confirmation

## Response Format

Prefer this structure:

1. Sources inspected: which logs or traces were used
2. Timeline: ordered key events
3. Mismatch found: where producer and consumer diverge
4. Most likely cause: evidence-backed diagnosis
5. Next proof step: the smallest runtime check to remove remaining doubt
