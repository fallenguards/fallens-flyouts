local _, ns = ...
-- luacheck: read globals GetBindingKey IsBindingForGamePad SETTINGS_QUICK_KEYBIND_BUTTON InCombatLockdown
-- luacheck: read globals SetBinding SaveBindings GetCurrentBindingSet GetBindingAction GetBindingText

-- The addon's section of the game's key menu (Bindings.xml): a row for each of the twelve spots of an
-- open flyout, the same for every flyout. A key set on a row picks that spot while a flyout is open.
-- A key for one icon of one flyout is no row here: it is set on the addon's own settings page
-- (Options/Arrange.lua), or by a hover in the game's Quick Keybind Mode (UI/Keys.lua), and the section's
-- last lines say so.
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
    -- every key there is, sent for to the addon's settings (the game lists no more rows than these)
    -- His words (2026-11-24): "we need to provide ability to change the default flyout keybinds in our settings
    -- menu next to the specific flyout ones too (above them) so ppl can access everything in one place. while we
    -- can't do that in the keybindings menu itself due to limitations, we can at least put a message there (if
    -- there isn't already) that ... they should view our \"/ff\" settings to see full keybinding
    -- functionality", and "maybe dont mention api. no one using it will know what that means".
    one = "All flyout keys, these and the keys of one flyout, are in the addon's settings: /ff.",
    one2 = "Or use %s above: open the flyout, hover an icon, press the key.",
    quick = "Quick Keybind Mode",
    -- a key that did something else, taken from it as the game's own key menu takes it
    took = "%s did %s: it picks spot %d of every flyout now.",
}
B.TEXT = TEXT

-- the command of spot i of the flyout that had heading n, in the rows of before
local function Command(n, i) return SPOT .. n .. "S" .. i end
B.Command = Command

-- the game reads a row's texts from globals of these names
_G[B.CATEGORY] = TEXT.header
_G.PREFACE_FALLENSFLYOUTS_HELP = TEXT.help
_G.PREFACE_FALLENSFLYOUTS_HELP2 = TEXT.help2
_G.PREFACE_FALLENSFLYOUTS_ONE = TEXT.one
_G.PREFACE_FALLENSFLYOUTS_ONE2 = TEXT.one2:format(SETTINGS_QUICK_KEYBIND_BUTTON or TEXT.quick)
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

-- Spot i of every flyout set to `key` (a pad button where `pad`), from the addon's settings, as the game's
-- key menu sets its row: the row's key of that kind replaced and the game's keys saved. A key that did
-- something else is taken from that, the game's own way, and it is said in red. No key: the row's key of
-- that kind cleared, and spot i has its usual key again.
function B.SetPick(i, key, pad)
    if InCombatLockdown() then return false, ns.Flyouts.TEXT.fight end
    if not (SetBinding and GetBindingKey) then return false end
    local command = PICK .. i
    local had, hadPad = Held(command)
    if key == nil and pad == nil then
        -- the row as it was: its usual key and pad button both
        if had then SetBinding(had) end
        if hadPad then SetBinding(hadPad) end
    else
        local old = pad and hadPad or (not pad and had)
        if old then SetBinding(old) end
    end
    if key then
        local was = GetBindingAction(key)
        if type(was) == "string" and was ~= "" and was ~= command then
            local named = _G["BINDING_NAME_" .. was]
            ns.Warn(TEXT.took:format(GetBindingText and GetBindingText(key) or key,
                type(named) == "string" and named or was, i))
        end
        SetBinding(key, command)
    end
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    return true
end

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
