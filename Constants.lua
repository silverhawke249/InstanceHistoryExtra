local _, env = ...

local consts = {}

consts.histReapTime = 24*60*60 -- 1 day
consts.histLimit = 30 -- instances per day
consts.histLimitHourly = 5 -- instances per hour
consts.maxdiff = 33 -- max number of instance difficulties
consts.prefix = "instHistory"

consts.thisToon = UnitName("player") .. " - " .. GetRealmName()
consts.transInstance = {
    -- lockout hyperlink id = LFDID
    [543] = 188,     -- Hellfire Citadel: Ramparts
    [540] = 189,     -- Hellfire Citadel: Shattered Halls : deDE
    [542] = 187,  -- Hellfire Citadel: Blood Furnace esES
    [534] = 195,     -- The Battle for Mount Hyjal
    [509] = 160,     -- Ruins of Ahn'Qiraj
    [557] = 179,  -- Auchindoun: Mana-Tombs : ticket 72 zhTW
    [556] = 180,  -- Auchindoun: Sethekk Halls : ticket 151 frFR
    [568] = 340,  -- Zul'Aman: frFR
    [1004] = 474, -- Scarlet Monastary: deDE
    [600] = 215,  -- Drak'Tharon: ticket 105 deDE
    [560] = 183,  -- Escape from Durnholde Keep: ticket 124 deDE
    [531] = 161,  -- AQ temple: ticket 137 frFR
    [1228] = 897, -- Highmaul: ticket 175 ruRU
    [552] = 1011, -- Arcatraz: ticket 216 frFR
    [1516] = 1190, -- Arcway: ticket 227/233 ptBR
    [1651] = 1347, -- Return to Karazhan: ticket 237 (fake LFDID)
    [545] = 185, -- The Steamvault: issue #143 esES
    [1530] = 1353, -- The Nighthold: issue #186 frFR
    [585] = 1154, -- Magisters' Terrace: issue #293 frFR
}

consts.texture = "Interface/RaidFrame/Raid-Bar-Hp-Fill"
consts.colors = {{r=145, g=19, b=15}, {r=255, g=255, b=255}}

consts.authorInfo = "Forked from \"Instance History\" WeakAura by Silverhawke."

env.c = consts
