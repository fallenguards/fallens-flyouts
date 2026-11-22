local _, ns = ...
-- luacheck: read globals CreateFrame GameTooltip

-- The settings page's way to arrange a flyout without a drag: pick an icon,
-- then pick the place it goes. For a controller's cursor as much as a mouse.
local A = {}
ns.Arrange = A
local F, Art = ns.Flyouts, ns.Art

local GAP, LINE, BUTTON_FLOOR, CHROME = 8, 22, 70, 20
-- how much the picked icon grows, as a held one does
local GROW = 1.25
local TEXT = {
    head = "Arrange a flyout",
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
    faces = "Pick with the face buttons",
    facesTip = "On a controller the first four icons take the face buttons, and the D-pad takes any past "
        .. "them. Off, the D-pad comes first. Each flyout can be swapped as it is made in gamepad mode.",
}
A.TEXT = TEXT

local panel
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

function A.Refresh()
    if not (panel and panel.arrange) then return end
    local w = panel.arrange
    local flyout, count = Current()
    if flyout and held and not flyout.entries[held] then held = nil end
    if not flyout then held = nil end
    w.which:SetText(flyout and TEXT.which:format(at, count, F.Name(flyout.main)) or TEXT.none)
    w.prev:SetEnabled(count > 1)
    w.next:SetEnabled(count > 1)
    w.turn:SetEnabled(flyout ~= nil and F.UnitOf(flyout) ~= nil)
    w.off:SetEnabled(held ~= nil)
    w.ranks:SetChecked(F.Ranked())
    w.hide:SetChecked(F.Hiding())
    w.around:SetChecked(F.Around())
    w.faces:SetChecked(F.Faces())
    for i, button in ipairs(w.icons) do
        local entry = flyout and flyout.entries[i]
        button:SetShown(entry ~= nil)
        if entry then button.icon:SetTexture(F.Icon(entry)) end
        -- the picked one grows and keeps its ring
        button:SetScale(held == i and GROW or 1)
        button.ring:SetShown(held == i)
    end
    local name = held and flyout and F.Name(flyout.entries[held])
    w.status:SetText(name and TEXT.held:format(name) or TEXT.note)
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
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
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
    local button = CreateFrame("Button", nil, panel)
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

function A.Build(page, above)
    if page.arrange then return end
    panel = page
    local w = {}
    local head = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -GAP * 3)
    head:SetText(TEXT.head)
    w.status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.status:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    w.status:SetJustifyH("LEFT")
    w.prev = Button(TEXT.prev, TEXT.prevTip, function() A.Step(-1) end)
    w.prev:SetPoint("TOPLEFT", w.status, "BOTTOMLEFT", 0, -GAP * 2)
    w.next = Button(TEXT.next, TEXT.nextTip, function() A.Step(1) end)
    w.next:SetPoint("LEFT", w.prev, "RIGHT", GAP / 2, 0)
    -- for those with no mouse to pull a flyout's grip
    w.turn = Button(TEXT.turn, TEXT.turnTip, A.Turn)
    w.turn:SetPoint("LEFT", w.next, "RIGHT", GAP / 2, 0)
    w.which = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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
        local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
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
    panel.arrange = w
    -- a flyout changed elsewhere shows here at once
    F.Watch(function(what)
        if what == "laid" and panel:IsVisible() then A.Refresh() end
    end)
    A.Refresh()
end
