---
name: you-obd-team
description: Default multi-agent entrypoint for the YOU OBD Lab plugin. Use when the user explicitly mentions the @you-obd-lab plugin, wants the plugin itself to lead the work, or needs a real team of Codex subagents coordinating Android, YouAutoTester, YouSimuladorOBD, plugin flows, and bench validation.
---

# You OBD Team

Use this skill as the default launcher for the plugin's real multi-agent workflow.

If the user explicitly invokes the `@you-obd-lab` plugin and does not request single-agent mode, default to a real subagent team instead of handling the task as one monolithic agent.

## Team Shape

Always start with at least:

- coordinator: `you-orchestrator`
- one owning specialist: `youautotester-lab`, `you-android-gateway`, or `you-obd-simulator`
- reviewer: `you-reviewer`

Add more specialists when the task crosses ownership boundaries.

## Ownership Rules

- `youautotester-lab` owns `firmware/YouAutoTester` and tester-local contracts
- `you-android-gateway` owns Android, `ADB`, BLE, IKRO capture, and forwarding flows
- `you-obd-simulator` owns simulator scenarios, modes, DTCs, and oracle behavior
- `you-orchestrator` owns cross-project contracts, sequencing, and handoffs
- `you-reviewer` owns regression review, risk assessment, and validation gaps

Never let two specialists edit the same files at the same time.

## Launch Workflow

### 1. Open with the coordinator

- Ask `you-orchestrator` to map the task, touched modules, contracts, risks, and ownership.
- Freeze any payload, WebSocket, route, or semantic contract before implementation begins.

### 2. Spawn the minimum team

- Keep the coordinator read-heavy.
- Spawn only the specialists that own impacted modules.
- Add `you-reviewer` for an independent pass before final consolidation.

### 3. Run in parallel only when ownership is disjoint

- Parallelize firmware and Android when they touch different files and a contract is already frozen.
- Add the simulator specialist only when scenario logic, oracle validation, or API/OBD consistency is part of the task.
- If the plugin workspace itself needs changes, keep that ownership in the main thread unless a dedicated owner is introduced later.

### 4. Close every agent with a handoff

Every agent should finish with:

- objective achieved
- contract used or frozen
- files affected
- risks remaining
- next owner

## Handoff Template

Prefer this exact shape:

- Ownership:
- Contract frozen:
- Files affected:
- Validation:
- Risks:
- Next owner:

## Worktree Guidance

- Prefer `Worktree` mode for multi-agent code changes in Git repos.
- Keep `Local` for quick investigation or when the user explicitly wants foreground work only.
- Use handoff when moving work between `Local` and `Worktree`.

## Escalation

Pause and realign before parallel execution when:

- two modules need to change the same file set
- the contract is still ambiguous
- Android, simulator, and tester disagree on source-of-truth
- the user asks for a quick one-off answer rather than execution

## Output Shape

Prefer this response structure:

1. Team selected: which agents will run and why
2. Ownership: files or modules owned by each agent
3. Contracts frozen: payloads, events, or semantics that must not drift
4. Parallel work: what can safely run at the same time
5. Reviewer scope: what must be checked before closing
