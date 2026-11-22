local _, ns = ...
-- luacheck: read globals GetBindingKey IsBindingForGamePad SETTINGS_QUICK_KEYBIND_BUTTON

-- The addon's section of the game's key menu (Bindings.xml): a row for each of the twelve spots of an
-- open flyout, the same for every flyout. A key set on a row picks that spot while a flyout is open.
-- A key for one icon of one flyout is no row here: it is set by a hover in the game's Quick Keybind
-- Mode (UI/Keys.lua), and the section's last lines say so.
-- Before 1.1.4 the section also had a heading and six rows for each of eight flyouts, used or not.
-- His words (2026-11-22): "why have empty flyouts here? that makes no sense. ... this makes it seem
-- like 8 is max". The game lists a section's rows once and none can be added or hidden while playing,
-- so those rows are gone from the list. They are still declared, hidden, for one reason: a key someone
-- set on one is read from it and becomes its icon's own key (Core/Flyouts.lua).
local B = {}
ns.Binds = B

-- the rows of the spots of every flyout: as many as a flyout holds
B.PICKS = 12
-- the rows of before: the flyouts that had a heading, and the spots under each
B.SLOTS, B.PLACES = 8, 6
local SPOT, PICK = "FALLENSFLYOUTS_F", "FALLENSFLYOUTS_PICK"
B.SPOT, B.PICK = SPOT, PICK
B.CATEGORY = "BINDING_HEADER_FALLENSFLYOUTS"
-- A line of the key menu is one line, 580 wide: each of these fits.
local TEXT = {
    header = "Fallen's Flyouts",
    help = "Keys for the icons inside your flyouts, the same for every flyout.",
    help2 = "They work while a flyout is open. With none set here they are 1 to 9, 0, - and =.",
    pick = "Spot %d of every flyout",
    -- the game's own name for its mode goes in where the game gives one
    one = "For a key on one icon of one flyout, use %s at the top of this page:",
    one2 = "open the flyout, hover the icon and press the key.",
    quick = "Quick Keybind Mode",
}
B.TEXT = TEXT

-- the command of spot i of the flyout that had heading n, in the rows of before
local function Command(n, i) return SPOT .. n .. "S" .. i end
B.Command = Command

-- the game reads a row's texts from globals of these names
_G[B.CATEGORY] = TEXT.header
_G.PREFACE_FALLENSFLYOUTS_HELP = TEXT.help
_G.PREFACE_FALLENSFLYOUTS_HELP2 = TEXT.help2
_G.PREFACE_FALLENSFLYOUTS_ONE = TEXT.one:format(SETTINGS_QUICK_KEYBIND_BUTTON or TEXT.quick)
_G.PREFACE_FALLENSFLYOUTS_ONE2 = TEXT.one2
for i = 1, B.PICKS do _G["BINDING_NAME_" .. PICK .. i] = TEXT.pick:format(i) end

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

-- the key and the pad button once set on row i under heading n, in the rows of before, if any
function B.Spot(n, i)
    if not n then return nil end
    return Held(Command(n, i))
end

-- the rows' keys as one string: it changes when the menu changes one
function B.State()
    if not GetBindingKey then return "" end
    local parts = {}
    for i = 1, B.PICKS do parts[#parts + 1] = table.concat({ GetBindingKey(PICK .. i) }, " ") end
    return table.concat(parts, "|")
end
