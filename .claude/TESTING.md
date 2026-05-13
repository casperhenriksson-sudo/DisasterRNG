# Testing

## How to run tests
1. Open Studio, ensure Rojo is connected (localhost:34872)
2. Test > Server & Clients > 2 players
3. In Studio server console: type /runtests (owner only — gated on game.CreatorId)
4. For manual tests: follow scenarios below

## TestRunner location
`src/server/Tests/TestRunner.lua` — server-only, never runs in production unless triggered

## Manual Test Scenarios

| Scenario | Expected Behavior | Last Tested |
|---|---|---|
| Sprint stamina drain | Stamina drops from 5→0 over ~5s of continuous sprint; stops draining at 0 | — |
| Climb stamina drain | Climbing drains same pool as sprint; cannot climb with 0 stamina | — |
| Dive i-frames during disaster | Player in dive animation takes no damage from disasters for duration | — |
| SECRET rarity announcement | All-server chat message fires; item awarded; no duplicate announcement | — |
| Round flow with 2 players | Countdown starts at 2 players, teleport occurs, disaster spawns, round ends, return to lobby | — |
| Round flow with 4+ players | Same as above; alive count decrements correctly | — |
| Mid-round join | Player joining during Active state sees "Round in progress", stays in lobby | — |
| Player disconnect during round | PlayerRemoving fires, alive count decrements, round can still end | — |
| DataStore persistence | DC balance, inventory, XP persist across server restart | — |
| Daily login streak | First login awards base DC; consecutive days increment streak bonus | — |
| Spin rarity distribution | Over 1000 spins, SECRET appears ~0.01% of the time (statistical) | — |
| Spin DC deduction | Correct DC cost deducted per spin tier before result | — |
