# Disaster RNG - Roblox Game

## Game Overview
Survival game where players survive "Brainrot Disasters". Connected via Roblox Studio MCP.

## Architecture
- **ServerScriptService**: RoundManager, SpinConnector, PlayerLoader, DataManager, SpinHandler, PerkManager
- **StarterPlayerScripts**: DisasterUI, HUDController, GameFeel
- **StarterGui/GameUI**: DisasterFrame, CountdownFrame, PlayerStatus, LeaderFrame, SpinFrame, PerkButton, NotifFrame

## Disasters
Tornado, Översvämning, Meteornedslag, Blixtstorm, Vulkanutbrott, Blizzard, Jordbävning, Tsunami, Syraregn, Sandstorm

## Rarities
| Rarity    | Chance  |
|-----------|---------|
| Common    | 45%     |
| Uncommon  | 25%     |
| Rare      | 15%     |
| Epic      | 8%      |
| Legendary | 3.5%    |
| Mythical  | 1.5%    |
| Divine    | 0.8%    |
| Corrupted | 0.15%   |
| Celestial | 0.04%   |
| SECRET    | 0.01%   |

## Rules
- Always use MCP to read scripts before editing
- Batch changes to save tokens
- Never delete existing functionality
- Always fix bugs before adding features
- DisasterFrame only visible during active disaster
