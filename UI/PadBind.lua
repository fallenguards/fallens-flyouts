local _, ns = ...
-- luacheck: read globals GamepadActionBarEditFrame hooksecurefunc InCombatLockdown GetCursorInfo ClearCursor
-- luacheck: read globals CreateFrame UIParent unpack geterrorhandler PlaceAction InputPromptLegends
-- luacheck: read globals C_Spell C_Item PickupMacro GetMacroInfo GAMEPAD_FACE_LEFT GAMEPAD_FACE_TOP GAMEPAD_FACE_RIGHT
-- luacheck: read globals GAMEPAD_PROMPT_DIVIDER_SLASH FRAME_ACTION_EDIT_ACTION_BAR FRAME_ACTION_CANCEL
-- luacheck: read globals GAMEPAD_FACE_BOTTOM GetTime C_Timer FRAME_ACTION_UNBIND

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
local F, Bars, Art = ns.Flyouts, ns.Bars, ns.Art

-- The face buttons, as the game names them. The bottom one is ours: the
-- game's dialog uses the other three, in a bind or while moving abilities.
local KEY_ADD, KEY_LEFT = GAMEPAD_FACE_BOTTOM or "PAD1", GAMEPAD_FACE_LEFT or "PAD3"
local KEY_EDIT, KEY_BACK = GAMEPAD_FACE_TOP or "PAD4", GAMEPAD_FACE_RIGHT or "PAD2"
local TEXT = {
    add = "Add to Flyout",
    swap = "Swap Out",
    close = "Done",
    edit = "Edit Action Bar",
    cancel = "Cancel",
    done = "%s is in the flyout of %s now.",
    -- the flyout just made: which of the pad's crosses picks from it
    faces = "Use Face Buttons",
    dpad = "Use D-Pad",
    -- the round plate behind a flyout that stands around its button
    plateOn = "Show Background",
    plateOff = "Hide Background",
    -- Edit Action Bar, on a button that has a flyout
    editFlyout = "Edit Flyout",
    nextTool = "Next Option",
    toolNext = "Select Next Icon",
    toolMove = "Move Icon On",
    toolOff = "Take Icon Off",
    unbind = "Unbind",
    refused = "The game kept the new ability on the button, so no flyout was made.",
}
G.TEXT, G.KEY = TEXT, KEY_ADD

local watched, offer
-- the flyout the last Add to Flyout made, while the dialog is still up: its picks can be swapped
local latest
-- Edit Action Bar: a flyout's button was picked up (its ability is held by the dialog); and the flyout
-- being edited, with the icon marked and the option the bottom button does
local picked, editing
-- how far under the dialog the picture of the flyout stands (the hint bar is between)
local VIEW_DOWN = 56
local view
local TOOLS = { "next", "move", "off", "faces", "plate" }
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
        local entry = ns.Macros.Entry(id)
        if entry then return entry end
        local name = GetMacroInfo(id)
        return name and { kind = "macro", id = name } or nil
    end
    return nil
end

-- The bar button that shows a slot: a shown one first. The game's console bar
-- is put away while its dialog is up, and may be on another page: none found
-- is no fault, the flyout finds its button later.
local function Live(slot)
    local hidden
    for _, button in ipairs(Bars.All(true)) do
        local its = Bars.Slot(button) == slot or (Bars.Pad(button) and button:GetID() == slot)
        if its then
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
    for _, entry in ipairs(F.Full(flyout)) do
        if Same(entry, new) then return true end
    end
    return #F.Full(flyout) < F.MAX
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

-- A picture of a flyout under the hint bar, as it stands around its button: its icons, the pad button
-- that picks each, the plate behind it where one is wanted, and a mark on the icon being edited. It is
-- drawn afresh whenever a choice on the bar changes.
local function View()
    if view then return view end
    view = CreateFrame("Frame", nil, holder)
    view.plate = Art.Disc(view)
    view.tokens = {}
    for i = 0, F.MAX do
        local token = Art.Token(view)
        token.key = token:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        token.key:SetPoint("TOPRIGHT", Art.KEY_X, Art.KEY_Y)
        token.ring = token:CreateTexture(nil, "OVERLAY", nil, 1)
        token.ring:SetAtlas(Art.NAMES.frameOver)
        token.ring:SetSize(Art.OVER_W, Art.OVER_H)
        token.ring:SetPoint("TOPLEFT")
        token.ring:Hide()
        view.tokens[i] = token
    end
    return view
