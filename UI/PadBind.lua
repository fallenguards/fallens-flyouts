local _, ns = ...
-- luacheck: read globals GamepadActionBarEditFrame hooksecurefunc InCombatLockdown GetCursorInfo ClearCursor
-- luacheck: read globals CreateFrame UIParent SetOverrideBindingClick ClearOverrideBindings unpack geterrorhandler
-- luacheck: read globals C_Spell C_Item PickupMacro GetMacroInfo GameTooltip PlaceAction

-- The game's gamepad mode, "Bind to Action Bar". Bound onto a button that
-- holds an ability, the new one replaces it, as ever. A hint by the game's
-- own then offers the other way: the old one stays, the new one is stacked.
-- The game's dialog is only watched: none of its fields or calls is touched.
local G = {}
ns.PadBind = G
local F, Bars = ns.Flyouts, ns.Bars

-- the face button the game leaves free while it asks for a combination
local KEY = "PAD3"
local GAP, PAD, LINE, GLYPH = 8, 28, 26, 18
local HINT = "FallensFlyoutsPadBindHint"
local EDIT_BARS = "^GamepadActionBarEditFrame"
local TEXT = {
    add = "Add to Flyout",
    tip = "Puts %s back on the button and adds %s to its flyout.",
    done = "%s is in the flyout of %s now.",
    refused = "The game kept the new ability on the button, so no flyout was made.",
}
G.TEXT, G.KEY = TEXT, KEY

local watched, hint, offer
-- between the dialog's opening for a bind and its shutting
local binding = false

local function Same(a, b) return a ~= nil and b ~= nil and a.kind == b.kind and a.id == b.id end

-- what one of the game's pick up calls would put on the cursor, as an entry
local function Entry(fn, params)
    local id = type(params) == "table" and params[1]
    if not id then return nil end
    if C_Spell and fn == C_Spell.PickupSpell then return { kind = "spell", id = id } end
    if C_Item and fn == C_Item.PickupItem then return { kind = "item", id = id } end
    if fn == PickupMacro then
        local name = GetMacroInfo(id)
        return name and { kind = "macro", id = name } or nil
    end
    return nil
end

-- the bar button that shows a slot: a shown one first, never the dialog's own copies
local function Live(slot)
    local hidden
    for _, button in ipairs(Bars.All(true)) do
        if Bars.Slot(button) == slot and not button:GetName():find(EDIT_BARS) then
            if button:IsVisible() then return button end
            hidden = hidden or button
        end
    end
    return hidden
end

-- whether the new one could join the old one's flyout
local function Fits(button, old, new)
    if Same(old, new) then return false end
    local flyout = F.At(button:GetName()) or F.Of(old)
    if not flyout then return true end
    if #flyout.entries >= F.MAX then return false end
    for _, entry in ipairs(flyout.entries) do
        if Same(entry, new) then return false end
    end
    return true
end

local function Clear()
    offer = nil
    if hint then
        hint:Hide()
        if not InCombatLockdown() then ClearOverrideBindings(hint) end
    end
end

-- The old ability back on its button, the new one into its flyout.
function G.Stack()
    local o = offer
    if not o or InCombatLockdown() then return false end
    Clear()
    -- placed over the new one, which comes off onto the cursor and is let go
    ClearCursor()
    o.oldFn(unpack(o.oldParams))
    if GetCursorInfo() then PlaceAction(o.slot) end
    ClearCursor()
    if not Bars.Holds(o.button, o.old) then
        ns.Log(("pad bind: slot %d did not take the old ability back"):format(o.slot))
        ns.Warn(TEXT.refused)
        return false
    end
    local flyout, why = F.Stack(o.button, o.new)
    if not flyout then
        ns.Log(("pad bind: not stacked on %s: %s"):format(o.button:GetName(), tostring(why)))
        if why then ns.Warn(why) end
        return false
    end
    ns.Log(("pad bind: %s:%s stacked on %s"):format(o.new.kind, tostring(o.new.id), o.button:GetName()))
    ns.Say(TEXT.done:format(F.Name(o.new), F.Name(o.old)))
    return true
end

local function Hint(frame)
    if not hint then
        hint = CreateFrame("Button", HINT, UIParent, "UIPanelButtonTemplate")
        hint:Hide()
        hint:SetFrameStrata("DIALOG")
        hint:SetScript("OnClick", G.Stack)
        hint:SetScript("OnEnter", function(self)
            if not offer then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(TEXT.tip:format(F.Name(offer.old), F.Name(offer.new)), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        hint:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    -- on the row of the game's own hints, under its dialog, at the other end
    local box = frame.BindingInfoFrame or frame
    hint:ClearAllPoints()
    hint:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -GAP)
    local glyph = F.PadGlyph(KEY, GLYPH)
    hint:SetText(glyph ~= "" and (glyph .. " " .. TEXT.add) or TEXT.add)
    hint:SetSize((hint:GetTextWidth() or 0) + PAD, LINE)
    return hint
end

-- The dialog just took a press; `slot` is the button's. Only in a plain
-- bind: while abilities are moved about, the game's own hints use this key.
local function Placed(frame, slot, possess)
    if not binding or possess or InCombatLockdown() then return Clear() end
    local box = frame.BindingInfoFrame
    if not frame:IsShown() or (box and not box:IsShown()) then return Clear() end
    -- on a taken button the dialog now holds what it took off it, and the button the new one
    local fn, params = frame.pickupFunc, frame.pickupParams
    local old = Entry(fn, params)
    local button = type(slot) == "number" and Live(slot)
    local new = button and Bars.Action(button)
    if not (old and new) or Same(old, new) then return Clear() end
    if not Fits(button, old, new) then
        ns.Log(("pad bind: the flyout of %s cannot take %s:%s"):format(button:GetName(), new.kind, tostring(new.id)))
        return Clear()
    end
    offer = { slot = slot, button = button, old = old, new = new, oldFn = fn, oldParams = { unpack(params) } }
    ns.Log(("pad bind: offer on %s (slot %d): keep %s:%s, stack %s:%s"):format(button:GetName(), slot, old.kind,
        tostring(old.id), new.kind, tostring(new.id)))
    Hint(frame):Show()
    SetOverrideBindingClick(hint, true, KEY, HINT, "LeftButton")
end

-- watches one dialog; the game's is found at the start
function G.Install(frame)
    if watched or not (frame and hooksecurefunc) then return false end
    for _, name in ipairs({ "EnterBindingMode", "PlaceOrClearHeldActionCapturedInputHandler", "ExitBindingMode" }) do
        if type(frame[name]) ~= "function" then return false end
    end
    watched = frame
    local function Guard(fn)
        return function(...) xpcall(fn, geterrorhandler(), ...) end
    end
    hooksecurefunc(frame, "EnterBindingMode", Guard(function()
        Clear()
        binding = true
    end))
    hooksecurefunc(frame, "PlaceOrClearHeldActionCapturedInputHandler", Guard(Placed))
    hooksecurefunc(frame, "ExitBindingMode", Guard(function()
        binding = false
        Clear()
    end))
    return true
end

function G.Offer() return offer end

ns.OnStart(function() G.Install(GamepadActionBarEditFrame) end)

-- nothing on the bars changes in a fight
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", Clear)
