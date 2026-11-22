local _, ns = ...
-- luacheck: read globals InCombatLockdown KeybindFrames_InQuickKeybindMode GameTooltip
-- luacheck: read globals CreateKeyChordStringUsingMetaKeyState IsKeyPressIgnoredForBinding QuickKeybindFrame
-- luacheck: read globals IsAltKeyDown IsControlKeyDown IsShiftKeyDown

-- An icon's own key inside its flyout: in the game's Quick Keybind Mode, hover the icon and press the
-- key. Nothing here touches the game's key bindings: a flyout's keys count only while it is open.
local K = {}
ns.Keys = K
local F = ns.Flyouts

local TEXT = {
    press = "Press a key to pick this with.",
    reset = "Backspace gives it its own key back.",
}
-- keys that only go with another key
local ALONE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true,
    RMETA = true, UNKNOWN = true }
-- these give an icon its place's key and pad button back
local RESET = { BACKSPACE = true, DELETE = true }

local hooked = false
local hovered

local function Quick()
    return KeybindFrames_InQuickKeybindMode ~= nil and KeybindFrames_InQuickKeybindMode() == true
end

-- whether a hover and a press set a key right now
function K.On()
    if InCombatLockdown() then return false end
    return Quick()
end

-- the key with the modifiers held, in the game's own order
local function Chord(key)
    if CreateKeyChordStringUsingMetaKeyState then return CreateKeyChordStringUsingMetaKeyState(key) end
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end

local function Tip(frame)
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(TEXT.press)
    GameTooltip:AddLine(TEXT.reset, 1, 1, 1, true)
    GameTooltip:Show()
end

function K.Leave() hovered = nil end

-- a key or pad button pressed over the hovered icon
function K.Pressed(key, pad)
    local frame = hovered
    ns.Log(("keys: %s %s over %s"):format(pad and "pad button" or "key", tostring(key),
        frame and tostring(frame:GetName()) or "nothing"))
    if not (frame and frame.flyout and K.On()) then return K.Leave() end
    if ALONE[key] or (IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key)) then return end
    local flyout, i = frame.flyout, frame.entryIndex
    if RESET[key] then
        F.SetKey(flyout, i, nil, false)
        F.SetKey(flyout, i, nil, true)
    elseif pad then
        F.SetKey(flyout, i, key, true)
    else
        F.SetKey(flyout, i, Chord(key), false)
    end
end

-- In the game's Quick Keybind Mode its own window takes every key, so the
-- key is read off that window; its own handling of the key runs first.
local function HookQuick()
    if hooked or not QuickKeybindFrame then return end
    hooked = true
    local function Seen(_, key)
        if hovered and Quick() then K.Pressed(key, type(key) == "string" and key:find("^PAD") ~= nil) end
    end
    QuickKeybindFrame:HookScript("OnKeyDown", Seen)
    QuickKeybindFrame:HookScript("OnGamePadButtonDown", Seen)
end

-- the mouse came onto a flyout icon; true when this mode took it
function K.Enter(frame)
    if not K.On() then return false end
    hovered = frame
    HookQuick()
    ns.Log(("keys: waiting over %s, the game's mode, its window hooked: %s"):format(tostring(frame:GetName()),
        tostring(hooked)))
    Tip(frame)
    return true
end
