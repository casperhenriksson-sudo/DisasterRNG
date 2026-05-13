# Architectural Decisions

Format: Date | Decision | Rationale | Trade-offs

---

| Date | Decision | Rationale | Trade-offs |
|---|---|---|---|
| 2026-01-01 | Server-authoritative for all game state | Roblox client is trivially exploitable; cheaters can fire any RemoteEvent with arbitrary values | Slightly higher latency feel on movement; mitigated by client-side prediction for cosmetic effects |
| 2026-01-01 | DisasterCoins not generic "Coins" | Distinct branding separates the in-game economy from any future premium currency; avoids confusion if a Robux currency is added later | Longer variable names throughout |
| 2026-01-01 | Subagent pattern (Researcher / Critic / Builder) | Prevents blind implementation; Researcher ensures full context, Critic catches issues before they hit prod, Builder has clear spec | 3x more tokens per major change; worth it for correctness |
| 2026-01-01 | Dive system added with server validation after initial cut | Initially cut for scope; re-added when movement felt incomplete. Server validation via MovementValidator prevents i-frame abuse | Added MovementValidator dependency to DisasterManager |
| 2026-01-01 | StaminaManager as shared pool | Sprint and climb share 5 units of stamina to prevent players from having unlimited sprint AND unlimited climb independently | Single pool means aggressive climbers can't sprint; acceptable trade-off |
| 2026-01-01 | No develop branch | Auto-sync runs every 2 minutes with git pull --rebase; a second branch causes rebase conflicts when two pushes race. Single main branch with meaningful commits is safer for a 2-person team | Less isolation for experimental features; use short-lived manual branches when needed |
| 2026-01-01 | UILibrary as 29 shared components | Consistent visual language across all UIs; one change updates all screens | More files to maintain; required only when UI consistency matters |
