local _, ns = ...
-- luacheck: read globals GetBindingKey IsBindingForGamePad

-- The addon's section of the game's key menu (Bindings.xml). Each flyout on
-- the bars has a heading there and a row for each of its spots: a key set on
-- a row picks that spot while its flyout is open. Under them, rows for the
-- spots of every flyout alike. The game lists the rows once, in the order of
-- the file: none can be added or hidden later, only named.
local B = {}
ns.Binds = B

-- flyouts with a heading of their own, and the spots of a flyout; Bindings.xml lists as many
B.SLOTS, B.PLACES = 8, 6
local SPOT, PICK = "FALLENSFLYOUTS_F", "FALLENSFLYOUTS_PICK"
B.SPOT, B.PICK = SPOT, PICK
B.CATEGORY = "BINDING_HEADER_FALLENSFLYOUTS"
local HELP = "PREFACE_FALLENSFLYOUTS_HELP"
local GRAY = "|cff808080%s|r"
local TEXT = {
    header = "Fallen's Flyouts",
    help = "Keys for the icons inside your flyouts. A key set here works while its flyout is open.",
    none = "Flyout %d: none yet",
    onPad = "%s (gamepad mode)",
    -- a heading kept for its keys while its flyout is not on the bars
    away = "%s (off your bars)",
    spot = "%d: %s",
    empty = "%d: (empty)",
    pick = "Spot %d of every flyout",
    pickHelp = "Every flyout: the keys of its spots where none is set above. With none set here they are 1 to 6.",
}
B.TEXT = TEXT

-- the command of spot i of the flyout with heading n
local function Command(n, i) return SPOT .. n .. "S" .. i end
B.Command = Command
local function Heading(n) return "PREFACE_" .. SPOT .. n end
B.Heading = Heading

-- the game reads a row's texts from globals of these names
_G[B.CATEGORY] = TEXT.header
_G[HELP] = TEXT.help
_G["PREFACE_" .. PICK] = TEXT.pickHelp
for n = 1, B.SLOTS do
    _G[Heading(n)] = TEXT.none:format(n)
    for i = 1, B.PLACES do _G["BINDING_NAME_" .. Command(n, i)] = TEXT.empty:format(i) end
end
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

-- the key and the pad button set for spot i of every flyout, if any
function B.Pick(i) return Held(PICK .. i) end

-- the key and the pad button set for spot i of the flyout with heading n, if any
function B.Spot(n, i)
    if not n then return nil end
    return Held(Command(n, i))
end

-- whether a key is set on any row under heading n
function B.Keyed(n)
    if not (n and GetBindingKey) then return false end
    for i = 1, B.PLACES do
        if GetBindingKey(Command(n, i)) ~= nil then return true end
    end
    return false
end

-- all our rows' keys as one string: it changes when the menu changes one
function B.State()
    if not GetBindingKey then return "" end
    local parts = {}
    for n = 1, B.SLOTS do
        for i = 1, B.PLACES do parts[#parts + 1] = table.concat({ GetBindingKey(Command(n, i)) }, " ") end
    end
    for i = 1, B.PLACES do parts[#parts + 1] = table.concat({ GetBindingKey(PICK .. i) }, " ") end
    return table.concat(parts, "|")
end

-- Heading n is named after the flyout it stands for; nil: no flyout has it.
-- `pad`: the flyout is on a bar of gamepad mode. `away`: it is on no bar now.
function B.Head(n, name, pad, away)
    local text = TEXT.none:format(n)
    if name and away then
        text = GRAY:format(TEXT.away:format(name))
    elseif name and pad then
        text = TEXT.onPad:format(name)
    elseif name then
        text = name
    end
    _G[Heading(n)] = text
end

-- row i under heading n is named after the icon in that spot; nil: the spot is empty
function B.Name(n, i, name)
    local text = TEXT.empty:format(i)
    if name then text = TEXT.spot:format(i, name) end
    _G["BINDING_NAME_" .. Command(n, i)] = text
end

-- the heading and the spot a command is a row of; nil for any other command
function B.Number(command)
    if type(command) ~= "string" then return nil end
    local n, i = command:match("^" .. SPOT .. "(%d+)S(%d+)$")
    if not n then return nil end
    return tonumber(n), tonumber(i)
end
