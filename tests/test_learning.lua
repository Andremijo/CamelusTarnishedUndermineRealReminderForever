-- Tests for deciding which bosses drop a Real when the game won't tell the
-- addon a boss's level: Wowhead's levels (ns.BOSS_LEVELS), Ring of the Law's
-- challenger, and learning from a corpse with no Real.
local ADDON_DIR = ADDON_DIR or "TarnishedRealReminder/"
local REAL, REAL_ID = "Tarnished Undermine Real", 213372 -- stand-in ID for the test

local passed, failed = 0, 0
local function check(cond, label)
    if cond then passed = passed + 1 else failed = failed + 1; print("FAIL: " .. label) end
end

local ns = {}
for line in io.lines(ADDON_DIR .. "TarnishedRealReminder.toc") do
    local file = line:match("^([%w_%-%.\\/]+%.lua)%s*$")
    if file then assert(loadfile(ADDON_DIR .. file:gsub("\\", "/")))("TarnishedRealReminder", ns) end
end
T.instance = { name = "Blackrock Depths", type = "party", id = 230 }
T.fire("ADDON_LOADED", "TarnishedRealReminder")
T.fire("PLAYER_ENTERING_WORLD")
T.advance(3.5)
local DB, CDB = ns.DB, ns.CDB

local n = 0
-- unitName: the name boss1 shows (nil = no boss frame at all).
local function kill(name, level, unitName)
    n = n + 1
    local guid = "G" .. n
    if unitName ~= false then
        T.units.boss1 = { name = unitName or name, level = level, guid = guid }
    end
    T.fire("ENCOUNTER_START", n, name, 1, 5)
    T.advance(1.5)
    T.fire("ENCOUNTER_END", n, name, 1, 5, 1)
    T.units.boss1 = nil
    T.advance(0.5)
    return guid
end
local function openCorpse(guid, items)
    T.loot, T.lootSource = items, guid
    T.fire("LOOT_READY")
    for _, it in ipairs(items) do
        if it.name == REAL then T.addToBags(REAL, REAL_ID, it.qty or 1); T.fire("BAG_UPDATE_DELAYED"); T.advance(0.3) end
    end
    T.loot = {}
    T.fire("LOOT_CLOSED")
    T.advance(1)
end
local function nextDay()
    T.server = T.resetAtServer + 10
    T.resetAtServer = T.resetAtServer + 86400
    ns.checkDailyReset()
end
local function enter(name, id)
    T.instance = { name = name, type = "party", id = id }
    T.fire("PLAYER_ENTERING_WORLD")
    T.advance(3.5)
end
local function row(groupName, name)
    for _, g in ipairs(ns.Roster.Build()) do
        if g.name == groupName then
            for _, r in ipairs(g.rows) do
                for _, nm in ipairs(r.names) do if nm == name then return r end end
            end
        end
    end
end
local function total(groupName)
    for _, g in ipairs(ns.Roster.Build()) do if g.name == groupName then return g.total end end
end

