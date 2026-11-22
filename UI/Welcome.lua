local _, ns = ...
-- luacheck: globals FallensFlyoutsDB
-- luacheck: read globals CreateFrame UIParent InCombatLockdown C_Timer OKAY GamepadMainActionBarFrame

-- What someone sees who has just installed the addon, once: a small window of the game's own kind (the
-- flat panel its Loot Rolls window is made of, so it wears this client's art and is dragged like it)
-- with a line on how a flyout is made and, under it, the flyouts that fill themselves, in a row, to be
-- put on a bar from there. It is gone for good once it is closed with Okay or its x.
local W = {}
ns.Welcome = W
local Auto, Art = ns.Auto, ns.Art

local NAME = "FallensFlyoutsWelcome"
-- The window: its margin at the sides, the room its title bar takes and the room under its last row,
-- the gap between its parts, how far apart the icons stand in icons (as on the settings page), the
-- room for a name under an icon, its Okay button, and how far down the screen it first stands.
local EDGE, TITLE, FOOT, GAP, APART, NAME_H = 18, 34, 14, 12, 1.9, 16
local OKAY_W, OKAY_H, FROM_TOP = 96, 22, 140
-- how long after the login it comes up: the bars are placed by then
local WAIT = 4
-- kept with the saved data: still to be shown, or closed by the player
local OWED, DONE = "owed", "done"
local TEXT = {
    title = "Fallen's Flyouts",
    make = "To make a flyout, drag a spell, item or macro onto a bar button and drop it on the +.",
    -- in the game's gamepad mode nothing is dragged
    makePad = "To make a flyout, bind an ability onto a button that already holds one and choose Add to Flyout.",
    auto = "You can also use these preset flyouts. Each one keeps itself filled with that kind of item from "
        .. "your bags. Drag one onto an action bar, or click it and then a bar button.",
    more = "More in the settings: /ff",
}
W.TEXT, W.OWED, W.DONE = TEXT, OWED, DONE

local frame, waiting

-- Whether the bars of the game's gamepad mode are on the screen. Their frame is there at all times
-- and the game shows it in that mode; it is not ours, so it is asked through a plain frame's own call.
local function PadMode()
    local bar = GamepadMainActionBarFrame
    return type(bar) == "table" and UIParent.IsVisible(bar) == true
end

local function Seen()
    if FallensFlyoutsDB then FallensFlyoutsDB.welcome = DONE end
end

-- closed by the player: for good
local function Dismiss()
    Seen()
    if frame then frame:Hide() end
end

local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", NAME, UIParent, "DefaultPanelFlatTemplate")
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    -- dragged by any part of it that is no button, as the game's own windows of this kind are
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", 0, -GAP / 2)
    end
    title:SetText(TEXT.title)
    frame.title = title
    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
    frame.close:SetScript("OnClick", Dismiss)

    local step = Art.ICON * APART
    local wide = step * (#Auto.KINDS - 1) + Art.ICON + GAP * 2
    frame.wide = wide
    local function Line(font, above, gap)
        local line = frame:CreateFontString(nil, "ARTWORK", font)
        if above then
            line:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
        else
            line:SetPoint("TOPLEFT", frame, "TOPLEFT", EDGE, -TITLE)
        end
        line:SetWidth(wide)
        line:SetJustifyH("LEFT")
        return line
    end
    frame.make = Line("GameFontHighlight")
    frame.auto = Line("GameFontHighlight", frame.make, GAP)
    frame.auto:SetText(TEXT.auto)
    -- the flyouts that fill themselves, as on their settings page: picked up by a drag or a click
    frame.icons = {}
    for i, kind in ipairs(Auto.KINDS) do
        local button = ns.AutoUI.Icon(kind, frame)
        if i == 1 then
            button:SetPoint("TOPLEFT", frame.auto, "BOTTOMLEFT", GAP, -GAP)
        else
            button:SetPoint("LEFT", frame.icons[i - 1], "LEFT", step, 0)
        end
        frame.icons[i] = button
    end
    frame.okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.okay:SetSize(OKAY_W, OKAY_H)
    frame.okay:SetText(OKAY)
    frame.okay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -EDGE, FOOT)
    frame.okay:SetScript("OnClick", Dismiss)
    frame.more = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    frame.more:SetPoint("LEFT", frame, "BOTTOMLEFT", EDGE, FOOT + OKAY_H / 2)
    frame.more:SetText(TEXT.more)
    return frame
end

-- as high as its words run to at this client's size of text
local function Fit()
    local words = (frame.make:GetStringHeight() or 0) + GAP + (frame.auto:GetStringHeight() or 0)
    frame:SetSize(frame.wide + EDGE * 2, TITLE + words + GAP + Art.ICON + NAME_H + GAP + OKAY_H + FOOT)
end

function W.Owed() return FallensFlyoutsDB ~= nil and FallensFlyoutsDB.welcome == OWED end
function W.Frame() return frame end

-- the window, up now; not in a fight, where nothing can be put on a bar
function W.Show()
    if InCombatLockdown() then return false end
    Build()
    frame.make:SetText(PadMode() and TEXT.makePad or TEXT.make)
    Fit()
    -- where it first stands; dragged, it stays where it was put until it is closed
    if not frame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOP", UIParent, "TOP", 0, -FROM_TOP)
    end
    frame:Show()
    return true
end

-- taken down without a word from the player: still owed
function W.Hide()
    if frame then frame:Hide() end
end

-- Shown when it is owed. In a fight it waits for the fight's end.
function W.Check()
    if not W.Owed() then return false end
    if InCombatLockdown() then
        waiting = true
        return false
    end
    waiting = nil
    return W.Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if waiting then W.Check() end
end)

ns.OnStart(function()
    local db = FallensFlyoutsDB
    -- judged once: saved data that holds a flyout is not a new install
    if db.welcome ~= OWED and db.welcome ~= DONE then
        local has = false
        for _, profile in pairs(db.profiles or {}) do
            local flyouts = type(profile) == "table" and profile.flyouts
            if type(flyouts) == "table" and #flyouts > 0 then has = true end
        end
        db.welcome = has and DONE or OWED
    end
    if db.welcome == OWED then C_Timer.After(WAIT, W.Check) end
end)
