# Known Problems

## Resolved

### GameManager not confirmed running at startup
**Resolved 2026-05-19.** GameManager was suspected broken but was functioning correctly. Added `print("GameManager file loaded")` as the first line of the Script to make startup confirmation visible in Output.

### UI elements overlapping across all game states
**Resolved 2026-05-19.** 16 ScreenGui elements were colliding in lobby, countdown, round, and round-end states (worst case: MoneyDisplay and XPContainer fully overlapping at bottom-left, always visible). All elements repositioned to dedicated screen zones with explicit Y gaps. No remaining collisions at 1920×1080.

## Open

<!-- Add new problems here -->
