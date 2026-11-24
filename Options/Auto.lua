local _, ns = ...
-- luacheck: globals SlashCmdList
-- luacheck: read globals CreateFrame Settings GameTooltip StaticPopup_Show C_Timer
-- luacheck: read globals UIParent

-- The settings page of the flyouts that fill themselves: an icon for each
-- kind, picked up here and dropped on an action bar. Under them, the player's
-- own: several kinds ticked in a list make one flyout that holds them all.
local UI = {}
ns.AutoUI = UI
local Auto, Art = ns.Auto, ns.Art

local EDGE, GAP = 16, 8
-- how far apart the icons stand, in icons, so that their names fit under them
local APART = 1.9
-- the list of kinds to tick and the button beside it: the list's width, the button's height, its least
-- width and the room about its word; and the room a name takes under an icon
local DROP_W, LINE, BUTTON_FLOOR, CHROME, NAME_H = 220, 22, 70, 20, 16
-- the x on each of the player's own: its size, and how far past the icon's corner its middle stands
local CLOSE, CLOSE_OUT = 18, 2
local TEXT = {
    title = "Automatic Flyouts",
    intro = "Each of these fills itself with what is in your bags, the best first, and keeps up as your bags change.",
    how = "Drag one onto an action bar. Or click it, then click a bar button.",
    fight = "Nothing on a bar changes in a fight: a flyout catches up when the fight ends.",
    slash = "The same from chat: /ff food, /ff drink and so on.",
    tip = "A flyout of the %s in your bags.",
    macro = "It sits on your bar as a macro named %s.",
    ownHead = "Make Your Own",
    ownIntro = "Tick the kinds one flyout should hold, then press Create. Yours appear in the row below.",
    kinds = "Kinds",
    ticked = "In this order: %s",
    noneTicked = "Nothing is ticked yet.",
    create = "Create",
    createTip = "Makes a flyout that holds every ticked kind, in the order ticked, each kind's best first.",
    ownTip = "A flyout of your own: %s.",
    delete = "Right-click to change its icon or name. The x deletes it.",
    deleteTip = "Delete this flyout.",
    askDelete = "Delete your flyout %s? Its macro goes with it.",
    ownNote = "Each of yours uses one of your general macros. Right-click one to change its icon or name; its x "
        .. "deletes it.",
}
UI.TEXT = TEXT

local panel
-- the kinds ticked for a flyout of the player's own, in the order they were ticked
local order = {}

-- picks a kind's macro up, to be dropped on a bar
function UI.Pick(id)
    local ok, why = Auto.Pick(id)
    if not ok and why then ns.Warn(why) end
    return ok
end

