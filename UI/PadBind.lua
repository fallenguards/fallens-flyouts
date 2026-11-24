local _, ns = ...
-- luacheck: read globals GamepadActionBarEditFrame hooksecurefunc InCombatLockdown GetCursorInfo ClearCursor
-- luacheck: read globals CreateFrame UIParent unpack geterrorhandler PlaceAction InputPromptLegends
-- luacheck: read globals C_Spell C_Item PickupMacro GetMacroInfo GAMEPAD_FACE_LEFT GAMEPAD_FACE_TOP GAMEPAD_FACE_RIGHT
-- luacheck: read globals GAMEPAD_PROMPT_DIVIDER_SLASH FRAME_ACTION_EDIT_ACTION_BAR FRAME_ACTION_CANCEL
-- luacheck: read globals GAMEPAD_FACE_BOTTOM GetTime C_Timer FRAME_ACTION_UNBIND
-- luacheck: read globals SetOverrideBindingClick ClearOverrideBindings HasAction PickupAction

-- The game's gamepad mode, binding an ability or moving one about (Edit
-- Action Bar). Put onto a button that holds an ability, the new one takes its
-- place, as ever. The hint bar under the dialog then names both ways on: swap
-- the old one out, or keep it there and add the new one to its flyout.
--
-- The game's dialog is only watched. None of its fields is written and none
-- of its calls is made: its code never runs under ours. It takes every pad
-- button itself while it is up, so the press is read off its own handler.
local G, E = {}, {}
ns.PadBind, ns.PadEdit = G, E
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
    icon = "Icon and Name",
    iconNote = "The icon and name window opens then.",
    -- Edit Flyout: asked for in the game's dialog, done in an editor of ours once the dialog is left
    editTitle = "Edit Flyout",
    openEditor = "Open Flyout Editor",
    note1 = "Press %s to leave Edit Action Bar.",
    note2 = "The flyout editor opens then.",
    note3 = "The D-pad moves the icons there. Pressed here it changes nothing.",
    editHint = "Editing: %s is selected. The D-pad moves it to that side of the button.",
    editRing = "Press the same side again for the next ring out.",
    -- the editor inside the game's dialog: the box's words
    inSelected = "%s is selected.",
    inMove = "The D-pad moves it to that side of the button.",
    -- the game's Unbind on a flyout's button does away with the button, and its flyout with it
    unbindFlyout = "Unbind and Remove Flyout",
}
G.TEXT, G.KEY = TEXT, KEY_ADD

local watched, offer
-- the flyout the last Add to Flyout made, while the dialog is still up: its picks can be swapped
local latest
-- Edit Action Bar: a flyout's button was picked up (its ability is held by the dialog); and the flyout
-- being edited, with the icon marked and the option the bottom button does
local picked, armed
-- the flyout editor's state while it is up: inside the game's dialog (`inside`) or after it
local editing
-- learned in play: a frame of ours is given no pad press ahead of the game's dialog on this client
local cannotCatch
-- the flyouts' marks on the dialog's copies of the bar's buttons, and how often they are looked at
local Marks
local MARK_LOOK = 0.25
-- the slot of the flyout last made, for its picture
local latestSlot
-- how far under the dialog the picture of the flyout stands (the hint bar is between)
local VIEW_DOWN = 56
local view
-- Our notice in the game's box, and the pieces of the box put out of sight for it: how far down its
-- first line stands, the room a line takes, the size of a button symbol in it, and how wide it may run.
local panel, covered
local PANEL_LEVEL = 100
local NOTE_Y, NOTE_STEP, NOTE_GLYPH, NOTE_WIDTH = 56, 28, 18, 430
-- The editor: the pad button that shows or hides the plate, what the names of its bound buttons begin
-- with, the room between its picture, its bar and its hint, and the sides a ring has.
-- In Edit Flyout LB shows or hides the background and RB opens the icon and name window, RB as the
-- right-click a mouse gives a flyout's bar button for it.
local KEY_PLATE, KEY_ICON, EDIT_BUTTON, EDIT_GAP, RING_SIDES = "PADLSHOULDER", "PADRSHOULDER", "FallensFlyoutsPadEdit",
    8, 4
