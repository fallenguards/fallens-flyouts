local _, ns = ...
-- luacheck: read globals CreateFrame Settings C_Timer

-- The Controller page, under the addon's own in the game's options beside Automatic Flyouts: what only a
-- controller needs, said so in its name and in its first words (built by Options/Arrange.lua).
-- His words (2026-11-24), of the settings page's "Arrange a flyout": "this is a very confusing section. if
-- we have a section only relevant to console players, then 1: it should be cleanly separated (aka like
-- another tab in the dropdown like automatic flyouts are) and 2, it should be clearly labelled as such...
-- i have no idea what i'm looking at there, and why things like keep a spell ranks in order button etc
-- are under arrange a flyout."
local UI = {}
ns.ControllerUI = UI

local panel = CreateFrame("Frame")
panel:Hide()
panel.name = ns.Arrange.TEXT.pad
UI.panel = panel

function UI.Build()
    if panel.built then return end
    ns.Start()
    ns.Arrange.BuildPad(panel, ns.OptionsScroller(panel))
    panel.built = true
end

-- it scrolls as far as its lowest control
function UI.Fit()
    if panel.built then ns.OptionsFit(panel, panel.arrange and panel.arrange.off) end
end

panel:SetScript("OnShow", function()
    UI.Build()
    ns.Arrange.Refresh()
    -- measured once the game has placed the page in its window
    C_Timer.After(0, UI.Fit)
    if ns.OptionsPageShown then ns.OptionsPageShown(panel) end
end)
panel:SetScript("OnHide", function()
    if ns.OptionsPageHidden then ns.OptionsPageHidden() end
end)

if Settings and Settings.RegisterCanvasLayoutSubcategory and ns.OptionsCategory then
    Settings.RegisterCanvasLayoutSubcategory(ns.OptionsCategory, panel, ns.Arrange.TEXT.pad)
end