-- the names of kinds, in the order given
local function PartNames(ids)
    local names = {}
    for _, id in ipairs(ids) do
        local part = Auto.Part(id)
        names[#names + 1] = part and part.name or id
    end
    return table.concat(names, ", ")
end

local function ShowTip(self)
    local kind = self.kind
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(kind.name)
    if kind.own then
        GameTooltip:AddLine(TEXT.ownTip:format(PartNames(kind.parts)), 1, 1, 1, true)
    else
        GameTooltip:AddLine(TEXT.tip:format(kind.name:lower()), 1, 1, 1, true)
    end
    GameTooltip:AddLine(TEXT.macro:format(Auto.Macro(kind.id) or kind.name), 1, 1, 1, true)
    if kind.own then GameTooltip:AddLine(TEXT.delete, 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- one of the player's own done away with, once it is said again that it is meant
function UI.AskDelete(kind)
    StaticPopup_Show("FALLENSFLYOUTS_CONFIRM", TEXT.askDelete:format(kind.name), nil, function()
        local ok, why = Auto.Unmix(kind.id)
        UI.Refresh()
        return ok, why
    end)
end

-- the icon and the name a button shows are its kind's
function UI.Dress(button, kind)
    button.kind = kind
    button.icon:SetTexture(kind.icon)
    button.label:SetText(kind.name)
end

-- an icon dressed as a flyout's own, with the kind's name under it; on the page, or on `parent`
function UI.Icon(kind, parent)
    local button = CreateFrame("Button", nil, parent or panel)
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
    over:SetSize(Art.FRAME, Art.FRAME)
    button.label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    button.label:SetPoint("TOP", button, "BOTTOM", 0, -GAP / 2)
    UI.Dress(button, kind)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnDragStart", function(self) UI.Pick(self.kind.id) end)
    -- any is picked up with the left button; the right one gives one of the player's own its icon and name,
    -- as a flyout's are set from its bar button (its x deletes it)
    button:SetScript("OnClick", function(self, which)
        if which == "RightButton" then
            if self.kind.own and ns.Icon then ns.Icon.OpenKind(self.kind) end
            return
        end
        UI.Pick(self.kind.id)
    end)
    button:SetScript("OnEnter", ShowTip)
    button:SetScript("OnLeave", HideTip)
    return button
end

-- the game's small close button on the top right corner of one of the player's own: it deletes it, once
-- that is said again (his words, 2026-11-23: "should have \"x\" appears in top right of each to clear them
-- instead of right click")
local function Remove(button)
    local made, x = pcall(CreateFrame, "Button", nil, button, "UIPanelCloseButtonNoScripts")
    if not made or not x then x = CreateFrame("Button", nil, button, "UIPanelCloseButton") end
    x:SetSize(CLOSE, CLOSE)
    x:ClearAllPoints()
    x:SetPoint("CENTER", button, "TOPRIGHT", CLOSE_OUT, CLOSE_OUT)
    x:SetFrameLevel(button:GetFrameLevel() + 2)
    x:SetScript("OnClick", function() UI.AskDelete(button.kind) end)
    x:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TEXT.deleteTip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    x:SetScript("OnLeave", HideTip)
    return x
end

local function IsTicked(id)
    for _, have in ipairs(order) do
        if have == id then return true end
    end
    return false
end

-- a kind ticked, or its tick taken off
function UI.Tick(id)
    for i, have in ipairs(order) do
        if have == id then
            table.remove(order, i)
            return UI.Refresh()
        end
    end
    order[#order + 1] = id
    UI.Refresh()
end
function UI.Ticked() return order end

-- the list: every kind a flyout of the player's own can hold, each with a box to tick
function UI.Fill(_, root)
    for _, part in ipairs(Auto.Parts()) do
        root:CreateCheckbox(part.name, IsTicked, UI.Tick, part.id)
    end
end

-- the ticked kinds become a flyout of the player's own, and the ticks are taken off
function UI.Create()
    local kind, why = Auto.Mix(order)
    if not kind then
        if why then ns.Warn(why) end
        return nil
    end
    order = {}
    if panel.drop.GenerateMenu then panel.drop:GenerateMenu() end
    UI.Refresh()
    return kind
end

-- what the page holds is as tall as it is, down to its last line: the scroll goes that far
function UI.Fit()
    if panel.built then ns.OptionsFit(panel, panel.note) end
end

function UI.Refresh()
    if not panel.built then return end
    panel.ticked:SetText(#order > 0 and TEXT.ticked:format(PartNames(order)) or TEXT.noneTicked)
    panel.create:SetEnabled(#order > 0)
    -- Each in a place as wide as its name, so that no name runs into the next (his snip, 2026-11-23: "text
    -- overlapping when i make multipel custom auto flyouts"); a row too long for the page goes on under it.
    local own = Auto.Mixes()
    local step, row = Art.ICON * APART, Art.ICON + NAME_H + GAP * 3
    local room = (panel.content:GetWidth() or 0) - EDGE * 2
    local x, rows = 0, 1
    for i, kind in ipairs(own) do
        local button = panel.own[i]
        if not button then
            button = UI.Icon(kind, panel.content)
            button.remove = Remove(button)
            panel.own[i] = button
        end
        UI.Dress(button, kind)
        local wide = math.max(step, (button.label:GetStringWidth() or 0) + GAP * 2)
        if x > 0 and room > 0 and x + wide > room then
            x, rows = 0, rows + 1
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", panel.ticked, "BOTTOMLEFT", x + (wide - Art.ICON) / 2, -(GAP * 2 + (rows - 1) * row))
        x = x + wide
        button:Show()
    end
    for i = #own + 1, #panel.own do panel.own[i]:Hide() end
    -- the words under the row, under its last line
    panel.note:ClearAllPoints()
    panel.note:SetPoint("TOPLEFT", panel.ticked, "BOTTOMLEFT", 0, -(GAP * 2 + rows * row - GAP))
    panel.note:SetPoint("RIGHT", panel.content, "RIGHT", -EDGE, 0)
    UI.Fit()
end

function UI.Build()
    if panel.built then return end
    ns.Start()
    -- the page scrolls inside the game's window, as the addon's first page does: nothing is drawn outside
    local content = ns.OptionsScroller(panel)
    local function Line(text, font, above, gap)
        local line = content:CreateFontString(nil, "ARTWORK", font)
        if above then
            line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
        else
            line:SetPoint("TOPLEFT", content, "TOPLEFT", EDGE, -EDGE)
        end
        line:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
        line:SetJustifyH("LEFT")
        line:SetText(text)
        return line
    end
    local head = Line(TEXT.title, "GameFontNormalLarge")
    local intro = Line(TEXT.intro, "GameFontHighlight", head, GAP)
    local how = Line(TEXT.how, "GameFontHighlight", intro, GAP)
    panel.icons = {}
    for i, kind in ipairs(Auto.KINDS) do
        local button = UI.Icon(kind, content)
        if i == 1 then
            button:SetPoint("TOPLEFT", how, "BOTTOMLEFT", GAP, -GAP * 3)
        else
            button:SetPoint("LEFT", panel.icons[i - 1], "LEFT", Art.ICON * APART, 0)
        end
        panel.icons[i] = button
    end
    local fight = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    fight:SetPoint("TOPLEFT", panel.icons[1], "BOTTOMLEFT", -GAP, -GAP * 5)
    fight:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
    fight:SetJustifyH("LEFT")
    fight:SetText(TEXT.fight)
    local slash = Line(TEXT.slash, "GameFontDisable", fight, GAP)

    -- the player's own: a list of kinds to tick, a button that makes a flyout of them, and their row
    local ownHead = Line(TEXT.ownHead, "GameFontNormalLarge", slash, GAP * 3)
    local ownIntro = Line(TEXT.ownIntro, "GameFontHighlight", ownHead, GAP)
    local drop = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    drop:SetPoint("TOPLEFT", ownIntro, "BOTTOMLEFT", 0, -GAP * 2)
    drop:SetWidth(DROP_W)
    if drop.SetDefaultText then drop:SetDefaultText(TEXT.kinds) end
    drop:SetupMenu(UI.Fill)
    panel.drop = drop
    local create = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    create:SetText(TEXT.create)
    create:SetSize(math.max(BUTTON_FLOOR, (create:GetTextWidth() or 0) + CHROME), LINE)
    create:SetPoint("LEFT", drop, "RIGHT", GAP, 0)
    create:SetScript("OnClick", UI.Create)
    create:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TEXT.createTip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    create:SetScript("OnLeave", HideTip)
    panel.create = create
    panel.ticked = Line("", "GameFontHighlight", drop, GAP)
    panel.own = {}
    -- under the row, whether or not it holds any yet
    local note = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    note:SetPoint("TOPLEFT", panel.ticked, "BOTTOMLEFT", 0, -(GAP * 2 + Art.ICON + NAME_H + GAP * 2))
    note:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
    note:SetJustifyH("LEFT")
    note:SetText(TEXT.ownNote)
    panel.note = note
    panel.built = true
    UI.Refresh()
end

panel = CreateFrame("Frame")
panel:Hide()
panel.name = TEXT.title
panel:SetScript("OnShow", function()
    UI.Build()
    UI.Refresh()
    -- measured once the game has placed the page in its window
    C_Timer.After(0, UI.Fit)
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
-- the Controller page after it (Options/Arrange.lua), then Feedback (Options/Profiles.lua)
if ns.ControllerUI then ns.ControllerUI.Register() end
if ns.FeedbackUI then ns.FeedbackUI.Register() end

-- /ff food and the like: the kind's macro on the cursor; anything else is the settings as before
local open = SlashCmdList.FALLENSFLYOUTS
SlashCmdList.FALLENSFLYOUTS = function(msg)
    local id = type(msg) == "string" and msg:lower():match("^%s*(%a+)%s*$")
    if id and Auto.Kind(id) then return UI.Pick(id) end
    if open then return open(msg) end
end
