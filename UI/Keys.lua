local _, ns = ...
-- luacheck: read globals InCombatLockdown KeybindFrames_InQuickKeybindMode GameTooltip
-- luacheck: read globals CreateKeyChordStringUsingMetaKeyState IsKeyPressIgnoredForBinding QuickKeybindFrame
-- luacheck: read globals IsAltKeyDown IsControlKeyDown IsShiftKeyDown CreateFrame GetTime geterrorhandler

-- An icon's own key inside its flyout: on the addon's settings page, a click on the icon's key and then
-- the key (K.Listen); or in the game's Quick Keybind Mode, a hover over the icon and the key. Nothing
-- here touches the game's key bindings: a flyout's keys count only while it is open.
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

-- FROM THE SETTINGS PAGE. His words (2026-11-23): "we seem to have completely removed the ability for
-- people to rebind flyouts individually without using the quick keybind mode....???? why does our
-- settings menu not allow for this?" The page lists a flyout's icons, each with its key; a click on a
-- key waits here for the next key pressed, which becomes that icon's own. The key is read by a typing
-- box that holds the keyboard while it waits (no frame of the addon's takes the keyboard otherwise). It
-- lets go at the key, at Escape, at a mouse click anywhere but on the waiting key (a key pressed later,
-- to walk on, must not be taken for it), when the page is put away (it is a part of the page) and in a
-- fight.
local SPECK = 1
-- typed characters whose key has another name
local NAMED = { [" "] = "SPACE" }
local waiting, catcher
local keyAt = 0

-- what is being waited for: { flyout, i }, or nil
function K.Waiting() return waiting end
function K.Box() return catcher end

function K.Stop()
    local was = waiting
    waiting = nil
    if catcher then
        catcher:ClearFocus()
        catcher:Hide()
    end
    if was and was.done then was.done() end
end

local function Take(key, pad)
    local w = waiting
    if not w then return end
    if ALONE[key] or (IsKeyPressIgnoredForBinding and IsKeyPressIgnoredForBinding(key)) then return end
    local ok, why
    if RESET[key] then
        F.SetKey(w.flyout, w.i, nil, true)
        ok, why = F.SetKey(w.flyout, w.i, nil, false)
    elseif pad then
        ok, why = F.SetKey(w.flyout, w.i, key, true)
    else
        ok, why = F.SetKey(w.flyout, w.i, Chord(key), false)
    end
    ns.Log(("keys: %s %s for icon %d of the flyout on %s, from the settings: %s"):format(pad and "pad button" or "key",
        tostring(key), w.i, tostring(w.flyout.host), ok and "set" or tostring(why)))
    if not ok and why then ns.Warn(why) end
    K.Stop()
end

local function Catcher(owner)
    if catcher then return catcher end
    catcher = CreateFrame("EditBox", nil, owner)
    catcher:Hide()
    catcher:SetAutoFocus(false)
    catcher:SetFontObject("GameFontNormal")
    catcher:SetSize(SPECK, SPECK)
    catcher:SetAlpha(0)
    catcher:SetPoint("TOPLEFT", owner, "TOPLEFT")
    catcher:SetScript("OnKeyDown", function(self, key)
        keyAt = GetTime()
        self:SetText("")
        if key ~= "ESCAPE" then xpcall(Take, geterrorhandler(), key, false) end
    end)
    -- a client that gives the box only what was typed: the character names the key
    catcher:SetScript("OnChar", function(self, char)
        self:SetText("")
        if GetTime() ~= keyAt then xpcall(Take, geterrorhandler(), NAMED[char] or char:upper(), false) end
    end)
    catcher:SetScript("OnEscapePressed", function() K.Stop() end)
    catcher:SetScript("OnEditFocusLost", function() K.Stop() end)
    -- not every client has a pad
    if catcher.EnableGamePadButton then
        catcher:EnableGamePadButton(true)
        catcher:SetScript("OnGamePadButtonDown", function(_, button) xpcall(Take, geterrorhandler(), button, true) end)
    end
    return catcher
end

-- Waits for the key that icon i of a flyout is to be picked with. `owner`: the page; `done`: told when
-- the waiting is over, whichever way; `button`: the key clicked on, which a click does not end the wait by.
function K.Listen(flyout, i, owner, done, button)
    if InCombatLockdown() then return false, F.TEXT.fight end
    if waiting then K.Stop() end
    waiting = { flyout = flyout, i = i, done = done, button = button }
    local box = Catcher(owner)
    box:Show()
    box:SetFocus()
    return true
end

-- nothing in a flyout changes in a fight; and a click elsewhere ends a wait (not every client says so)
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
pcall(events.RegisterEvent, events, "GLOBAL_MOUSE_DOWN")
events:SetScript("OnEvent", function(_, event)
    if not waiting then return end
    if event == "GLOBAL_MOUSE_DOWN" and waiting.button and waiting.button:IsMouseOver() then return end
    K.Stop()
end)

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
