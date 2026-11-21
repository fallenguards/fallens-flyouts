local _, ns = ...
-- luacheck: read globals GamepadActionBarEditFrame hooksecurefunc InCombatLockdown GetCursorInfo ClearCursor
-- luacheck: read globals CreateFrame UIParent unpack geterrorhandler PlaceAction InputPromptLegends
-- luacheck: read globals C_Spell C_Item PickupMacro GetMacroInfo GAMEPAD_FACE_LEFT GAMEPAD_FACE_TOP GAMEPAD_FACE_RIGHT
-- luacheck: read globals GAMEPAD_PROMPT_DIVIDER_SLASH FRAME_ACTION_EDIT_ACTION_BAR FRAME_ACTION_CANCEL
-- luacheck: read globals GAMEPAD_FACE_BOTTOM GetTime C_Timer

-- The game's gamepad mode, binding an ability or moving one about (Edit
-- Action Bar). Put onto a button that holds an ability, the new one takes its
-- place, as ever. The hint bar under the dialog then names both ways on: swap
-- the old one out, or keep it there and add the new one to its flyout.
--
-- The game's dialog is only watched. None of its fields is written and none
-- of its calls is made: its code never runs under ours. It takes every pad
-- button itself while it is up, so the press is read off its own handler.
local G = {}
ns.PadBind = G
local F, Bars = ns.Flyouts, ns.Bars

-- The face buttons, as the game names them. The bottom one is ours: the
-- game's dialog uses the other three, in a bind or while moving abilities.
local KEY_ADD, KEY_LEFT = GAMEPAD_FACE_BOTTOM or "PAD1", GAMEPAD_FACE_LEFT or "PAD3"
local KEY_EDIT, KEY_BACK = GAMEPAD_FACE_TOP or "PAD4", GAMEPAD_FACE_RIGHT or "PAD2"
local EDIT_BARS, MAIN_BARS = "^GamepadActionBarEditFrame", "^GamepadMainActionBarFrame"
local TEXT = {
    add = "Add to Flyout",
    swap = "Swap Out",
    close = "Done",
    edit = "Edit Action Bar",
    cancel = "Cancel",
    done = "%s is in the flyout of %s now.",
    refused = "The game kept the new ability on the button, so no flyout was made.",
}
G.TEXT, G.KEY = TEXT, KEY_ADD

local watched, offer
-- between the dialog's opening for a bind and its shutting; else abilities are being moved
local binding = false
-- when the dialog last placed an ability: that press is not also a press on a hint
local placedAt
-- how long after the dialog shuts a flyout looks for its button
local FIND_AFTER = 0.3
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

-- The bar button that shows a slot: a shown one first, never the dialog's own
-- copies. The game's console bar is hidden while its dialog is up, and may be
-- on another page: none found is no fault, the flyout finds its button later.
local function Live(slot)
    local hidden
    for _, button in ipairs(Bars.All(true)) do
        local name = button:GetName()
        local its = Bars.Slot(button) == slot or (name:find(MAIN_BARS) ~= nil and button:GetID() == slot)
        if its and not name:find(EDIT_BARS) then
            if button:IsVisible() then return button end
            hidden = hidden or button
        end
    end
    return hidden
end

-- the flyout the old one leads, on that button or wherever it is
local function Led(button, old)
    local flyout = button and F.At(button:GetName())
    if flyout and Same(flyout.main, old) then return flyout end
    return F.Of(old)
end

-- Whether the new one can be with the old one: it is in its flyout already
-- (then the old one only goes back on its button), or there is room for it.
local function Fits(button, old, new)
    local flyout = Led(button, old)
    if not flyout then return true end
    for _, entry in ipairs(flyout.entries) do
        if Same(entry, new) then return true end
    end
    return #flyout.entries < F.MAX
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
    -- in the order the game lists its buttons: bottom, left, top, right
    local built = pcall(function()
        prompts.add = Prompt(KEY_ADD, TEXT.add)
        prompts.left = Prompt(KEY_LEFT, TEXT.swap)
        prompts.edit = Prompt(KEY_EDIT, FRAME_ACTION_EDIT_ACTION_BAR or TEXT.edit)
        prompts.back = Prompt(KEY_BACK, TEXT.swap)
    end)
    if not built then return nil end
    legend = made
    return legend
end

