local _, ns = ...
-- luacheck: globals FallensFlyoutsDB
-- luacheck: read globals CreateFrame UIParent InCombatLockdown C_Timer OKAY GamepadMainActionBarFrame
-- luacheck: read globals DEFAULT_CHAT_FRAME C_AddOns EventRegistry strsplit geterrorhandler

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
    -- His words (2026-11-23): "why does our initial user popout not mention the right click to change
    -- flyout icon? ppl literally won't even know."
    icon = "Right-click a flyout's bar button to give it an icon and a name of its own.",
    auto = "You can also use these preset flyouts. Each one keeps itself filled with what you have of that kind. "
        .. "Drag one onto an action bar, or click it and then a bar button.",
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
    local shown = Auto.Shown()
    local wide = step * (#shown - 1) + Art.ICON + GAP * 2
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
    frame.icon = Line("GameFontHighlight", frame.make, GAP)
    frame.icon:SetText(TEXT.icon)
    frame.auto = Line("GameFontHighlight", frame.icon, GAP)
    frame.auto:SetText(TEXT.auto)
    -- the flyouts that fill themselves, as on their settings page: picked up by a drag or a click
    frame.icons = {}
    for i, kind in ipairs(shown) do
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
    local words = (frame.make:GetStringHeight() or 0) + GAP + (frame.icon:GetStringHeight() or 0) + GAP
        + (frame.auto:GetStringHeight() or 0)
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

-- After an update, once for the whole account: a line in chat with the addon's icon and name, and a link
-- to what changed since the version seen last. Not for someone new: the window above is theirs. His words
-- (2026-11-24): "please make sure when updates go out, the first time someone logs in with an update (not
-- the first time user ofc since they already get intro popup and whatnot) they get like \"Thanks for
-- updating to v#.#.#. [Here]'s what changed.\"", and "remember to always use the addon icon in chat
-- messages like usual. and the name." What changed is the CHANGELOG.md of each version, kept here
-- (W.CHANGES, written by tools/changes.py; a test holds the two the same). With a controller the link
-- cannot be clicked: the Feedback page of the settings has a What's New button for the same window.
do
    local ICON = "|TInterface\\AddOns\\FallensFlyouts\\media\\icon:16:16|t"
    local LINK = "addon:FallensFlyouts:changes"
    local SAY = {
        thanks = "%s Thanks for updating Fallen's Flyouts to v%s. %s's what changed.",
        here = "Here",
        title = "What's New in Fallen's Flyouts",
        none = "Nothing is written down for this version.",
    }
    W.UPDATE = SAY
    -- the link's own color, as the game draws a link that opens a window of its own
    local LINK_COLOR = "|cff71d5ff"
    -- the window: its width and its greatest height, and how long after the login the line comes, under the
    -- game's own lines
    local NEWS_W, NEWS_H, SAY_AFTER = 560, 440, 6

    function W.Version()
        local get = C_AddOns and C_AddOns.GetAddOnMetadata
        local ok, version = pcall(get, "FallensFlyouts", "Version")
        return ok and type(version) == "string" and version or "?"
    end

    -- whether version a comes after version b, number by number
    local function Newer(a, b)
        local x, y = {}, {}
        for n in tostring(a):gmatch("%d+") do x[#x + 1] = tonumber(n) end
        for n in tostring(b):gmatch("%d+") do y[#y + 1] = tonumber(n) end
        for i = 1, math.max(#x, #y) do
            local p, q = x[i] or 0, y[i] or 0
            if p ~= q then return p > q end
        end
        return false
    end
    W.Newer = Newer

    -- what changed after `from` up to the version in use (or `upTo`), newest first; without `from`, that
    -- version's alone
    function W.Since(from, upTo)
        local now, out = upTo or W.Version(), {}
        for _, entry in ipairs(W.CHANGES or {}) do
            local notLater = not Newer(entry.version, now)
            local after = from and Newer(entry.version, from) or (not from and entry.version == now)
            if notLater and after then out[#out + 1] = entry end
        end
        return out
    end

    -- The line in chat. `as`: the version it speaks of, where that is not the one in use: the dev preview of
    -- a version before the toc says it (his words, 2026-11-24: "i need via dev to see what the whatsnew
    -- message in chat will look like so i can click and view it there too").
    function W.Announce(from, as)
        local link = ("|H%s:%s:%s|h%s[%s]|r|h"):format(LINK, from or "", as or "", LINK_COLOR, SAY.here)
        DEFAULT_CHAT_FRAME:AddMessage(SAY.thanks:format(ICON, as or W.Version(), link))
    end

    local news
    -- The list's own spacing: a marker before each line of what changed and its words indented past it, room
    -- between lines and before each version, and the scroll bar's distance from the dark ground's edges. His
    -- words (2026-11-24): "why is the whatsnew in a paragraph instead of in a list?", and of the scroll bar,
    -- "slider not centered vertically in the dark background section of the window like it should be".
    local MARK, INDENT, LINE_GAP, VERSION_GAP, BAR_EDGE = "-", 14, 4, 10, 6
    -- the window's height besides its list: the title above it, and the Okay row below it
    local AROUND = (TITLE - EDGE) + FOOT + OKAY_H + GAP
    W.NEWS_AROUND = AROUND
    local function BuildNews()
        if news then return news end
        news = CreateFrame("Frame", "FallensFlyoutsWhatsNew", UIParent, "DefaultPanelFlatTemplate")
        news:Hide()
        news:SetFrameStrata("DIALOG")
        news:SetToplevel(true)
        news:SetMovable(true)
        news:SetClampedToScreen(true)
        news:EnableMouse(true)
        news:RegisterForDrag("LeftButton")
        news:SetScript("OnDragStart", function(self) self:StartMoving() end)
        news:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        news:SetSize(NEWS_W, NEWS_H)
        -- Opaque, under the game's own panel art, whose ground lets the world show through. His words
        -- (2026-11-24): "make background for the whatsnew opaque."
        local ground = news:CreateTexture(nil, "BACKGROUND", nil, -8)
        if news.Bg then
            ground:SetAllPoints(news.Bg)
        else
            ground:SetPoint("TOPLEFT", news, "TOPLEFT", 4, -4)
            ground:SetPoint("BOTTOMRIGHT", news, "BOTTOMRIGHT", -4, 4)
        end
        ground:SetColorTexture(0, 0, 0, 1)
        news.ground = ground
        local title = news.TitleContainer and news.TitleContainer.TitleText
        if not title then
            title = news:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            title:SetPoint("TOP", news, "TOP", 0, -GAP / 2)
        end
        title:SetText(SAY.title)
        news.close = CreateFrame("Button", nil, news, "UIPanelCloseButtonDefaultAnchors")
        news.close:SetScript("OnClick", function() news:Hide() end)
        news.okay = CreateFrame("Button", nil, news, "UIPanelButtonTemplate")
        news.okay:SetSize(OKAY_W, OKAY_H)
        news.okay:SetText(OKAY)
        -- in the middle of its row (his snip, 2026-11-24: "okay button not centered")
        news.okay:SetPoint("BOTTOM", news, "BOTTOM", 0, FOOT)
        news.okay:SetScript("OnClick", function() news:Hide() end)
        -- what changed scrolls, as the settings pages do
        news.page = CreateFrame("Frame", nil, news)
        news.page:SetPoint("TOPLEFT", news, "TOPLEFT", 0, -TITLE + EDGE)
        news.page:SetPoint("BOTTOMRIGHT", news, "BOTTOMRIGHT", 0, FOOT + OKAY_H + GAP)
        news.content = ns.OptionsScroller(news.page)
        -- the scroll bar inside the dark ground, as far from its top as from its bottom
        local bar = news.page.bar
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPRIGHT", ground, "TOPRIGHT", -BAR_EDGE, -BAR_EDGE)
            bar:SetPoint("BOTTOMRIGHT", ground, "BOTTOMRIGHT", -BAR_EDGE, BAR_EDGE)
        end
        news.rows, news.marks = {}, {}
        return news
    end

    -- what changed, as the rows of a list: each version's heading, each part's heading, and each line
    function W.ChangesRows(entries)
        local rows = {}
        for _, entry in ipairs(entries) do
            rows[#rows + 1] = { head = true, version = true,
                text = ("|cffffd100v%s|r  |cff9d9d9d%s|r"):format(entry.version, entry.date or "") }
            for _, part in ipairs(entry.parts) do
                rows[#rows + 1] = { head = true, text = "|cffffd100" .. part.name .. "|r" }
                for _, item in ipairs(part.items) do rows[#rows + 1] = { text = item } end
            end
        end
        if #rows == 0 then rows[1] = { head = true, text = SAY.none } end
        return rows
    end
    -- the same as words, a row to a line
    function W.ChangesText(entries)
        local out = {}
        for _, row in ipairs(W.ChangesRows(entries)) do out[#out + 1] = (row.head and "" or MARK .. " ") .. row.text end
        return table.concat(out, "\n")
    end

    -- The list laid row by row, each line's words wrapping under their own start, and the window as high as
    -- the list needs, up to NEWS_H, past which it scrolls; till then there is nothing to scroll, and the
    -- game's scroll bar stays away. His words (2026-11-24): "the whats new box needs to smart resize up to
    -- its current size and then have a scroll", and "slider is present even when text doesnt warrant
    -- scrolling yet".
    local function LayNews(rows)
        local content = news.content
        local wide = content:GetWidth() or 0
        if wide < 200 then wide = NEWS_W - 24 end
        local y = -GAP
        for i, row in ipairs(rows) do
            local words, mark = news.rows[i], news.marks[i]
            if not words then
                words = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                words:SetJustifyH("LEFT")
                words:SetSpacing(2)
                mark = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                news.rows[i], news.marks[i] = words, mark
            end
            if row.version and i > 1 then y = y - VERSION_GAP end
            local x = row.head and EDGE or EDGE + INDENT
            words:ClearAllPoints()
            words:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
            words:SetWidth(wide - x - EDGE)
            words:SetText(row.text)
            words:Show()
            mark:ClearAllPoints()
            mark:SetPoint("TOPLEFT", content, "TOPLEFT", EDGE, y)
            mark:SetText(MARK)
            mark:SetShown(not row.head)
            y = y - (words:GetStringHeight() or 12) - LINE_GAP
        end
        for i = #rows + 1, #news.rows do
            news.rows[i]:Hide()
            news.marks[i]:Hide()
        end
        local tall = math.ceil(-y - LINE_GAP + GAP)
        content:SetHeight(tall)
        news:SetHeight(math.min(NEWS_H, tall + AROUND))
        local scroll = news.page.scroll
        if scroll and scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end
    W.NEWS_H = NEWS_H

    -- the window, with what changed since `from`
    function W.ShowChanges(from, upTo)
        BuildNews()
        local entries = W.Since(from, upTo)
        local rows = W.ChangesRows(entries)
        news.said = W.ChangesText(entries)
        if not news:IsShown() then
            news:ClearAllPoints()
            news:SetPoint("TOP", UIParent, "TOP", 0, -FROM_TOP)
        end
        news:Show()
        LayNews(rows)
        -- once more when the window has its width
        C_Timer.After(0, function() LayNews(rows) end)
        return news
    end
    function W.News() return news end
    -- what the window says, as words
    function W.NewsText() return news and news.said or "" end

    -- the link clicked in chat (the game hands an addon's links on through its event registry)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("SetItemRef", function(_, link)
            local kind, addon, what, from, as = strsplit(":", tostring(link))
            if kind == "addon" and addon == "FallensFlyouts" and what == "changes" then
                xpcall(W.ShowChanges, geterrorhandler(), from ~= "" and from or nil, as ~= "" and as or nil)
            end
        end, W)
    end

    -- Once for the account, after the window above has judged whether this is someone new.
    ns.OnStart(function()
        local db = FallensFlyoutsDB
        local now, seen = W.Version(), db.seenVersion
        db.seenVersion = now
        if db.welcome == OWED or seen == now then return end
        -- an older version put back: nothing new to tell
        if seen and not Newer(now, seen) then return end
        C_Timer.After(SAY_AFTER, function() W.Announce(seen) end)
    end)
end

-- What changed in each version, newest first: CHANGELOG.md's, written here by tools/changes.py.
-- BEGIN generated: changes (tools/changes.py, from CHANGELOG.md)
W.CHANGES = {
    { version = "1.1.8", date = "2026-11-24", parts = {
        { name = "Added", items = {
            "Mages have \"Portals\" and \"Teleports\" preset flyouts, each holding the ones you know.",
            "\"Close a flyout left open\" in /ff closes a flyout by itself when nothing is picked from it, " ..
                "after the time you set.",
        } },
        { name = "Fixed", items = {
            "The + on a bar button no longer shows through windows over the bars.",
        } },
    } },
    { version = "1.1.7", date = "2026-11-24", parts = {
        { name = "Added", items = {
            "Gear sets go in flyouts, like mounts and pets.",
            "Adding to a flyout shows where it goes. Bring a spell or item to a button's + or onto an open " ..
                "flyout, then let go between two icons to insert it or on an icon to replace it.",
            "A \"Default flyout binds\" bar in /ff sets the keys every flyout picks with, above each flyout's " ..
                "own keys.",
            "A Feedback page in the settings has \"Report a Bug\", \"Suggest an Idea\", and \"What's New\". Reports " ..
                "come with your setup filled in, and /ff status opens the page.",
            "\"Match Base Icon Size\", \"Show the flyout background\", and \"Background opacity\" settings.",
            "A hint at the foot of a flyout button's tooltip says how to change what it shows. You can turn " ..
                "hints off in /ff.",
            "With a controller, RB in \"Edit Flyout\" changes a flyout button's icon and name, and LB shows or " ..
                "hides the background.",
        } },
        { name = "Changed", items = {
            "Inside a flyout, let go of an icon on another to swap the two, or between two icons to insert " ..
                "it.",
            "A right-click on a flyout icon casts it, so [button:2] macros work. Drag an icon off to take it " ..
                "off.",
            "With a controller, a new flyout picks with the other cross from its button's, so one on the " ..
                "D-pad picks with the face buttons. The \"New flyouts pick with\" setting on the Controller page " ..
                "changes this, and flyouts you have keep how they pick.",
            "Settings only a controller needs have their own Controller page.",
        } },
    } },
    { version = "1.1.6", date = "2026-11-23", parts = {
        { name = "Added", items = {
            "Mounts and battle pets go in a flyout. Drag one from the Mounts or Pet Journal tab of the " ..
                "Collections window, or off a bar, onto a bar button's plus, as you would a spell: its icon in " ..
                "the flyout summons it, shows its tooltip, and grays out where it cannot be used, as on a bar. A " ..
                "mount or a pet on a bar button can be the first of a flyout too. In combat they are refused with " ..
                "a word in red; add them out of combat.",
        } },
        { name = "Fixed", items = {
            "Toys work in flyouts as on a bar. A toy added to a flyout (a hearthstone toy, say) vanished from " ..
                "it at once, and dropped again it was refused with \"That is in the flyout already.\": \"Hide items " ..
                "I have none of\" took it for an item you had none of, since toys are kept in the Toy Box, never " ..
                "in the bags. A toy of your own now shows in its flyout, in color where it can be used, with the " ..
                "toy's own tooltip, and a click uses it as from the Toy Box. Until now it showed the tooltip of " ..
                "the item that teaches the toy (\"Use: Adds this toy to your Toy Box.\"). Dragged out of a flyout, " ..
                "a toy is picked up as from the Toy Box.",
        } },
    } },
    { version = "1.1.5", date = "2026-11-23", parts = {
        { name = "Added", items = {
            "A setting, off unless turned on, under Arrange a flyout in the settings (/ff): Press a flyout's " ..
                "key again for the last one used. With a flyout open, pressing its key again casts the icon you " ..
                "picked from it last and shuts it, in combat too. A key that is also one of the flyout's own " ..
                "picks stays that pick.",
        } },
        { name = "Fixed", items = {
            "A flyout on Action Bar 1 follows the bar at once when a druid's form, a stance or stealth turns " ..
                "the bar to another page, in combat too. Each page is a bar of its own: a flyout made out of form " ..
                "is on its button only out of form, even where the form's page holds the same ability in that " ..
                "place, and one made in Bear Form only in Bear Form. Until now a flyout caught up only about a " ..
                "second after each shift, and in combat not until the fight was over: in between, a click on its " ..
                "button cast the button's ability, or opened the other page's flyout.",
            "In combat the plus for adding to a flyout stands where it does out of combat, past the tip of " ..
                "the flyout's arrow, and a drop there adds to the flyout. It stood on the arrow itself, pulled " ..
                "down onto the button's edge.",
            "Dragging an ability off a bar in combat could be refused, with an error naming Fallen's Flyouts " ..
                "(\"tried to call the protected function 'PickupAction()'\"), once the flyout icon window (a " ..
                "right-click on a flyout's bar button) had been open in that session. The icon window no longer " ..
                "touches what the game's bar buttons check at the start of a drag. While it is open, an ability " ..
                "dragged off a bar is picked up as by any drag.",
        } },
    } },
    { version = "1.1.4", date = "2026-11-23", parts = {
        { name = "Added", items = {
            "Automatic flyouts of your own. On the Automatic Flyouts page of the settings, tick the kinds one " ..
                "flyout should hold (Food and Drink together, say) and press Create: it joins a row of yours on " ..
                "that page, is dragged onto a bar like the ready-made ones, and keeps itself filled the same way, " ..
                "each kind's best first. Besides the seven ready-made kinds the list has the game's other kinds " ..
                "of consumable. Right-click one of yours on that page to give it an icon and a name of its own, " ..
                "as you would a flyout on a bar: its macro takes them too. The x on its corner deletes it.",
            "A flyout can be given a name, as a macro can. Right-click the flyout's bar button: the icon " ..
                "window has a name box, sixteen letters as for a macro, and the name is written on the button " ..
                "where a macro's name stands. The window's search has a box of its own now, beside Choose an " ..
                "Icon.",
            "An ability dropped on an icon of a flyout takes that icon's place, as on a bar slot: the icon " ..
                "casts it from then on, on its spot and with its key, and the one it held comes onto the cursor. " ..
                "In combat too. A click sets it down the same way out of combat. Until now a drop on an icon did " ..
                "nothing.",
            "Flyout keys, in the settings (/ff): every flyout has a bar there, with its picture and name, " ..
                "that opens as a section of the game's Keybindings options does, to a row for each of its icons " ..
                "with the key that picks it. Click a key and press another to give that icon a key of its own in " ..
                "that flyout; right-click gives it its spot's key back.",
        } },
        { name = "Changed", items = {
            "The Fallen's Flyouts section of the game's Keybindings options is now only the twelve rows for " ..
                "the spots of every flyout. The heading and six rows it had for each of eight flyouts, used or " ..
                "not, are gone: they made eight look like a limit, which it is not. A key for one icon of one " ..
                "flyout is set in the addon's settings, under Flyout keys, or as before by hovering the icon in " ..
                "Quick Keybind Mode, and the section says so. A key already set on one of the old rows goes on " ..
                "working: it is that icon's own key now.",
            "The window someone sees after a first install says that a right-click on a flyout's bar button " ..
                "gives the flyout an icon and a name of its own.",
        } },
        { name = "Fixed", items = {
            "A flyout's bar button dragged to another bar slot in combat takes its flyout along at once: its " ..
                "arrow, its keys and a click on the button all open it there. Until now the flyout stayed on the " ..
                "old button until combat ended. A flyout whose button was dropped on, its ability left on the " ..
                "cursor, follows that ability to the button it is set down on.",
            "An icon dragged out of its flyout in combat leaves it at once: the icons after it move up a " ..
                "spot, and a flyout left with only its button's own ability is no flyout any more, as out of " ..
                "combat. Let go over another icon of the same flyout, it takes that icon's spot. An icon with a " ..
                "key of its own keeps that key wherever it goes; the others take the keys of the spots they stand " ..
                "on. Until now nothing in a flyout could be changed until combat ended. Out of combat it lifts " ..
                "and slides as before. A flyout that fills itself, and one whose icons stand around its button, " ..
                "keep their icons in combat.",
            "A flyout's icon shows when its ability is out of range of the target, as a bar button does: its " ..
                "key turns red, and an icon with no key shows the game's range dot. Where the bars are set up to " ..
                "tint a whole button out of range, the flyout's icons take that same tint. Until now a flyout " ..
                "showed no range at all.",
            "An ability can be added to a flyout in combat: drag it onto the plus, which stands on the " ..
                "flyout's arrow in combat. It takes the next spot, with its key, at once. Until now nothing could " ..
                "be added until combat ended. A flyout that fills itself, and one whose icons stand around its " ..
                "button, take none in combat, and a new flyout is still made out of combat.",
            "The plus for adding to a flyout stands on the side that flyout opens from. For a flyout turned " ..
                "to open another way it stood on the bar's usual side.",
        } },
    } },
    { version = "1.1.3", date = "2026-11-22", parts = {
        { name = "Added", items = {
            "A first login with the addon shows a small window, once: one line on how a flyout is made, and " ..
                "the preset flyouts that keep themselves filled from your bags (Food, Drink, Potions and the " ..
                "rest) in a row, each ready to be dragged onto a bar from there. It is one of the game's own " ..
                "windows in look and can be dragged about. Okay or its x closes it for good. Anyone who already " ..
                "has a flyout never sees it.",
        } },
        { name = "Fixed", items = {
            "Holding a flyout's key to keep it open did not work when that key was also one of the flyout's " ..
                "own pick keys (a flyout on the 1 button, say): it shut after the first pick. Such a key can now " ..
                "be held like any other. While it is down it keeps the flyout open, and once let go it is its " ..
                "icon's key again.",
            "The key text of a bar button lying under an open flyout showed through the flyout's icon. A " ..
                "flyout is now drawn over the bar buttons' texts as well as the buttons.",
            "An error in another addon that listens to this one could stop flyouts being laid out and " ..
                "followed: a flyout then stayed on a button whose ability had been dragged off. Such an error is " ..
                "now reported and stops nothing.",
            "A flyout's icons did not say how many of an item there are. Each icon now shows it in its " ..
                "corner, as a bar button does: the number in the bags for anything used up or stacked, and a " ..
                "spell's charges or uses.",
            "The settings page was taller than the game's Options window, so its last check boxes hung out " ..
                "under it. The page now scrolls inside the window, with the game's own scroll bar, and a " ..
                "controller's cursor scrolls it too.",
        } },
        { name = "Changed", items = {
            "An open flyout's keys are always the flyout's. With Fallen's Modifier Keys, a key set as a " ..
                "modifier there used to be skipped, so icons began at 2: they begin at 1 again, and the modifier " ..
                "key is left alone only while it is being held down. This needs the Fallen's Modifier Keys " ..
                "release that comes out alongside this one.",
            "A flyout now holds up to twelve, up from six, picked with the bar's own twelve keys: 1 to 9, 0, " ..
                "- and =. The game's Keybindings options have a row for each of the twelve spots of every flyout. " ..
                "In gamepad mode a ninth to twelfth icon stand on a third ring around the button; no pad button " ..
                "picks that ring, so there they are picked by key or by a click.",
            "The settings page says, over Arrange a flyout, that none of it is needed with a mouse: a flyout " ..
                "is made by dragging a spell, item or macro onto a bar button, where the + appears. That section " ..
                "is for a controller.",
        } },
        { name = "Removed", items = {
            "Set Keys is gone from the settings page. A key for an icon inside a flyout is set the game's own " ..
                "ways: in its Keybindings options, or by hovering the icon in Quick Keybind Mode and pressing the " ..
                "key.",
        } },
    } },
    { version = "1.1.2", date = "2026-11-21", parts = {
        { name = "Fixed", items = {
            "The game's mouseover casting was ignored by a flyout's icons: a heal picked from a flyout went " ..
                "to the target, not to the friend under the mouse as it does from a bar button. A flyout's icons " ..
                "now obey it as the bar's own buttons do, with its key where one is set, and the focus cast key " ..
                "as well.",
        } },
    } },
    { version = "1.1.1", date = "2026-11-21", parts = {
        { name = "Added", items = {
            "In gamepad mode a flyout opens around its button, each icon on the side its pad button is: the " ..
                "first above the button on D-pad up, then right, down and left. A fifth and sixth stand a step " ..
                "further out and take the face buttons of their sides. A check box under Arrange a flyout in the " ..
                "settings (/ff) turns this off, and a flyout given a shape of its own keeps it.",
            "The face buttons can pick before the D-pad: a check box under Arrange a flyout sets it for every " ..
                "flyout, and in gamepad mode, right after Add to Flyout, the same button swaps it for the flyout " ..
                "just made (the hint bar names it: Use Face Buttons, Use D-Pad).",
            "A button whose flyout opens around it is marked by four small dots at its corner, laid out like " ..
                "the pad's buttons, in place of the arrow: an arrow there looked like a D-pad direction to press.",
            "A flyout that opens around its button has a round background with a rim behind it, so an open " ..
                "flyout is seen at a glance. A check box under Arrange a flyout turns it off; in gamepad mode the " ..
                "hint bar does too (Hide Background, Show Background).",
            "In gamepad mode, binding an ability onto a taken button shows the flyout in place, around that " ..
                "button: its icons and the pad button that picks each. It changes at once when the face buttons, " ..
                "the D-pad or the background are swapped there.",
            "Edit Flyout, in gamepad mode: in Edit Action Bar, pick up a button that has a flyout and the " ..
                "hint bar offers Edit Flyout. The ability goes back on its button and the flyout editor is up at " ..
                "once, there in Edit Action Bar, around that button. In it the D-pad puts the selected icon on " ..
                "that side of the button, whether an icon is there or not (one that is there changes places with " ..
                "it), and the same side again puts it on the outer ring. Each icon stays where it is put. The " ..
                "hint bar names the rest: select the next icon, take it off, pick with the face buttons or the " ..
                "D-pad, show or hide the background, done.",
            "In gamepad mode, the buttons shown in Bind to Action Bar and Edit Action Bar wear the flyout " ..
                "mark too, so the buttons that have flyouts can be told there.",
            "The icon window (right-click a flyout's button) has a row of the flyout's own icons over the " ..
                "game's list. Pick one and it goes onto the bar button itself, so its icon, tooltip and cooldown " ..
                "are there to see without opening the flyout. What was on the button stays in the flyout.",
            "Reset to default icon, in the same window: the button gets back the ability it had, and any icon " ..
                "picked for it is taken off.",
            "A flyout lying along a side of its button can be centered on the button. Drag its grip to the " ..
                "middle of that side of the button and it snaps there; the Turn button under Arrange a flyout in " ..
                "the settings steps through the centered shapes too.",
        } },
        { name = "Changed", items = {
            "A flyout now goes with its button when the button is thrown away. Drag the button off the bar " ..
                "and let go, or unbind it in gamepad mode, and its flyout is removed: it no longer comes back " ..
                "when the same spell is put on a bar again. Moving the button to another spot keeps its flyout, " ..
                "as before.",
            "Turning a flyout by its grip is steadier: a shape takes over only when the mouse is clearly " ..
                "nearer to it and has stayed there a moment, so the flyout no longer jumps through every shape " ..
                "passed on the way.",
            "Macros that cast ranks of one spell are kept in rank order in a flyout, Rank 1 first, as the " ..
                "spells themselves are.",
        } },
        { name = "Fixed", items = {
            "Macros that share a name were taken for one and the same macro. This is common: many players " ..
                "name their macros with a single space to keep the name off the button. A second such macro " ..
                "dropped on the first was refused with \"That is in the flyout already.\", and a flyout could show " ..
                "or run the wrong one. Macros are now told apart by their text as well as their name.",
            "A macro's icon in a flyout now shows the tooltip its bar button would: the spell or the item the " ..
                "macro stands for. It used to show only the macro's name.",
            "A macro with a blank name is listed in the game's Keybindings options by what it casts.",
            "An error from the spellbook while the addon looked for bar buttons (\"attempt to index a nil " ..
                "value\" in the game's spellbook code).",
            "Flyouts showed through windows that were over the action bars. A flyout is now in the same layer " ..
                "as its bar, so such a window covers it too.",
            "The arrow on a flyout's button could stay dimmed after a click.",
            "In gamepad mode the mark on a flyout's button was sized late when its group grew or shrank. It " ..
                "keeps the button's size at every moment now.",
            "A flyout lying along a side of its button had no edge at its near end. It is closed at both ends " ..
                "now.",
            "A spell dragged out of a flyout had to be clicked onto a bar spot. Letting go over the spot now " ..
                "places it, as with a spell dragged from anywhere else.",
        } },
    } },
    { version = "1.1.0", date = "2026-11-21", parts = {
        { name = "Added", items = {
            "Automatic flyouts, on a page of their own in the settings (/ff): Food, Drink, Potions, Elixirs, " ..
                "Flasks, Scrolls and Bandages. Drag one onto an action bar and it fills itself with what is in " ..
                "your bags, the best first, and keeps up as your bags change: the last of something used up, it " ..
                "is gone; more of it or something new in your bags, it is back. Each sits on your bar as a macro " ..
                "with an icon of its own. Nothing on a bar changes in a fight, so a flyout catches up when the " ..
                "fight ends. /ff food, /ff drink and so on put one on your cursor from chat.",
            "A flyout can be turned: out of combat, with the mouse on an open flyout, a grip appears at its " ..
                "far end. Drag the grip to where the flyout should end and it snaps there as you go: straight out " ..
                "from any side of its button, or lying along a side as a row or a column. Let go and it stays; " ..
                "drag it back and it opens the bar's own way again. With no mouse, the Turn button under Arrange " ..
                "a flyout in the settings steps through the same shapes.",
            "Ranks of one spell in the same flyout are kept in rank order, Rank 1 first, whichever of them " ..
                "the button holds. Other icons stay where you put them. A check box under Arrange a flyout in the " ..
                "settings (/ff) turns this off.",
        } },
        { name = "Changed", items = {
            "Flyouts you make by hand now leave out the items you have none of, and take them back, each in " ..
                "its old place, when you have some again. Untick Hide items I have none of under Arrange a flyout " ..
                "in the settings to keep them in place, grayed, as before.",
            "The Fallen's Flyouts section of the game's Keybindings options is laid out by flyout: each " ..
                "flyout on your bars, up to eight of them, has a heading, with a row for each of its spots. A key " ..
                "set on a row picks that spot while its flyout is open. Under them are rows for the spots of " ..
                "every flyout alike. A flyout on a bar of gamepad mode says so in its heading, and a flyout whose " ..
                "ability is on no bar keeps a heading only while a key is set under it.",
            "The rows there that set an extra key to open a flyout are gone: a flyout opens with its bar " ..
                "button's own key.",
        } },
        { name = "Fixed", items = {
            "A flyout on an upright bar opened along the bar, not to the side, while the buttons beside its " ..
                "own were empty and hidden.",
            "A key given to a flyout's bar button in the moment after the addon had bound its own keys was " ..
                "not taken up until keys changed again.",
            "Shift-dragging an icon out of a flyout cast it first. A mouse click on an icon now casts when " ..
                "the button is let go, as on the game's own flyouts; the keys still cast on the press.",
            "A spell's tooltip in a flyout now shows its rank.",
            "On a controller, the button that opened a flyout while a shoulder was held only shut it when " ..
                "pressed again. It now picks the spot it stands for, as a plain key does.",
        } },
    } },
    { version = "1.0.0", date = "2026-11-21", parts = {
        { name = "Added", items = {
            "Your own flyouts on any action bar button: pick up a spell, an item or a macro and drop it on " ..
                "the plus that appears on a button. Up to six on each button, and as many flyouts as you like.",
            "Open a flyout with the button's key or a click, then press 1 to 6 to cast. It works in combat.",
            "Hold the button's key to keep the flyout open and press as many as you like; it closes when you " ..
                "let go.",
            "Controller support: pick with the D-pad and face buttons, shown with your controller's own " ..
                "symbols.",
            "The game's own flyout look and size, with cooldowns and out-of-mana dimming on every icon. A " ..
                "size setting makes them bigger or smaller.",
            "Your own key for any icon in a flyout: use Set Keys in the settings or the game's Quick Keybind " ..
                "Mode, hover the icon and press a key. A flyout's keys only count while it is open, so your " ..
                "normal keybinds are never changed.",
            "A section of its own in the game's Keybindings options: a key for each flyout, and the keys that " ..
                "pick each icon of an open one. Hover a flyout's row there and its bar button lights up.",
            "A flyout follows its ability when you move it to another button.",
            "Shift-drag an icon to move it inside its flyout: it lifts, the others slide out of its way, and " ..
                "it lands where you let go. Drag it out of the flyout to take it off.",
            "In gamepad mode, binding or moving an ability onto a button that already has one still replaces " ..
                "it, and the game's hint bar then names both ways on: Add to Flyout, which keeps the old ability " ..
                "on the button and stacks the new one into its flyout, or Swap Out.",
            "No mouse drag needed: the settings (/ff) have an Arrange section where you pick an icon and then " ..
                "the place it goes, made for a controller's cursor.",
            "Right-click an icon to take it off a flyout. Right-click the button to pick an icon for the " ..
                "flyout.",
            "Profiles for a character, a class or everyone, in the settings (/ff).",
        } },
    } },
}
-- END generated: changes