-- how often the open editor looks at its button, and how long the button may be out of view
local EDIT_LOOK, EDIT_UNSEEN = 0.2, 1
-- a prompt for the hint bar, made by the game's own maker once the bar is
local MakePrompt
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
    MakePrompt = function(key, text)
        local good, frame = pcall(Prompt, key, text)
        return good and frame or nil
    end
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
-- `where`: a button to stand around (in place), or a box to stand under. `flyout`: the one drawn, nil
-- for one not made yet; `lead`: what its button holds; `marked`: an icon's place.
local function Picture(where, flyout, lead, entries, marked)
    -- only a flyout that will stand around its button is drawn so
    if not holder or not F.Around() or (flyout and flyout.side) then return NoPicture() end
    local v = View()
    -- over the game's dialog and its copies of the bar's buttons
    v:SetFrameStrata("TOOLTIP")
    v:SetFrameLevel(PANEL_LEVEL)
    local reach = Art.BUTTON / 2 + F.RING_GAP + Art.ICON / 2
    local spots = F.Spots(entries)
    local radius = F.PlateReach(F.TopSpot(entries), reach)
    v:SetSize(2 * radius, 2 * radius)
    v:ClearAllPoints()
    if where.button then
        -- at the button's own size, its middle on the button's
        v:SetScale(Bars.Scale(where.button))
        v:SetPoint("CENTER", where.button, "CENTER")
    else
        v:SetScale(1)
        v:SetPoint("TOP", where.box, "BOTTOM", 0, -VIEW_DOWN)
    end
    v.around = where.button
    Art.LayDisc(v.plate, v, F.Plate() and radius or nil)
    local faces = F.Faces(flyout)
    local pads = F.RingPads(entries, faces)
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
            token:SetPoint("CENTER", v, "CENTER", F.RingSpot(spots[i], reach))
            token.spot = spots[i]
            token.icon:SetTexture(F.Icon(entry))
            -- an icon of the third ring has no pad button
            token.key:SetText(pads[i] and F.PadText(pads[i]) or "")
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
-- The game's own hint bar, under ours. While ours is up the game's is put out of sight: ours names
-- every button that matters then, and where it was the shorter of the two the game's end showed
-- beside it ("stacked hint bars", his snip of 2026-11-21). Only its alpha is set, and set back after.
local FrameAlpha = UIParent.SetAlpha
local veiled
local function Veil(theirs)
    if veiled and veiled ~= theirs then FrameAlpha(veiled, 1) end
    veiled = theirs or nil
    if veiled then FrameAlpha(veiled, 0) end
end

-- `selecting`: the dialog is at Edit Action Bar's first step, whose box has a hint bar of its own;
-- otherwise the game's bar is the one under its box of the held ability.
local function Up(frame, bar, selecting)
    bar:ApplyDefaultPromptPositioning()
    local footer = frame[selecting and "editModeFooter" or "bindingModeFooter"]
    local theirs = type(footer) == "table" and footer.inputLegend or nil
    if type(theirs) ~= "table" then theirs = nil end
    bar:ClearAllPoints()
    if theirs then
        bar:SetPoint("TOPLEFT", theirs, "TOPLEFT")
    else
        bar:SetPoint("TOPLEFT", frame.BindingInfoFrame or frame, "BOTTOMLEFT")
    end
    Veil(theirs)
    bar:Show()
    holder:Show()
end

-- where a flyout's picture stands: around the dialog's own copy of the slot's button (in place, where
-- the eyes are), or under the box when no such button is in view
local function Where(frame, slot)
    local copy = slot and Bars.Copy(slot)
    if copy then return { button = copy } end
    return { box = frame.BindingInfoFrame or frame }
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
        drawn = Picture(Where(frame, latestSlot), latest, latest.main, latest.entries)
    elseif offer then
        local flyout, entries = WouldBe(offer)
        drawn = Picture(Where(frame, offer.slot), flyout, offer.old, entries)
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
    if prompts.plate then prompts.plate:Hide() end
    prompts.back:SetShown(not (moving and done))
    if moving then
        prompts.back:SetPromptText(FRAME_ACTION_CANCEL or TEXT.cancel)
    else
        prompts.back:SetPromptText(done and TEXT.close or TEXT.swap)
    end
    Up(frame, bar)
end

