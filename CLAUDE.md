# Disaster RNG - Roblox Game

Roblox game developed by 2-person team using Rojo + GitHub workflow.

## Project Structure
- **Lobby**: large island around 0,0,0 (palm trees, safe zone)
- **Game island**: smaller isolated island around 500,0,0 (where disasters spawn)
- **Repository**: github.com/casperhenriksson-sudo/DisasterRNG
- **Local path**: C:\Users\caspe\Desktop\DisasterRNG

## Folder Structure
- `src/server/` - ServerScriptService (RoundManager, LobbyManager, DisasterManager, SpinConnector, PlayerLoader, DataManager, SpinHandler, PerkManager, ChatCommands)
- `src/client/` - StarterPlayerScripts (DisasterUI, HUDController, GameFeel, CountdownDisplay, SoundController)
- `src/shared/` - ReplicatedStorage modules (SpinData, UIs/UILibrary)
- `src/StarterGui/` - StarterGui UI (DisasterFrame, CountdownFrame, PlayerStatus, LeaderFrame, SpinFrame)

## Round State Machine
Waiting -> Countdown (10s) -> Active -> Ending -> Waiting
- Min 2 players to start countdown
- Players teleport to game island on RoundStart
- Disasters spawn ONLY on game island
- Survivors teleport back to lobby on RoundEnd
- Mid-round joiners see "Round in progress" and wait in lobby

## Rarities (Spin System)
Common 45%, Uncommon 25%, Rare 15%, Epic 8%, Legendary 3.5%, Mythical 1.5%, Divine 0.8%, Corrupted 0.15%, Celestial 0.04%, SECRET 0.01%

## Disasters
Tornado, Översvämning, Meteornedslag, Blixtstorm, Vulkanutbrott, Blizzard, Jordbävning, Tsunami, Syraregn, Sandstorm

## Features Implemented
- Round state machine with guards (no race conditions)
- Teleport system (lobby <-> game island)
- HUD: round counter, big countdown numbers, status messages, alive count
- SoundController: lobby music, tension music, SFX (countdown beeps, fanfares, death sounds)
- Death effect: ColorCorrection (Saturation -1, red tint) over 1.2s
- ChatCommands: /skip (majority vote), /timeleft, /players
- Mid-round join detection
- PlayerRemoving cleanup (handles disconnects)
- Security: server-side luckMultiplier clamping in SpinConnector
- DEBUG_MODE flag in RoundManager and DisasterManager (dprint helper)

## Development Rules
- Spawn 3 subagents (Researcher, Critic, Builder) for major changes
- Batch all tool calls
- No unnecessary explanations
- Edit files in src/ - Rojo syncs to Studio automatically (~1-2s)
- Use bypassPermissions / auto-approve all
- Commit each logical change separately with clear messages

## Workflow
- **Local dev**: Auto-sync runs in background. Edit files. Done.
- **Remote dev (via Claude Code Remote)**: Editing src/ files, commits push to GitHub. Local pulls automatically next sync.
- **Testing**: Open Studio, Rojo auto-connected, click Test > Server & Clients > 2 players

## Fully Automated Sync
Background sync runs 24/7 - no manual action needed.
- Rojo auto-starts on Windows login (scheduled task)
- Syncs every 2 minutes: push local + pull remote
- Auto-restarts Rojo if it crashes
- To disable: run uninstall-autostart.ps1 in repo root
- To re-enable: run install-autostart.ps1 in repo root

## Known TODOs / Follow-ups
- Set PrimaryPart on workspace.Model (game island) - Earthquake warning
- Consider: visual indicator for mid-round joiners (currently text-only)
- Future: perk system using SpinHandler/PerkManager
- Future: currency shop, leaderboard persistence

## Test Commands (Studio)
1. Test > Server & Clients > 2 players
2. Both spawn in lobby
3. Countdown starts (10s)
4. Teleport to game island
5. Disaster spawns, players die
6. Round ends, return to lobby
