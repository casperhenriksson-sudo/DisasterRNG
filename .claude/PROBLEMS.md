# Known Problems

Format: Severity | Issue | Workaround | Fix Priority

---

| Severity | Issue | Workaround | Fix Priority |
|---|---|---|---|
| Medium | workspace.Model missing PrimaryPart — Earthquake warning fires but CFrame anchor is unreliable | None; visually works but may offset on server lag | High |
| Medium | StaminaManager may double-drain during simultaneous sprint+climb transition | Player loses extra stamina on edge case; not exploitable | Medium |
| Low | Mid-round join UI is text-only ("Round in progress") | Acceptable for now | Low |
| Low | CLAUDE.md previously listed src/StarterGui/ as a folder; it does not exist as a filesystem path (StarterGui contents are in default.project.json Rojo mapping) | Use default.project.json as source of truth for Rojo mappings | Low |
