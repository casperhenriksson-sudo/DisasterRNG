-- QuestData: Daily Quest pool with 3 tiers
local QuestData = {}

QuestData.Quests = {
    -- Easy (weight 40, reward 100 DC)
    { id="play3rounds",   tier="Easy",   type="roundPlayed",      goal=3,   reward=100,  label="Play 3 rounds" },
    { id="survive1",      tier="Easy",   type="disasterSurvived", goal=1,   reward=100,  label="Survive 1 disaster" },
    { id="time5min",      tier="Easy",   type="timeInGame",       goal=300, reward=100,  label="Spend 5 minutes in game" },
    { id="sprint10",      tier="Easy",   type="sprintUsed",       goal=10,  reward=100,  label="Use sprint 10 times" },
    -- Medium (weight 40, reward 300 DC)
    { id="survive5",      tier="Medium", type="disasterSurvived", goal=5,   reward=300,  label="Survive 5 disasters" },
    { id="win1",          tier="Medium", type="roundWon",         goal=1,   reward=300,  label="Win 1 round" },
    { id="earn200dc",     tier="Medium", type="dcEarned",         goal=200, reward=300,  label="Earn 200 DC from gameplay" },
    { id="tornado1",      tier="Medium", type="tornadoSurvived",  goal=1,   reward=300,  label="Survive a Tornado" },
    { id="tsunami1",      tier="Medium", type="tsunamiSurvived",  goal=1,   reward=300,  label="Survive a Tsunami" },
    -- Hard (weight 20, reward 1000 DC)
    { id="win3",          tier="Hard",   type="roundWon",         goal=3,   reward=1000, label="Win 3 rounds" },
    { id="survive10row",  tier="Hard",   type="surviveStreak",    goal=10,  reward=1000, label="Survive 10 disasters in a row" },
    { id="earn1000dc",    tier="Hard",   type="dcEarned",         goal=1000,reward=1000, label="Earn 1000 DC in one day" },
    { id="equip_rare",    tier="Hard",   type="equipRarePlus",    goal=1,   reward=1000, label="Equip a Rare+ item" },
    { id="nodamage1",     tier="Hard",   type="noDamageRound",    goal=1,   reward=1000, label="Survive a round with no damage" },
}

QuestData.TierWeight = { Easy=40, Medium=40, Hard=20 }
QuestData.RARE_PLUS = {"Rare","Epic","Legendary","Mythical","Divine","Corrupted","Celestial","Secret"}

-- Lookup by id
QuestData.ById = {}
for _, q in ipairs(QuestData.Quests) do
    QuestData.ById[q.id] = q
end

-- Group by tier
QuestData.ByTier = { Easy = {}, Medium = {}, Hard = {} }
for _, q in ipairs(QuestData.Quests) do
    table.insert(QuestData.ByTier[q.tier], q)
end

return QuestData
