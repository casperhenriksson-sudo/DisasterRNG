# Code Patterns

## Conventions to follow

**Server-side validation for all client requests**
Never trust a client-fired RemoteEvent value for game state. Validate on server. See MovementValidator and SpinConnector for examples.

**DEBUG_MODE flag**
Every server module that produces log output must check `DEBUG_MODE` before printing.
```lua
local DEBUG_MODE = false
local function dprint(...) if DEBUG_MODE then print(...) end end
```

**ModuleScript exports**
Shared logic lives in `src/shared/` as ModuleScripts. Return a table of functions. Never use globals.

**RemoteEvent naming convention**
- C→S events: verb + noun (SprintRequest, DiveRequest, ClimbStartEvent)
- S→C events: noun + Event or noun + Update (RoundEvent, CurrencyUpdate, DiveGranted)
- S→All broadcasts: noun + AnnounceEvent (SecretAnnounceEvent)

**Cleanup patterns**
Always connect to `Players.PlayerRemoving` and `game:BindToClose` for any per-player state. See DataManager and RoundManager.

## Anti-patterns to avoid

- **Client trust**: Never use a client-provided value for damage, currency, or round state
- **Raw print()**: Always use dprint() or guard with DEBUG_MODE
- **Magic numbers**: Put durations, damage values, costs in a Config table or at the top of the file as named constants
- **Unbounded loops**: Every `while true do` needs a `task.wait()` or exit condition

## Branch strategy

Single `main` branch. Auto-sync handles pushes every 2 minutes.

- **Feature work**: For large changes, create a short-lived branch manually (`git checkout -b feature/name`), merge to main when done, delete branch.
- **Hotfixes**: Branch from main, fix, merge back to main.
- **Do NOT use a permanent `develop` branch** — auto-sync's `git pull --rebase` causes conflicts when two pushes race on a shared branch.
- **Releases**: Merge to main when stable. Tag with `git tag -a v0.X.0 -m "message"`, then `git push --tags`. Document in RELEASES.md.

## Release process (manual checklist)
1. `git pull` — ensure up to date
2. Review last 10 commits for anything untested
3. Run /runtests in Studio, verify pass
4. `git tag -a v0.X.0 -m "Release notes"`
5. `git push --tags`
6. Append entry to `.claude/RELEASES.md`

## Refactor checklist
1. Read target file fully before touching it
2. Identify: duplicate code, magic numbers, missing nil checks
3. Refactor without changing behavior — no new features
4. Verify against test scenarios in TESTING.md
5. Commit with description of what was cleaned (not just "refactor")
