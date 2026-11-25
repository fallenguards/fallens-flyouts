local _, ns = ...
-- luacheck: read globals CreateFrame GameTooltip GetBindingText Settings C_Timer StaticPopup_Show InCombatLockdown
-- luacheck: read globals CANCEL
-- luacheck: globals StaticPopupDialogs

-- What the settings say of flyouts: on the addon's own page, General (the settings for every flyout) and
-- Flyout keys; on the Controller page (at the foot of this file), what only a controller needs, the settings
-- of gamepad mode and a way to arrange a flyout without a drag: pick an icon, then the place it goes.
-- His words (2026-11-24), of the settings page's "Arrange a flyout": "this is a very confusing section. if
-- we have a section only relevant to console players, then 1: it should be cleanly separated (aka like
-- another tab in the dropdown like automatic flyouts are) and 2, it should be clearly labelled as such...
-- i have no idea what i'm looking at there, and why things like keep a spell ranks in order button etc
-- are under arrange a flyout."
local A = {}
ns.Arrange = A
local F, Art, Binds = ns.Flyouts, ns.Art, ns.Binds

local EDGE, GAP, LINE, BUTTON_FLOOR, CHROME = 16, 8, 22, 70, 20
-- The keys of each flyout, as the game's Keybindings options show a section: a banner that opens and
-- shuts, and under it a row for each key. The banner's art and its measures are the game's own
-- (SettingsExpandableSectionTemplate), and so are a row's (KeyBindingFrameBindingTemplate): its height,
-- how far in its text starts, the text's room, and the key button's size. The key button itself is the
-- game's (KeyBindingFrameBindingButtonTemplate).
local BANNER = { left = "Options_ListExpand_Left", middle = "_Options_ListExpand_Middle",
    shut = "Options_ListExpand_Right", open = "Options_ListExpand_Right_Expanded" }
local BANNER_H, BANNER_IN, BANNER_UP, BANNER_ICON = 30, 21, 2, 18
local ROW_H, ROW_IN, ROW_TOP, LABEL_W, KEY_W, KEY_H, ROW_ICON, FOOT = 25, 37, 6, 170, 160, 22, 18, 1
local KEY_BUTTON = "KeyBindingFrameBindingButtonTemplate"
-- the line under the words over the list that says what key is waited for: one line high always
local WAIT_H = 14
-- how much the picked icon grows, as a held one does
local GROW = 1.25
local TEXT = {
    keysHead = "Flyout keys",
    keysNote = "Every flyout picks its icons with the keys of their spots: set those under Default flyout binds. A "
        .. "flyout's own bar gives an icon a key of its own in that flyout. Click a key and press the new one; "
        .. "right-click gives the usual one back.",
    -- the spots of every flyout, above each flyout's own. His words (2026-11-24): "why call it every flyout.
    -- why not \"Default flyout binds\""
    every = "Default flyout binds",
    spot = "Spot %d",
    spotTip = "Click, then press the key that picks this spot of every open flyout. Right-click gives it its "
        .. "usual key, %s.",
    spotWait = "Press a key for spot %d of every flyout. Escape leaves it as it is.",
    keysWait = "Press a key for %s. Escape leaves it as it is.",
    keysNone = "No flyout is on the bars.",
    keyPress = "Press a key",
    keyTip = "Click, then press the key that picks this icon while its flyout is open. Right-click gives it "
        .. "its spot's key back.",
    keyOwn = "This is the icon's own key in this flyout.",
    keySpot = "This is the key of its spot, the same in every flyout.",
    general = "General",
    -- the Controller page: its name in the game's list, and its first words, for nobody to take it for the
    -- way a flyout is made
    pad = "Controller",
    live = "Only for playing with a controller, in the game's gamepad mode. With a mouse and keyboard none of "
        .. "this page is needed: drag a spell, item, toy, mount or macro onto a bar button, where the + appears, "
        .. "and it becomes a flyout.",
    padHead = "Gamepad mode",
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
    twice = "Press a flyout's key again for the last one used",
    -- His words (2026-11-24), of a flyout on 1: "the tooltip/warning doesn't say what that behavior will be at
    -- all". A key that is one of the flyout's icon keys stays that icon's (BIND in Core/Flyouts.lua).
    twiceTip = "With a flyout open, pressing its key again casts the icon you picked from it last, and shuts "
        .. "it. If its key is also one of its icon keys (a flyout on 1, say), that key still picks its own icon: "
        .. "1 then 1 casts the first icon.",
    -- what the setting costs, in red in its tooltip and in the question before it is turned on
    twiceWarn = "Its key no longer shuts an open flyout: Escape (B on a controller) or a click on its bar "
        .. "button does.",
    twiceAsk = "%s\n\n%s\n\n|cffff2020%s|r",
    twiceOn = "Turn On",
    last = "Show the last one used on its button",
    lastTip = "A flyout's bar button shows the icon you picked from it last, with its cooldown and tooltip, until "
        .. "you pick another.",
    hints = "Show hints in tooltips",
    hintsTip = "A gray line at the foot of a flyout's tooltips says what a click or a button does there: a "
        .. "right-click on its bar button to change what the button shows and its name, a drag to move an "
        .. "icon. For every character on this account.",
    iconName = "Icon and Name",
    iconNameTip = "Opens the window that changes what this flyout's bar button shows (its icon, tooltip and "
        .. "cooldown) and its name, as a right-click on the button does, or RB in Edit Flyout.",
    plate = "Round background behind it",
    plateTip = "A flyout that opens around its button has a round plate behind it, so an open flyout is "
        .. "seen at a glance.",
    faces = "New flyouts pick with",
    facesTip = "On a controller, which of the pad's crosses picks the icons of a flyout made from now on. "
        .. "The other cross from its button: a flyout on a face button picks with the D-pad, and one on the "
        .. "D-pad with the face buttons; one on any other button picks with the D-pad. Flyouts made before "
        .. "keep how they pick. Any flyout can be swapped as it is made in gamepad mode, or in Edit Flyout.",
    cross = { opposite = "The other cross from its button", dpad = "The D-pad", face = "The face buttons",
        same = "The same cross as its button" },
}
A.TEXT = TEXT

