# Architecture

## Folder Structure

```
src/
  server/         — ServerScriptService (16 modules)
  client/         — StarterPlayerScripts (18 scripts)
  shared/         — ReplicatedStorage (SpinData + UILibrary)
```

### Server modules
| Module | Role |
|---|---|
| GameManager | Entry point — requires and wires all server systems |
| RoundManager | Core round state machine |
| DisasterManager | 10 disaster implementations |
| LobbyManager | Lobby spawning, practice mode, fun zones, leaderboard |
| DataManager | DataStore wrapper, player data cache |
| CurrencyManager | DisasterCoins economy, daily login streaks, win milestones |
| SpinConnector | Handles SpinEvent (legacy) and SpinRequestEvent (tier-based) |
| SpinHandler | Weighted rarity RNG, tier guarantees |
| InventoryManager | Inventory read/write, equip handling |
| PerkManager | 17 passive + 8 active perks |
| AchievementManager | 16 achievement definitions + per-round checks |
| StaminaManager | Shared 5-unit stamina pool (sprint + climb) |
| MovementValidator | Server-authoritative dive i-frames + wall climb anti-cheat |
| SprintHandler | Server-authoritative sprint via SprintRequest |
| PlayerLoader | Loads data on join, creates GetData RemoteFunction |
| ChatCommands | /skip, /timeleft, /players, /coins |

## Round State Machine

```
Waiting ──(≥2 players)──► Countdown (10s) ──► Active ──► Ending ──► Waiting
                                                  │
                              (disasters spawn only on game island at 500,0,0)
```
- Lobby: large island at 0,0,0
- Game island: smaller island at 500,0,0
- Mid-round joiners: held in lobby, see "Round in progress"

## Service Interactions

```
GameManager
  ├── RoundManager ──► DataManager, PerkManager, DisasterManager
  │                ──► CurrencyManager, AchievementManager
  │                ──► fires: RoundEvent
  ├── InventoryManager ──► DataManager
  │                    ──► fires: EquipEvent, EquipUpdateEvent
  ├── MovementValidator ──► StaminaManager
  │                     ──► fires: DiveGranted, ClimbStopEvent
  └── StaminaManager (shared with SprintHandler)

SpinConnector ──► SpinData, SpinHandler, PerkManager
              ──► CurrencyManager, DataManager, RoundManager
              ──► fires: SpinResultEvent, SecretAnnounceEvent

PlayerLoader ──► DataManager, PerkManager, CurrencyManager
             ──► creates: GetData (RemoteFunction)
             ──► fires: EquipUpdateEvent

LobbyManager ──► DataManager
             ──► fires: LobbyEvent
```

## RemoteEvent Map

| Name | Direction | Purpose |
|---|---|---|
| RoundEvent | S→C | All round state messages |
| DisasterEvent | S→C | Fog, warnings, clearEffects |
| SpinEvent | C→S | Legacy brainrot spin |
| SpinRequestEvent | C→S | Tier-based spin request |
| SpinResultEvent | S→C | Spin result |
| SecretAnnounceEvent | S→All | SECRET rarity announcement |
| CurrencyUpdate | S→C | DC balance update |
| PerkEvent | Bidirectional | Perk notifications + client activation |
| AchievementEvent | S→C | Achievement earned |
| LobbyEvent | S→C | playerJoined, roundSoon, leaderboard, practice |
| LobbyRequest | C→S | startPractice |
| EquipEvent | C→S | Equip/unequip item |
| EquipUpdateEvent | S→All | Broadcast equipped state |
| SprintRequest | C→S | Start/stop sprint |
| DiveRequest | C→S | Request dive |
| DiveGranted | S→C | Confirm dive + cooldown |
| ClimbStartEvent | C→S | Start climbing |
| ClimbHeartbeat | C→S | Anti-cheat position tick |
| ClimbStopReq | C→S | Stop climbing |
| ClimbStopEvent | S→C | Force stop (no_stamina / teleport / no_surface) |

**RemoteFunctions:**
| Name | Created by | Purpose |
|---|---|---|
| GetData | PlayerLoader | Money, luck, rebirth, DC, equipped, inventoryCount |
| GetInventory | InventoryManager | Full inventory table (5s throttle) |
