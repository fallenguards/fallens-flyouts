local _, ns = ...
-- luacheck: read globals UIParent GetTime GetBindingAction EnumerateFrames HasAction GetActionInfo GetActionText
-- luacheck: read globals issecretvalue GetNumMacros GetMacroInfo GetMacroSpell C_Spell C_MountJournal PlayerHasToy
-- luacheck: read globals C_PetJournal C_ToyBox C_EquipmentSet

-- Action buttons, whoever made them, found by what they are.
local B = {}
ns.Bars = B

-- the game's own bars: button name to binding command
local CLIENT_BARS = {
    { "ActionButton", "ACTIONBUTTON" },
    { "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
    { "MultiBarBottomRightButton", "MULTIACTIONBAR2BUTTON" },
    { "MultiBarRightButton", "MULTIACTIONBAR3BUTTON" },
    { "MultiBarLeftButton", "MULTIACTIONBAR4BUTTON" },
    { "MultiBar5Button", "MULTIACTIONBAR5BUTTON" },
    { "MultiBar6Button", "MULTIACTIONBAR6BUTTON" },
    { "MultiBar7Button", "MULTIACTIONBAR7BUTTON" },
}
local MODS = { "", "SHIFT-", "CTRL-", "ALT-", "CTRL-SHIFT-", "ALT-SHIFT-", "ALT-CTRL-", "ALT-CTRL-SHIFT-" }
local PAD_KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK",
    "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PADFORWARD", "PADBACK",
}
local OTHER_KEYS = {
    "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "`", "SPACE", "TAB", "ENTER", "BACKSPACE", "DELETE", "INSERT",
    "HOME", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT", "NUMPADDIVIDE", "NUMPADMULTIPLY",
    "NUMPADMINUS", "NUMPADPLUS", "NUMPADDECIMAL", "MOUSEWHEELUP", "MOUSEWHEELDOWN",
}
local BAR_BUTTON = 45
-- how many buttons along its bar a button looks for one to read the bar's run from
local NEIGHBORS = 11
-- the game's gamepad bind dialog shows copies of the console bar: no bar of anyone's
local DIALOG_COPIES = "^GamepadActionBarEditFrame"
-- and gamepad mode has bars of its own
local PAD_BARS = "^GamepadMainActionBarFrame"

local universe, keyMap, keyMapAt, inventory, inventoryAt

local function Secret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function Plain(v)
    if type(v) ~= "number" or Secret(v) then return nil end
    return v
end
B.Plain = Plain

local function Universe()
    if universe then return universe end
    local base = {}
    for c = 65, 90 do base[#base + 1] = string.char(c) end
    for d = 0, 9 do
        base[#base + 1] = tostring(d)
        base[#base + 1] = "NUMPAD" .. d
    end
    for f = 1, 24 do base[#base + 1] = "F" .. f end
    for b = 3, 31 do base[#base + 1] = "BUTTON" .. b end
    for _, key in ipairs(OTHER_KEYS) do base[#base + 1] = key end
    for _, key in ipairs(PAD_KEYS) do base[#base + 1] = key end
    universe = {}
    for _, mod in ipairs(MODS) do
        for _, key in ipairs(base) do universe[#universe + 1] = mod .. key end
    end
    return universe
end

-- what every key does now: action to its keys
function B.KeyMap(fresh)
    local now = GetTime()
    if not fresh and keyMap and now - keyMapAt < 1 then return keyMap end
    keyMap, keyMapAt = {}, now
    for _, key in ipairs(Universe()) do
        local action = GetBindingAction(key, true)
        if action and action ~= "" then
            local keys = keyMap[action]
            if not keys then
                keys = {}
                keyMap[action] = keys
            end
            keys[#keys + 1] = key
        end
    end
    return keyMap
end

local function ClientCommand(name)
    for _, bar in ipairs(CLIENT_BARS) do
        local index = name:match("^" .. bar[1] .. "(%d+)$")
        if index then return bar[2] .. index end
    end
end

function B.Slot(button)
    local slot = button.action
    if type(slot) ~= "number" or slot <= 0 then slot = button:GetAttribute("action") end
    if type(slot) == "number" and slot > 0 then return slot end
end

-- Every frame there is gets asked: only by the frame calls themselves, never by a frame's own field
-- of the same name. The game's spellbook entries have a GetName of their own (a spell's name), which
-- fails on an entry with no spell.
local FrameName, FrameIsType = UIParent.GetName, UIParent.IsObjectType
local function IsButton(frame)
    -- the cheap and certain test first: anything but a check button is no action button
    if not FrameIsType(frame, "CheckButton") then return false end
    local name = FrameName(frame)
    return type(name) == "string" and frame:IsProtected() and not name:find(DIALOG_COPIES)
        and frame:GetAttribute("type") == "action" and B.Slot(frame) ~= nil
end

-- The copies of the bar's buttons that the game's bind dialog shows while it is up (the bar itself is
-- put away then), by the slot each stands for: its ID, which is what the dialog itself reads off it.
-- `seen`: only those in view.
local FrameID, FrameSeen = UIParent.GetID, UIParent.IsVisible
-- found once for each time the dialog comes up: walking every frame there is costs too much to repeat
local copyList
local function CopyList()
    if copyList and #copyList > 0 then return copyList end
    copyList = {}
    local frame = EnumerateFrames()
    while frame do
        if not frame:IsForbidden() and FrameIsType(frame, "CheckButton") then
            local name = FrameName(frame)
            if type(name) == "string" and name:find(DIALOG_COPIES) then copyList[#copyList + 1] = frame end
        end
        frame = EnumerateFrames(frame)
    end
    return copyList
end
function B.ForgetCopies() copyList = nil end
function B.Copies(seen)
    local out = {}
    for _, frame in ipairs(CopyList()) do
        local slot = FrameID(frame)
        if type(slot) == "number" and slot > 0 and (not seen or FrameSeen(frame)) then out[slot] = frame end
    end
    return out
end
function B.Copy(slot) return B.Copies(true)[slot] end

-- whether a button is on the bars of the game's gamepad mode
function B.Pad(button)
    local name = button and button:GetName()
    return type(name) == "string" and name:find(PAD_BARS) ~= nil
end

-- every named action button there is, read now
local function Scan()
    local found = {}
    local frame = EnumerateFrames()
    while frame do
        if not frame:IsForbidden() and IsButton(frame) then found[#found + 1] = frame end
        frame = EnumerateFrames(frame)
    end
    table.sort(found, function(a, b) return a:GetName() < b:GetName() end)
    return found
end
-- the same, as last read if that was a moment ago
function B.All(fresh)
    local now = GetTime()
    if not fresh and inventory and now - inventoryAt < 5 then return inventory end
    inventory, inventoryAt = Scan(), now
    return inventory
end
-- what B.All last read, with no new reading; and a reading of the caller's own, which B.All does not keep
function B.Known() return inventory end
B.Scan = Scan

-- a saved name back to its button, if it still is one
function B.Named(name)
    local frame = type(name) == "string" and _G[name]
    if type(frame) ~= "table" or type(frame.IsObjectType) ~= "function" then return nil end
    if frame:IsForbidden() or not IsButton(frame) then return nil end
    return frame
end

-- a key may click the button itself or a helper child of it
local function Within(frame, host)
    for _ = 1, 3 do
        if type(frame) ~= "table" or type(frame.IsForbidden) ~= "function" or frame:IsForbidden() then return false end
        if frame == host then return true end
        frame = frame:GetParent()
    end
    return false
end

-- the keys that press this button now
function B.Keys(host, fresh)
    local commands, keys = {}, {}
    local function Add(command)
        if type(command) == "string" and command ~= "" then commands[command] = true end
    end
    Add(host.commandName)
    Add(host:GetAttribute("commandName"))
    Add(ClientCommand(host:GetName()))
    for action, list in pairs(B.KeyMap(fresh)) do
        local target = action:match("^CLICK (.-):")
        if commands[action] or (target and Within(_G[target], host)) then
            for _, key in ipairs(list) do keys[#keys + 1] = key end
        end
    end
    table.sort(keys)
    return keys
end

-- a button's size against the game's 45
function B.Size(host)
    local w = Plain(host:GetWidth())
    return w and w > 0 and w / BAR_BUTTON or 1
end

-- that, times the bar's own scale: for what sits beside the bar
function B.Scale(host)
    return host:GetEffectiveScale() / UIParent:GetEffectiveScale() * B.Size(host)
end

-- Bar runs up and down: read off the nearest other button of its bar, a
-- shown one first. A hidden one will do: an empty button is hidden at
-- times, and it is still in its place. Else the bar's shape.
function B.Tall(host)
    local stem, index = (host:GetName() or ""):match("^(.-)(%d+)$")
    local x, y = host:GetCenter()
    x, y = Plain(x), Plain(y)
    if stem and x and y then
        index = tonumber(index)
        local spare
        for away = 1, NEIGHBORS do
            for _, step in ipairs({ away, -away }) do
                local near = _G[stem .. (index + step)]
                if type(near) == "table" and near ~= host and near.GetCenter then
                    local nx, ny = near:GetCenter()
                    nx, ny = Plain(nx), Plain(ny)
                    if nx and ny and (nx ~= x or ny ~= y) then
                        local tall = math.abs(ny - y) > math.abs(nx - x)
                        if near:IsVisible() then return tall, "next button" end
                        if spare == nil then spare = tall end
                    end
                end
            end
        end
        if spare ~= nil then return spare, "a hidden button" end
    end
    local parent = host:GetParent()
    if parent and parent ~= UIParent then
        local w, h = Plain(parent:GetWidth()), Plain(parent:GetHeight())
        return w ~= nil and h ~= nil and h > w, "bar shape"
    end
    return false, "nothing"
end

-- away from the bar it sits in, toward the middle of the screen
function B.Way(host)
    local tall, from = B.Tall(host)
    local x, y = host:GetCenter()
    x, y = Plain(x), Plain(y)
    local scale = host:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local runs = (tall and "up and down" or "side to side") .. " by " .. from
    if tall then
        return x and x * scale > UIParent:GetWidth() / 2 and "LEFT" or "RIGHT", runs
    end
    return y and y * scale > UIParent:GetHeight() / 2 and "DOWN" or "UP", runs
end

-- where a flyout was laid out; a change lays it again
function B.Placed(host)
    local x, y = host:GetCenter()
    local function Whole(v) return math.floor((Plain(v) or 0) + 0.5) end
    return ("%s %d %d %d %.2f"):format((B.Way(host)), Whole(x), Whole(y), Whole(host:GetWidth()), B.Scale(host))
end

-- Macros. A macro is known by its name and its text. Names are shared freely (a name of one space, to
-- keep it off the button, is common), and the text tells two of one name apart. A macro's entry is
-- { kind = "macro", id = name, text = text }. One with no text (older saved data, a flyout that fills
-- itself) goes by its name alone, as the first macro of that name.
local M = {}
ns.Macros = M
local ACCOUNT_MACROS = 120
local cache, memo

-- the macro list by place: { place, name, text, icon }
local function List()
    if cache then return cache end
    cache, memo = {}, setmetatable({}, { __mode = "k" })
    if not (GetNumMacros and GetMacroInfo) then return cache end
    local shared, own = GetNumMacros()
    local function Add(place)
        local name, icon, text = GetMacroInfo(place)
        if type(name) ~= "string" or Secret(name) then return end
        if Secret(text) or type(text) ~= "string" then text = nil end
        cache[#cache + 1] = { place = place, name = name, text = text, icon = icon }
    end
    for place = 1, shared or 0 do Add(place) end
    for place = ACCOUNT_MACROS + 1, ACCOUNT_MACROS + (own or 0) do Add(place) end
    return cache
end
M.List = List
-- the macro list is read afresh at the next asking
function M.Changed() cache, memo = nil, nil end

-- the entry for the macro at a place in the list
function M.Entry(place)
    if type(place) ~= "number" then return nil end
    for _, m in ipairs(List()) do
        if m.place == place then return { kind = "macro", id = m.name, text = m.text } end
    end
end

-- two macro entries are one macro: of one name, and of one text where both have a text
function M.Same(a, b)
    return a.id == b.id and (a.text == nil or b.text == nil or a.text == b.text)
end

-- The place in the list of an entry's macro, and how many macros have its name. By its name and text.
-- By its name alone for an entry with no text, and for one whose text no macro has any more while its
-- name is one macro's only (its text was changed while no one watched).
function M.Find(entry)
    List()
    local known = memo[entry]
    if known then return known[1], known[2] end
    local first, exact
    local count = 0
    for _, m in ipairs(cache) do
        if m.name == entry.id then
            count = count + 1
            first = first or m.place
            if not exact and entry.text ~= nil and m.text == entry.text then exact = m.place end
        end
    end
    local place = exact
    if not place and (entry.text == nil or count == 1) then place = first end
    memo[entry] = { place or false, count }
    return place or false, count
end

-- What a secure button is given to run an entry's macro: its name while no other macro has it (a name
-- stays right when the list shifts), else its place in the list.
function M.Run(entry)
    local place, count = M.Find(entry)
    if place and count > 1 then return place end
    return entry.id
end

-- what to ask the game about an entry's macro by: its place, or its name when it is not in the list
function M.Ref(entry) return M.Find(entry) or entry.id end

-- A name to show for an entry's macro. One with a blank name is named by the spell it stands for just
-- now, else by what its text casts first.
function M.Name(entry)
    local name = entry.id
    if type(name) == "string" and name:find("%S") then return name end
    local place = M.Find(entry)
    local spell = place and GetMacroSpell and GetMacroSpell(place)
    if spell and not Secret(spell) and C_Spell and C_Spell.GetSpellName then
        local known = C_Spell.GetSpellName(spell)
        if type(known) == "string" and not Secret(known) and known ~= "" then return known end
    end
    local text = entry.text
    if not text and place then
        for _, m in ipairs(cache) do
            if m.place == place then text = m.text end
        end
    end
    if type(text) ~= "string" then return nil end
    for line in text:gmatch("[^%c]+") do
        -- the first word (#showtooltip, /cast) and any conditions are left out
        local rest = line:gsub("^%s*[#/]%a+%s*", "")
        rest = rest:gsub("%b[]", "")
        rest = rest:match("^%s*([^;]-)%s*$")
        if rest and rest ~= "" then return rest end
    end
    return nil
end

-- The macro on a bar slot, as an entry. The game gives the macro's place in the list for the slot (seen
-- on Forever: "macro", 6, ""). Where it gives a spell or an item in its place (a macro that stands for
-- one just now), the macros of the slot's name are told apart by the spell they stand for; when that
-- leaves several of different texts, the entry has no text and goes by the name.
function M.OnSlot(slot)
    local kind, id, sub = GetActionInfo(slot)
    if kind ~= "macro" or Secret(id) or Secret(sub) then return nil end
    local name = GetActionText and GetActionText(slot)
    if type(name) ~= "string" or Secret(name) or name == "" then return nil end
    local list = List()
    local numbered = type(id) == "number" and sub ~= "spell" and sub ~= "item"
    if numbered then
        for _, m in ipairs(list) do
            if m.place == id and m.name == name then return { kind = "macro", id = name, text = m.text } end
        end
    end
    local text, several
    local found = false
    for _, m in ipairs(list) do
        if m.name == name then
            local fits = true
            if sub == "spell" and GetMacroSpell then
                local spell = GetMacroSpell(m.place)
                fits = not Secret(spell) and spell == id
            end
            if fits then
                if found and m.text ~= text then several = true end
                found, text = true, text or m.text
            end
        end
    end
    if several then text = nil end
    return { kind = "macro", id = name, text = text }
end

-- the kinds of their own a flyout holds besides spells, items and macros: mounts, battle pets and gear sets
-- (below)
local KINDS = {}
B.Kinds = KINDS

-- a slot's action as kind and id; a macro goes by its name, and by its text with it; a mount and a battle
-- pet as kinds of their own (the slot says "summonmount" and the mount's number, "summonpet" and the pet's)
local function Read(slot)
    local kind, id = GetActionInfo(slot)
    if Secret(kind) or Secret(id) then return nil end
    if kind == "macro" then
        local entry = M.OnSlot(slot)
        if not entry then return nil end
        return kind, entry.id, entry.text
    end
    if kind == "summonmount" then
        kind = "mount"
    elseif kind == "summonpet" then
        kind = "battlepet"
    end
    if KINDS[kind] and not KINDS[kind].Known(id) then return nil end
    return kind, id
end

-- Toys, mounts and battle pets. A player's report (2026-11-23): "I keep getting the red error message at
-- the top of my screen that says "That is in the flyout already." when attempting to add different
-- hearthstones to one flyout. A similar issue when trying to add a campfire toy to a 'professions' one, it
-- vanishes from the cursor and says the same thing. The mounts have no + symbol popping up at all when one
-- is selected." His words (2026-11-23): "we should support literally any item that can go on an action
-- bar". Seen on his account (/ffdev toys and /ffdev kinds, 2026-11-23): the Toy Box puts a toy on the
-- cursor as "item" and its number, the bags hold none of it, and the item calls take it for one in the
-- bags (C_Item.IsUsableItem false where C_ToyBox.IsToyUsable is true); the mount journal puts a mount there
-- as "mount", its number and its place in the journal's list, a bar slot keeps it as "summonmount" and the
-- number, and the spell calls take its spell for unusable; the Pet Journal puts a battle pet there as
-- "battlepet" and its GUID, a bar slot keeps it as "summonpet" and the GUID. So each by its own calls:
-- `Known`, `Name`, `Icon`, `Usable`, `Tip` (the tooltip the game gives it), `Macro` (the line that casts
-- it from a flyout's icon, as the game's own slash command does) and `Pickup` (onto the cursor as its
-- journal puts it there).

-- a mount by its number: its name, its spell, its picture and whether it can be summoned here and now
local function MountInfo(id)
    local MJ = C_MountJournal
    if type(id) ~= "number" or Secret(id) or not (MJ and MJ.GetMountInfoByID) then return nil end
    local ok, name, spell, icon, _, usable = pcall(MJ.GetMountInfoByID, id)
    if not ok or type(name) ~= "string" or Secret(name) or name == "" then return nil end
    return name, spell, icon, usable
end
KINDS.mount = {
    Known = function(id) return MountInfo(id) ~= nil end,
    Name = function(id) return (MountInfo(id)) end,
    Icon = function(id) return (select(3, MountInfo(id))) end,
    Usable = function(id)
        local _, _, _, usable = MountInfo(id)
        return Secret(usable) or usable ~= false
    end,
    Tip = function(tip, id)
        local name, spell = MountInfo(id)
        if spell and not Secret(spell) and tip.SetMountBySpellID then return tip:SetMountBySpellID(spell) end
        if name then tip:SetText(name) end
    end,
    Macro = function(id)
        local name = MountInfo(id)
        return name and ("/cast " .. name) or nil
    end,
    -- by its place in the journal's list; none while the journal's search or filters leave it out
    Pickup = function(id)
        local MJ = C_MountJournal
        if not (MJ and MJ.GetNumDisplayedMounts and MJ.GetDisplayedMountInfo and MJ.Pickup) then return end
        for i = 1, MJ.GetNumDisplayedMounts() or 0 do
            if select(12, MJ.GetDisplayedMountInfo(i)) == id then return MJ.Pickup(i) end
        end
    end,
}

-- a battle pet by its GUID: the name it goes by (one given it, else its own) and its picture
local function PetInfo(guid)
    local PJ = C_PetJournal
    if type(guid) ~= "string" or Secret(guid) or not (PJ and PJ.GetPetInfoByPetID) then return nil end
    local ok, _, custom, _, _, _, _, _, name, icon = pcall(PJ.GetPetInfoByPetID, guid)
    if not ok then return nil end
    if type(custom) == "string" and not Secret(custom) and custom ~= "" then name = custom end
    if type(name) ~= "string" or Secret(name) or name == "" then return nil end
    return name, icon
end
KINDS.battlepet = {
    Known = function(guid) return PetInfo(guid) ~= nil end,
    Name = function(guid) return (PetInfo(guid)) end,
    Icon = function(guid) return (select(2, PetInfo(guid))) end,
    Usable = function(guid)
        local PJ = C_PetJournal
        if not (PJ and PJ.PetIsSummonable) then return true end
        local ok, can = pcall(PJ.PetIsSummonable, guid)
        return not ok or Secret(can) or can ~= false
    end,
    Tip = function(tip, guid)
        if tip.SetCompanionPet then return tip:SetCompanionPet(guid) end
        local name = PetInfo(guid)
        if name then tip:SetText(name) end
    end,
    Macro = function(guid) return "/summonpet " .. guid end,
    Pickup = function(guid)
        if C_PetJournal and C_PetJournal.PickupPet then C_PetJournal.PickupPet(guid) end
    end,
}

-- A gear set, the equipment manager's, by its name. His words (2026-11-24): "we need to add ability for gear
-- sets to be in flyouts too." Seen on his account (/ffdev gear, 2026-11-24): the equipment manager puts a
-- set on the cursor as "equipmentset" and its name, a bar slot keeps it the same way, and the tooltip has
-- the game's own SetEquipmentSet. A click puts the set on as the game's /equipset does.
local function GearInfo(name)
    local ES = C_EquipmentSet
    if type(name) ~= "string" or Secret(name) or name == "" then return nil end
    if not (ES and ES.GetEquipmentSetID and ES.GetEquipmentSetInfo) then return nil end
    local ok, id = pcall(ES.GetEquipmentSetID, name)
    if not ok or type(id) ~= "number" or Secret(id) then return nil end
    local got, _, icon = pcall(ES.GetEquipmentSetInfo, id)
    if not got then return nil end
    return id, icon
end
KINDS.equipmentset = {
    Known = function(name) return GearInfo(name) ~= nil end,
    Name = function(name) return GearInfo(name) and name or nil end,
    Icon = function(name) return (select(2, GearInfo(name))) end,
    Usable = function(name) return GearInfo(name) ~= nil end,
    Tip = function(tip, name)
        if tip.SetEquipmentSet then return tip:SetEquipmentSet(name) end
        tip:SetText(name)
    end,
    Macro = function(name) return "/equipset " .. name end,
    Pickup = function(name)
        local id = GearInfo(name)
        if id and C_EquipmentSet.PickupEquipmentSet then C_EquipmentSet.PickupEquipmentSet(id) end
    end,
}

-- whether an item is a toy of the player's own: kept in the Toy Box, never in the bags
function B.OwnToy(id)
    if not PlayerHasToy or type(id) ~= "number" then return false end
    local ok, own = pcall(PlayerHasToy, id)
    return ok and not Secret(own) and own == true
end

-- whether a toy of the player's own can be used here and now, as the Toy Box asks it
function B.ToyUsable(id)
    if not (C_ToyBox and C_ToyBox.IsToyUsable) then return true end
    local ok, usable = pcall(C_ToyBox.IsToyUsable, id)
    return not ok or Secret(usable) or usable ~= false
end

-- what a button holds, if it can lead a flyout
function B.Action(button)
    local slot = B.Slot(button)
    if not slot or not HasAction(slot) then return nil end
    local kind, id, text = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro" or KINDS[kind]) and id then
        return { kind = kind, id = id, text = text }
    end
end

-- what a bar slot holds, if it can go in a flyout
function B.ActionAt(slot)
    if type(slot) ~= "number" or not HasAction(slot) then return nil end
    local kind, id, text = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro" or KINDS[kind]) and id then
        return { kind = kind, id = id, text = text }
    end
end

-- whether a slot holds an action
function B.HoldsAt(slot, main)
    if not slot or not HasAction(slot) then return false end
    local kind, id, text = Read(slot)
    if kind == nil or kind ~= main.kind or id ~= main.id then return false end
    return kind ~= "macro" or M.Same(main, { id = id, text = text })
end

function B.Holds(button, main)
    return B.HoldsAt(B.Slot(button), main)
end

-- Action Bar 1 of the game's own turns its twelve buttons to another page of slots: a druid's form, a
-- stance, stealth, the bar's page arrows. The game sets the bar's "actionpage" for it (its
-- ActionBarController, in a fight too), and button i stands then for slot (page - 1) * 12 + i (the
-- buttons' CalculateAction, which reads the page off the bar). A button some other addon gives a slot
-- of its own (an "action" of its own, as Dominos does) is not turned so.
local MAIN_BAR, MAIN_BUTTON, MAIN_COUNT = "MainActionBar", "ActionButton", 12
-- the most pages a slot of the bar can be on: its six own, the forms' and stances', a vehicle's, a
-- passing shapeshift's and an override bar's
local MAIN_PAGES = 14
B.MAIN_BAR, B.MAIN_BUTTON, B.MAIN_COUNT = MAIN_BAR, MAIN_BUTTON, MAIN_COUNT
-- What the game turns the bar's page by (its ActionBarController: a vehicle's bar, an override bar, a
-- passing shapeshift, the bar's own page, a form's or stance's bar), as a state driver's conditions: the
-- state changes whenever the page may have. The page itself is read off the bar.
B.PAGE_STATES = "[vehicleui]v;[overridebar]o;[shapeshift]t;[possessbar]p;[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;"
    .. "[bar:6]6;[bonusbar:1]b1;[bonusbar:2]b2;[bonusbar:3]b3;[bonusbar:4]b4;[bonusbar:5]b5;1"

-- the bar, while it turns its buttons by its page
function B.MainBar()
    local bar = _G[MAIN_BAR]
    if type(bar) ~= "table" or type(bar.GetAttribute) ~= "function" then return nil end
    if not tonumber(bar:GetAttribute("actionpage")) then return nil end
    return bar
end

-- i, for the button of Action Bar 1 the bar turns by its page; nil for any other button
function B.MainIndex(name)
    if type(name) ~= "string" or not B.MainBar() then return nil end
    local i = tonumber(name:match("^" .. MAIN_BUTTON .. "(%d+)$"))
    if not i or i < 1 or i > MAIN_COUNT then return nil end
    local button = B.Named(name)
    if not button or button:GetAttribute("action") ~= nil then return nil end
    return i
end

-- the slots button i of the bar stands for on those of its pages that hold `main`
function B.PageSlots(i, main)
    local out = {}
    for page = 1, MAIN_PAGES do
        local slot = (page - 1) * MAIN_COUNT + i
        if B.HoldsAt(slot, main) then out[#out + 1] = slot end
    end
    return out
end

function B.Used(button)
    local slot = B.Slot(button)
    return button:IsVisible() and slot ~= nil and HasAction(slot)
end

-- The first shown button that holds an action, by name. With `hidden`, and
-- none shown, a button of the game's own bars that holds it on a hidden bar.
function B.Find(main, buttons, hidden)
    for _, button in ipairs(buttons or B.All(true)) do
        if button:IsVisible() and B.Holds(button, main) then return button:GetName() end
    end
    if not hidden then return nil end
    for _, bar in ipairs(CLIENT_BARS) do
        for i = 1, 12 do
            local button = B.Named(bar[1] .. i)
            if button and B.Holds(button, main) then return button:GetName() end
        end
    end
    return nil
end
