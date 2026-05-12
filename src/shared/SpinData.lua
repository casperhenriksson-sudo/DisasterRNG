local SpinData = {}

SpinData.Rarities = {
    {name = "Common",    weight = 4500, color = Color3.fromRGB(200, 200, 200)},
    {name = "Uncommon",  weight = 2500, color = Color3.fromRGB(80, 200, 80)},
    {name = "Rare",      weight = 1500, color = Color3.fromRGB(60, 120, 255)},
    {name = "Epic",      weight = 800,  color = Color3.fromRGB(160, 60, 255)},
    {name = "Legendary", weight = 350,  color = Color3.fromRGB(255, 200, 0)},
    {name = "Mythical",  weight = 150,  color = Color3.fromRGB(255, 50, 50)},
    {name = "Divine",    weight = 80,   color = Color3.fromRGB(0, 220, 255)},
    {name = "Corrupted", weight = 15,   color = Color3.fromRGB(80, 0, 120)},
    {name = "Celestial", weight = 4,    color = Color3.fromRGB(255, 100, 255)},
    {name = "Secret",    weight = 1,    color = Color3.fromRGB(255, 255, 255)},
}

SpinData.Brainrots = {
    Common = {
        {name = "Soggy Doggy Tsunami",   perk = "Sturdy"},
        {name = "Coughing Coffin Carlo", perk = "Tough"},
        {name = "Stumbling Stumpo",      perk = "SoftLanding"},
    },
    Uncommon = {
        {name = "Slippery Spaghetto Fredo", perk = "WaterLegs"},
        {name = "Bouncy Bufalo Berto",      perk = "QuickFeet"},
        {name = "Windy Wiggle Worm",        perk = "LowProfile"},
    },
    Rare = {
        {name = "Flamingo Fuego Fernando",     perk = "FireImmune"},
        {name = "Crumbling Crocodilo Secondo", perk = "Magnetic"},
        {name = "Thundering Trombone Tomasso", perk = "Featherweight"},
    },
    Epic = {
        {name = "Volcanic Vuvuzela Vittorio", perk = "SmokeBomb"},
        {name = "Seismic Serpente Silvano",   perk = "QuickRevive"},
        {name = "Gravitino Gattino",          perk = "DoubleLife"},
    },
    Legendary = {
        {name = "Bombardiro Secondo Nucleare", perk = "TeleportDash"},
        {name = "Tempesto Tralala Massimo",    perk = "TimeBubble"},
        {name = "Abyssino Crocofino",          perk = "DisasterSense"},
    },
    Mythical = {
        {name = "Terraformio Bufalone", perk = "Cloned"},
        {name = "Eclipso Gatturno",     perk = "MirrorShield"},
        {name = "Il Grande Vermicello", perk = "GroupMind"},
    },
    Divine = {
        {name = "Sancto Flamingo Eternale",   perk = "EchoShield"},
        {name = "Celestino Cane del Diluvio", perk = "ArenaGuard"},
        {name = "Angelo Bombardiro",          perk = "SemiTransparent"},
    },
    Corrupted = {
        {name = "Glitcho Serpente Corrotto", perk = "GlitchMovement"},
        {name = "Void Gattino Nero",         perk = "ChaosMagnet"},
        {name = "Il Corrotto Trombone",      perk = "ContagiousCurse"},
    },
    Celestial = {
        {name = "Cosmo Crocoflamingo",        perk = "TimeStop"},
        {name = "Universo Vermicello Finale", perk = "CosmicAura"},
        {name = "Infinito Bufalone Stellare", perk = "MirrorArena"},
    },
    Secret = {
        {name = "???", perk = "???"},
    },
}

SpinData.BonusChances = {
    {multiplier = 2,  weight = 150},
    {multiplier = 5,  weight = 60},
    {multiplier = 10, weight = 25},
    {multiplier = 20, weight = 8},
    {multiplier = 50, weight = 2},
}

return SpinData
