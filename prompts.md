# Prompt Templates

Copy a block, fill in the `[ ]` placeholders, paste into Claude Code.

---

## Fix a Bug

```
Bug: [one-line description]

Repro:
1. [step]
2. [step]
3. [what happens vs what should happen]

Relevant file(s): [e.g. src/server/DisasterManager.lua]

Fix the bug. Don't refactor surrounding code. Don't add error handling
beyond what's needed to close this specific issue.
```

---

## Add a New Disaster Type

```
Add a new disaster called [NAME] to src/server/DisasterManager.lua.

Behaviour:
- [what it does to the map / players]
- Duration: [X] seconds
- Visual: [describe effect - parts, beams, particles, etc.]

Rarity tier: [Common / Rare / Epic / etc.]
Spin display name: "[display name]"

Follow the exact pattern of an existing disaster (e.g. Tornado).
Register it in the disasters table with the same fields as the others.
Don't touch RoundManager, GameManager, or any disaster that already exists.
```

---

## Review a Recent Commit

```
Review the changes in [commit hash / "the last commit"].

For each changed file tell me:
1. Does the logic match the intent described in the commit message?
2. Any off-by-one errors, race conditions, or unhandled edge cases?
3. Anything that could break the round state machine
   (Waiting → Countdown → Active → Ending → Waiting)?

Flag real issues only. No style notes, no refactor suggestions.
```

---

## Add a New Chat Command

```
Add a new chat command /[name] to src/server/ChatCommands.server.lua.

What it does: [description]
Who can use it: [all players / admins only]
Arguments: [none / describe args]

Follow the same pattern as the existing commands in that file.
No new modules, no new RemoteEvents. Just the command handler.
```

---

## Refactor One Module

```
Refactor src/server/[filename].lua.

Goal: [e.g. "split into smaller functions", "remove repeated pattern X",
       "rename variables for clarity"]

Constraints:
- Public API must stay identical (same function names, same return types)
- Don't change behaviour, only structure
- Don't touch any other file
- Keep the DEBUG_MODE / dprint pattern if it's present

After refactoring, confirm the public API is unchanged.
```
