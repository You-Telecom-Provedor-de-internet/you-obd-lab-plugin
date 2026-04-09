---
name: you-contract-guardian
description: Guard payloads, route contracts, WebSocket events, and state handoffs across the YOU stack. Use when the task changes JSON fields, route parameters, websocket messages, DTOs, API responses, or when drift between producer and consumer is the main risk.
---

# You Contract Guardian

Use this skill when the dangerous part of the task is semantic drift between producer and consumer.

## Primary Area

- JSON payloads
- WebSocket events
- HTTP routes and parameters
- DTOs, state snapshots, and cross-repo message shapes

## Objective

- Freeze the contract before implementation spreads
- Surface breaking changes early
- Keep producer and consumer evidence aligned

## Local Model Assist

For large payload or log diffs, use a local draft pass first:

- `../../scripts/invoke-you-ollama-profile.ps1 -Profile analitico`
- `../../scripts/invoke-you-ollama-profile.ps1 -Profile pesado`

Use `gpt-5.4` to approve the final contract interpretation and migration plan.

## What This Skill May Touch

- Contract inventories, payload examples, and compatibility notes
- Additive migration guidance and producer/consumer mapping
- Plugin skill or prompt guidance when ownership boundaries are unclear

## What This Skill Must Not Do

- Rename fields casually without listing every consumer
- Claim a contract is safe without naming proof
- Let UI wording hide a backend or transport change
- Let a human code such as `os_code` compete with a canonical UUID such as `service_order_id` without stating which one wins

## Workflow

### 1. Freeze the surface

- List the producer
- List the consumer
- List the exact field, event, or route shape involved

### 2. Compare old and new meaning

- Separate additive changes from breaking changes
- Note ordering, nullability, and timing assumptions
- Call out fields that are optional in code but required in practice
- If UUID and human code coexist, state which field is canonical, which is fallback, and where consumers promote the canonical value

### 3. Define proof

- Name which tests, traces, or logs prove the contract
- State what is still inferred rather than validated

## Response Format

Prefer this structure:

1. Contract surface: producer, consumer, and boundary type
2. Current shape: fields, semantics, defaults, and timing assumptions
3. Risk of drift: breaking changes, partial migrations, or silent mismatches
4. Safe path: additive migration or guarded rollout plan
5. Proof required: logs, tests, API calls, or device evidence needed
