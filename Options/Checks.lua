local _, ns = ...
-- luacheck: read globals CreateFrame GameTooltip

-- The settings page's check boxes. Each is for every flyout of the profile in use.
local C = {}
ns.Checks = C
local F = ns.Flyouts

local GAP = 8
local TEXT = {
    head = "Flyout options",
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
C.TEXT = TEXT

local panel

function C.Refresh()
    if not (panel and panel.checks) then return end
    local w = panel.checks
    w.ranks:SetChecked(F.Ranked())
    w.hide:SetChecked(F.Hiding())
    w.around:SetChecked(F.Around())
    w.faces:SetChecked(F.Faces())
    w.plate:SetChecked(F.Plate())
end

local function ShowTip(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- a box's press sets its choice; a refusal (a fight) is said in red and the box shows what stands
local function Sets(set)
    return function(on)
        local ok, why = set(on)
        if not ok and why then ns.Warn(why) end
        C.Refresh()
    end
end

-- built under the last control of the page, on the part of it that scrolls
function C.Build(page, above, scrolled)
    if page.checks then return end
    panel = page
    local holder = scrolled or page
    local w = {}
    local head = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -GAP * 3)
    head:SetText(TEXT.head)
    -- the game's own check boxes: beside `after`, or a line under `under`
    local function Check(text, tip, set, after, under, gap)
        local box = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
        if under then
            box:SetPoint("TOPLEFT", under, "BOTTOMLEFT", 0, -(gap or GAP / 2))
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
        local run = Sets(set)
        box:SetScript("OnClick", function(self) run(self:GetChecked() and true or false) end)
        box:SetScript("OnEnter", ShowTip)
        box:SetScript("OnLeave", HideTip)
        return box, label
    end
    local ranksLabel, aroundLabel
    w.ranks, ranksLabel = Check(TEXT.ranks, TEXT.ranksTip, F.SetRanked, nil, head, GAP)
    w.hide = Check(TEXT.hide, TEXT.hideTip, F.SetHiding, ranksLabel)
    -- a line lower, the two for a controller, and under the first of them what goes with it
    w.around, aroundLabel = Check(TEXT.around, TEXT.aroundTip, F.SetAround, nil, w.ranks)
    w.faces = Check(TEXT.faces, TEXT.facesTip, F.SetFaces, aroundLabel)
    w.plate = Check(TEXT.plate, TEXT.plateTip, F.SetPlate, nil, w.around)
    panel.checks = w
    C.Refresh()
end
