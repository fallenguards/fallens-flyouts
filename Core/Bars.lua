local _, ns = ...
-- luacheck: read globals UIParent GetTime GetBindingAction EnumerateFrames HasAction GetActionInfo GetActionText
-- luacheck: read globals issecretvalue GetNumMacros GetMacroInfo GetMacroSpell C_Spell

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

-- The copy of a slot's button that the game's bind dialog shows while it is up, when one is in view:
-- the bar itself is put away then.
function B.Copy(slot)
    local frame = EnumerateFrames()
    while frame do
        if not frame:IsForbidden() and FrameIsType(frame, "CheckButton") then
            local name = FrameName(frame)
            if type(name) == "string" and name:find(DIALOG_COPIES) and frame:IsVisible()
                and (B.Slot(frame) == slot or frame:GetID() == slot) then
                return frame
            end
        end
        frame = EnumerateFrames(frame)
    end
end

-- whether a button is on the bars of the game's gamepad mode
function B.Pad(button)
    local name = button and button:GetName()
    return type(name) == "string" and name:find(PAD_BARS) ~= nil
end

-- every named action button there is
function B.All(fresh)
    local now = GetTime()
    if not fresh and inventory and now - inventoryAt < 5 then return inventory end
    inventory, inventoryAt = {}, now
    local frame = EnumerateFrames()
    while frame do
        if not frame:IsForbidden() and IsButton(frame) then inventory[#inventory + 1] = frame end
        frame = EnumerateFrames(frame)
    end
    table.sort(inventory, function(a, b) return a:GetName() < b:GetName() end)
    return inventory
end

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

-- a slot's action as kind and id; a macro goes by its name, and by its text with it
local function Read(slot)
    local kind, id = GetActionInfo(slot)
    if Secret(kind) or Secret(id) then return nil end
    if kind == "macro" then
        local entry = M.OnSlot(slot)
        if not entry then return nil end
        return kind, entry.id, entry.text
    end
    return kind, id
end

-- what a button holds, if it can lead a flyout
function B.Action(button)
    local slot = B.Slot(button)
    if not slot or not HasAction(slot) then return nil end
    local kind, id, text = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro") and id then
        return { kind = kind, id = id, text = text }
    end
end

-- what a bar slot holds, if it can go in a flyout
function B.ActionAt(slot)
    if type(slot) ~= "number" or not HasAction(slot) then return nil end
    local kind, id, text = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro") and id then
        return { kind = kind, id = id, text = text }
    end
end

function B.Holds(button, main)
    local slot = B.Slot(button)
    if not slot or not HasAction(slot) then return false end
    local kind, id, text = Read(slot)
    if kind == nil or kind ~= main.kind or id ~= main.id then return false end
    return kind ~= "macro" or M.Same(main, { id = id, text = text })
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
