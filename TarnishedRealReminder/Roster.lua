-- Today's boss checklist: every Real boss, grouped by dungeon, with a status.
--
-- Starts from ns.ROSTER (Data.lua), then folds in what the game itself has
-- reported: bosses seen through ENCOUNTER_END (DB.knownBosses, kept across
-- sessions) and today's loot and pending records. Names are matched loosely,
-- so a guide name and the game's name for the same boss share one row, and
-- the row then shows the game's name.
local _, ns = ...

local Roster = {}
ns.Roster = Roster

-- Status of a row, in the order they are explained to the player.
Roster.STATUS = {
    looted  = { color = { 0.25, 1, 0.25 },  text = function(r) local n = r.looted.n or 1; return n > 1 and (n .. " Reals") or "1 Real" end },
    none    = { color = { 0.6, 0.6, 0.6 },  text = "nothing for you" },
    waiting = { color = { 1, 0.35, 0.35 },  text = "killed - loot it!" },
    missed  = { color = { 1, 0.35, 0.35 },  text = "killed, not looted" },
    todo    = { color = { 1, 1, 1 },        text = "not looted" },
    optional = { color = { 0.62, 0.62, 0.62 }, text = "optional" },
    low     = { color = { 0.42, 0.42, 0.42 },
                text = function(r)
                    if r.noReal then return "drops no Real" end
                    if r.notOnList then return "not on the drop list" end
                    if r.learnedNoReal then return "no Real (learned)" end
                    if type(r.level) == "number" and r.level > 0 then return "level " .. r.level .. ", no Real" end
                    return "below 55, no Real"
                end },
    ignored = { color = { 0.42, 0.42, 0.42 }, text = "ignored" },
}

local function norm(s)
    s = tostring(s or ""):lower():gsub("[^%w ]", ""):gsub("%s+", " ")
    s = s:gsub("^ ", ""):gsub(" $", "")
    return s
end
Roster.norm = norm

