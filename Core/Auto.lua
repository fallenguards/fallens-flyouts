local _, ns = ...
-- luacheck: read globals C_Container C_Item C_Spell C_Timer Enum CreateFrame InCombatLockdown UnitLevel issecretvalue
-- luacheck: read globals CreateMacro GetMacroInfo PickupMacro ClearCursor NUM_TOTAL_EQUIPPED_BAG_SLOTS NUM_BAG_SLOTS

-- Flyouts that fill themselves from the bags: all there is to eat, all there
-- is to drink, the potions, and so on, each kind apart. What sits on the bar
-- is a macro of the addon's own with one fixed icon for its kind, the only
-- thing an addon can make for a bar. Its flyout is worked out for whoever is
-- logged in, and again whenever the bags change.
local A = {}
ns.Auto = A
local F = ns.Flyouts

-- the game's numbers for a consumable and its kinds, should its own lists be missing
local CONSUMABLE = 0
local SUB = { Potion = 1, Elixir = 2, Flasksphials = 3, Scroll = 4, Fooddrink = 5, Bandage = 7 }
-- Food and drink are one kind to the game. They are told apart by the icon
-- of what using one casts: a drink's is this spell's.
local DRINK = 430
-- a line of a macro the game passes over: it says the macro is ours, and of which kind
local MARK = "#fallensflyouts "
-- how many names are tried for a kind's macro when someone else's has the first
local NAMES = 3
-- how long word on items is waited for before the flyouts are worked out again
local WORD = 0.3
-- each kind: its name on the bar, its icon, the game's name for its items; `drink` for the two that share one
local KINDS = {
    { id = "food", name = "Food", icon = 133952, sub = "Fooddrink", drink = false },
    { id = "drink", name = "Drink", icon = 132793, sub = "Fooddrink", drink = true },
    { id = "potions", name = "Potions", icon = 134829, sub = "Potion" },
    { id = "elixirs", name = "Elixirs", icon = 134843, sub = "Elixir" },
    { id = "flasks", name = "Flasks", icon = 134842, sub = "Flasksphials" },
    { id = "scrolls", name = "Scrolls", icon = 134938, sub = "Scroll" },
    { id = "bandages", name = "Bandages", icon = 133685, sub = "Bandage" },
}
local TEXT = {
    fight = "Flyouts change only out of a fight.",
    full = "Your macro list is full: the flyout needs one macro of its own.",
}
A.KINDS, A.TEXT, A.MARK = KINDS, TEXT, MARK

local byId = {}
for _, kind in ipairs(KINDS) do byId[kind.id] = kind end

-- the items the game still owes word on: the lists are worked out again when it comes
local owed, queued = {}, false
-- the level a level-up just named: the game's own answer can lag behind it
local grown = 0
local events = CreateFrame("Frame")

local function Hidden(v) return issecretvalue ~= nil and issecretvalue(v) end

function A.Kind(id) return byId[id] end

local function Sub(name)
    local list = Enum and Enum.ItemConsumableSubclass
    return list and list[name] or SUB[name]
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

-- The items of a kind in the bags that this character can use, the best
-- first, as a flyout's entries. Second: the game owes word on one of them.
function A.Entries(id)
    local kind = byId[id]
    if not kind then return {}, false end
    local consumable = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or CONSUMABLE
    local want, mine = Sub(kind.sub), math.max(Count(UnitLevel("player")), grown)
    local found, short = {}, false
    for _, item in ipairs(Bags()) do
        local _, _, _, _, _, class, sub = C_Item.GetItemInfoInstant(item)
        local fits = not Hidden(class) and not Hidden(sub) and class == consumable and sub == want
        if fits and kind.drink ~= nil then
            local drinks = Drinks(item)
            if drinks == nil then owed[item], short = true, true end
            fits = drinks ~= nil and drinks == kind.drink
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
    local entries = {}
    for i = 1, math.min(#found, F.MAX) do entries[i] = { kind = "item", id = found[i].id } end
    return entries, short
end

-- the names a kind's macro may go by: its own, then numbered ones
local function Names(kind)
    local names = { kind.name }
    for n = 2, NAMES do names[n] = kind.name .. " " .. n end
    return names
end

-- the name of a kind's macro, if it is in the macro list: known by the line that marks it ours
function A.Macro(id)
    local kind = byId[id]
    if not kind then return nil end
    for _, name in ipairs(Names(kind)) do
        local _, _, body = GetMacroInfo(name)
        if type(body) == "string" and body:find(MARK .. kind.id, 1, true) == 1 then return name end
    end
    return nil
end

-- makes it if there is none, under the first of its names that no other macro has
local function Make(kind)
    local have = A.Macro(kind.id)
    if have then return have end
    for _, name in ipairs(Names(kind)) do
        if not GetMacroInfo(name) then
            local ok, index = pcall(CreateMacro, name, kind.icon, MARK .. kind.id, false)
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
    local flyout = { host = "", main = { kind = "macro", id = name }, auto = kind.id, entries = {} }
    list[#list + 1] = flyout
    return flyout
end

-- Puts a kind's macro on the cursor, to be dropped on a bar. Out of a fight.
function A.Pick(id)
    local kind = byId[id]
    if not kind then return false end
    if InCombatLockdown() then return false, TEXT.fight end
    local name = Make(kind)
    if not name then return false, TEXT.full end
    if not Flyout(kind, name) then return false end
    ClearCursor()
    -- dropped on a bar, the bar's change has the flyout look for its button
    PickupMacro(name)
    return true, name
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
    local changed = false
    owed = {}
    for _, flyout in ipairs(list) do
        if flyout.auto and byId[flyout.auto] then
            local entries = A.Entries(flyout.auto)
            if not Alike(entries, flyout.entries or {}) then changed = true end
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

for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, item)
    if not ns.started then return end
    if event == "PLAYER_LEVEL_UP" then grown = Count(item) end
    if event ~= "GET_ITEM_INFO_RECEIVED" then return A.Refresh() end
    -- only an item we wait for counts; they come one at a time: once they have stopped coming
    if not owed[item] or queued then return end
    queued = true
    C_Timer.After(WORD, function()
        queued = false
        A.Refresh()
    end)
end)
