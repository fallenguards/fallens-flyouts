local _, ns = ...
-- luacheck: read globals CreateFrame GameTooltip GetBindingText

-- The settings page's way to arrange a flyout without a drag: pick an icon,
-- then pick the place it goes. For a controller's cursor as much as a mouse.
local A = {}
ns.Arrange = A
local F, Art = ns.Flyouts, ns.Art

local EDGE, GAP, LINE, BUTTON_FLOOR, CHROME = 16, 8, 22, 70, 20
-- a row of the keys list: the room for an icon's name, how wide its key is, and the room between rows
local NAME_W, KEY_W, ROW_GAP, FOOT = 200, 150, 4, 1
-- how much the picked icon grows, as a held one does
local GROW = 1.25
local TEXT = {
    keysHead = "Keys of one flyout",
    keysNote = "The game's Keybindings options set a key for each spot of every flyout. Here an icon of one flyout "
        .. "gets a key of its own: click its key, then press the key. Right-click gives it its spot's key back.",
    keysWait = "Press a key for %s. Escape leaves it as it is.",
    keyPress = "Press a key",
    keyTip = "Click, then press the key that picks this icon while its flyout is open. Right-click gives it "
        .. "its spot's key back.",
    head = "Arrange a flyout",
    -- for those with a mouse: nobody is to take this section for the way a flyout is made
    live = "With a mouse none of this is needed: drag a spell, item or macro onto a bar button, where the + "
        .. "appears, and it becomes a flyout. This section is for a controller.",
    note = "Pick an icon, then pick the place it goes. No drag needed.",
    none = "No flyout is on the bars.",
    which = "%d of %d: %s",
    held = "Now pick the place for %s.",
    prev = "Previous",
    next = "Next",
    off = "Take Off",
    prevTip = "The flyout before this one.",
    nextTip = "The next flyout.",
    offTip = "Takes the picked icon off the flyout.",
    turn = "Turn",
    turnTip = "Turns the flyout to open another way: to each side of its button, straight out or lying along it.",
    ranks = "Keep a spell's ranks in order",
    ranksTip = "Ranks of one spell in a flyout stay in rank order, Rank 1 first.",
    hide = "Hide items I have none of",
    hideTip = "Flyouts leave out items you have none of, and take them back when you have some again. "
        .. "Off, they stay, grayed.",
    around = "Open around the button in gamepad mode",
    aroundTip = "On the bars of gamepad mode a flyout opens around its button, each icon on the side its pad "
        .. "button is: up, right, down, left. Off, it opens as a strip.",
    plate = "Round background behind it",
    plateTip = "A flyout that opens around its button has a round plate behind it, so an open flyout is "
        .. "seen at a glance.",
    faces = "Pick with the face buttons",
    facesTip = "On a controller the first four icons take the face buttons, and the D-pad takes any past "
        .. "them. Off, the D-pad comes first. Each flyout can be swapped as it is made in gamepad mode.",
}
A.TEXT = TEXT

-- the page, and the part of it that scrolls: what is built here hangs on that
local panel, holder
local at, held = 1, nil

