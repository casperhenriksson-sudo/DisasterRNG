# Disaster RNG — Project Overview

## Working with this project

1. **Always run `pwd` first.** Confirm you're in the DisasterRNG project root (contains `src/`, `default.project.json`) before touching any files.

2. **Spawn subagents only for large tasks.** Large = new feature spanning 3+ files, full module refactor, or new system from scratch. For bug fixes, single command additions, and config tweaks: do it directly, no subagents.

3. **Don't proactively suggest infrastructure improvements.** No new tools, automation, slash commands, GitHub Actions, or workflow changes unless explicitly asked.

4. **When scope is unclear, ask one question.** Don't guess big and over-deliver. One short clarifying question is better than building the wrong thing.

5. **After completing work, list exactly what changed.** Name every file that was modified/created and state the exact commit message(s). No high-level summaries.

6. **Treat Toolbox-imported models as untrusted.** Before doing anything else with a model from the Toolbox, scan all scripts inside it for: `require(x.Value)` patterns, `game.JobId == ""` guards, `script:Destroy()` anti-Studio patterns. Flag any matches as potential malware before proceeding.

AI-assisted Roblox game developed by a 2-person team using Rojo + GitHub workflow. Players survive randomized disasters on a game island while spending DisasterCoins on a gacha spin system for cosmetic items and perks. Server-authoritative architecture throughout — no client trust.

## Start every major session by reading:
- `.claude/ARCHITECTURE.md` — how systems connect
- `.claude/PROBLEMS.md` — known issues before touching anything
- `.claude/PATTERNS.md` — code conventions and branch rules

## Reference files:
- `.claude/DECISIONS.md` — why things are built the way they are
- `.claude/ROADMAP.md` — what's next
- `.claude/TESTING.md` — manual test scenarios
- `.claude/PROJECT_STATE.md` — current feature snapshot
