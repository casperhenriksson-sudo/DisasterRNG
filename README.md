# DisasterRNG

Roblox game developed with [Rojo](https://rojo.space/) for filesystem-based development and Git version control.

## Prerequisites

- [Roblox Studio](https://www.roblox.com/create) installed
- [Rojo Studio Plugin](https://www.roblox.com/catalog/13916111004) installed in Studio
- Rojo CLI installed (see below)

## Install Rojo

```bash
# Option A: using Aftman (recommended)
aftman install    # reads .aftman.toml

# Option B: manual
# Download from https://github.com/rojo-rbx/rojo/releases and add to PATH
```

## Project Structure

```
src/
├── server/    # ServerScriptService  (.server.lua = Script, .lua = ModuleScript)
├── client/    # StarterPlayerScripts (.client.lua = LocalScript)
└── shared/    # ReplicatedStorage    (.lua = ModuleScript)
```

## Sync Workflow

1. Open terminal in project root
2. Run `rojo serve`
3. Open Roblox Studio -> Plugins tab -> Rojo -> Connect
4. Edit `.lua` files in your editor -- Studio updates instantly

> Do NOT edit synced scripts in Studio while Rojo is running.

## Push to GitHub

```bash
# First time
git remote add origin https://github.com/<your-username>/DisasterRNG.git
git push -u origin main

# Every time
git add .
git commit -m "your message"
git push
```

## Build (optional)

```bash
rojo build --output DisasterRNG.rbxlx
```