-- Our hint bar over the game's, saying what each of its buttons does now.
-- In a bind the right button backs out, leaving the swap; while abilities
-- are moved the left one lets the old one go and the right one undoes.
local function Show(frame, moving, done)
    local bar = Legend()
    if not bar then return end
    prompts.add:SetShown(not done)
    prompts.left:SetShown(moving)
    prompts.left:SetPromptText(done and TEXT.close or TEXT.swap)
    prompts.edit:SetShown(not moving)
    prompts.back:SetShown(not (moving and done))
    if moving then
        prompts.back:SetPromptText(FRAME_ACTION_CANCEL or TEXT.cancel)
    else
        prompts.back:SetPromptText(done and TEXT.close or TEXT.swap)
    end
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
    if not Same(Bars.ActionAt(o.slot), o.old) then
        ns.Log(("pad bind: slot %d did not take the old ability back"):format(o.slot))
        ns.Warn(TEXT.refused)
        Hide()
        return false
    end
    local flyout, why = F.StackLed(o.old, o.new, o.button)
    if not flyout then
        ns.Log(("pad bind: not stacked on slot %d: %s"):format(o.slot, tostring(why)))
        if why then ns.Warn(why) end
        Hide()
        return false
    end
    ns.Log(("pad bind: %s:%s stacked with %s:%s on %s"):format(o.new.kind, tostring(o.new.id), o.old.kind,
        tostring(o.old.id), o.button and o.button:GetName() or "a button to be found"))
    ns.Say(TEXT.done:format(F.Name(o.new), F.Name(o.old)))
    -- the dialog is still up: the bar now names the button that ends it
    if watched then Show(watched, o.moving, true) end
    return true
end

-- no offer this time, and why: read back when it is said not to have shown
local function Skip(why)
    ns.Log("pad bind: no offer: " .. why)
    return Clear()
end

-- The dialog just took a press and placed what it held; `slot` is the button's.
local function Placed(frame, slot, possess)
    placedAt = GetTime()
    if possess then return Skip("a pet bar button") end
    if InCombatLockdown() then return Skip("in a fight") end
    if type(slot) ~= "number" then return Skip("no slot given") end
    local box = frame.BindingInfoFrame
    if not frame:IsShown() or (box and not box:IsShown()) then return Skip("the button was empty: placed") end
    -- on a taken button the dialog now holds what it took off it, and the slot the new one
    local fn, params = frame.pickupFunc, frame.pickupParams
    local old, new = Entry(fn, params), Bars.ActionAt(slot)
    if not old then return Skip("what the button held is no spell, item or macro") end
    if not new then return Skip("what was placed is no spell, item or macro") end
    if Same(old, new) then return Skip("the same ability") end
    local button = Live(slot)
    if not Fits(button, old, new) then return Skip("the flyout is full") end
    offer = { slot = slot, button = button, old = old, new = new, oldFn = fn, oldParams = { unpack(params) },
        moving = not binding }
    ns.Log(("pad bind: offer on slot %d (%s, %s): keep %s:%s, add %s:%s; hint bar %s"):format(slot,
        button and button:GetName() or "no button of it up", binding and "a bind" or "moving", old.kind,
        tostring(old.id), new.kind, tostring(new.id), Legend() and "drawn" or "could not be made"))
    Show(frame, offer.moving, false)
end

-- a pad button the dialog was handed; one that placed an ability is not a hint's
local function Pressed(_, key)
    if not offer or placedAt == GetTime() then return end
    ns.Log(("pad bind: %s pressed while the offer is up"):format(tostring(key)))
    if key == KEY_ADD then G.Stack() end
end

-- watches one dialog; the game's is found at the start
function G.Install(frame)
    if watched or not (frame and hooksecurefunc) then return false end
    for _, name in ipairs({ "EnterBindingMode", "PlaceOrClearHeldActionCapturedInputHandler", "ExitBindingMode",
        "StartListeningForButtons", "TransitionToSelectActionToPickup", "ExitEditMode" }) do
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
    -- the dialog gone, the console bar is back: a flyout looks for its button again
    local function Gone()
        Clear()
        F.Moved()
        C_Timer.After(FIND_AFTER, F.Follow)
    end
    hooksecurefunc(frame, "ExitBindingMode", Guard(function()
        binding = false
        Gone()
    end))
    -- moving abilities: the held one was set down, let go or put back, or the mode left
    hooksecurefunc(frame, "TransitionToSelectActionToPickup", Guard(Clear))
    hooksecurefunc(frame, "ExitEditMode", Guard(Gone))
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
