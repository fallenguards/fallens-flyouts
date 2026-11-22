local _, ns = ...
-- luacheck: globals StaticPopupDialogs FallensFlyoutsDB
-- luacheck: read globals CreateFrame UIParent StaticPopup_Show InCombatLockdown C_Timer OKAY NORMAL_FONT_COLOR
-- luacheck: read globals GamepadMainActionBarFrame

-- What someone sees who has just installed the addon, once: the game's own dialog with a line on how a
-- flyout is made, and under it the flyouts that fill themselves, in a row, to be put on a bar from there.
-- It is gone for good once it is closed with Okay, its x or Escape.
local W = {}
ns.Welcome = W
local Auto, Art = ns.Auto, ns.Art

local POPUP = "FALLENSFLYOUTS_WELCOME"
-- The row of icons: its margin at each side, the room over the icons, how far apart they stand in icons
-- (as on the settings page), the room for a name under an icon, for the last line, and the gap between.
local EDGE, TOP, APART, NAME, LINE, GAP = 16, 12, 1.9, 14, 14, 8
-- how long after the login it comes up: the bars are placed by then
local WAIT = 4
-- kept with the saved data: still to be shown, or closed by the player
local OWED, DONE = "owed", "done"
local TEXT = {
    title = "Fallen's Flyouts",
    make = "To make a flyout, drag a spell, item or macro onto a bar button and drop it on the +.",
    -- in the game's gamepad mode nothing is dragged
    makePad = "To make a flyout, bind an ability onto a button that already holds one and choose Add to Flyout.",
    auto = "These fill themselves from your bags. Drag one onto an action bar, or click it and then a bar button:",
    more = "More in the settings: /ff",
}
W.TEXT, W.POPUP, W.OWED, W.DONE = TEXT, POPUP, OWED, DONE

local row, waiting

-- Whether the bars of the game's gamepad mode are on the screen. Their frame is there at all times
-- and the game shows it in that mode; it is not ours, so it is asked through a plain frame's own call.
local function PadMode()
    local bar = GamepadMainActionBarFrame
    return type(bar) == "table" and UIParent.IsVisible(bar) == true
end

-- The flyouts that fill themselves, as on their settings page: an icon each, its name under it, picked
-- up by a drag or a click. The game's dialog takes this frame in under its text.
local function Row()
    if row then return row end
    row = CreateFrame("Frame", nil, UIParent)
    row:Hide()
    local step = Art.ICON * APART
    row:SetSize(step * (#Auto.KINDS - 1) + Art.ICON + EDGE * 2, TOP + Art.ICON + GAP / 2 + NAME + GAP + LINE)
    row.icons = {}
    for i, kind in ipairs(Auto.KINDS) do
        local button = ns.AutoUI.Icon(kind, row)
        if i == 1 then
            button:SetPoint("TOPLEFT", row, "TOPLEFT", EDGE, -TOP)
        else
            button:SetPoint("LEFT", row.icons[i - 1], "LEFT", step, 0)
        end
        row.icons[i] = button
    end
    row.more = row:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    row.more:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
    row.more:SetText(TEXT.more)
    return row
end

local function Seen()
    if FallensFlyoutsDB then FallensFlyoutsDB.welcome = DONE end
end

StaticPopupDialogs[POPUP] = {
    text = "%s",
    button1 = OKAY,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    -- these two go straight into the game's frame calls, which take true and nothing else
    closeButton = true,
    closeButtonIsHide = true,
    wideText = 1,
    preferredIndex = 3,
    OnAccept = function() Seen() end,
    -- Escape comes as "clicked". The game also calls this with no reason when it could not put the
    -- dialog up at all: then nothing was seen.
    OnCancel = function(_, _, why)
        if why == "clicked" then Seen() end
    end,
    OnCloseClicked = function() Seen() end,
}

function W.Owed() return FallensFlyoutsDB ~= nil and FallensFlyoutsDB.welcome == OWED end

-- the dialog, up now; not in a fight, where nothing can be put on a bar
function W.Show()
    if InCombatLockdown() then return false end
    local title = TEXT.title
    if NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.WrapTextInColorCode then
        title = NORMAL_FONT_COLOR:WrapTextInColorCode(title)
    end
    local text = table.concat({ title, PadMode() and TEXT.makePad or TEXT.make, TEXT.auto }, "\n\n")
    StaticPopup_Show(POPUP, text, nil, nil, Row())
    return true
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