-- The pieces of the game's box that speak of binding an ability: its title, its instruction, and the
-- ability's name and icon. Only looked up; none of the box's fields is written.
local function Theirs(frame)
    local box = type(frame) == "table" and frame.BindingInfoFrame
    local out = {}
    if type(box) ~= "table" then return out, nil end
    local title = type(box.TitleBox) == "table" and box.TitleBox.TitleText or nil
    for _, region in ipairs({ box.BindInstructionText, box.ActionName, box.ActionIcon, title }) do
        if type(region) == "table" and region.SetAlpha then out[#out + 1] = region end
    end
    return out, title
end

-- While our notice stands in the box, the game's words there (about binding the ability it holds) are
-- made unseen, not changed, and seen again after.
local function Cover(frame, on)
    -- the dialog puts its tooltip up afresh at every ability it takes hold of
    local tip = on and frame.ActionTooltip
    if type(tip) == "table" and tip.Hide then tip:Hide() end
    if on == (covered ~= nil) then return end
    if on then
        covered = Theirs(frame)
        for _, region in ipairs(covered) do region:SetAlpha(0) end
    else
        for _, region in ipairs(covered) do region:SetAlpha(1) end
        covered = nil
        if panel then panel:Hide() end
    end
end

-- Our notice in the game's box, in the top layer: the box's own border and title box are frames of
-- their own, and words a few levels over the box stood behind their dark fill.
local function Notice(frame, words)
    local box = frame.BindingInfoFrame or frame
    if not panel then
        panel = CreateFrame("Frame", nil, holder)
        panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge2")
        panel.lines = {}
        for i, font in ipairs({ "GameFontHighlightLarge", "GameFontHighlight", "GameFontNormal" }) do
            panel.lines[i] = panel:CreateFontString(nil, "OVERLAY", font)
        end
    end
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(PANEL_LEVEL)
    panel:ClearAllPoints()
    panel:SetAllPoints(box)
    local _, title = Theirs(frame)
    panel.title:ClearAllPoints()
    if title then
        panel.title:SetPoint("CENTER", title, "CENTER")
    else
        panel.title:SetPoint("TOP", panel, "TOP", 0, -NOTE_STEP)
    end
    panel.title:SetText(TEXT.editTitle)
    for i, line in ipairs(panel.lines) do
        line:ClearAllPoints()
        line:SetPoint("TOP", panel, "TOP", 0, -(NOTE_Y + (i - 1) * NOTE_STEP))
        line:SetWidth(NOTE_WIDTH)
        line:SetText(words[i])
    end
    panel:Show()
end

-- The bar in Edit Action Bar, on a button that has a flyout. Picked up: the bottom button offers to
-- edit the flyout, the others are the game's, named as it names them. Once that is asked for, the
-- ability is back on its button and the editor opens when the dialog is left: the box says so, and
-- the bar names the one button to press.
local function ShowPicked(frame)
    local bar = Legend()
    if not bar then return end
    local on = armed or picked
    -- edited and done with: the game's own dialog has the screen again
    if not on or on.done then return end
    local flyout = on.flyout
    Picture(Where(frame, on.slot), flyout, flyout.main, flyout.entries)
    prompts.add:SetShown(armed == nil)
    prompts.add:SetPromptText(TEXT.editFlyout)
    prompts.edit:Hide()
    prompts.left:SetShown(armed == nil)
    prompts.left:SetPromptText(TEXT.unbindFlyout)
    prompts.back:Show()
    prompts.back:SetPromptText(armed and (armed.icon and TEXT.icon or TEXT.openEditor)
        or (FRAME_ACTION_CANCEL or TEXT.cancel))
    if prompts.plate then prompts.plate:Hide() end
    if prompts.icon then prompts.icon:Hide() end
    -- Waiting to be left, the dialog is either still holding (its box of the held ability is up, and the
    -- notice stands in it) or back at its first step, where the bar alone says it. Just picked up, the
    -- box of the held ability is the one the game is about to put up.
    local box = frame.BindingInfoFrame
    local holding = armed ~= nil and type(box) == "table" and box:IsShown()
    Up(frame, bar, armed ~= nil and not holding)
    Cover(frame, holding)
    if holding and armed.icon then
        Notice(frame, { TEXT.note1:format(F.PadText(KEY_BACK, NOTE_GLYPH)), TEXT.iconNote })
    elseif holding then
        Notice(frame, { TEXT.note1:format(F.PadText(KEY_BACK, NOTE_GLYPH)), TEXT.note2, TEXT.note3 })
    end
end

local function Hide()
    if watched then Cover(watched, false) end
    Veil(nil)
    if holder then holder:Hide() end
end

local function Clear()
    offer, latest, picked, latestSlot = nil, nil, nil, nil
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

-- Armed, the dialog still believes it holds an ability, and sets it down at whichever bar button is
-- pressed (his D-pad up, 2026-11-21). Each such press is undone at once: the slot gets back what it
-- held when the edit was asked for, or is emptied when it was empty. What the dialog took off a slot
-- it then holds, and its own record of that says how to put back what we know no way to pick up.
local OTHER = "other"
local function Heal(frame, slot, possess)
    local was = armed.bars[slot]
    if possess or InCombatLockdown() or type(slot) ~= "number" or was == nil then
        return ns.Log(("pad bind: a press for slot %s while waiting to edit; no slot this can undo"):format(
            tostring(slot)))
    end
    ClearCursor()
    if was == false then
        if HasAction(slot) then PickupAction(slot) end
    elseif was == OTHER then
        local fn, params = frame.pickupFunc, frame.pickupParams
        if type(fn) == "function" and type(params) == "table" and not Entry(fn, params) then
            fn(unpack(params))
            if GetCursorInfo() then PlaceAction(slot) end
        end
    elseif not F.Same(Bars.ActionAt(slot), was) then
        F.Pickup(was)
        if GetCursorInfo() then PlaceAction(slot) end
    end
    ClearCursor()
    local now = Bars.ActionAt(slot)
    local back
    if was == false then
        back = not HasAction(slot)
    elseif was == OTHER then
        back = HasAction(slot) and now == nil
    else
        back = F.Same(now, was)
    end
    ns.Log(("pad bind: a press for slot %d while waiting to edit was undone: %s"):format(slot,
        back and "the slot is as it was" or "THE SLOT IS NOT AS IT WAS"))
    if not back then ns.Warn(TEXT.refused) end
    if not editing then ShowPicked(frame) end
end

-- Edit Action Bar took a flyout's ability off its button and the bottom button was pressed. The
-- ability goes back on its button at once. Nothing is edited in the game's dialog: while it is up it
-- sets down the ability it thinks it holds at every D-pad press (his D-pad up, 2026-11-21, put the
-- ability on his D-pad up spot). The editor opens when the dialog is left; until then Heal undoes
-- whatever the dialog sets down.
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
    -- every slot the dialog can set an ability down on, as it stands now
    local bars = {}
    for slot in pairs(Bars.Copies()) do bars[slot] = Bars.ActionAt(slot) or (HasAction(slot) and OTHER) or false end
    picked, armed = nil, { flyout = p.flyout, slot = p.slot, bars = bars }
    F.Apply()
    if not watched then return true end
    -- The editor, here and now, the pad's presses kept from the dialog. Where that cannot be (learned
    -- the first time it fails), the box says to leave the dialog and the editor opens after it.
    if not cannotCatch and E.Open(p.flyout, watched) then return true end
    ns.Log(("pad bind: the flyout on %s is to be edited once the dialog is left"):format(tostring(p.flyout.host)))
    ShowPicked(watched)
    return true
