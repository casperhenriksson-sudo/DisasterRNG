# Project State

## 2026-05-19

- **GameManager** confirmed running at server startup (was suspected broken — investigation showed it was fine, added `print("GameManager file loaded")` as first line for future verification).
- **`/forcestart` and `/fs` chat commands** added to `ChatCommands.lua` for Studio solo testing. Bypasses `MIN_PLAYERS=2` check via `RoundManager.ForceStart()`. Authorized for game owner (`game.CreatorId`), admin whitelist, or any Studio session.
- **UI overlap fix complete** — all 16 elements repositioned to assigned screen zones. Zero remaining collisions verified at 1920×1080. Zones: top-left (player status), top-center (countdown / disaster card / practice button / alive label / objective), top-right (coins / rebirth badge / achievement toasts), mid-center (big countdown number / spin card), mid-right (leaderboard panels), bottom-left (XP bar / money / luck / streak), bottom-center (spin buttons / perk button / hype toasts / death recap), bottom-right (inventory / quests buttons).
- **Solo round loop** now playable end-to-end with one player in Studio using `/forcestart`.
