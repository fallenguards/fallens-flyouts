local _, ns = ...
-- luacheck: read globals GetBindingKey IsBindingForGamePad

-- The addon's rows in the game's key menu (Bindings.xml): a key of its own
-- for each flyout, and the keys that pick each place of an open one. The
-- flyouts on the bars of gamepad mode have rows under a heading of their own.
local B = {}
ns.Binds = B

-- rows of each kind; Bindings.xml lists as many
B.SLOTS, B.PAD_SLOTS, B.PLACES = 12, 6, 6
local OPEN, PADOPEN, PICK = "FALLENSFLYOUTS_OPEN", "FALLENSFLYOUTS_PADOPEN", "FALLENSFLYOUTS_PICK"
B.OPEN, B.PADOPEN, B.PICK = OPEN, PADOPEN, PICK
B.CATEGORY = "BINDING_HEADER_FALLENSFLYOUTS"
local TEXT = {
    header = "Fallen's Flyouts",
    open = "Flyout %d",
    openNamed = "Flyout %d: %s",
    -- a row kept for its key while its flyout is not on those bars
    openAway = "|cff808080Flyout %d (off): %s|r",
    pick = "Icon %d of an open flyout",
    openHelp = "Flyouts on your action bars. A key set here opens one, as the key of its bar button does.",
    padHelp = "Flyouts on the bars of gamepad mode. A key or a button set here opens one.",
    pickHelp = "The keys that pick from an open flyout. With none set here they are 1 to 6.",
}
B.TEXT = TEXT

-- the command of row n: of the gamepad mode rows with `pad`
local function Row(n, pad) return (pad and PADOPEN or OPEN) .. n end

-- how many rows there are of a kind
function B.Rows(pad)
    if pad then return B.PAD_SLOTS end
    return B.SLOTS
end

-- the game reads a row's texts from globals of these names
_G[B.CATEGORY] = TEXT.header
_G["PREFACE_" .. OPEN] = TEXT.openHelp
_G["PREFACE_" .. PADOPEN] = TEXT.padHelp
_G["PREFACE_" .. PICK] = TEXT.pickHelp
for n = 1, B.SLOTS do _G["BINDING_NAME_" .. OPEN .. n] = TEXT.open:format(n) end
for n = 1, B.PAD_SLOTS do _G["BINDING_NAME_" .. PADOPEN .. n] = TEXT.open:format(n) end
for i = 1, B.PLACES do _G["BINDING_NAME_" .. PICK .. i] = TEXT.pick:format(i) end

local function IsPad(key)
    if IsBindingForGamePad then return IsBindingForGamePad(key) == true end
    return key:find("PAD", 1, true) ~= nil
end

-- the key and the pad button a row holds
local function Held(command)
    if not GetBindingKey then return nil end
    local key, pad
    local one, two = GetBindingKey(command)
    if one then
        if IsPad(one) then pad = one else key = one end
    end
    if two then
        if IsPad(two) then pad = pad or two else key = key or two end
    end
    return key, pad
end

-- the key and the pad button set for place i of an open flyout, if any
function B.Pick(i) return Held(PICK .. i) end

-- every key set on row n
function B.Open(n, pad)
    if not (n and GetBindingKey) then return {} end
    return { GetBindingKey(Row(n, pad)) }
end

-- whether a key is set on row n
function B.Keyed(n, pad)
    return n ~= nil and GetBindingKey ~= nil and GetBindingKey(Row(n, pad)) ~= nil
end

-- all our rows' keys as one string: it changes when the menu changes one
function B.State()
    if not GetBindingKey then return "" end
    local parts = {}
    for n = 1, B.SLOTS do parts[#parts + 1] = table.concat({ GetBindingKey(OPEN .. n) }, " ") end
    for n = 1, B.PAD_SLOTS do parts[#parts + 1] = table.concat({ GetBindingKey(PADOPEN .. n) }, " ") end
    for i = 1, B.PLACES do parts[#parts + 1] = table.concat({ GetBindingKey(PICK .. i) }, " ") end
    return table.concat(parts, "|")
end

-- A row is named after the ability its flyout sits on; nil: no flyout has
-- the row. `away`: the flyout is not on those bars now, the row is its key's.
function B.Name(n, lead, pad, away)
    local text = TEXT.open:format(n)
    if lead then text = (away and TEXT.openAway or TEXT.openNamed):format(n, lead) end
    _G["BINDING_NAME_" .. Row(n, pad)] = text
end

-- the row a command is: its number, and whether it is a gamepad mode row; nil for any other command
function B.Number(command)
    if type(command) ~= "string" then return nil end
    local n = tonumber(command:match("^" .. OPEN .. "(%d+)$"))
    if n then return n, false end
    n = tonumber(command:match("^" .. PADOPEN .. "(%d+)$"))
    if n then return n, true end
    return nil
end