end
function G.Armed() return armed end
function G.Picked() return picked end
function G.View() return view end
function G.Panel() return panel end
function G.Veiled() return veiled end

-- The flyout editor of gamepad mode. It is up only outside the game's dialog, where the pad's buttons
-- can be bound to buttons of ours: the D-pad puts the selected icon on that side of the button, taken
-- or empty (an icon there changes places with it), and the face buttons select, take off, swap the
-- pad's crosses and end it. The flyout is pictured in place, around its own button.
local EDIT_KEYS = {
    { key = "PADDUP", act = "side", side = 1 }, { key = "PADDRIGHT", act = "side", side = 2 },
    { key = "PADDDOWN", act = "side", side = 3 }, { key = "PADDLEFT", act = "side", side = 4 },
    { key = KEY_ADD, act = "next" }, { key = KEY_LEFT, act = "off" }, { key = KEY_EDIT, act = "pads" },
    { key = KEY_PLATE, act = "plate" }, { key = KEY_ICON, act = "icon" }, { key = KEY_BACK, act = "done" },
    { key = "ESCAPE", act = "done" },
}
local editor
E.KEYS = EDIT_KEYS

function E.Editing() return editing end
function E.Hint() return editor and editor.hint:IsShown() and editor.hint:GetText() or "" end

