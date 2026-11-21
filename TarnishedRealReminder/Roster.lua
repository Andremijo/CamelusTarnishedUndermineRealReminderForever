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
    low     = { color = { 0.42, 0.42, 0.42 }, text = "below 55, no Real" },
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

local function defIndexFor(instanceName)
    local l = instanceName and instanceName:lower()
    if not l then return nil end
    for i, def in ipairs(ns.ROSTER) do
        if def.name:lower() == l then return i end
        for _, n in ipairs(def.instanceNames or {}) do
            if n == l then return i end
        end
    end
end

-- Checklist group name for an instance name ("Lower Blackrock Spire" ->
-- "Blackrock Spire"), or the instance name itself if it isn't in the list.
function Roster.GroupNameFor(instanceName)
    local i = defIndexFor(instanceName)
    return i and ns.ROSTER[i].name or instanceName
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
        for _, b in ipairs(def.bosses) do
            local names = { b[1] }
            for _, a in ipairs(b.aliases or {}) do names[#names + 1] = a end
            g.rows[#g.rows + 1] = { display = b[1], names = names, low = b.low, static = true }
        end
    end

    local function groupFor(inst)
        inst = inst or "Other"
        local i = defIndexFor(inst)
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
        local g = groupFor(inst)
        local list = {}
        for boss in pairs(DB.knownBosses[inst]) do list[#list + 1] = boss end
        table.sort(list)
        for _, boss in ipairs(list) do addName(g, boss) end
    end
    for _, v in pairs(CDB.looted) do
        addName(groupFor(v.instance), v.name).looted = v
    end
    for _, p in ipairs(CDB.pending) do
        if not p.test then addName(groupFor(p.instance), p.name).pending = p end
    end

    local here = ns.currentInstance()
    local result = {}
    for _, g in ipairs(groups) do
        g.total, g.done, g.missed, g.reals = 0, 0, 0, 0
        for _, r in ipairs(g.rows) do
            local level
            for _, n in ipairs(r.names) do level = level or DB.bossLevels[n:lower()] end
            r.level = level
            if type(level) == "number" and level > 0 then r.low = level < ns.MIN_BOSS_LEVEL end
            r.ignored = DB.ignoredBosses[Roster.IgnoreKey(r)] and true or false

            if r.looted then
                r.status = r.looted.none and "none" or "looted"
            elseif r.pending then
                local inside = here and r.pending.instance and defIndexFor(here) == defIndexFor(r.pending.instance)
                r.status = inside and "waiting" or "missed"
            elseif r.ignored then
                r.status = "ignored"
            elseif r.low then
                r.status = "low"
            else
                r.status = "todo"
            end

            if r.status ~= "ignored" and r.status ~= "low" then g.total = g.total + 1 end
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
