local _, ns = ...
-- luacheck: globals FallensFlyoutsDB
-- luacheck: read globals C_Container C_Item C_Spell C_Timer Enum CreateFrame InCombatLockdown UnitLevel issecretvalue
-- luacheck: read globals CreateMacro GetMacroInfo PickupMacro ClearCursor NUM_TOTAL_EQUIPPED_BAG_SLOTS NUM_BAG_SLOTS
-- luacheck: read globals DeleteMacro EditMacro GetFlyoutInfo GetFlyoutSlotInfo IsPlayerSpell UnitClass UnitFactionGroup

-- Flyouts that fill themselves from the bags: all there is to eat, all there
-- is to drink, the potions, and so on, each kind apart. What sits on the bar
-- is a macro of the addon's own with one fixed icon for its kind, the only
-- thing an addon can make for a bar. Its flyout is worked out for whoever is
-- logged in, and again whenever the bags change.
-- A kind of the player's own holds several of those kinds in one flyout (food and drink, say). His
-- words (2026-11-22): "how do we allow users to make custom auto-populated flyouts like our shipped
-- ones? ... put all said categories into a dropdown, and people can select one or more to combine too?
-- so for ex could put food and drink into one."
local A = {}
ns.Auto = A
local F = ns.Flyouts

-- the game's numbers for a consumable and its kinds, should its own lists be missing
local CONSUMABLE = 0
local SUB = { Potion = 1, Elixir = 2, Flasksphials = 3, Scroll = 4, Fooddrink = 5, Bandage = 7 }
-- the game numbers its kinds of consumable from 0; this far they are asked for where its list is missing
local SUB_LAST = 12
-- a kind the game keeps only for old items says so in its name
local OLD = "OBSOLETE"
-- Food and drink are one kind to the game. They are told apart by the icon
-- of what using one casts: a drink's is this spell's.
local DRINK = 430
-- a line of a macro the game passes over: it says the macro is ours, and of which kind
local MARK = "#fallensflyouts "
-- how many names are tried for a kind's macro when someone else's has the first
local NAMES = 3
-- how long word on items is waited for before the flyouts are worked out again
local WORD = 0.3
-- A kind of the player's own: what its id begins with, how many there may be (one row of the settings
-- page), the most letters a macro's name takes, and the icon of one whose parts have none (the game's
-- question mark).
local MIX, MIX_MOST, NAME_MOST, NO_ICON = "mix", 7, 16, 134400
-- Each kind: its name on the bar, its icon, the game's name for its items; `drink` for the two that share one.
-- A mage's portals and teleports are spells: the ones the mage knows of those the game keeps in its own flyouts
-- of them, one for each side (`flyouts`), with the icon of the first. His words (2026-11-24): "also for mages,
-- \"portals\" should be one of our preset flyouts btw.", "and teleports", "separately".
local KINDS = {
    { id = "food", name = "Food", icon = 133952, sub = "Fooddrink", drink = false },
    { id = "drink", name = "Drink", icon = 132793, sub = "Fooddrink", drink = true },
    { id = "potions", name = "Potions", icon = 134829, sub = "Potion" },
    { id = "elixirs", name = "Elixirs", icon = 134843, sub = "Elixir" },
    { id = "flasks", name = "Flasks", icon = 134842, sub = "Flasksphials" },
    { id = "scrolls", name = "Scrolls", icon = 134938, sub = "Scroll" },
    { id = "bandages", name = "Bandages", icon = 133685, sub = "Bandage" },
    { id = "portals", name = "Portals", flyouts = { Alliance = 248, Horde = 249 }, class = "MAGE" },
    { id = "teleports", name = "Teleports", flyouts = { Alliance = 250, Horde = 251 }, class = "MAGE" },
}
local TEXT = {
    fight = "Flyouts change only out of a fight.",
    full = "Your macro list is full: the flyout needs one macro of its own.",
    none = "Tick at least one kind first.",
    most = "There is room for no more flyouts of your own. Delete one first.",
    more = " +%d",
    both = "%s/%s",
}
A.KINDS, A.TEXT, A.MARK, A.MIX_MOST = KINDS, TEXT, MARK, MIX_MOST