-------------------------------------------------------------------------------
-- Wowhead's levels decide when the game hides the level.
kill("High Interrogator Gerstahn", SECRET)
check(#CDB.pending == 0, "Gerstahn (52 on Wowhead), level hidden: no reminder")
kill("Pyromancer Loregrain", nil, false)
check(#CDB.pending == 0, "Loregrain (52, not on the drop list), no boss frame at all: no reminder")
kill("Magmus", SECRET)
check(#CDB.pending == 1, "Magmus (57), level hidden: reminder")
ns.dismissAll()

-- The drop list (Wowhead's Forever data): Bael'Gar (54) and Lord Incendius
-- drop a Real although they're near or below 55.
kill("Bael'gar", SECRET)
check(#CDB.pending == 1, "Bael'Gar (54, on the drop list): reminder")
kill("Lord Incendius", 53)
check(#CDB.pending == 2, "Lord Incendius (on the drop list), even read as 53: reminder")
r = row("Blackrock Depths", "Bael'gar")
check(r.status == "waiting", "checklist counts Bael'Gar")
ns.dismissAll()
-- Not on the list and a rare, summoned or unknown boss: no reminder.
kill("Panzor the Invincible", 57)
kill("Black Guard Swordsmith", 61)
check(#CDB.pending == 0, "rare Panzor (57) and unknown Black Guard Swordsmith (61): no reminder")
r = row("Blackrock Depths", "Panzor the Invincible")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "not on the drop list", "checklist: Panzor not on the drop list")
-- Not on the list but a regular 55+ boss: still reminds (the list may lack reports).
enter("Stratholme", 329)
kill("Balnazzar", 62)
check(#CDB.pending == 1, "Balnazzar (regular boss, not on the list): still reminds")
ns.dismissAll()
-- The new dungeons aren't covered by the list.
enter("Blackmaw Hold", 99902)
kill("Mystery Blackmaw Boss", nil, false)
check(#CDB.pending == 1, "unknown boss in a new dungeon: reminds (never miss a Real)")
ns.dismissAll()
CDB.looted = {}
DB.knownBosses["Blackmaw Hold"] = nil
enter("Blackrock Depths", 230)
local r = row("Blackrock Depths", "Houndmaster Grebmar")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "level 52, no Real", "checklist: Grebmar level 52, no Real")
r = row("Blackrock Depths", "High Interrogator Gerstahn")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Gerstahn drops no Real")
r = row("Blackrock Depths", "Phalanx")
check(r.level == 55 and r.status == "todo", "Phalanx (55) counts")

-- Ribbly Screwspigot (53): reported as a boss in game, confirmed no Real.
kill("Ribbly Screwspigot", SECRET)
kill("Ribbly Screwspigot", nil, false)
check(#CDB.pending == 0, "Ribbly never reminds (confirmed no Real)")
r = row("Blackrock Depths", "Ribbly Screwspigot")
check(r and r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Ribbly drops no Real")
-- Plugger Spazzring (55): reported as a boss in game, confirmed no Real, even
-- with his level 55 read.
kill("Plugger Spazzring", 55)
kill("Plugger Spazzring", SECRET)
check(#CDB.pending == 0, "Plugger never reminds (confirmed no Real, though level 55)")
r = row("Blackrock Depths", "Plugger Spazzring")
check(r and r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Plugger drops no Real")

-- Chest of the Seven: a chest, not a boss. Neither the encounter nor any of
-- the seven dwarves (level 55-57) reminds.
kill("Chest of the Seven", SECRET)
kill("The Seven", 57, "Doom'rel")
kill("Hate'rel", 55)
check(#CDB.pending == 0, "Chest of the Seven and its dwarves never remind")

-- Hearthsinger Forresten (Stratholme): confirmed in game, no Real.
enter("Stratholme", 329)
kill("Hearthsinger Forresten", 60)
kill("Hearthsinger Forresten", SECRET)
check(#CDB.pending == 0, "Hearthsinger Forresten never reminds (confirmed no Real)")
r = row("Stratholme Live", "Hearthsinger Forresten")
check(r and r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Forresten drops no Real")
kill("Crimson Hammersmith", 60)
kill("Crimson Hammersmith", SECRET)
check(#CDB.pending == 0, "Crimson Hammersmith never reminds (confirmed no Real)")
r = row("Stratholme Live", "Crimson Hammersmith")
check(r and r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Crimson Hammersmith drops no Real")
enter("Blackrock Depths", 230)

-- High Interrogator Gerstahn and Lord Roccor: confirmed in game, no Real,
-- whatever level is read (even a wrong 58).
kill("High Interrogator Gerstahn", 58)
kill("Lord Roccor", 58)
check(#CDB.pending == 0, "Gerstahn and Roccor never remind (confirmed no Real)")
r = row("Blackrock Depths", "Lord Roccor")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: Roccor drops no Real")

-- Fineous Darkvire is level 54 but confirmed in game to drop a Real: he
-- always reminds, whatever his level.
kill("Fineous Darkvire", 54)
check(#CDB.pending == 1, "Darkvire (54, confirmed Real): reminder")
r = row("Blackrock Depths", "Fineous Darkvire")
check(r.level == 54 and r.status == "waiting", "checklist counts Darkvire")
ns.dismissAll()

-- For bosses without such evidence, Wowhead's level beats anything read in
-- game (Houndmaster Grebmar, 52, not on the drop list):
--   an add at a higher level on another boss frame,
T.units.boss2 = { name = "Ironhand Guardian", level = 58, guid = "G-add" }
kill("Houndmaster Grebmar", SECRET)
T.units.boss2 = nil
check(#CDB.pending == 0, "Grebmar with a level-58 add: no reminder")
--   a wrong level read for him,
kill("Houndmaster Grebmar", 58)
check(#CDB.pending == 0, "Grebmar read as 58: no reminder (Wowhead says 52)")
--   or a wrong level stored by an older version.
DB.bossLevels["houndmaster grebmar"] = 58
kill("Houndmaster Grebmar", nil, false)
check(#CDB.pending == 0, "Grebmar with a stale stored level 58: no reminder")
r = row("Blackrock Depths", "Houndmaster Grebmar")
check(r.level == 52 and r.status == "low", "checklist shows Wowhead's 52, not the stored 58")

-- A below-55 boss that does give a Real is learned: no reminder the first
-- time, but the Real is recorded, and from then on it reminds.
nextDay()
local pyro = kill("Pyromancer Loregrain", SECRET)
check(#CDB.pending == 0, "Loregrain (52): no reminder the first time")
openCorpse(pyro, { { name = REAL, id = REAL_ID } })
check(CDB.looted["pyromancer loregrain"] and DB.realBosses["pyromancer loregrain"], "its Real is recorded and learned")
check(T.chatContains("does drop them"), "the player is told")
kill("Pyromancer Loregrain", SECRET)
check(#CDB.pending == 0, "same day again: already looted, no reminder")
nextDay()
kill("Pyromancer Loregrain", SECRET)
check(#CDB.pending == 1, "next day: Loregrain reminds")
r = row("Blackrock Depths", "Pyromancer Loregrain")
check(r.status == "waiting", "checklist counts Loregrain now")
ns.dismissAll()
DB.realBosses["pyromancer loregrain"] = nil

-- An add's level is never stored as the boss's.
DB.bossLevels["general angerforge"] = nil
T.units.boss2 = { name = "Anvilrage Reservist", level = 58, guid = "G-add2" }
kill("General Angerforge", SECRET)
T.units.boss2 = nil
check(DB.bossLevels["general angerforge"] == nil, "an add's level isn't saved as the boss's level")
ns.dismissAll()
-- A boss Wowhead has no level for still uses its own level read in game.
enter("Blackmaw Hold", 99902)
kill("Varrox Bleakhoof", 52)
check(#CDB.pending == 0, "unlisted boss read as 52: no reminder")
kill("Unbound Spirit", 60)
check(#CDB.pending == 1, "unlisted boss read as 60: reminder")
ns.dismissAll()
DB.noRealBosses = {}
DB.bossLevels["varrox bleakhoof"], DB.bossLevels["unbound spirit"] = nil, nil
CDB.looted["varrox bleakhoof"], CDB.looted["unbound spirit"] = nil, nil
enter("Blackrock Depths", 230)

-- Warder Stilgiss is level 56 but drops no Real (reported in game).
kill("Warder Stilgiss", 56)
check(#CDB.pending == 0, "Warder Stilgiss, level 56 read: no reminder (drops no Real)")
kill("The Vault", SECRET)
kill("The Vault", nil, false)
check(#CDB.pending == 0, "The Vault (after Warder Stilgiss): no reminder")
r = row("Blackrock Depths", "The Vault")
check(r and r.display == "The Vault" and #r.names == 1 and ns.Roster.STATUS.low.text(r) == "drops no Real",
    "The Vault has its own row: drops no Real")
r = row("Blackrock Depths", "Warder Stilgiss & Verek")
check(r and r.display ~= "The Vault" and r.display:find("Stilgiss", 1, true), "Stilgiss & Verek keep their own row")
kill("Warder Stilgiss & Verek", SECRET)
check(#CDB.pending == 0, "Warder Stilgiss & Verek, level hidden: no reminder")
kill("Verek", nil, false)
check(#CDB.pending == 0, "Verek: no reminder")
r = row("Blackrock Depths", "Warder Stilgiss & Verek")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "drops no Real", "checklist: drops no Real")
table.insert(CDB.pending, { key = "warder stilgiss", name = "Warder Stilgiss", t = 0, instance = "Blackrock Depths", guids = {} })
T.fire("PLAYER_ENTERING_WORLD"); T.advance(3.5)
check(#CDB.pending == 0, "a waiting Stilgiss reminder is dropped at the loading screen")

-- Ring of the Law: the challenger who shows up decides.
kill("Ring of the Law", SECRET, "Grizzle")
check(#CDB.pending == 0, "Ring of the Law vs Grizzle (54): no reminder")
nextDay()
local ring = kill("Ring of the Law", SECRET, "Gorosh the Dervish")
check(#CDB.pending == 1, "Ring of the Law vs Gorosh the Dervish (56): reminder")
-- Its corpse without a Real must not teach "no Real": tomorrow may be Gorosh again.
openCorpse(ring, { { name = "Arena Wristguards", quality = 3 } })
check(#CDB.pending == 0 and DB.noRealBosses["ring of the law"] == nil, "Ring of the Law is never learned as no-Real")
nextDay()
kill("Ring of the Law", SECRET, false)
check(#CDB.pending == 1, "Ring of the Law, challenger unknown: reminder (never miss a Real)")
ns.dismissAll()
nextDay()
-- Challenger seen only as the target (no boss frame).
T.units.target = { name = "Hedrum the Creeper", level = SECRET, guid = "G-hedrum" }
T.fire("ENCOUNTER_START", 900, "Ring of the Law", 1, 5)
T.fire("PLAYER_TARGET_CHANGED")
T.advance(1.5)
T.fire("ENCOUNTER_END", 900, "Ring of the Law", 1, 5, 1)
T.units.target = nil
T.advance(0.5)
check(#CDB.pending == 0, "Ring of the Law vs Hedrum (53), seen as target: no reminder")
check(DB.bossLevels["ring of the law"] == nil, "no level stored under Ring of the Law")
r = row("Blackrock Depths", "Ring of the Law")
check(r.level == nil and r.status ~= "low", "checklist doesn't call Ring of the Law below 55")

-------------------------------------------------------------------------------
-- Learning, for bosses Wowhead has no level for (the new dungeons).
enter("Blackmaw Hold", 99902)
local g = kill("Withermaw", SECRET)
check(#CDB.pending == 1, "boss without a known level reminds the first time")
openCorpse("G-trash", { { name = "Linen Cloth" } })
check(#CDB.pending == 1 and not DB.noRealBosses["withermaw"], "trash corpse teaches nothing")
openCorpse(g, { { name = "Cloak of the Fleshborer", quality = 3 } })
check(#CDB.pending == 0, "reminder cleared by its own corpse")
check(DB.noRealBosses["withermaw"] == "Withermaw", "learned: its corpse had no Real")
check(T.chatContains("doesn't drop one"), "the player is told what was learned")
nextDay()
kill("Withermaw", SECRET)
check(#CDB.pending == 0, "next day: no reminder for the learned boss")
r = row("Blackmaw Hold", "Withermaw")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "no Real (learned)", "checklist: no Real (learned)")
check(total("Blackmaw Hold") == 6, "learned boss left out of the count (" .. tostring(total("Blackmaw Hold")) .. ")")

-- What was learned from the corpse beats a level read in game (Warder
-- Stilgiss is level 56 and drops no Real)...
local g2 = kill("Withermaw", 59)
check(#CDB.pending == 0, "learned no-Real beats a readable level 59")
r = row("Blackmaw Hold", "Withermaw")
check(r.status == "low" and ns.Roster.STATUS.low.text(r) == "no Real (learned)", "checklist still: no Real (learned)")
-- ...but the moment it does give a Real, the learning is undone.
openCorpse(g2, { { name = REAL, id = REAL_ID } })
check(DB.noRealBosses["withermaw"] == nil, "looting a Real from it unlearns it, even without a reminder")
check(CDB.looted["withermaw"] and not CDB.looted["withermaw"].none, "and that Real is recorded")
nextDay()
kill("Withermaw", 59)
check(#CDB.pending == 1, "after unlearning it reminds again")
ns.dismissAll()

-- A level-56 boss whose corpse has no Real is learned and stays quiet,
-- even with its level readable.
enter("Blackmaw Hold", 99902)
local g3 = kill("Elder Shaman Bloodmane", 56)
check(#CDB.pending == 1, "level 56 boss reminds the first time")
openCorpse(g3, { { name = "Totem of Something", quality = 3 } })
nextDay()
kill("Elder Shaman Bloodmane", 56)
check(#CDB.pending == 0, "level 56 boss learned as no-Real stays quiet")

-- /trr relearn.
DB.noRealBosses["varrox bleakhoof"] = "Varrox Bleakhoof"
ns.slash("relearn")
check(next(DB.noRealBosses) == nil and T.chatContains("forgotten"), "/trr relearn forgets learned bosses")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
