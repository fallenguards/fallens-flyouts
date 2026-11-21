local _, ns = ...
-- luacheck: read globals UIParent GetTime GetBindingAction EnumerateFrames HasAction GetActionInfo GetActionText
-- luacheck: read globals issecretvalue

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

local function IsButton(frame)
    local name = frame:GetName()
    return frame:IsObjectType("CheckButton") and frame:IsProtected() and type(name) == "string"
        and not name:find(DIALOG_COPIES) and frame:GetAttribute("type") == "action" and B.Slot(frame) ~= nil
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

-- bar runs up and down: by the next button, else shape
function B.Tall(host)
    local stem, index = (host:GetName() or ""):match("^(.-)(%d+)$")
    local x, y = host:GetCenter()
    x, y = Plain(x), Plain(y)
    if stem and x and y then
        for _, step in ipairs({ 1, -1 }) do
            local near = _G[stem .. (tonumber(index) + step)]
            if type(near) == "table" and near ~= host and near.GetCenter and near:IsVisible() then
                local nx, ny = near:GetCenter()
                nx, ny = Plain(nx), Plain(ny)
                if nx and ny and (nx ~= x or ny ~= y) then
                    return math.abs(ny - y) > math.abs(nx - x), "next button"
                end
            end
        end
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

-- a slot's action as kind and id; a macro goes by its name
local function Read(slot)
    local kind, id = GetActionInfo(slot)
    if Secret(kind) or Secret(id) then return nil end
    if kind == "macro" then
        id = GetActionText and GetActionText(slot)
        if type(id) ~= "string" or Secret(id) or id == "" then return nil end
    end
    return kind, id
end

-- what a button holds, if it can lead a flyout
function B.Action(button)
    local slot = B.Slot(button)
    if not slot or not HasAction(slot) then return nil end
    local kind, id = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro") and id then return { kind = kind, id = id } end
end

-- what a bar slot holds, if it can go in a flyout
function B.ActionAt(slot)
    if type(slot) ~= "number" or not HasAction(slot) then return nil end
    local kind, id = Read(slot)
    if (kind == "spell" or kind == "item" or kind == "macro") and id then return { kind = kind, id = id } end
end

function B.Holds(button, main)
    local slot = B.Slot(button)
    if not slot or not HasAction(slot) then return false end
    local kind, id = Read(slot)
    return kind ~= nil and kind == main.kind and id == main.id
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