local byId = {}
for _, kind in ipairs(KINDS) do byId[kind.id] = kind end
-- the kinds a flyout of the player's own can hold: the ones above, then the game's other kinds of
-- consumable, each under the game's own name
local parts, partOf
-- the kinds of the player's own, and the saved list they were read from
local mixes, mixesOf

-- the items the game still owes word on: the lists are worked out again when it comes
local owed, queued = {}, false
-- the level a level-up just named: the game's own answer can lag behind it
local grown = 0
local events = CreateFrame("Frame")

local function Hidden(v) return issecretvalue ~= nil and issecretvalue(v) end

-- The spells of a kind the game keeps in flyouts of its own, in the game's order, this side's first, each
-- once (both sides' teleports hold Dalaran); with `known`, those this character knows.
local function Spells(kind, known)
    local out, seen, ids = {}, {}, {}
    if not (kind.flyouts and GetFlyoutInfo and GetFlyoutSlotInfo) then return out end
    local side = UnitFactionGroup and UnitFactionGroup("player")
    if kind.flyouts[side] then ids[1] = kind.flyouts[side] end
    local others = {}
    for name, id in pairs(kind.flyouts) do
        if name ~= side then others[#others + 1] = id end
    end
    table.sort(others)
    for _, id in ipairs(others) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local ok, _, _, slots = pcall(GetFlyoutInfo, id)
        for slot = 1, (ok and not Hidden(slots) and type(slots) == "number") and slots or 0 do
            local got, spell, _, isKnown = pcall(GetFlyoutSlotInfo, id, slot)
            if got and not Hidden(spell) and type(spell) == "number" and not seen[spell] then
                local mine = not Hidden(isKnown) and isKnown == true
                if not mine and IsPlayerSpell then
                    local has = IsPlayerSpell(spell)
                    mine = not Hidden(has) and has == true
                end
                if mine or not known then
                    seen[spell] = true
                    out[#out + 1] = spell
                end
            end
        end
    end
    return out
end

-- a kind of spells takes the icon of the first it holds, else of the first of this side's
local function Dress(kind)
    if not kind.flyouts or (kind.icon and kind.icon ~= NO_ICON) then return end
    local first = Spells(kind, true)[1] or Spells(kind)[1]
    local icon = first and C_Spell.GetSpellTexture(first)
    kind.icon = (not Hidden(icon) and type(icon) == "number") and icon or NO_ICON
end

-- the icon of a flyout's entry, a spell's or an item's
local function EntryIcon(entry)
    if not entry then return nil end
    local icon
    if entry.kind == "spell" then
        icon = C_Spell.GetSpellTexture(entry.id)
    elseif C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(entry.id)
    end
    if Hidden(icon) or type(icon) ~= "number" then return nil end
    return icon
end

-- whether this character has a use for a kind: a mage's are a mage's alone
function A.Fits(kind)
    if not (kind and kind.class) then return kind ~= nil end
    local _, class = UnitClass("player")
    return class == kind.class
end

local function Sub(name)
    local list = Enum and Enum.ItemConsumableSubclass
    return list and list[name] or SUB[name]
end

local function Consumable()
    return Enum and Enum.ItemClass and Enum.ItemClass.Consumable or CONSUMABLE
end

-- The kinds that can be ticked for a flyout of the player's own. The game's other kinds of consumable
-- are asked for by number and named by the game; one the shipped kinds stand for is left out, and so
-- is one the game has no name for or keeps only for old items.
function A.Parts()
    if parts then return parts end
    parts, partOf = {}, {}
    local taken, last = {}, SUB_LAST
    for _, kind in ipairs(KINDS) do
        parts[#parts + 1] = kind
        taken[Sub(kind.sub) or -1] = true
    end
    for _, n in pairs(Enum and Enum.ItemConsumableSubclass or {}) do
        if type(n) == "number" and n > last then last = n end
    end
    if C_Item.GetItemSubClassInfo then
        for n = 0, last do
            local name = not taken[n] and C_Item.GetItemSubClassInfo(Consumable(), n)
            if not Hidden(name) and type(name) == "string" and name ~= "" and not name:find(OLD, 1, true) then
                -- of these only what can be used goes in: the game files things under them that cannot
                parts[#parts + 1] = { id = "sub" .. n, name = name, num = n, usable = true }
            end
        end
    end
    for _, part in ipairs(parts) do partOf[part.id] = part end
    return parts
end

-- the shipped kinds offered to this character, each with its icon
function A.Shown()
    A.Parts()
    local out = {}
    for _, kind in ipairs(KINDS) do
        if A.Fits(kind) then
            Dress(kind)
            out[#out + 1] = kind
        end
    end
    return out
end

function A.Part(id)
    A.Parts()
    return partOf[id]
end

-- as much of a name as fits in `room`, in whole letters
local function Short(name, room)
    if #name <= room then return name end
    local cut = room
    -- not through the middle of a letter of several bytes
    while cut > 0 and (name:byte(cut + 1) or 0) >= 128 and (name:byte(cut + 1) or 0) < 192 do cut = cut - 1 end
    return (name:sub(1, cut):gsub("%s+$", ""))
end

-- a name for a kind of the player's own, short enough for a macro: its one part's, both of two where
-- they fit, else the first and how many more
local function Title(ids)
    local first, second = partOf[ids[1]], partOf[ids[2]]
    local name = first and first.name or MIX
    if #ids == 1 then return Short(name, NAME_MOST) end
    if #ids == 2 and second and #TEXT.both:format(name, second.name) <= NAME_MOST then
        return TEXT.both:format(name, second.name)
    end
    local more = TEXT.more:format(#ids - 1)
    return Short(name, NAME_MOST - #more) .. more
end

-- a saved kind of the player's own as a kind like the shipped ones; nil for one whose parts are all gone
local function Own(saved)
    if type(saved) ~= "table" or type(saved.id) ~= "string" or type(saved.parts) ~= "table" then return nil end
    A.Parts()
    local ids, icon = {}, type(saved.icon) == "number" and saved.icon or nil
    for _, id in ipairs(saved.parts) do
        local part = partOf[id]
        if part then
            ids[#ids + 1] = id
            Dress(part)
            if part.icon ~= NO_ICON then icon = icon or part.icon end
        end
    end
    if #ids == 0 then return nil end
    return { id = saved.id, name = saved.name or Title(ids), icon = icon or NO_ICON, parts = ids, own = true }
end

-- The kinds of the player's own, kept for the whole account as their macros are:
-- FallensFlyoutsDB.mixes = { next = n, list = { { id = "mix1", name = "Food/Drink", parts = { "food", "drink" } } } }
local function Mixes()
    local db = FallensFlyoutsDB
    if type(db) ~= "table" then return {} end
    if type(db.mixes) ~= "table" then db.mixes = {} end
    if type(db.mixes.list) ~= "table" then db.mixes.list = {} end
    if mixes and mixesOf == db.mixes.list then return mixes end
    -- read anew: the saved data is another than last time
    for _, kind in ipairs(mixes or {}) do byId[kind.id] = nil end
    mixes, mixesOf = {}, db.mixes.list
    for _, saved in ipairs(mixesOf) do
        local kind = Own(saved)
        if kind and not byId[kind.id] then
            mixes[#mixes + 1] = kind
            byId[kind.id] = kind
        end
    end
    return mixes
end
function A.Mixes() return Mixes() end

function A.Kind(id)
    Mixes()
    return byId[id]
end

-- whether using an item is drinking; nil while the game has not said what it casts
local function Drinks(item)
    local _, spell = C_Item.GetItemSpell(item)
    if Hidden(spell) or type(spell) ~= "number" then return nil end
    local texture, drink = C_Spell.GetSpellTexture(spell), C_Spell.GetSpellTexture(DRINK)
    if Hidden(texture) or Hidden(drink) or texture == nil or drink == nil then return nil end
    return texture == drink
end

-- every different item in the bags
local function Bags()
    local seen, out = {}, {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if not Hidden(id) and type(id) == "number" and not seen[id] then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    return out
end

-- a number the game gave, or 0 for one it kept back or does not have yet
local function Count(v)
    if Hidden(v) or type(v) ~= "number" then return 0 end
    return v
end

-- The items of one part among `bags` that a character of level `mine` can use, the best first.
-- Second: the game owes word on one of them.
local function Found(part, bags, mine)
    if part.flyouts then
        local spells = {}
        for _, spell in ipairs(Spells(part, true)) do spells[#spells + 1] = { kind = "spell", id = spell } end
        return spells, false
    end
    local want = part.num or Sub(part.sub)
    local found, short = {}, false
    for _, item in ipairs(bags) do
        local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(item)
        local fits = not Hidden(class) and not Hidden(sub) and class == Consumable() and sub == want
        if fits and part.drink ~= nil then
            local drinks = Drinks(item)
            if drinks == nil then owed[item], short = true, true end
            fits = drinks ~= nil and drinks == part.drink
        end
        if fits and part.usable then
            local _, spell = C_Item.GetItemSpell(item)
            fits = not Hidden(spell) and spell ~= nil
        end
        if fits then
            local name, _, _, level, needs = C_Item.GetItemInfo(item)
            if name == nil then owed[item], short = true, true end
            needs = Count(needs)
            -- one for a higher level than this character's is left out
            if mine == 0 or needs <= mine then
                found[#found + 1] = { id = item, level = Count(level), needs = needs }
            end
        end
    end
    table.sort(found, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        if a.needs ~= b.needs then return a.needs > b.needs end
        return a.id > b.id
    end)
    return found, short
end

-- The items of a kind in the bags that this character can use (for a kind of spells, the ones it knows), as a
-- flyout's entries: the best
-- first, and for a kind of the player's own each part's in the order the parts were ticked. As many
-- as a flyout holds. Second: the game owes word on one of them.
function A.Entries(id)
    local kind = A.Kind(id)
    if not kind then return {}, false end
    A.Parts()
    local bags, mine = Bags(), math.max(Count(UnitLevel("player")), grown)
    local of = { kind }
    if kind.parts then
        of = {}
        for _, part in ipairs(kind.parts) do of[#of + 1] = partOf[part] end
    end
    local lists, take, short, room = {}, {}, false, F.MAX
    for i, part in ipairs(of) do
        local found, owes = Found(part, bags, mine)
        lists[i], take[i], short = found, 0, short or owes
    end
    -- the room is shared out one at a time, so that no part is crowded out by one before it
    local gave = true
    while room > 0 and gave do
        gave = false
        for i, found in ipairs(lists) do
            if room > 0 and take[i] < #found then
                take[i], room, gave = take[i] + 1, room - 1, true
            end
        end
    end
    local entries = {}
    for i, found in ipairs(lists) do
        for n = 1, take[i] do entries[#entries + 1] = { kind = found[n].kind or "item", id = found[n].id } end
    end
    return entries, short
end

-- the names a kind's macro may go by: its own, then numbered ones
local function Names(kind)
    local names = { kind.name }
    for n = 2, NAMES do names[n] = kind.name .. " " .. n end
    return names
end

-- whether a macro's text marks it as this kind's: the mark and the kind's id, and no more of an id after
local function Marked(body, kind)
    local mark = MARK .. kind.id
    if type(body) ~= "string" or body:find(mark, 1, true) ~= 1 then return false end
    return not body:sub(#mark + 1, #mark + 1):find("%w")
end

-- the name of a kind's macro, if it is in the macro list: known by the line that marks it ours
function A.Macro(id)
    local kind = A.Kind(id)
    if not kind then return nil end
    for _, name in ipairs(Names(kind)) do
        local _, _, body = GetMacroInfo(name)
        if Marked(body, kind) then return name end
    end
    return nil
end

-- makes it if there is none, under the first of its names that no other macro has
local function Make(kind)
    local have = A.Macro(kind.id)
    if have then return have end
    Dress(kind)
    for _, name in ipairs(Names(kind)) do
        if not GetMacroInfo(name) then
            local ok, index = pcall(CreateMacro, name, kind.icon or NO_ICON, MARK .. kind.id, false)
            if ok and index then return name end
            return nil
        end
    end
    return nil
end

-- The flyout of a kind in the profile in use, made if it is not there. It
-- sits wherever its macro is on the bars, as any flyout sits with its ability.
local function Flyout(kind, name)
    local list = F.List()
    if not list then return nil end
    for _, flyout in ipairs(list) do
        if flyout.auto == kind.id then
            flyout.main = { kind = "macro", id = name }
            return flyout
        end
    end
    local flyout = { host = "", main = { kind = "macro", id = name }, auto = kind.id, entries = {}, cross = true }
    list[#list + 1] = flyout
    return flyout
end

-- Puts a kind's macro on the cursor, to be dropped on a bar. Out of a fight.
function A.Pick(id)
    local kind = A.Kind(id)
    if not (kind and A.Fits(kind)) then return false end
    if InCombatLockdown() then return false, TEXT.fight end
    local name = Make(kind)
    if not name then return false, TEXT.full end
    if not Flyout(kind, name) then return false end
    ClearCursor()
    -- dropped on a bar, the bar's change has the flyout look for its button
    PickupMacro(name)
    return true, name
end

-- A kind of the player's own that holds the ticked parts, in their order. The same parts ticked again
-- give the kind there is already. Second: why not.
function A.Mix(ids)
    if InCombatLockdown() then return nil, TEXT.fight end
    A.Parts()
    local list, seen = {}, {}
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        if partOf[id] and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    if #list == 0 then return nil, TEXT.none end
    local db = FallensFlyoutsDB
    if type(db) ~= "table" then return nil end
    local own = Mixes()
    for _, kind in ipairs(own) do
        if table.concat(kind.parts, " ") == table.concat(list, " ") then return kind end
    end
    if #own >= MIX_MOST then return nil, TEXT.most end
    local n = tonumber(db.mixes.next) or 1
    db.mixes.next = n + 1
    local saved = { id = MIX .. n, name = Title(list), parts = list }
    db.mixes.list[#db.mixes.list + 1] = saved
    local kind = Own(saved)
    own[#own + 1] = kind
    byId[kind.id] = kind
    -- parts with no icon of their own: the icon of the best the bags hold of them now
    if kind.icon == NO_ICON then
        local icon = EntryIcon(A.Entries(kind.id)[1])
        if icon then saved.icon, kind.icon = icon, icon end
    end
    return kind
end

-- A kind of the player's own given a name or an icon of its own, from the icon window its right-click opens
-- on the settings page. His words (2026-11-23): "right click should be for setting icon like usual". Kept
-- with the kind; its macro is renamed and given the icon too, so that the bars show them, and its flyouts
-- follow the macro's new name (A.Refresh). `name`: nil leaves it as it is, "" gives back the name of its
-- kinds; `icon`: nil leaves it, false gives back its own.
function A.Restyle(id, name, icon)
    if InCombatLockdown() then return false, TEXT.fight end
    local kind = A.Kind(id)
    if not (kind and kind.own) then return false end
    local saved
    for _, one in ipairs(mixesOf or {}) do
        if one.id == id then saved = one end
    end
    if not saved then return false end
    local macro = A.Macro(id)
    if type(name) == "string" then
        -- as the game does with a macro's name
        local clean = name:gsub('"', ""):match("^%s*(.-)%s*$")
        if clean == "" then
            saved.name = nil
        else
            saved.name = Short(clean, NAME_MOST)
        end
        kind.name = saved.name or Title(kind.parts)
    end
    if icon == false then
        saved.icon = nil
        local fresh = Own(saved)
        kind.icon = fresh and fresh.icon or NO_ICON
        -- no icon of its own kinds: the icon of the best the bags hold of them, as when it was made
        if kind.icon == NO_ICON then
            local found = EntryIcon(A.Entries(id)[1])
            if found then saved.icon, kind.icon = found, found end
        end
    elseif type(icon) == "number" then
        saved.icon, kind.icon = icon, icon
    end
    if macro and EditMacro then
        -- the first of its names that no other macro has (its own present name among them)
        local to = macro
        for _, one in ipairs(Names(kind)) do
            if one == macro or not GetMacroInfo(one) then
                to = one
                break
            end
        end
        pcall(EditMacro, macro, to, kind.icon)
    end
    A.Refresh()
    return true
end

-- Does away with a kind of the player's own: its macro, its flyout in the profile in use, and the kind.
-- Its flyouts in other profiles go when those are next in use.
function A.Unmix(id)
    if InCombatLockdown() then return false, TEXT.fight end
    local kind = A.Kind(id)
    if not (kind and kind.own) then return false end
    local name = A.Macro(id)
    if name and DeleteMacro then pcall(DeleteMacro, name) end
    for i = #mixesOf, 1, -1 do
        if mixesOf[i].id == id then table.remove(mixesOf, i) end
    end
    for i = #mixes, 1, -1 do
        if mixes[i].id == id then table.remove(mixes, i) end
    end
    byId[id] = nil
    A.Refresh()
    return true
end

local function Alike(a, b)
    if #a ~= #b then return false end
    for i, entry in ipairs(a) do
        if entry.kind ~= b[i].kind or entry.id ~= b[i].id then return false end
    end
    return true
end

-- The bags changed, or word on an item came: a flyout whose list would read
-- otherwise now is laid again. In a fight that waits for the fight's end.
function A.Refresh()
    local list = F.List()
    if not list then return false end
    Mixes()
    local changed = false
    owed = {}
    for i = #list, 1, -1 do
        local flyout = list[i]
        if flyout.auto and byId[flyout.auto] then
            local entries = A.Entries(flyout.auto)
            if not Alike(entries, flyout.entries or {}) then changed = true end
            -- its macro renamed (a kind of the player's own given a name): the flyout goes by the new name
            local macro = not InCombatLockdown() and A.Macro(flyout.auto)
            if macro and type(flyout.main) == "table" and flyout.main.kind == "macro" and flyout.main.id ~= macro then
                flyout.main.id, changed = macro, true
            end
        elseif type(flyout.auto) == "string" and flyout.auto:find("^" .. MIX .. "%d+$") then
            -- of a kind of the player's own that is no more: the flyout goes with it
            if not InCombatLockdown() then
                F.Forget(flyout)
                changed = true
            end
        elseif F.Hiding() then
            -- one made by hand: it shows what the player has of it
            if not Alike(F.Held(flyout), flyout.entries or {}) then changed = true end
        end
    end
    -- word on items is listened for only while some is owed, and only for those
    if next(owed) then
        pcall(events.RegisterEvent, events, "GET_ITEM_INFO_RECEIVED")
    else
        pcall(events.UnregisterEvent, events, "GET_ITEM_INFO_RECEIVED")
    end
    if changed then F.Apply() end
    return changed
end

-- whether a flyout in use holds a kind of spells, alone or among a kind of the player's own
local function HoldsSpells()
    for _, flyout in ipairs(F.List() or {}) do
        local kind = flyout.auto and A.Kind(flyout.auto)
        if kind and kind.flyouts then return true end
        for _, id in ipairs(kind and kind.parts or {}) do
            local part = A.Part(id)
            if part and part.flyouts then return true end
        end
    end
    return false
end

-- a spell learned is looked for in the flyouts of spells
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, item)
    if not ns.started then return end
    if event == "SPELLS_CHANGED" and not HoldsSpells() then return end
    -- word on an item comes for every item anyone asks about: only one this waits for counts
    if event == "GET_ITEM_INFO_RECEIVED" and not owed[item] then return end
    if event == "PLAYER_LEVEL_UP" then grown = Count(item) end
    if event ~= "GET_ITEM_INFO_RECEIVED" then return A.Refresh() end
    -- they come one at a time: once they have stopped coming
    if queued then return end
    queued = true
    C_Timer.After(WORD, function()
        queued = false
        A.Refresh()
    end)
end)
