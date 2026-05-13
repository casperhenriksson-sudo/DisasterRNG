Add a new disaster type. Ask the user for:
- Name (Swedish if matching existing theme, e.g. Jordbävning, Vulkanutbrott)
- Unique mechanic (1 sentence)
- Duration (seconds)
- Failure mode: instant death, damage-over-time, or ragdoll
- Visual effect description

Then:
1. Spawn 3 subagents: Researcher reads DisasterManager.lua and DisasterEffects.client.lua to understand existing patterns; Critic validates the mechanic for balance and edge cases; Builder implements.
2. Builder adds disaster to DisasterManager.lua
3. Builder adds warning UI to DisasterWarning.client.lua
4. Builder adds to the disaster pool
5. Builder provides test instructions
6. Update `.claude/TESTING.md` with new scenario
7. Commit with message: "Add [Name] disaster"

Follow server-authoritative patterns from PATTERNS.md.
