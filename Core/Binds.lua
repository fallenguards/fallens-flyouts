local _, ns = ...
-- luacheck: read globals GetBindingKey IsBindingForGamePad

-- The addon's rows in the game's key menu (Bindings.xml): a key of its own
-- for each flyout, and the keys that pick each place of an open one.
local B = {}
ns.Binds = B

-- rows of each kind; Bindings.xml lists as many
B.SLOTS, B.PLACES = 12, 6
local OPEN, PICK = "FALLENSFLYOUTS_OPEN", "FALLENSFLYOUTS_PICK"
B.OPEN, B.PICK = OPEN, PICK
B.CATEGORY = "BINDING_HEADER_FALLENSFLYOUTS"
local TEXT = {
    header = "Fallen's Flyouts",
    open = "Flyout %d",
    openNamed = "Flyout %d: %s",
    pick = "Icon %d of an open flyout",
    openHelp = "A key of its own for each flyout. The key of its bar button opens it too.",
    pickHelp = "The keys that pick from an open flyout. With none set here they are 1 to 6.",
}
B.TEXT = TEXT

-- the game reads a row's texts from globals of these names
_G[B.CATEGORY] = TEXT.header
_G["PREFACE_" .. OPEN] = TEXT.openHelp
_G["PREFACE_" .. PICK] = TEXT.pickHelp
for n = 1, B.SLOTS do _G["BINDING_NAME_" .. OPEN .. n] = TEXT.open:format(n) end
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

-- every key set on the row of flyout number n
function B.Open(n)
    if not (n and GetBindingKey) then return {} end
    return { GetBindingKey(OPEN .. n) }
end

-- all our rows' keys as one string: it changes when the menu changes one
function B.State()
    if not GetBindingKey then return "" end
    local parts = {}
    for n = 1, B.SLOTS do parts[#parts + 1] = table.concat({ GetBindingKey(OPEN .. n) }, " ") end
    for i = 1, B.PLACES do parts[#parts + 1] = table.concat({ GetBindingKey(PICK .. i) }, " ") end
    return table.concat(parts, "|")
end

-- a flyout's row is named after the ability it sits on; nil: no flyout has that number
function B.Name(n, lead)
    _G["BINDING_NAME_" .. OPEN .. n] = lead and TEXT.openNamed:format(n, lead) or TEXT.open:format(n)
end

-- the number of the flyout a row's command opens; nil for any other command
function B.Number(command)
    return type(command) == "string" and tonumber(command:match("^" .. OPEN .. "(%d+)$")) or nil
end