-- Inside the game's dialog the pad's presses are the dialog's unless a frame of ours, over it, is given
-- them first and keeps them. That frame: up only while the editor is up in the dialog, it keeps every
-- pad button but the one that ends the editing, which goes on to the dialog as its own Cancel.
local catcher, caughtAt
local BY_KEY = {}
for _, bind in ipairs(EDIT_KEYS) do BY_KEY[bind.key] = bind end
local function Caught(self, button)
    local e = editing
    local pass = not (e and e.inside)
    if not pass then
        caughtAt = GetTime()
        local bind = BY_KEY[button]
        -- the press that opened the editor is not one in it
        if bind and e.openedAt ~= caughtAt then
            pass = bind.act == "done"
            ns.Log(("pad edit: %s kept from the game's dialog%s"):format(tostring(button),
                pass and ", then passed on to it" or ""))
            xpcall(E.Do, geterrorhandler(), bind)
        end
    end
    if self.SetPropagateKeyboardInput and not InCombatLockdown() then self:SetPropagateKeyboardInput(pass) end
    return pass
end
local function Catch(on)
    if not on then
        if catcher then catcher:Hide() end
        return
    end
    if not catcher then
        catcher = CreateFrame("Frame", "FallensFlyoutsPadCatcher", UIParent)
        catcher:Hide()
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetAllPoints(UIParent)
        if catcher.EnableGamePadButton then catcher:EnableGamePadButton(true) end
        catcher:SetScript("OnGamePadButtonDown", Caught)
        -- never up without the editor under it: a frame that keeps the pad must not outlive its use
        catcher:SetScript("OnUpdate", function(self)
            if not (editing and editing.inside and watched and watched:IsShown()) then self:Hide() end
        end)
    end
    catcher:Show()
end
function E.Catcher() return catcher end
function G.CannotCatch() return cannotCatch == true end
-- what was learned of this client is forgotten: the next edit tries inside the dialog again
function G.Relearn() cannotCatch = nil end

-- The pad's buttons go back to the game before anything else. (A fight's beginning is still time
-- enough; should one ever be on already, it is done when the fight ends.) `waiting`: closed inside
-- the dialog only to open after it; otherwise an edit inside the dialog is over and done with.
function E.Close(waiting)
    if editor and not InCombatLockdown() then ClearOverrideBindings(editor) end
    Catch(false)
    if not editing then return true end
    ns.Log("pad edit: closed")
    local inside = editing.inside
    editing = nil
    if editor then
        editor.hint:Hide()
        editor:Hide()
    end
    if inside and armed and waiting ~= true then armed.done = true end
    Hide()
    return true
end

