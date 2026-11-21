local _, ns = ...
-- luacheck: read globals GamepadActionBarEditFrame hooksecurefunc InCombatLockdown GetCursorInfo ClearCursor
-- luacheck: read globals CreateFrame UIParent unpack geterrorhandler PlaceAction InputPromptLegends
-- luacheck: read globals C_Spell C_Item PickupMacro GetMacroInfo GAMEPAD_FACE_LEFT GAMEPAD_FACE_TOP GAMEPAD_FACE_RIGHT
-- luacheck: read globals GAMEPAD_PROMPT_DIVIDER_SLASH FRAME_ACTION_EDIT_ACTION_BAR

-- The game's gamepad mode, "Bind to Action Bar". Bound onto a button that
-- holds an ability, the new one takes its place, as ever. The hint bar under
-- the dialog then names both ways on: swap the old one out, or keep it there
-- and add the new one to its flyout.
--
-- The game's dialog is only watched. None of its fields is written and none
-- of its calls is made: its code never runs under ours. It takes every pad
-- button itself while it is up, so the press is read off its own handler.
local G = {}
ns.PadBind = G
local F, Bars = ns.Flyouts, ns.Bars

-- the face buttons, as the game names them
local KEY_ADD, KEY_EDIT = GAMEPAD_FACE_LEFT or "PAD3", GAMEPAD_FACE_TOP or "PAD4"
local KEY_BACK = GAMEPAD_FACE_RIGHT or "PAD2"
local EDIT_BARS = "^GamepadActionBarEditFrame"
local TEXT = {
    add = "Add to Flyout",
    swap = "Swap Out",
    close = "Done",
    edit = "Edit Action Bar",
    done = "%s is in the flyout of %s now.",
    refused = "The game kept the new ability on the button, so no flyout was made.",
}
G.TEXT, G.KEY = TEXT, KEY_ADD

local watched, offer
-- between the dialog's opening for a bind and its shutting
local binding = false
-- a press that placed an ability is not also a press on a hint
local placedNow = false
-- our hint bar, made by the game's own maker; false when that failed
local legend, holder
local prompts = {}

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

-- The game's own hint bar, from its own maker and its own prompt template,
-- so ours is drawn as the one it stands on. Its keys are the game's to take.
local function Legend()
    if legend ~= nil then return legend or nil end
    legend = false
    local maker = InputPromptLegends and InputPromptLegends.CreateInputLegend
    if not maker then return nil end
    holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()
    holder:SetFrameStrata("DIALOG")
    local ok, made = pcall(maker, holder, "legend")
    if not ok or type(made) ~= "table" then return nil end
    local function Prompt(key, text)
        local divider = GAMEPAD_PROMPT_DIVIDER_SLASH
        local frame = made:GetOrCreatePromptFrameUsingTemplateAndInputs("StandardOneIcon", { key }, divider)
        frame:SetPromptText(text)
        frame:EnablePrompt()
        return frame
    end
    -- in the order the game lists its buttons: left, top, right
    local built = pcall(function()
        prompts.add = Prompt(KEY_ADD, TEXT.add)
        prompts.edit = Prompt(KEY_EDIT, FRAME_ACTION_EDIT_ACTION_BAR or TEXT.edit)
        prompts.back = Prompt(KEY_BACK, TEXT.swap)
    end)
    if not built then return nil end
    legend = made
    return legend
end

-- our hint bar over the game's, saying what each button does now
local function Show(frame, done)
    local bar = Legend()
    if not bar then return end
    prompts.add:SetShown(not done)
    prompts.back:SetPromptText(done and TEXT.close or TEXT.swap)
    bar:ApplyDefaultPromptPositioning()
    local footer = frame.bindingModeFooter
    local theirs = footer and footer.inputLegend
    bar:ClearAllPoints()
    if theirs then
        bar:SetPoint("TOPLEFT", theirs, "TOPLEFT")
    else
        bar:SetPoint("TOPLEFT", frame.BindingInfoFrame or frame, "BOTTOMLEFT")
    end
    bar:Show()
    holder:Show()
end

local function Hide()
    if holder then holder:Hide() end
end

local function Clear()
    offer = nil
    Hide()
end

-- The old ability back on its button, the new one into its flyout.
function G.Stack()
    local o = offer
    if not o or InCombatLockdown() then return false end
    offer = nil
    -- placed over the new one, which comes off onto the cursor and is let go
    ClearCursor()
    o.oldFn(unpack(o.oldParams))
    if GetCursorInfo() then PlaceAction(o.slot) end
    ClearCursor()
    if not Bars.Holds(o.button, o.old) then
        ns.Log(("pad bind: slot %d did not take the old ability back"):format(o.slot))
        ns.Warn(TEXT.refused)
        Hide()
        return false
    end
    local flyout, why = F.Stack(o.button, o.new)
    if not flyout then
        ns.Log(("pad bind: not stacked on %s: %s"):format(o.button:GetName(), tostring(why)))
        if why then ns.Warn(why) end
        Hide()
        return false
    end
    ns.Log(("pad bind: %s:%s stacked on %s"):format(o.new.kind, tostring(o.new.id), o.button:GetName()))
    ns.Say(TEXT.done:format(F.Name(o.new), F.Name(o.old)))
    -- the dialog is still up: its right button shuts it
    if watched then Show(watched, true) end
    return true
end

-- The dialog just took a press; `slot` is the button's. Only in a plain
-- bind: while abilities are moved about, the game's own hints use this key.
local function Placed(frame, slot, possess)
    placedNow = true
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
    ns.Log(("pad bind: offer on %s (slot %d): keep %s:%s, add %s:%s; hint bar %s"):format(button:GetName(), slot,
        old.kind, tostring(old.id), new.kind, tostring(new.id), Legend() and "drawn" or "could not be made"))
    Show(frame, false)
end

-- a pad button the dialog was handed; one that placed an ability is not a hint's
local function Pressed(_, key)
    local placed = placedNow
    placedNow = false
    if not offer or placed then return end
    ns.Log(("pad bind: %s pressed while the offer is up"):format(tostring(key)))
    if key == KEY_ADD then G.Stack() end
end

-- watches one dialog; the game's is found at the start
function G.Install(frame)
    if watched or not (frame and hooksecurefunc) then return false end
    for _, name in ipairs({ "EnterBindingMode", "PlaceOrClearHeldActionCapturedInputHandler", "ExitBindingMode",
        "StartListeningForButtons" }) do
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
    -- the game sets its button handler afresh each time it listens: ours rides behind each one
    local pressed = Guard(Pressed)
    hooksecurefunc(frame, "StartListeningForButtons", Guard(function(self)
        self:HookScript("OnGamePadButtonDown", pressed)
    end))
    return true
end

function G.Offer() return offer end
function G.Bar() return legend or nil, prompts end

ns.OnStart(function() G.Install(GamepadActionBarEditFrame) end)

-- nothing on the bars changes in a fight
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", Clear)