end
local function NoPicture()
    if view then view:Hide() end
    return false
end
-- `flyout`: the one drawn, nil for one not made yet; `lead`: what its button holds; `marked`: an icon's place
local function Picture(frame, flyout, lead, entries, marked)
    -- only a flyout that will stand around its button is drawn so
    if not holder or not F.Around() or (flyout and flyout.side) then return NoPicture() end
    local v = View()
    local reach = Art.BUTTON / 2 + F.RING_GAP + Art.ICON / 2
    local radius = F.PlateReach(#entries, reach)
    v:SetSize(2 * radius, 2 * radius)
    v:ClearAllPoints()
    v:SetPoint("TOP", frame.BindingInfoFrame or frame, "BOTTOM", 0, -VIEW_DOWN)
    Art.LayDisc(v.plate, v, F.Plate() and radius or nil)
    local faces = F.Faces(flyout)
    local pads = F.RingPads(#entries, faces)
    local hub = v.tokens[0]
    hub:ClearAllPoints()
    hub:SetPoint("CENTER", v, "CENTER")
    hub:SetScale(Art.BUTTON / Art.ICON)
    hub.icon:SetTexture((flyout and flyout.icon) or (lead and F.Icon(lead)) or nil)
    hub.key:SetText("")
    hub:Show()
    for i = 1, F.MAX do
        local token, entry = v.tokens[i], entries[i]
        token:SetShown(entry ~= nil)
        if entry then
            token:ClearAllPoints()
            token:SetPoint("CENTER", v, "CENTER", F.RingSpot(i, reach))
            token.icon:SetTexture(F.Icon(entry))
            token.key:SetText(F.PadText(pads[i]))
            token.pad = pads[i]
            token.ring:SetShown(marked == i)
        end
    end
    v.count, v.faces, v.marked = #entries, faces, marked
    v:Show()
    return true
end

-- the flyout an offer would make or add to, and its icons as they would be
local function WouldBe(o)
    local flyout = Led(o.button, o.old)
    local entries, has = {}, false
    for _, entry in ipairs(flyout and F.Full(flyout) or { o.old }) do
        entries[#entries + 1] = entry
        has = has or Same(entry, o.new)
    end
    if not has then entries[#entries + 1] = o.new end
    return flyout, entries
end

-- the hint bar set where the game's own is, and shown
local function Up(frame, bar)
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

-- Our hint bar over the game's, saying what each of its buttons does now.
-- In a bind the right button backs out, leaving the swap; while abilities
-- are moved the left one lets the old one go and the right one undoes.
local function Show(frame, moving, done)
    local bar = Legend()
    if not bar then return end
    -- once the flyout is made, the same button swaps what picks from it: the other cross of the pad
    prompts.add:SetShown(not done or latest ~= nil)
    if done and latest then
        prompts.add:SetPromptText(F.Faces(latest) and TEXT.dpad or TEXT.faces)
    else
        prompts.add:SetPromptText(TEXT.add)
    end
    -- the flyout as it will be, or as it is now
    local drawn = false
    if latest then
        drawn = Picture(frame, latest, latest.main, latest.entries)
    elseif offer then
        local flyout, entries = WouldBe(offer)
        drawn = Picture(frame, flyout, offer.old, entries)
    else
        NoPicture()
    end
    -- The left button is the game's while abilities are moved about. In a bind it is free: there it
    -- shows or hides the plate behind the flyout, when a flyout is pictured.
    if moving then
        prompts.left:Show()
        prompts.left:SetPromptText(done and TEXT.close or TEXT.swap)
    else
        prompts.left:SetShown(drawn)
        prompts.left:SetPromptText(F.Plate() and TEXT.plateOff or TEXT.plateOn)
    end
    prompts.edit:SetShown(not moving)
    prompts.edit:SetPromptText(FRAME_ACTION_EDIT_ACTION_BAR or TEXT.edit)
    prompts.back:SetShown(not (moving and done))
    if moving then
        prompts.back:SetPromptText(FRAME_ACTION_CANCEL or TEXT.cancel)
    else
        prompts.back:SetPromptText(done and TEXT.close or TEXT.swap)
    end
    Up(frame, bar)
end

-- what the bottom button does to the flyout being edited, in the bar's words
local function ToolText(e)
    local tool = TOOLS[e.tool]
    if tool == "next" then return TEXT.toolNext end
    if tool == "move" then return TEXT.toolMove end
    if tool == "off" then return TEXT.toolOff end
    if tool == "faces" then return F.Faces(e.flyout) and TEXT.dpad or TEXT.faces end
    return F.Plate() and TEXT.plateOff or TEXT.plateOn
end

-- The bar in Edit Action Bar, on a button that has a flyout. Picked up: the bottom button offers to
-- edit the flyout, the others are the game's, named as it names them. Editing: the bottom button does
-- the option shown, the top one goes to the next option, and the right one ends it.
local function ShowEdit(frame)
    local bar = Legend()
    if not bar then return end
    local e = editing
    local flyout = e and e.flyout or (picked and picked.flyout)
    if not flyout then return end
    Picture(frame, flyout, flyout.main, flyout.entries, e and e.mark or nil)
    prompts.add:Show()
    prompts.add:SetPromptText(e and ToolText(e) or TEXT.editFlyout)
    prompts.edit:SetShown(e ~= nil)
    prompts.edit:SetPromptText(TEXT.nextTool)
    prompts.left:SetShown(e == nil)
    prompts.left:SetPromptText(FRAME_ACTION_UNBIND or TEXT.unbind)
    prompts.back:Show()
    prompts.back:SetPromptText(e and TEXT.close or (FRAME_ACTION_CANCEL or TEXT.cancel))
    Up(frame, bar)
end

local function Hide()
    if holder then holder:Hide() end
end

local function Clear()
    offer, latest, picked, editing = nil, nil, nil, nil
    Hide()
end

-- the plate behind flyouts that stand around their button, shown or hidden: for every such flyout
function G.Plate()
    if InCombatLockdown() or not (offer or latest) then return false end
    if not F.SetPlate(not F.Plate()) then return false end
    ns.Log(("pad bind: the plate behind such flyouts is now %s"):format(F.Plate() and "shown" or "hidden"))
    if watched then Show(watched, false, latest ~= nil) end
    return true
end

-- Edit Action Bar took a flyout's ability off its button. It goes back, and the flyout is edited in
-- place: the dialog still thinks it holds the ability, and its own Cancel or Unbind ends that.
function G.Edit()
    local p = picked
    if not p or InCombatLockdown() then return false end
    ClearCursor()
    p.fn(unpack(p.params))
    if GetCursorInfo() then PlaceAction(p.slot) end
    ClearCursor()
    if not Same(Bars.ActionAt(p.slot), p.lead) then
        ns.Log(("pad bind: slot %d did not take the flyout's ability back"):format(p.slot))
        ns.Warn(TEXT.refused)
        Clear()
        return false
    end
    picked, editing = nil, { flyout = p.flyout, mark = 1, tool = 1 }
    F.Apply()
    ns.Log(("pad bind: editing the flyout on %s"):format(tostring(p.flyout.host)))
    if watched then ShowEdit(watched) end
    return true
end

-- the option shown on the bar, done to the flyout being edited
function G.Do()
    local e = editing
    if not e or InCombatLockdown() then return false end
    local flyout, tool = e.flyout, TOOLS[e.tool]
    local count = #flyout.entries
    if tool == "next" then
        e.mark = e.mark % count + 1
    elseif tool == "move" then
        local to = e.mark % count + 1
        if F.Move(flyout, e.mark, to) then e.mark = to end
    elseif tool == "off" then
        local ok, gone = F.Remove(flyout, e.mark)
        if ok and (gone or #flyout.entries == 0) then
            -- its last went: there is no flyout left to edit
            editing = nil
            Hide()
            return true
        end
        e.mark = math.max(1, math.min(e.mark, #flyout.entries))
    elseif tool == "faces" then
        F.SetFace(flyout, not F.Faces(flyout))
    else
        F.SetPlate(not F.Plate())
    end
    ns.Log(("pad bind: edit, %s; icon %d marked"):format(tool, e.mark))
    if watched then ShowEdit(watched) end
    return true
end

function G.NextTool()
    local e = editing
    if not e then return false end
    e.tool = e.tool % #TOOLS + 1
    if watched then ShowEdit(watched) end
    return true
end
function G.Editing() return editing end
function G.Picked() return picked end
function G.View() return view end

-- The flyout just made picks with the pad's other cross: the face buttons for the D-pad, or back.
function G.Swap()
    local flyout = latest
    if not flyout or InCombatLockdown() then return false end
    local ok = F.SetFace(flyout, not F.Faces(flyout))
    if not ok then return false end
    ns.Log(("pad bind: the flyout on %s now picks with the %s first"):format(tostring(flyout.host),
        F.Faces(flyout) and "face buttons" or "D-pad"))
    if watched then Show(watched, G.moving == true, true) end
    return true
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
    -- the dialog is still up: the bar now names the button that ends it, and the one that swaps the picks
    latest, G.moving = flyout, o.moving
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
    if placedAt == GetTime() then return end
    if editing then
        if key == KEY_ADD then G.Do() elseif key == KEY_EDIT then G.NextTool() end
        return
    end
    if picked then
        if key == KEY_ADD then G.Edit() end
        return
    end
    if not (offer or latest) then return end
    ns.Log(("pad bind: %s pressed while %s"):format(tostring(key),
        offer and "the offer is up" or "a flyout was just made"))
    if key == KEY_ADD then
        if offer then G.Stack() else G.Swap() end
    elseif key == KEY_LEFT and not (offer and offer.moving) and not (latest and G.moving) then
        G.Plate()
    end
end

-- Edit Action Bar picked an ability up off a button. Where that button has a flyout, the bar offers
-- to edit the flyout.
local function Picked(frame, slot, possess)
    if possess or InCombatLockdown() or type(slot) ~= "number" then return end
    local fn, params = frame.pickupFunc, frame.pickupParams
    local lead = Entry(fn, params)
    local flyout = lead and F.Of(lead)
    if not flyout or flyout.auto then return end
    local host = Bars.Named(flyout.host)
    if not host or not (Bars.Slot(host) == slot or (Bars.Pad(host) and host:GetID() == slot)) then return end
    Clear()
    picked = { slot = slot, flyout = flyout, lead = lead, fn = fn, params = { unpack(params) } }
    ns.Log(("pad bind: the button of a flyout was picked up (slot %d, %s): Edit Flyout is offered"):format(slot,
        tostring(flyout.host)))
    ShowEdit(frame)
end

-- watches one dialog; the game's is found at the start
function G.Install(frame)
    if watched or not (frame and hooksecurefunc) then return false end
    for _, name in ipairs({ "EnterBindingMode", "PlaceOrClearHeldActionCapturedInputHandler", "ExitBindingMode",
        "StartListeningForButtons", "TransitionToSelectActionToPickup", "ExitEditMode" }) do
        if type(frame[name]) ~= "function" then return false end
    end
    watched = frame
    -- while the dialog is up the console bar is put away: a flyout stays on its button
    F.StillWhile(function() return frame:IsShown() end)
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
    -- an ability picked up off a button, where this client's dialog has that step
    if type(frame.SelectActionToPickupCapturedInputHandler) == "function" then
        hooksecurefunc(frame, "SelectActionToPickupCapturedInputHandler", Guard(Picked))
    end
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
