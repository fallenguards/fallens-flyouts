local _, ns = ...
-- luacheck: globals StaticPopupDialogs
-- luacheck: read globals UIParent CreateFrame InCombatLockdown KeybindFrames_InQuickKeybindMode GameTooltip
-- luacheck: read globals CreateKeyChordStringUsingMetaKeyState IsAltKeyDown IsControlKeyDown IsShiftKeyDown
-- luacheck: read globals StaticPopup_Show StaticPopup_Hide DONE

-- An icon's own key inside its flyout: hover the icon and press the key.
-- On in the game's Quick Keybind Mode and from the settings. Nothing here
-- touches the game's key bindings: a flyout's keys count only while it is open.
local K = {}
ns.Keys = K
local F = ns.Flyouts

local POPUP = "FALLENSFLYOUTS_KEYS"
local TEXT = {
    popup = "Open a flyout, hover an icon and press the key to pick it with. "
        .. "Escape over an icon gives it its own key back.",
    press = "Press a key to pick this with.",
    reset = "Escape gives it its own key back.",
}
-- keys that only go with another key
local ALONE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true,
    RMETA = true, UNKNOWN = true }

local own = false
local catcher, hovered

-- whether a hover and a press set a key right now
function K.On()
    if InCombatLockdown() then return false end
    return own or (KeybindFrames_InQuickKeybindMode ~= nil and KeybindFrames_InQuickKeybindMode() == true)
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

function K.Leave()
    hovered = nil
    if catcher then
        catcher:ClearFocus()
        catcher:Hide()
    end
end

-- a key or pad button pressed over the hovered icon
function K.Pressed(key, pad)
    local frame = hovered
    if not (frame and frame.flyout and K.On()) then return K.Leave() end
    if ALONE[key] then return end
    local flyout, i = frame.flyout, frame.entryIndex
    if key == "ESCAPE" then
        F.SetKey(flyout, i, nil, false)
        F.SetKey(flyout, i, nil, true)
    elseif pad then
        F.SetKey(flyout, i, key, true)
    else
        F.SetKey(flyout, i, Chord(key), false)
    end
end

-- Keys are read from a typing box that holds the focus while an icon is
-- hovered in this mode: focus drops by itself when the box hides.
local function Catcher()
    if catcher then return catcher end
    catcher = CreateFrame("EditBox", nil, UIParent)
    catcher:Hide()
    catcher:SetAutoFocus(false)
    catcher:SetFontObject("GameFontNormal")
    catcher:SetSize(1, 1)
    catcher:SetAlpha(0)
    catcher:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    catcher:SetScript("OnKeyDown", function(self, key)
        self:SetText("")
        if key ~= "ESCAPE" then K.Pressed(key, false) end
    end)
    catcher:SetScript("OnEscapePressed", function() K.Pressed("ESCAPE", false) end)
    catcher:SetScript("OnTextChanged", function(self, typed)
        if typed then self:SetText("") end
    end)
    catcher:SetScript("OnEditFocusLost", function(self) self:Hide() end)
    -- not every client has a pad
    if catcher.EnableGamePadButton then
        catcher:EnableGamePadButton(true)
        catcher:SetScript("OnGamePadButtonDown", function(_, button) K.Pressed(button, true) end)
    end
    return catcher
end

-- the mouse came onto a flyout icon; true when this mode took it
function K.Enter(frame)
    if not K.On() then return false end
    hovered = frame
    local box = Catcher()
    box:Show()
    box:SetFocus()
    Tip(frame)
    return true
end

function K.Start()
    if InCombatLockdown() then return ns.Warn(F.TEXT.fight) end
    StaticPopup_Show(POPUP)
end

StaticPopupDialogs[POPUP] = {
    text = TEXT.popup,
    button1 = DONE,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnShow = function() own = true end,
    OnHide = function()
        own = false
        K.Leave()
    end,
}

-- a fight ends the mode: nothing in a flyout changes in one
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    K.Leave()
    if own then StaticPopup_Hide(POPUP) end
end)