-- the flyouts on the bars, in the order they are laid
local function Flyouts()
    local out = {}
    local units, used = F.Units()
    for f = 1, used do out[#out + 1] = units[f].flyout end
    return out
end

local function Current()
    local list = Flyouts()
    at = math.max(1, math.min(#list, at))
    return list[at], #list
end

-- a key as the game writes it, or the pad's symbol while the pad is the input in use
local function KeyName(key, pad)
    local text = F.PadInUse() and pad and F.PadText(pad) or ""
    if text == "" and key then text = GetBindingText and GetBindingText(key) or key end
    return text or ""
end

function A.Refresh()
    if not (panel and panel.arrange) then return end
    local w = panel.arrange
    local flyout, count = Current()
    if flyout and held and not flyout.entries[held] then held = nil end
    if not flyout then held = nil end
    w.which:SetText(flyout and TEXT.which:format(at, count, F.Name(flyout.main)) or TEXT.none)
    -- the keys list: the same flyout, a row for each of its icons
    local waiting = ns.Keys and ns.Keys.Waiting()
    if waiting and waiting.flyout ~= flyout then waiting = nil end
    w.keyWhich:SetText(w.which:GetText())
    w.keyPrev:SetEnabled(count > 1)
    w.keyNext:SetEnabled(count > 1)
    local last = w.keyPrev
    for i, row in ipairs(w.rows) do
        local entry = flyout and flyout.entries[i]
        row:SetShown(entry ~= nil)
        if entry then
            last = row
            row.icon:SetTexture(F.Icon(entry))
            row.name:SetText(F.Name(entry))
            local key, pad, own = F.Picked(flyout, i)
            local listening = waiting ~= nil and waiting.i == i
            row.key:SetText(listening and TEXT.keyPress or KeyName(key, pad))
            -- a key of the icon's own in the game's gold, its spot's key in white
            row.key:SetNormalFontObject(own and "GameFontNormal" or "GameFontHighlight")
            if listening then row.key:LockHighlight() else row.key:UnlockHighlight() end
        end
    end
    local name = waiting and flyout.entries[waiting.i] and F.Name(flyout.entries[waiting.i])
    w.keysNote:SetText(name and TEXT.keysWait:format(name) or TEXT.keysNote)
    -- what stands under the list hangs on its last row
    w.foot:ClearAllPoints()
    w.foot:SetPoint("TOPLEFT", last, "BOTTOMLEFT")
    w.prev:SetEnabled(count > 1)
    w.next:SetEnabled(count > 1)
    w.turn:SetEnabled(flyout ~= nil and F.UnitOf(flyout) ~= nil)
    w.off:SetEnabled(held ~= nil)
    w.ranks:SetChecked(F.Ranked())
    w.hide:SetChecked(F.Hiding())
    w.around:SetChecked(F.Around())
    w.faces:SetChecked(F.Faces())
    w.plate:SetChecked(F.Plate())
    for i, button in ipairs(w.icons) do
        local entry = flyout and flyout.entries[i]
        button:SetShown(entry ~= nil)
        if entry then button.icon:SetTexture(F.Icon(entry)) end
        -- the picked one grows and keeps its ring
        button:SetScale(held == i and GROW or 1)
        button.ring:SetShown(held == i)
    end
    local picked = held and flyout and F.Name(flyout.entries[held])
    w.status:SetText(picked and TEXT.held:format(picked) or TEXT.note)
    if ns.ProfileUI and ns.ProfileUI.Fit then ns.ProfileUI.Fit() end
end

-- A click on the key of icon i: the left button waits for the key it is to have, or stops waiting; the
-- right button gives the icon its spot's key back.
function A.Key(i, button)
    local flyout = Current()
    local K = ns.Keys
    if not (flyout and flyout.entries[i] and K) then return end
    local was = K.Waiting()
    K.Stop()
    if button == "RightButton" then
        F.SetKey(flyout, i, nil, true)
        local ok, why = F.SetKey(flyout, i, nil, false)
        if not ok and why then ns.Warn(why) end
    elseif not (was and was.flyout == flyout and was.i == i) then
        local ok, why = K.Listen(flyout, i, holder, A.Refresh, panel.arrange.rows[i].key)
        if not ok and why then ns.Warn(why) end
    end
    A.Refresh()
end

-- a press on icon i: picks it up, puts it down, or moves the picked one there
function A.Pick(i)
    local flyout = Current()
    if not (flyout and flyout.entries[i]) then return end
    if not held then
        held = i
    elseif held == i then
        held = nil
    else
        local ok, why = F.Move(flyout, held, i)
        if not ok and why then ns.Warn(why) end
        held = nil
    end
    A.Refresh()
end

-- the picked icon off its flyout
function A.TakeOff()
    local flyout = Current()
    local unit, i = flyout and held and F.UnitOf(flyout), held
    held = nil
    if unit then F.TakeOff(unit, i) end
    A.Refresh()
end

function A.Step(by)
    if ns.Keys then ns.Keys.Stop() end
    local _, count = Current()
    if count > 0 then at = (at - 1 + by) % count + 1 end
    held = nil
    A.Refresh()
end

function A.Held() return held end
function A.At() return at end

local function ShowTip(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

local function Button(label, tip, run)
    local button = CreateFrame("Button", nil, holder, "UIPanelButtonTemplate")
    button:SetText(label)
    button:SetSize(math.max(BUTTON_FLOOR, (button:GetTextWidth() or 0) + CHROME), LINE)
    button.tip = tip
    button:SetScript("OnClick", run)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", HideTip)
    return button
end

-- an icon dressed as a flyout's own, pressed to pick it or its place
local function Icon(i)
    local button = CreateFrame("Button", nil, holder)
    button:SetSize(Art.ICON, Art.ICON)
    button.back = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    button.back:SetAtlas(Art.NAMES.back)
    button.back:SetAllPoints()
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    Art.Dress(button, button.icon)
    button:SetNormalAtlas(Art.NAMES.frame)
    button:SetHighlightAtlas(Art.NAMES.frameOver)
    local frame, over = button:GetNormalTexture(), button:GetHighlightTexture()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT")
    frame:SetSize(Art.FRAME, Art.FRAME)
    over:ClearAllPoints()
    over:SetPoint("TOPLEFT")
    over:SetSize(Art.OVER_W, Art.OVER_H)
    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetAtlas(Art.NAMES.frameOver)
    button.ring:SetSize(Art.OVER_W, Art.OVER_H)
    button.ring:SetPoint("TOPLEFT")
    button.ring:Hide()
    button:SetScript("OnClick", function() A.Pick(i) end)
    return button
end

-- a row of the keys list: an icon, its name, and its key as a button
local function Row(i)
    local row = CreateFrame("Frame", nil, holder)
    row:SetSize(LINE + GAP + NAME_W + GAP + KEY_W, LINE)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(LINE, LINE)
    row.icon:SetPoint("LEFT")
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.key = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.key:SetSize(KEY_W, LINE)
    row.key:SetPoint("LEFT", row.name, "RIGHT", GAP, 0)
    row.key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.key.tip = TEXT.keyTip
    row.key:SetScript("OnClick", function(_, button) A.Key(i, button) end)
    row.key:SetScript("OnEnter", ShowTip)
    row.key:SetScript("OnLeave", HideTip)
    return row
end

-- built under the last control of the page, when the page is
-- the check box: ranks of one spell kept in rank order, or left as they are put
function A.Ranks(on)
    local ok, why = F.SetRanked(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

-- the flyout shown here takes its next shape
function A.Turn()
    local flyout = Current()
    if flyout and ns.Turn then
        local ok, why = ns.Turn.Next(flyout)
        if not ok and why then ns.Warn(why) end
    end
    A.Refresh()
end

-- the other check box: items the player has none of are left out of flyouts, or stay grayed
function A.Hide(on)
    local ok, why = F.SetHiding(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

-- the controller's two: flyouts around the button in gamepad mode, and which of its crosses picks first
function A.Around(on)
    local ok, why = F.SetAround(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end
function A.Faces(on)
    local ok, why = F.SetFaces(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end
function A.Plate(on)
    local ok, why = F.SetPlate(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

function A.Build(page, above, scrolled)
    if page.arrange then return end
    panel, holder = page, scrolled or page
    local w = {}
    -- first the keys of one flyout: for everyone, where the section under it is for a controller
    local keysHead = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    keysHead:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -GAP * 3)
    keysHead:SetText(TEXT.keysHead)
    w.keysNote = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.keysNote:SetPoint("TOPLEFT", keysHead, "BOTTOMLEFT", 0, -GAP)
    w.keysNote:SetPoint("RIGHT", holder, "RIGHT", -EDGE, 0)
    w.keysNote:SetJustifyH("LEFT")
    w.keysNote:SetText(TEXT.keysNote)
    w.keyPrev = Button(TEXT.prev, TEXT.prevTip, function() A.Step(-1) end)
    w.keyPrev:SetPoint("TOPLEFT", w.keysNote, "BOTTOMLEFT", 0, -GAP * 2)
    w.keyNext = Button(TEXT.next, TEXT.nextTip, function() A.Step(1) end)
    w.keyNext:SetPoint("LEFT", w.keyPrev, "RIGHT", GAP / 2, 0)
    w.keyWhich = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.keyWhich:SetPoint("LEFT", w.keyNext, "RIGHT", GAP, 0)
    w.rows = {}
    for i = 1, F.MAX do
        local row = Row(i)
        if i == 1 then
            row:SetPoint("TOPLEFT", w.keyPrev, "BOTTOMLEFT", 0, -GAP * 2)
        else
            row:SetPoint("TOPLEFT", w.rows[i - 1], "BOTTOMLEFT", 0, -ROW_GAP)
        end
        w.rows[i] = row
    end
    -- the list is as long as the flyout has icons: what follows hangs on this, set under its last row
    w.foot = CreateFrame("Frame", nil, holder)
    w.foot:SetSize(FOOT, FOOT)
    w.foot:SetPoint("TOPLEFT", w.keyPrev, "BOTTOMLEFT")
    -- the page put away ends a wait for a key
    holder:HookScript("OnHide", function() if ns.Keys then ns.Keys.Stop() end end)
    local head = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", w.foot, "BOTTOMLEFT", 0, -GAP * 3)
    head:SetText(TEXT.head)
    -- as wide as the page, on as many lines as it takes
    w.live = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.live:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    w.live:SetPoint("RIGHT", holder, "RIGHT", -EDGE, 0)
    w.live:SetJustifyH("LEFT")
    w.live:SetText(TEXT.live)
    w.status = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.status:SetPoint("TOPLEFT", w.live, "BOTTOMLEFT", 0, -GAP)
    w.status:SetJustifyH("LEFT")
    w.prev = Button(TEXT.prev, TEXT.prevTip, function() A.Step(-1) end)
    w.prev:SetPoint("TOPLEFT", w.status, "BOTTOMLEFT", 0, -GAP * 2)
    w.next = Button(TEXT.next, TEXT.nextTip, function() A.Step(1) end)
    w.next:SetPoint("LEFT", w.prev, "RIGHT", GAP / 2, 0)
    -- for those with no mouse to pull a flyout's grip
    w.turn = Button(TEXT.turn, TEXT.turnTip, A.Turn)
    w.turn:SetPoint("LEFT", w.next, "RIGHT", GAP / 2, 0)
    w.which = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.which:SetPoint("LEFT", w.turn, "RIGHT", GAP, 0)
    w.icons = {}
    for i = 1, F.MAX do
        local button = Icon(i)
        if i == 1 then
            button:SetPoint("TOPLEFT", w.prev, "BOTTOMLEFT", GAP / 2, -GAP * 2)
        else
            button:SetPoint("LEFT", w.icons[i - 1], "RIGHT", Art.NEXT * 2, 0)
        end
        w.icons[i] = button
    end
    w.off = Button(TEXT.off, TEXT.offTip, A.TakeOff)
    w.off:SetPoint("TOPLEFT", w.icons[1], "BOTTOMLEFT", -GAP / 2, -GAP * 2)
    -- the game's own check boxes, beside it: both for every flyout of the profile
    local function Check(text, tip, run, after, under)
        local box = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
        if under then
            box:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -GAP / 2)
        else
            box:SetPoint("LEFT", after, "RIGHT", GAP * 2, 0)
        end
        local label = box.Text or box.text
        if not label then
            label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", box, "RIGHT", GAP / 2, 0)
        end
        label:SetText(text)
        box.tip = tip
        box:SetScript("OnClick", function(self) run(self:GetChecked() and true or false) end)
        box:SetScript("OnEnter", ShowTip)
        box:SetScript("OnLeave", HideTip)
        return box, label
    end
    local ranksLabel
    w.ranks, ranksLabel = Check(TEXT.ranks, TEXT.ranksTip, A.Ranks, w.off)
    w.hide = Check(TEXT.hide, TEXT.hideTip, A.Hide, ranksLabel)
    -- a line lower, the two for a controller
    local aroundLabel
    w.around, aroundLabel = Check(TEXT.around, TEXT.aroundTip, A.Around, nil, w.ranks)
    w.faces = Check(TEXT.faces, TEXT.facesTip, A.Faces, aroundLabel)
    w.plate = Check(TEXT.plate, TEXT.plateTip, A.Plate, nil, w.around)
    panel.arrange = w
    -- a flyout changed elsewhere shows here at once
    F.Watch(function(what)
        if what == "laid" and panel:IsVisible() then A.Refresh() end
    end)
    A.Refresh()
end