-- the addon's page and the Controller page, and the part of each that scrolls: what is built hangs on that
local panel, holder, padPage, padHolder
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

-- which flyouts' banners are open: by the flyout, for as long as it is one; EVERY for the spots of every
-- flyout
local opened = setmetatable({}, { __mode = "k" })
local EVERY = {}
opened[EVERY] = nil
local Banner, Row
-- the addon's own picture, on the banner of every flyout's spots
local ADDON_ICON = "Interface\\AddOns\\FallensFlyouts\\media\\icon"

-- a flyout's own picture and name: those it was given, else its button's ability's
local function Face(flyout)
    local lead = flyout.main or flyout.entries[1]
    return flyout.icon or (lead and F.Icon(lead)) or nil, flyout.name or (lead and F.Name(lead)) or ""
end

-- The keys section: a banner for each flyout on the bars, and under an open one a row for each icon.
-- Each stands under the one before it, so the list is as long as it has to be.
function A.KeysRefresh()
    local w = panel and panel.arrange
    if not (w and w.banners) then return end
    local waiting = ns.Keys and ns.Keys.Waiting()
    local list = Flyouts()
    local last, drop = w.keysWait, -GAP
    local function Under(frame, down)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, down)
        frame:SetPoint("RIGHT", holder, "RIGHT", -EDGE, 0)
        frame:Show()
        last = frame
    end
    -- First the keys of every flyout's spots, the same rows as the game's key menu has, so that every key is
    -- here in one place.
    -- His words (2026-11-24): "we need to provide ability to change the default flyout keybinds in our settings
    -- menu next to the specific flyout ones too (above them) so ppl can access everything in one place. while we
    -- can't do that in the keybindings menu itself due to limitations, we can at least put a message there (if
    -- there isn't already) that ... they should view our \"/ff\" settings to see full keybinding
    -- functionality", and "maybe dont mention api. no one using it will know what that means".
    local every = w.every
    if not every then
        every = Banner()
        every.every = true
        w.every = every
    end
    every.icon:SetTexture(ADDON_ICON)
    every.text:SetText(TEXT.every)
    local all = opened[EVERY] == true
    every.open = all
    every.right:SetAtlas(all and BANNER.open or BANNER.shut, true)
    Under(every, drop)
    drop = -GAP / 2
    for i = 1, F.MAX do
        local row = every.rows[i]
        if all then
            row = row or Row(every, i)
            every.rows[i] = row
            row.icon:SetTexture(nil)
            row.label:SetText(TEXT.spot:format(i))
            local key, pad = Binds.Pick(i)
            local listening = waiting ~= nil and waiting.spot == true and waiting.i == i
            row.key:SetText(listening and TEXT.keyPress or KeyName(key or F.KEYS[i], pad or F.PADS[i]))
            row.key.tip = TEXT.spotTip:format(KeyName(F.KEYS[i], F.PADS[i]))
            row.key.waiting = listening
            if row.key.SetSelected then row.key:SetSelected(listening) end
            Under(row, i == 1 and -ROW_TOP or 0)
        elseif row then
            row:Hide()
        end
    end
    for n, flyout in ipairs(list) do
        local banner = w.banners[n] or Banner()
        w.banners[n] = banner
        banner.flyout = flyout
        local icon, name = Face(flyout)
        banner.icon:SetTexture(icon)
        banner.text:SetText(name)
        local open = opened[flyout] == true
        banner.open = open
        banner.right:SetAtlas(open and BANNER.open or BANNER.shut, true)
        Under(banner, drop)
        drop = -GAP / 2
        for i = 1, F.MAX do
            local row = banner.rows[i]
            local entry = open and flyout.entries[i] or nil
            if entry then
                row = row or Row(banner, i)
                banner.rows[i] = row
                row.icon:SetTexture(F.Icon(entry))
                row.label:SetText(F.Name(entry))
                local key, pad, own = F.Picked(flyout, i)
                local listening = waiting ~= nil and waiting.flyout == flyout and waiting.i == i
                row.key:SetText(listening and TEXT.keyPress or KeyName(key, pad))
                row.key.tip = TEXT.keyTip .. "\n" .. (own and TEXT.keyOwn or TEXT.keySpot)
                -- lit as the game lights a key it is waiting to be given
                row.key.waiting = listening
                if row.key.SetSelected then row.key:SetSelected(listening) end
                Under(row, i == 1 and -ROW_TOP or 0)
            elseif row then
                row:Hide()
            end
        end
    end
    for n = #list + 1, #w.banners do
        local banner = w.banners[n]
        banner.flyout = nil
        banner:Hide()
        for _, row in pairs(banner.rows) do row:Hide() end
    end
    -- The words over the list stay as they are while a key is waited for; what is waited for is said on a
    -- line of its own under them, as high when empty as when not, so that nothing under it moves. Words of
    -- another length in their place moved the very rows being set. His words (2026-11-23): "can you stop
    -- hiding the \"The game's Keybindings options set a key for ....\" message when i click a bind to set
    -- in the settings? it's moving the page around and is a pain in the ass", and "you can just have the
    -- 2nd message show underneath or something idk... but you're moving the region i'm keybinding".
    w.keysNote:SetText(#list == 0 and TEXT.keysNone or TEXT.keysNote)
    local says = ""
    if waiting and waiting.spot then
        says = TEXT.spotWait:format(waiting.i)
    elseif waiting and waiting.flyout and waiting.flyout.entries[waiting.i] then
        says = TEXT.keysWait:format(F.Name(waiting.flyout.entries[waiting.i]))
    end
    w.keysWait:SetText(says)
    -- what stands under the list hangs on its last line
    w.foot:ClearAllPoints()
    w.foot:SetPoint("TOPLEFT", last, "BOTTOMLEFT")
end

-- a press on a flyout's banner opens or shuts its rows
function A.KeysToggle(flyout)
    if not flyout then return end
    local K = ns.Keys
    local was = K and K.Waiting()
    if was and (was.flyout == flyout or (flyout == EVERY and was.spot)) then K.Stop() end
    opened[flyout] = not opened[flyout] or nil
    A.Refresh()
end
function A.KeysOpen(flyout) return opened[flyout == "every" and EVERY or flyout] == true end

function A.Refresh()
    local w = panel and panel.arrange
    if w then
        A.KeysRefresh()
        w.ranks:SetChecked(F.Ranked())
        w.hide:SetChecked(F.Hiding())
        w.twice:SetChecked(F.Twice())
        w.last:SetChecked(F.ShowLast())
        w.hints:SetChecked(ns.Profiles.Hints())
    end
    local p = padPage and padPage.arrange
    if p then
        local flyout, count = Current()
        if flyout and held and not flyout.entries[held] then held = nil end
        if not flyout then held = nil end
        p.which:SetText(flyout and TEXT.which:format(at, count, F.Name(flyout.main)) or TEXT.none)
        p.prev:SetEnabled(count > 1)
        p.next:SetEnabled(count > 1)
        p.turn:SetEnabled(flyout ~= nil and F.UnitOf(flyout) ~= nil)
        p.off:SetEnabled(held ~= nil)
        p.icon:SetEnabled(flyout ~= nil)
        p.around:SetChecked(F.Around())
        p.faces:GenerateMenu()
        p.plate:SetChecked(F.Plate())
        for i, button in ipairs(p.icons) do
            local entry = flyout and flyout.entries[i]
            button:SetShown(entry ~= nil)
            if entry then button.icon:SetTexture(F.Icon(entry)) end
            -- the picked one grows and keeps its ring
            button:SetScale(held == i and GROW or 1)
            button.ring:SetShown(held == i)
        end
        local picked = held and flyout and F.Name(flyout.entries[held])
        p.status:SetText(picked and TEXT.held:format(picked) or TEXT.note)
    end
    if w and ns.ProfileUI and ns.ProfileUI.Fit then ns.ProfileUI.Fit() end
    if p and ns.ControllerUI then ns.ControllerUI.Fit() end
end

-- A click on the key of icon i of a flyout: the left button waits for the key it is to have, or stops
-- waiting; the right button gives the icon its spot's key back. `key`: the button clicked.
function A.Key(flyout, i, button, key)
    local K = ns.Keys
    if not (flyout and flyout.entries[i] and K) then return end
    local was = K.Waiting()
    K.Stop()
    if button == "RightButton" then
        F.SetKey(flyout, i, nil, true)
        local ok, why = F.SetKey(flyout, i, nil, false)
        if not ok and why then ns.Warn(why) end
    elseif not (was and was.flyout == flyout and was.i == i) then
        local ok, why = K.Listen(flyout, i, holder, A.Refresh, key)
        if not ok and why then ns.Warn(why) end
    end
    A.Refresh()
end

-- A click on the key of spot i of every flyout: the left button waits for the key it is to have, or stops
-- waiting; the right button gives it its usual key back.
function A.SpotKey(i, button, key)
    local K = ns.Keys
    if not K then return end
    local was = K.Waiting()
    K.Stop()
    if button == "RightButton" then
        local ok, why = Binds.SetPick(i, nil, nil)
        if not ok and why then ns.Warn(why) end
    elseif not (was and was.spot and was.i == i) then
        local ok, why = K.ListenSpot(i, holder, A.Refresh, key)
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

-- the game's red for a warning
local WARN_R, WARN_G, WARN_B = 1, 0.125, 0.125
local function ShowTip(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    if self.warn then GameTooltip:AddLine(self.warn, WARN_R, WARN_G, WARN_B, true) end
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- the Controller page's buttons
local function Button(label, tip, run)
    local button = CreateFrame("Button", nil, padHolder, "UIPanelButtonTemplate")
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
    local button = CreateFrame("Button", nil, padHolder)
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

-- a flyout's banner: the game's own section art, with the flyout's picture before its name
function Banner()
    local banner = CreateFrame("Button", nil, holder)
    banner:Hide()
    banner:SetHeight(BANNER_H)
    banner.left = banner:CreateTexture(nil, "BACKGROUND")
    banner.left:SetAtlas(BANNER.left, true)
    banner.left:SetPoint("TOPLEFT")
    banner.right = banner:CreateTexture(nil, "BACKGROUND")
    banner.right:SetAtlas(BANNER.shut, true)
    banner.right:SetPoint("TOPRIGHT")
    banner.middle = banner:CreateTexture(nil, "BACKGROUND")
    banner.middle:SetAtlas(BANNER.middle, true)
    banner.middle:SetPoint("TOPLEFT", banner.left, "TOPRIGHT")
    banner.middle:SetPoint("TOPRIGHT", banner.right, "TOPLEFT")
    banner.icon = banner:CreateTexture(nil, "ARTWORK")
    banner.icon:SetSize(BANNER_ICON, BANNER_ICON)
    banner.icon:SetPoint("LEFT", BANNER_IN, BANNER_UP)
    banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    banner.text:SetPoint("LEFT", banner.icon, "RIGHT", GAP, 0)
    banner.text:SetJustifyH("LEFT")
    banner.rows = {}
    banner:SetScript("OnClick", function(self) A.KeysToggle(self.every and EVERY or self.flyout) end)
    return banner
end

-- a row under a banner: an icon's picture and name, and its key as the game's own key button
function Row(banner, i)
    local row = CreateFrame("Frame", nil, holder)
    row:Hide()
    row:SetHeight(ROW_H)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_ICON, ROW_ICON)
    row.icon:SetPoint("LEFT", ROW_IN, 0)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", GAP, 0)
    row.label:SetWidth(LABEL_W)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    -- the game's key button; a client without it gets the game's plain button
    local made, key = pcall(CreateFrame, "Button", nil, row, KEY_BUTTON)
    if not made then key = CreateFrame("Button", nil, row, "UIPanelButtonTemplate") end
    row.key = key
    key:SetSize(KEY_W, KEY_H)
    key:SetPoint("LEFT", row.label, "RIGHT", GAP, 0)
    key:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    key:SetScript("OnClick", function(self, button)
        if banner.every then return A.SpotKey(i, button, self) end
        A.Key(banner.flyout, i, button, self)
    end)
    key:SetScript("OnEnter", ShowTip)
    key:SetScript("OnLeave", HideTip)
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

-- the hints at the foot of the addon's tooltips, for the whole account
function A.Hints(on)
    ns.Profiles.SetHints(on)
    A.Refresh()
end

-- the icon and name window for the flyout shown on the Controller page
function A.IconName()
    local flyout = Current()
    if flyout and ns.Icon then ns.Icon.Open(flyout) end
end

-- a flyout's key pressed again while it is open casts the icon picked last from it, or only shuts it
function A.Twice(on)
    local ok, why = F.SetTwice(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

-- Ticked on, it asks first, saying in red what it costs: the key that opened a flyout no longer shuts it.
-- His words (2026-11-24): "with the double click to cast last setting, i just realized that goes against
-- the flow of the key toggling the flyout in the first place. so i think we need a popup warning in red
-- text, and tooltip for it in red text, that lets the user know they will no longer be able to close the
-- flyout with the same key immediately after opening it, and that they'll have to use esc or whatever
-- instead."
-- The game's own question, once per tick; turned off, it is off at once.
StaticPopupDialogs.FALLENSFLYOUTS_TWICE = {
    text = "%s",
    button1 = TEXT.twiceOn,
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnAccept = function() A.Twice(true) end,
    -- the box shows it is still off
    OnCancel = function() A.Refresh() end,
}
function A.AskTwice(on)
    if on and not F.Twice() and not InCombatLockdown() then
        A.Refresh()
        return StaticPopup_Show("FALLENSFLYOUTS_TWICE", TEXT.twiceAsk:format(TEXT.twice, TEXT.twiceTip,
            TEXT.twiceWarn))
    end
    A.Twice(on)
end

-- the controller's two: flyouts around the button in gamepad mode, and which of its crosses picks first
function A.Around(on)
    local ok, why = F.SetAround(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end
-- the four ways a new flyout's cross is chosen, as the drop down lists them
function A.Cross(cross)
    local ok, why = F.SetCross(cross)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end
function A.FillCross(_, root)
    local function IsOn(cross) return F.Cross() == cross end
    for _, cross in ipairs({ "opposite", "dpad", "face", "same" }) do
        root:CreateRadio(TEXT.cross[cross], IsOn, A.Cross, cross)
    end
end
function A.Plate(on)
    local ok, why = F.SetPlate(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

-- A player's ask, passed on by him (2026-11-25): "someone requested the flyout icon to change to be whatever
-- the last-casted spell from the flyout is."
function A.Last(on)
    local ok, why = F.SetShowLast(on)
    if not ok and why then ns.Warn(why) end
    A.Refresh()
end

-- the game's own check box, after another on its line or under one, with its words and its tip
local function Check(parent, text, tip, run, after, under)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
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

-- a heading as the page's others, `down` under what is above it
local function Head(parent, text, above, down)
    local head = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, down)
    head:SetText(text)
    return head
end

-- a flyout changed elsewhere shows here at once, on whichever page is up
local watching = false
local function Watch()
    if watching then return end
    watching = true
    F.Watch(function(what)
        if what == "laid" and ((panel and panel:IsVisible()) or (padPage and padPage:IsVisible())) then A.Refresh() end
    end)
end

-- On the addon's page, under the size: General, the settings for every flyout, then the keys of each flyout.
function A.Build(page, above, scrolled)
    if page.arrange then return end
    panel, holder = page, scrolled or page
    local w = {}
    local general = Head(holder, TEXT.general, above, -GAP * 3)
    local ranksLabel
    w.ranks, ranksLabel = Check(holder, TEXT.ranks, TEXT.ranksTip, A.Ranks, nil, general)
    w.ranks:ClearAllPoints()
    w.ranks:SetPoint("TOPLEFT", general, "BOTTOMLEFT", 0, -GAP)
    w.hide = Check(holder, TEXT.hide, TEXT.hideTip, A.Hide, ranksLabel)
    local twiceLabel
    w.twice, twiceLabel = Check(holder, TEXT.twice, TEXT.twiceTip, A.AskTwice, nil, w.ranks)
    w.twice.warn = TEXT.twiceWarn
    w.hints = Check(holder, TEXT.hints, TEXT.hintsTip, A.Hints, twiceLabel)
    w.last = Check(holder, TEXT.last, TEXT.lastTip, A.Last, nil, w.twice)
    local keysHead = Head(holder, TEXT.keysHead, w.last, -GAP * 3)
    w.keysNote = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w.keysNote:SetPoint("TOPLEFT", keysHead, "BOTTOMLEFT", 0, -GAP)
    w.keysNote:SetPoint("RIGHT", holder, "RIGHT", -EDGE, 0)
    w.keysNote:SetJustifyH("LEFT")
    w.keysNote:SetText(TEXT.keysNote)
    w.keysWait = holder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    w.keysWait:SetPoint("TOPLEFT", w.keysNote, "BOTTOMLEFT", 0, -GAP)
    w.keysWait:SetPoint("RIGHT", holder, "RIGHT", -EDGE, 0)
    w.keysWait:SetHeight(WAIT_H)
    w.keysWait:SetJustifyH("LEFT")
    w.keysWait:SetWordWrap(false)
    -- a banner for each flyout, made as there are flyouts (A.KeysRefresh); the page ends under its last line
    w.banners = {}
    w.foot = CreateFrame("Frame", nil, holder)
    w.foot:SetSize(FOOT, FOOT)
    w.foot:SetPoint("TOPLEFT", w.keysWait, "BOTTOMLEFT")
    -- the page put away ends a wait for a key
    holder:HookScript("OnHide", function() if ns.Keys then ns.Keys.Stop() end end)
    panel.arrange = w
    Watch()
    A.Refresh()
end

-- The Controller page: what it is for, first; the settings of gamepad mode; then arranging a flyout
-- without a drag.
function A.BuildPad(page, scrolled)
    if page.arrange then return end
    padPage, padHolder = page, scrolled or page
    local p = {}
    local title = padHolder:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", padHolder, "TOPLEFT", EDGE, -EDGE)
    title:SetText(TEXT.pad)
    -- as wide as the page, on as many lines as it takes
    p.live = padHolder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p.live:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -GAP)
    p.live:SetPoint("RIGHT", padHolder, "RIGHT", -EDGE, 0)
    p.live:SetJustifyH("LEFT")
    p.live:SetText(TEXT.live)
    local padHead = Head(padHolder, TEXT.padHead, p.live, -GAP * 3)
    p.around = Check(padHolder, TEXT.around, TEXT.aroundTip, A.Around, nil, padHead)
    p.around:ClearAllPoints()
    p.around:SetPoint("TOPLEFT", padHead, "BOTTOMLEFT", 0, -GAP)
    p.plate = Check(padHolder, TEXT.plate, TEXT.plateTip, A.Plate, nil, p.around)
    -- which cross picks the icons of a flyout made from now on: the game's drop down, its words over it
    local crossLabel = padHolder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    crossLabel:SetPoint("TOPLEFT", p.plate, "BOTTOMLEFT", 0, -GAP)
    crossLabel:SetText(TEXT.faces)
    p.faces = CreateFrame("DropdownButton", nil, padHolder, "WowStyle1DropdownTemplate")
    p.faces:SetPoint("TOPLEFT", crossLabel, "BOTTOMLEFT", 0, -GAP / 2)
    p.faces:SetWidth(260)
    p.faces.tip = TEXT.facesTip
    p.faces:HookScript("OnEnter", ShowTip)
    p.faces:HookScript("OnLeave", HideTip)
    p.faces:SetupMenu(A.FillCross)
    local head = Head(padHolder, TEXT.head, p.faces, -GAP * 3)
    p.status = padHolder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p.status:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    p.status:SetJustifyH("LEFT")
    p.prev = Button(TEXT.prev, TEXT.prevTip, function() A.Step(-1) end)
    p.prev:SetPoint("TOPLEFT", p.status, "BOTTOMLEFT", 0, -GAP * 2)
    p.next = Button(TEXT.next, TEXT.nextTip, function() A.Step(1) end)
    p.next:SetPoint("LEFT", p.prev, "RIGHT", GAP / 2, 0)
    -- for those with no mouse to pull a flyout's grip
    p.turn = Button(TEXT.turn, TEXT.turnTip, A.Turn)
    p.turn:SetPoint("LEFT", p.next, "RIGHT", GAP / 2, 0)
    p.which = padHolder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    p.which:SetPoint("LEFT", p.turn, "RIGHT", GAP, 0)
    p.icons = {}
    for i = 1, F.MAX do
        local button = Icon(i)
        if i == 1 then
            button:SetPoint("TOPLEFT", p.prev, "BOTTOMLEFT", GAP / 2, -GAP * 2)
        else
            button:SetPoint("LEFT", p.icons[i - 1], "RIGHT", Art.NEXT * 2, 0)
        end
        p.icons[i] = button
    end
    p.off = Button(TEXT.off, TEXT.offTip, A.TakeOff)
    p.off:SetPoint("TOPLEFT", p.icons[1], "BOTTOMLEFT", -GAP / 2, -GAP * 2)
    -- the icon and name window for the flyout shown here, as a right-click on its bar button opens it
    p.icon = Button(TEXT.iconName, TEXT.iconNameTip, A.IconName)
    p.icon:SetPoint("LEFT", p.off, "RIGHT", GAP / 2, 0)
    padPage.arrange = p
    Watch()
    A.Refresh()
end

-- The Controller page, under the addon's own in the game's options beside Automatic Flyouts: what only a
-- controller needs, said so in its name and in its first words (A.BuildPad). Listed by Options/Auto.lua,
-- right after its own page, so that it stands after Automatic Flyouts.
do
    local UI = {}
    ns.ControllerUI = UI
    local page = CreateFrame("Frame")
    page:Hide()
    page.name = TEXT.pad
    UI.panel = page

    function UI.Build()
        if page.built then return end
        ns.Start()
        A.BuildPad(page, ns.OptionsScroller(page))
        page.built = true
    end

    -- it scrolls as far as its lowest control
    function UI.Fit()
        if page.built then ns.OptionsFit(page, page.arrange and page.arrange.off) end
    end

    function UI.Register()
        if Settings and Settings.RegisterCanvasLayoutSubcategory and ns.OptionsCategory then
            Settings.RegisterCanvasLayoutSubcategory(ns.OptionsCategory, page, TEXT.pad)
        end
    end

    page:SetScript("OnShow", function()
        UI.Build()
        A.Refresh()
        -- measured once the game has placed the page in its window
        C_Timer.After(0, UI.Fit)
        if ns.OptionsPageShown then ns.OptionsPageShown(page) end
    end)
    page:SetScript("OnHide", function()
        if ns.OptionsPageHidden then ns.OptionsPageHidden() end
    end)
end