-- While it is up: it ends when its button is gone from view for a while (the pad put down, another
-- bar page), when the game's dialog comes up, or in a fight; and it is drawn anew when the button is
-- resized (a group of the pad's bar zoomed).
local function Watch(self, elapsed)
    self.since = (self.since or 0) + elapsed
    if self.since < EDIT_LOOK then return end
    local e, waited = editing, self.since
    self.since = 0
    local unit = e and F.UnitOf(e.flyout)
    if not unit or InCombatLockdown() or (watched and watched:IsShown()) then return E.Close() end
    e.unseen = unit.host:IsVisible() and 0 or (e.unseen or 0) + waited
    if e.unseen > EDIT_UNSEEN then return E.Close() end
    local width = unit.host:GetWidth()
    if width ~= e.width then
        e.width = width
        E.Draw()
    end
end

-- the picture around the flyout's own button, the selected icon marked, and the bar saying what each
-- button does now
function E.Draw()
    local e = editing
    local bar = e and Legend()
    local unit = e and F.UnitOf(e.flyout)
    if not (bar and unit) then return E.Close() end
    local flyout = e.flyout
    -- in the dialog the flyout's button is the dialog's copy of it; after it, the button itself
    local where = { button = unit.host }
    if e.inside then where = Where(e.inside, armed and armed.slot) end
    if not Picture(where, flyout, flyout.main, flyout.entries, e.mark) then return E.Close() end
    prompts.add:Show()
    prompts.add:SetPromptText(TEXT.toolNext)
    prompts.left:Show()
    prompts.left:SetPromptText(TEXT.toolOff)
    prompts.edit:Show()
    prompts.edit:SetPromptText(F.Faces(flyout) and TEXT.dpad or TEXT.faces)
    prompts.back:Show()
    prompts.back:SetPromptText(TEXT.close)
    if not prompts.plate then prompts.plate = MakePrompt(KEY_PLATE, TEXT.plateOff) end
    if prompts.plate then
        prompts.plate:Show()
        prompts.plate:SetPromptText(F.Plate() and TEXT.plateOff or TEXT.plateOn)
    end
    if not prompts.icon then prompts.icon = MakePrompt(KEY_ICON, TEXT.icon) end
    if prompts.icon then
        prompts.icon:Show()
        prompts.icon:SetPromptText(TEXT.icon)
    end
    local entry = flyout.entries[e.mark]
    if e.inside then
        -- the game's box holds the words, and our bar stands where the game's does
        Up(e.inside, bar)
        Cover(e.inside, true)
        Notice(e.inside, { TEXT.inSelected:format(entry and F.Name(entry) or ""), TEXT.inMove, TEXT.editRing })
        return true
    end
    bar:ApplyDefaultPromptPositioning()
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", view, "TOP", 0, EDIT_GAP)
    bar:Show()
    editor.hint:ClearAllPoints()
    editor.hint:SetPoint("BOTTOM", bar, "TOP", 0, EDIT_GAP)
    editor.hint:SetText(TEXT.editHint:format(entry and F.Name(entry) or "") .. "\n" .. TEXT.editRing)
    editor.hint:Show()
    holder:Show()
    return true
end

-- RB in the editor: the icon and name window for the flyout being edited, as a right-click on its bar
-- button opens it. The editor closes, so that the window has the pad. Inside the game's dialog, which keeps
-- the pad while it is up, the window opens once the dialog is left.
function E.Icon()
    local e = editing
    if not (e and ns.Icon) then return false end
    local flyout = e.flyout
    if e.inside then
        if armed then armed.icon = true end
        E.Close(true)
        ShowPicked(watched)
        ns.Log("pad edit: the icon and name window opens once the dialog is left")
        return true
    end
    E.Close()
    ns.Icon.Open(flyout)
    ns.Log(("pad edit: the icon and name window for the flyout on %s"):format(tostring(flyout.host)))
    return true
end

-- one press in the editor
function E.Do(bind)
    local e = editing
    if not e then return false end
    if InCombatLockdown() or bind.act == "done" then return E.Close() end
    if bind.act == "icon" then return E.Icon() end
    local flyout = e.flyout
    local spots = F.Spots(flyout.entries)
    if bind.act == "side" then
        -- To that side of the button, taken or empty: anywhere on the dial ("why would they HAVE to swap
        -- with an existing one?", 2026-11-21). Pressed for the side it stands on: a ring further out
        -- there, and from the outermost back to the first.
        local to, at = bind.side, spots[e.mark]
        if (at - 1) % RING_SIDES + 1 == to then
            to = at + RING_SIDES
            if to > F.SPOTS then to = bind.side end
        end
        F.Place(flyout, e.mark, to)
    elseif bind.act == "next" then
        -- round the dial as it lies: the icon on the next spot on, the first after the last
        local at, best, first = spots[e.mark], nil, nil
        for i, spot in ipairs(spots) do
            if spot > at and (not best or spot < spots[best]) then best = i end
            if not first or spot < spots[first] then first = i end
        end
        e.mark = best or first or e.mark
    elseif bind.act == "off" then
        local ok, gone = F.Remove(flyout, e.mark)
        if ok and (gone or #flyout.entries == 0) then return E.Close() end
        e.mark = math.max(1, math.min(e.mark, #flyout.entries))
    elseif bind.act == "pads" then
        F.SetFace(flyout, not F.Faces(flyout))
    elseif bind.act == "plate" then
        F.SetPlate(not F.Plate())
    end
    ns.Log(("pad edit: %s; icon %d selected"):format(bind.act == "side" and ("side " .. bind.side) or bind.act, e.mark))
    -- the flyout itself stays shut: open, its own picks would be on these buttons
    F.Shut()
    return E.Draw()
end

-- `dialog`: the game's dialog, to edit inside it; none, to edit after it with the pad's buttons bound
function E.Open(flyout, dialog)
    if InCombatLockdown() or not flyout or flyout.auto or not Legend() then return false end
    if not F.UnitOf(flyout) then return false end
    F.Shut()
    -- the first icon round the dial is the one selected
    local mark, low = 1, nil
    for i, spot in ipairs(F.Spots(flyout.entries)) do
        if not low or spot < low then mark, low = i, spot end
    end
    if dialog then
        editing = { flyout = flyout, mark = mark, inside = dialog, openedAt = GetTime() }
        Catch(true)
        ns.Log(("pad edit: open inside the game's dialog for the flyout on %s"):format(tostring(flyout.host)))
        return E.Draw()
    end
    if not editor then
        editor = CreateFrame("Frame", "FallensFlyoutsPadEditor", UIParent)
        editor:Hide()
        editor:SetScript("OnUpdate", Watch)
        for _, bind in ipairs(EDIT_KEYS) do
            local button = CreateFrame("Button", EDIT_BUTTON .. bind.key, editor)
            button:RegisterForClicks("AnyDown")
            -- on the press only
            button:SetScript("OnClick", function(_, _, down)
                if down == false then return end
                xpcall(E.Do, geterrorhandler(), bind)
            end)
        end
        editor.hint = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    end
    editing = { flyout = flyout, mark = mark, width = F.UnitOf(flyout).host:GetWidth() }
    editor.since = 0
    editor:Show()
    for _, bind in ipairs(EDIT_KEYS) do SetOverrideBindingClick(editor, true, bind.key, EDIT_BUTTON .. bind.key) end
    ns.Log(("pad edit: open for the flyout on %s"):format(tostring(flyout.host)))
    return E.Draw()
end

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
    -- the dialog is still up: the bar now names the button that ends it, and the one that swaps the picks
    latest, latestSlot, G.moving = flyout, o.slot, o.moving
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
    if armed then return Heal(frame, slot, possess) end
    -- set down, the picked up ability is the game's to move: Edit Flyout is no longer offered for it
    picked = nil
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
local function Pressed(frame, key)
    -- The editor is up in the dialog and the dialog was still given a press that is the editor's: on this
    -- client a frame of ours cannot keep the pad from it. Said once in the log, and from then on the
    -- editor opens after the dialog instead (whatever the press set down has been undone already).
    if editing and editing.inside and key ~= KEY_BACK and editing.openedAt ~= GetTime() then
        cannotCatch = true
        ns.Log(("pad edit: the game's dialog was given %s while the editor was up in it (our frame %s it first): "
            .. "the editor will open after the dialog"):format(tostring(key),
            caughtAt == GetTime() and "saw" or "never saw"))
        E.Close(true)
        ShowPicked(frame)
        return
    end
    if placedAt == GetTime() then return end
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
    -- another ability picked up: an edit asked for before is off
    if armed then
        armed = nil
        Clear()
    end
    if possess or InCombatLockdown() or type(slot) ~= "number" then return end
    local fn, params = frame.pickupFunc, frame.pickupParams
    local lead = Entry(fn, params)
    local flyout = lead and F.Of(lead)
    if not flyout or flyout.auto then return end
    -- the editor moves icons around the button: only a flyout that stands around its button has one
    if flyout.side or not F.Around() then return end
    local host = Bars.Named(flyout.host)
    if not host or not (Bars.Slot(host) == slot or (Bars.Pad(host) and host:GetID() == slot)) then return end
    Clear()
    picked = { slot = slot, flyout = flyout, lead = lead, fn = fn, params = { unpack(params) } }
    ns.Log(("pad bind: the button of a flyout was picked up (slot %d, %s): Edit Flyout is offered"):format(slot,
        tostring(flyout.host)))
    ShowPicked(frame)
end

-- watches one dialog; the game's is found at the start
-- The dialog shows copies of the bar's buttons, and a copy has none of the bar's marks: there was no
-- telling which buttons have flyouts ("we just force user to memorize which is the flyouts?",
-- 2026-11-21). While the dialog is up, a copy whose ability leads a flyout wears the flyout's dots.
local marks
local function LayMarks()
    local seen, n = Bars.Copies(true), 0
    for slot, copy in pairs(seen) do
        local lead = Bars.ActionAt(slot)
        local flyout = lead and F.Of(lead)
        -- the same ability on two buttons: the flyout is on the one it was last on, where that still holds it
        local home = flyout and Bars.Named(flyout.host)
        local homeSlot = home and Bars.Pad(home) and home:GetID() or nil
        if homeSlot and homeSlot ~= slot and seen[homeSlot] and F.Same(Bars.ActionAt(homeSlot), lead) then
            flyout = nil
        end
        if flyout then
            n = n + 1
            local mark = marks.pool[n]
            if not mark then
                mark = CreateFrame("Frame", nil, marks)
                mark.dots = Art.Dots(mark)
                marks.pool[n] = mark
            end
            mark:SetScale(Bars.Scale(copy))
            mark:ClearAllPoints()
            mark:SetAllPoints(copy)
            Art.LayDots(mark.dots, copy, true)
            mark.on = copy
            mark:Show()
        end
    end
    for i = n + 1, #marks.pool do
        marks.pool[i]:Hide()
        marks.pool[i].on = nil
    end
    marks.count = n
end
function Marks(on)
    if not on then
        if marks then marks:Hide() end
        return
    end
    if not marks then
        marks = CreateFrame("Frame", nil, UIParent)
        marks:Hide()
        -- over the dialog and its copies, under the picture of a flyout
        marks:SetFrameStrata("FULLSCREEN_DIALOG")
        marks.pool, marks.count, marks.since = {}, 0, 0
        marks:SetScript("OnUpdate", function(self, elapsed)
            self.since = self.since + elapsed
            if self.since < MARK_LOOK then return end
            self.since = 0
            if not (watched and watched:IsShown()) then return self:Hide() end
            xpcall(LayMarks, geterrorhandler())
        end)
    end
    marks:Show()
    LayMarks()
end
function G.Marks() return marks end

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
        -- an edit asked for in the dialog begins now that the dialog is gone
        if editing and editing.inside then E.Close() end
        local next = armed
        armed = nil
        if next and next.done then next = nil end
        Marks(false)
        Clear()
        F.Moved()
        C_Timer.After(FIND_AFTER, function()
            F.Follow()
            if next and next.icon and ns.Icon then
                ns.Icon.Open(next.flyout)
            elseif next then
                E.Open(next.flyout)
            end
        end)
    end
    hooksecurefunc(frame, "ExitBindingMode", Guard(function()
        binding = false
        Gone()
    end))
    -- moving abilities: the held one was set down, let go or put back, or the mode left
    hooksecurefunc(frame, "TransitionToSelectActionToPickup", Guard(function(self)
        -- Picked up and neither set down nor put back: the game's Unbind. With its ability on no button
        -- the flyout is removed (set down elsewhere or put back, it is on one and stays).
        if picked and not armed then F.Discard(picked.flyout) end
        -- Back at the dialog's first step with the editor still up in it: the dialog acted on a press
        -- that was the editor's (ended by its own button, the editor is closed before the dialog hears of
        -- it). A frame of ours cannot keep the pad from it here: the editor will open after the dialog.
        if editing and editing.inside then
            cannotCatch = true
            ns.Log("pad edit: the game's dialog stepped back while the editor was up in it: "
                .. "the editor will open after it")
            E.Close(true)
        end
        if armed and armed.done then armed = nil end
        Clear()
        -- still waiting to be left for the editor: the bar goes on saying which button does it
        if armed then ShowPicked(self) end
    end))
    -- an ability picked up off a button, where this client's dialog has that step
    if type(frame.SelectActionToPickupCapturedInputHandler) == "function" then
        hooksecurefunc(frame, "SelectActionToPickupCapturedInputHandler", Guard(Picked))
    end
    hooksecurefunc(frame, "ExitEditMode", Guard(Gone))
    -- the game sets its button handler afresh each time it listens: ours rides behind each one
    local pressed = Guard(Pressed)
    hooksecurefunc(frame, "StartListeningForButtons", Guard(function(self)
        self:HookScript("OnGamePadButtonDown", pressed)
        -- the dialog is up: its copies of the bar's buttons are found afresh and wear the flyouts' marks
        Bars.ForgetCopies()
        Marks(true)
    end))
    return true
end

function G.Offer() return offer end
function G.Bar() return legend or nil, prompts end

ns.OnStart(function() G.Install(GamepadActionBarEditFrame) end)

-- nothing on the bars changes in a fight
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    -- first of all the pad's buttons go back to the game: in a fight they could not
    E.Close()
    if event == "PLAYER_REGEN_ENABLED" then return end
    armed = nil
    Clear()
end)
