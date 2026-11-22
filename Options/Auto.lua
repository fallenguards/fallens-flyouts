local _, ns = ...
-- luacheck: globals SlashCmdList
-- luacheck: read globals CreateFrame Settings GameTooltip

-- The settings page of the flyouts that fill themselves: an icon for each
-- kind, picked up here and dropped on an action bar.
local UI = {}
ns.AutoUI = UI
local Auto, Art = ns.Auto, ns.Art

local EDGE, GAP = 16, 8
-- how far apart the icons stand, in icons, so that their names fit under them
local APART = 1.9
local TEXT = {
    title = "Automatic Flyouts",
    intro = "Each of these fills itself with what is in your bags, the best first, and keeps up as your bags change.",
    how = "Drag one onto an action bar. Or click it, then click a bar button.",
    fight = "Nothing on a bar changes in a fight: a flyout catches up when the fight ends.",
    slash = "The same from chat: /ff food, /ff drink and so on.",
    tip = "A flyout of the %s in your bags.",
    macro = "It sits on your bar as a macro named %s.",
}
UI.TEXT = TEXT

local panel

-- picks a kind's macro up, to be dropped on a bar
function UI.Pick(id)
    local ok, why = Auto.Pick(id)
    if not ok and why then ns.Warn(why) end
    return ok
end

local function ShowTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.kind.name)
    GameTooltip:AddLine(TEXT.tip:format(self.kind.name:lower()), 1, 1, 1, true)
    GameTooltip:AddLine(TEXT.macro:format(Auto.Macro(self.kind.id) or self.kind.name), 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- an icon dressed as a flyout's own, with the kind's name under it; on the page, or on `parent`
function UI.Icon(kind, parent)
    local button = CreateFrame("Button", nil, parent or panel)
    button:SetSize(Art.ICON, Art.ICON)
    button.kind = kind
    button.back = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    button.back:SetAtlas(Art.NAMES.back)
    button.back:SetAllPoints()
    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    button.icon:SetTexture(kind.icon)
    Art.Dress(button, button.icon)
    button:SetNormalAtlas(Art.NAMES.frame)
    button:SetHighlightAtlas(Art.NAMES.frameOver)
    local frame, over = button:GetNormalTexture(), button:GetHighlightTexture()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT")
    frame:SetSize(Art.FRAME, Art.FRAME)
    over:ClearAllPoints()
    over:SetPoint("TOPLEFT")
    over:SetSize(Art.FRAME, Art.FRAME)
    button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.label:SetPoint("TOP", button, "BOTTOM", 0, -GAP / 2)
    button.label:SetText(kind.name)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function() UI.Pick(kind.id) end)
    button:SetScript("OnClick", function() UI.Pick(kind.id) end)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", HideTip)
    return button
end

function UI.Build()
    if panel.built then return end
    ns.Start()
    local function Line(text, font, above, gap)
        local line = panel:CreateFontString(nil, "ARTWORK", font)
        if above then
            line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
        else
            line:SetPoint("TOPLEFT", panel, "TOPLEFT", EDGE, -EDGE)
        end
        line:SetPoint("RIGHT", panel, "RIGHT", -EDGE, 0)
        line:SetJustifyH("LEFT")
        line:SetText(text)
        return line
    end
    local head = Line(TEXT.title, "GameFontNormalLarge")
    local intro = Line(TEXT.intro, "GameFontHighlight", head, GAP)
    local how = Line(TEXT.how, "GameFontHighlight", intro, GAP)
    panel.icons = {}
    for i, kind in ipairs(Auto.KINDS) do
        local button = UI.Icon(kind, panel)
        if i == 1 then
            button:SetPoint("TOPLEFT", how, "BOTTOMLEFT", GAP, -GAP * 3)
        else
            button:SetPoint("LEFT", panel.icons[i - 1], "LEFT", Art.ICON * APART, 0)
        end
        panel.icons[i] = button
    end
    local fight = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    fight:SetPoint("TOPLEFT", panel.icons[1], "BOTTOMLEFT", -GAP, -GAP * 5)
    fight:SetPoint("RIGHT", panel, "RIGHT", -EDGE, 0)
    fight:SetJustifyH("LEFT")
    fight:SetText(TEXT.fight)
    Line(TEXT.slash, "GameFontDisable", fight, GAP)
    panel.built = true
end

panel = CreateFrame("Frame")
panel:Hide()
panel.name = TEXT.title
panel:SetScript("OnShow", function()
    UI.Build()
    if ns.OptionsPageShown then ns.OptionsPageShown(panel) end
end)
panel:SetScript("OnHide", function()
    if ns.OptionsPageHidden then ns.OptionsPageHidden() end
end)
UI.panel = panel

-- a page of its own under the addon's, for those who want these
if Settings and Settings.RegisterCanvasLayoutSubcategory and ns.OptionsCategory then
    Settings.RegisterCanvasLayoutSubcategory(ns.OptionsCategory, panel, TEXT.title)
end

-- /ff food and the like: the kind's macro on the cursor; anything else is the settings as before
local open = SlashCmdList.FALLENSFLYOUTS
SlashCmdList.FALLENSFLYOUTS = function(msg)
    local id = type(msg) == "string" and msg:lower():match("^%s*(%a+)%s*$")
    if id and Auto.Kind(id) then return UI.Pick(id) end
    if open then return open(msg) end
end