-- Same boss? Equal names; or the longer name is the shorter one plus a title
-- ("Kirtonos" / "Kirtonos the Herald") or plus a few letters
-- ("Ras Frostwhisper" / "Ras Frostwhisperer"). "Future Boss" and
-- "Future Boss Three" stay different. Other spellings go in ROSTER aliases.
function Roster.Match(a, b)
    a, b = norm(a), norm(b)
    if a == "" or b == "" then return false end
    if a == b then return true end
    local short, long = a, b
    if #short > #long then short, long = long, short end
    if #short < 5 or long:sub(1, #short) ~= short then return false end
    local rest = long:sub(#short + 1)
    return rest:sub(1, 5) == " the " or (#rest <= 3 and not rest:find(" ", 1, true))
end

local function rowMatches(row, name)
    for _, n in ipairs(row.names) do
        if Roster.Match(n, name) then return true end
    end
    return false
end

-- Checklist groups for an instance name. Usually one; the halves of
-- Blackrock Spire, the wings of Dire Maul and the sides of Stratholme may
-- share an instance name, and are then told apart by boss name.
local function defIndexesFor(instanceName)
    local l = instanceName and instanceName:lower()
    local out = {}
    if not l then return out end
    for i, def in ipairs(ns.ROSTER) do
        local hit = def.name:lower() == l
        for _, n in ipairs(def.instanceNames or {}) do
            if n == l then hit = true end
        end
        if hit then out[#out + 1] = i end
    end
    return out
end

local function defHasBoss(def, name)
    for _, b in ipairs(def.bosses) do
        if Roster.Match(b[1], name) then return true end
        for _, a in ipairs(b.aliases or {}) do
            if Roster.Match(a, name) then return true end
        end
    end
    return false
end

-- The group a boss belongs to: the one listing it, else the first group for
-- the instance.
local function defIndexFor(instanceName, bossName)
    local list = defIndexesFor(instanceName)
    if bossName and #list > 1 then
        for _, i in ipairs(list) do
            if defHasBoss(ns.ROSTER[i], bossName) then return i end
        end
    end
    return list[1]
end

-- True if two instance names belong to the same dungeon.
local function sameDungeon(a, b)
    if not (a and b) then return false end
    if a == b then return true end
    for _, i in ipairs(defIndexesFor(a)) do
        for _, j in ipairs(defIndexesFor(b)) do
            if i == j then return true end
        end
    end
    return false
end

-- Checklist group name for an instance name ("Lower Blackrock Spire" ->
-- "Blackrock Spire"), or the instance name itself if it isn't in the list.
-- With several groups for one instance (Dire Maul), returns all their names.
function Roster.GroupNameFor(instanceName)
    local list = defIndexesFor(instanceName)
    if #list == 0 then return instanceName end
    return ns.ROSTER[list[1]].name
end

function Roster.GroupNamesFor(instanceName)
    local names = {}
    for _, i in ipairs(defIndexesFor(instanceName)) do names[ns.ROSTER[i].name] = true end
    if not next(names) and instanceName then names[instanceName] = true end
    return names
end

-- The boss list's entry for a boss in a dungeon, or nil.
local function listedBoss(bossName, instanceName)
    for _, i in ipairs(defIndexesFor(instanceName)) do
        for _, b in ipairs(ns.ROSTER[i].bosses) do
            local hit = Roster.Match(b[1], bossName)
            for _, a in ipairs(b.aliases or {}) do hit = hit or Roster.Match(a, bossName) end
            if hit then return b end
        end
    end
end

-- Level of a boss from ns.BOSS_LEVELS (Wowhead), or nil. Second return:
-- true for a "variable" encounter (Ring of the Law), whose level depends on
-- the challenger and so can't come from its name.
function Roster.ListedLevel(bossName, instanceName)
    if not bossName then return nil end
    local direct = ns.BOSS_LEVELS[bossName:lower()]
    if direct then return direct, false end
    local b = listedBoss(bossName, instanceName)
    if not b then return nil, false end
    if b.variable then return nil, true end
    local level = ns.BOSS_LEVELS[b[1]:lower()]
    for _, a in ipairs(b.aliases or {}) do level = level or ns.BOSS_LEVELS[a:lower()] end
    return level, false
end

-- Is the boss on the drop list (Data.lua ns.DROP_LIST)? Checks every name
-- the boss list knows for it, and loose name matches.
function Roster.OnDropList(bossName, instanceName)
    if not bossName then return false end
    if ns.DROP_LIST[bossName:lower()] then return true end
    local b = listedBoss(bossName, instanceName)
    if b then
        if ns.DROP_LIST[b[1]:lower()] then return true end
        for _, a in ipairs(b.aliases or {}) do
            if ns.DROP_LIST[a:lower()] then return true end
        end
    end
    for listed in pairs(ns.DROP_LIST) do
        if Roster.Match(listed, bossName) then return true end
    end
    return false
end

-- Does the drop list cover this dungeon (the five classic ones, not the new
-- Forever dungeons)?
function Roster.DropListCovers(instanceName)
    local list = defIndexesFor(instanceName)
    if #list == 0 then return false end
    for _, i in ipairs(list) do
        if ns.ROSTER[i].new then return false end
    end
    return true
end

-- What the drop list says: "yes" (on it), "no" (not on it and a rare,
-- summoned or unknown boss in a covered dungeon), or nil (no verdict).
function Roster.DropListVerdict(bossName, instanceName)
    if not Roster.DropListCovers(instanceName) then return nil end
    if Roster.OnDropList(bossName, instanceName) then return "yes" end
    local b = listedBoss(bossName, instanceName)
    if not b or b.optional or b.likelyNoReal then return "no" end
    return nil
end

function Roster.IsVariable(bossName, instanceName)
    local b = listedBoss(bossName, instanceName)
    return b and b.variable and true or false
end

-- Key under which a row's "ignored" choice is saved.
function Roster.IgnoreKey(row) return norm(row.names[1]) end

function Roster.Build()
    ns.checkDailyReset()
    local DB, CDB = ns.DB, ns.CDB
    local groups = {}

    local function newGroup(name)
        local g = { name = name, rows = {} }
        groups[#groups + 1] = g
        return g
    end
    for _, def in ipairs(ns.ROSTER) do
        local g = newGroup(def.name)
        g.def = def
        for _, b in ipairs(def.bosses) do
            local names = { b[1] }
            for _, a in ipairs(b.aliases or {}) do names[#names + 1] = a end
            local level
            if not b.variable then
                for _, n in ipairs(names) do level = level or ns.BOSS_LEVELS[n:lower()] end
            end
            g.rows[#g.rows + 1] = { display = b[1], names = names, optional = b.optional, variable = b.variable,
                                    noReal = b.noReal, real = b.real, likelyNoReal = b.likelyNoReal,
                                    listedLevel = level, static = true }
        end
    end

    local function groupFor(inst, bossName)
        inst = inst or "Other"
        local i = defIndexFor(inst, bossName)
        if i then return groups[i] end
        for _, g in ipairs(groups) do
            if g.name == inst then return g end
        end
        return newGroup(inst)
    end

    -- A boss name reported by the game: tick an existing row or add one.
    local function addName(g, name)
        for _, r in ipairs(g.rows) do
            if rowMatches(r, name) then
                if not r.seen then
                    r.seen = true
                    r.display = name -- show the game's own name
                end
                local known = false
                for _, n in ipairs(r.names) do
                    if norm(n) == norm(name) then known = true end
                end
                if not known then table.insert(r.names, name) end
                return r
            end
        end
        local r = { display = name, names = { name }, seen = true }
        g.rows[#g.rows + 1] = r
        return r
    end

    local instances = {}
    for inst in pairs(DB.knownBosses) do instances[#instances + 1] = inst end
    table.sort(instances)
    for _, inst in ipairs(instances) do
        local list = {}
        for boss in pairs(DB.knownBosses[inst]) do list[#list + 1] = boss end
        table.sort(list)
        for _, boss in ipairs(list) do addName(groupFor(inst, boss), boss) end
    end
    for _, v in pairs(CDB.looted) do
        addName(groupFor(v.instance, v.name), v.name).looted = v
    end
    for _, p in ipairs(CDB.pending) do
        if not p.test then addName(groupFor(p.instance, p.name), p.name).pending = p end
    end

    local here = ns.currentInstance()
    local result = {}
    for _, g in ipairs(groups) do
        g.total, g.done, g.missed, g.reals = 0, 0, 0, 0
        for _, r in ipairs(g.rows) do
            -- Level: Wowhead's, else the boss's own level read in game (never
            -- for variable encounters like Ring of the Law).
            local level = r.listedLevel
            if not level and not r.variable then
                for _, n in ipairs(r.names) do
                    local l = DB.bossLevels[n:lower()]
                    if not level and type(l) == "number" and l > 0 then level = l end
                end
            end
            r.level = level
            r.low, r.learnedNoReal = false, false
            local learned, learnedReal = false, false
            if not r.variable then
                for _, n in ipairs(r.names) do
                    if DB.noRealBosses[n:lower()] then learned = true end
                    if DB.realBosses[n:lower()] or ns.REAL_BOSSES[n:lower()] then learnedReal = true end
                end
            end
            local covered = g.def and not g.def.new
            local onList = false
            if covered then
                for _, n in ipairs(r.names) do
                    if ns.DROP_LIST[n:lower()] then onList = true end
                end
            end
            r.notOnList = covered and not onList and (r.optional or r.likelyNoReal or not r.static) and true or false
            if r.noReal then
                r.low = true
            elseif r.real or learnedReal then
                r.low = false -- drops a Real whatever its level
            elseif learned then
                r.low, r.learnedNoReal = true, true
            elseif onList then
                r.low = false -- on the drop list, whatever its level
            elseif r.notOnList then
                r.low = true
            elseif type(level) == "number" and level > 0 then
                r.low = level < ns.MIN_BOSS_LEVEL
            end
            r.ignored = DB.ignoredBosses[Roster.IgnoreKey(r)] and true or false

            if r.looted then
                r.status = r.looted.none and "none" or "looted"
            elseif r.pending then
                r.status = sameDungeon(here, r.pending.instance) and "waiting" or "missed"
            elseif r.ignored then
                r.status = "ignored"
            elseif r.low then
                r.status = "low"
            elseif r.optional then
                r.status = "optional"
            else
                r.status = "todo"
            end

            if r.status ~= "ignored" and r.status ~= "low" and r.status ~= "optional" then g.total = g.total + 1 end
            if r.status == "looted" or r.status == "none" then g.done = g.done + 1 end
            if r.status == "looted" then g.reals = g.reals + (r.looted.n or 1) end
            if r.status == "waiting" or r.status == "missed" then g.missed = g.missed + 1 end
        end
        if #g.rows > 0 then result[#result + 1] = g end
    end
    return result
end

function Roster.ToggleIgnore(row)
    local key = Roster.IgnoreKey(row)
    ns.DB.ignoredBosses[key] = (not ns.DB.ignoredBosses[key]) or nil
end
