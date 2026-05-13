# Project State Snapshot

*Updated manually or via /game-status command.*

## Last known commit
See `git log --oneline -1` for current.

## Features shipped
- Round state machine (Waiting → Countdown → Active → Ending → Waiting)
- Teleport system (lobby ↔ game island)
- 10 disasters: Tornado, Flood, Meteor Strike, Lightning Storm, Volcanic Eruption, Blizzard, Earthquake, Tsunami, Acid Rain, Sandstorm
- HUD: round counter, countdown, status messages, alive count
- SoundController: lobby/tension music, SFX
- Death effect: ColorCorrection desaturation
- ChatCommands: /skip (vote), /timeleft, /players, /coins
- Mid-round join detection
- PlayerRemoving cleanup
- DisasterCoins economy + daily login streaks + win milestones
- 16 achievements
- Item inventory system (Basic/Big/Mega spin tiers)
- 10 rarity tiers (Common → SECRET 0.01%)
- 17 passive + 8 active perks (PerkManager)
- StaminaManager (5-unit shared pool for sprint + climb)
- Server-authoritative dive with i-frames (MovementValidator)
- Server-authoritative wall climb with anti-cheat (MovementValidator)
- Server-authoritative sprint (SprintHandler)
- LobbyManager: practice mode, fun zones (Trampoline, Teleporter, Slide, Parkour), leaderboard
- XP/level system (15 thresholds, level 16 cap)
- UILibrary: 29 shared UI components
- EquipVisuals: aura effects on equipped items

## Stats
Run these to get current counts:
```
git log --oneline | wc -l   # commit count
Get-ChildItem src/ -Recurse -Filter *.lua | Measure-Object   # file count
```
