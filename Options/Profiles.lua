local _, ns = ...
-- luacheck: globals SLASH_FALLENSFLYOUTS1 SLASH_FALLENSFLYOUTS2 SlashCmdList StaticPopupDialogs
-- luacheck: globals FallensFlyouts_OnAddonCompartmentClick
-- luacheck: read globals CreateFrame Settings MenuUtil StaticPopup_Show InCombatLockdown C_Timer
-- luacheck: read globals OKAY CANCEL YES NO GameTooltip SettingsPanel SmartNavigation
-- luacheck: read globals SmartNavigation_MarkFrameIgnored SmartNavigation_ClearIgnoreStatus ScrollUtil
-- luacheck: read globals GetBuildInfo GetLocale GetPhysicalScreenSize UnitClass UnitLevel C_GamePad C_AddOns
-- luacheck: read globals date UIParent
-- luacheck: read globals MinimalSliderWithSteppersMixin CreateMinimalSliderFormatter

-- The Profiles page in the game's options; /ff and /flyouts open it.
local P = ns.Profiles
local UI = {}
ns.ProfileUI = UI

local TITLE = "Fallen's Flyouts"
local EDGE, GAP, LINE = 16, 8, 22
-- the scroll bar: the room kept for it at the page's right, how far it stands from what scrolls and
-- from the page's top and bottom; and how far a turn of the wheel goes where the game's bar is missing
local BAR_ROOM, BAR_GAP, BAR_INSET, WHEEL = 24, 8, 4, 30
-- floors: each grows to the text it holds
local DROP_FLOOR, BUTTON_FLOOR, CHROME = 200, 70, 40

local TEXT = {
    head = "Profiles",
    intro = "A profile is a set of flyouts. Each character uses one.",
    own = "%s (this character)",
    class = "%s (this class)",
    all = "%s (every character)",
    onlyMe = "Only this character uses it.",
    users = "Used by %s.",
    askNew = "Name the new profile. It starts empty.",
    askCopy = "Name the new profile. It starts as a copy of this one.",
    askRename = "A new name for the profile %s.",
    askDelete = "Delete the profile %s? Characters on it go back to their own.",
    askReset = "Remove every flyout from the profile %s?",
    askCopyFrom = "Replace the flyouts of %s with those of %s?",
    noOthers = "There is no other profile to copy from.",
    fight = "The options open out of a fight.",
    sizeHead = "Size and background",
    size = "Flyout size",
    sizeNote = "100% is the size of the game's own flyouts.",
    match = "Match Base Icon Size",
    matchTip = "Makes a flyout's icons as large as the icon of the bar button it opens from.",
    back = "Show the flyout background",
    backTip = "The game's flyout background behind the icons, and the round one behind a flyout that opens "
        .. "around its button. Off, the icons stand on their own.",
    alpha = "Background opacity",
    percent = "%d%%",
}
-- His words (2026-11-24): "bro what is this \"smaller, larger\" lmao. just throwing away ui principles? why
-- not just follow the api's scroll anyway?" with a snip of the game's own stepper slider, and "i feel like
-- we should have a button for \"match base icon size\" (which does what you would think) and maybe a box
-- nearby to toggle whether the flyout background is shown at all, and an opacity for the flyout
-- background."
-- The sliders are the game's own with a stepper at each end (MinimalSliderWithSteppersTemplate, as its
-- options have them): their ends and step in percent, the room for a row's name, and a slider's width.
local SIZE_LOW, SIZE_HIGH, SIZE_STEP = 50, 200, 5
local ALPHA_LOW, ALPHA_HIGH, ALPHA_STEP = 0, 100, 5
local NAME_W, SLIDER_W = 170, 250

local panel, category

local Warn = ns.Warn

-- a name popup's box, under whichever name this client gives it
local function Box(dialog)
    if dialog.GetEditBox then return dialog:GetEditBox() end
    local name = dialog.GetName and dialog:GetName()
    return dialog.EditBox or dialog.editBox or (name and _G[name .. "EditBox"])
end

-- a refused name keeps the box open
local function Named(dialog, data)
    local box = Box(dialog)
    local name, why = data.run(box and box:GetText())
    if name then return false end
    Warn(why)
    return true
end

StaticPopupDialogs.FALLENSFLYOUTS_NAME = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 32,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnShow = function(self, data)
        local box = Box(self)
        if not box then return end
        box:SetText(data and data.start or "")
        box:HighlightText()
    end,
    OnAccept = Named,
    EditBoxOnEnterPressed = function(self, data)
        local dialog = self:GetParent()
        if not Named(dialog, data) then dialog:Hide() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

StaticPopupDialogs.FALLENSFLYOUTS_CONFIRM = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnAccept = function(_, data)
        local ok, why = data()
        if ok == false then Warn(why) end
    end,
}

local function AskName(text, start, run)
    StaticPopup_Show("FALLENSFLYOUTS_NAME", text, nil, { start = start, run = run })
end

local function Confirm(text, run)
    StaticPopup_Show("FALLENSFLYOUTS_CONFIRM", text, nil, run)
end

function UI.Label(entry)
    if entry.kind == "own" then return TEXT.own:format(entry.name) end
    if entry.kind == "class" then return TEXT.class:format(entry.name) end
    if entry.kind == "all" then return TEXT.all:format(entry.name) end
    return entry.name
end

local function IsOn(name) return name == P.Active() end

function UI.Pick(name)
    local ok, why = P.Use(name)
    if not ok then Warn(why) end
end

-- the rows: every character's three, then the rest
function UI.Fill(_, root)
    for _, entry in ipairs(P.Names()) do
        root:CreateRadio(UI.Label(entry), IsOn, UI.Pick, entry.name)
    end
end

-- every made profile but the one in use
local function Others()
    local out = {}
    for _, entry in ipairs(P.Names()) do
        if entry.made and entry.name ~= P.Active() then out[#out + 1] = entry end
    end
    return out
end

local function CopyFromMenu(owner)
    local others = Others()
    if #others == 0 then return Warn(TEXT.noOthers) end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, entry in ipairs(others) do
            root:CreateButton(UI.Label(entry), function()
                Confirm(TEXT.askCopyFrom:format(P.Active(), entry.name), function() return P.CopyFrom(entry.name) end)
            end)
        end
    end)
end

local BUTTONS = {
    { key = "new", label = "New", tip = "A new, empty profile for this character.",
        run = function() AskName(TEXT.askNew, "", function(text) return P.New(text, false) end) end },
    { key = "copy", label = "Copy", tip = "A new profile that starts as a copy of this one.",
        run = function() AskName(TEXT.askCopy, "", function(text) return P.New(text, true) end) end },
    { key = "from", label = "Copy From", tip = "Replaces this profile's flyouts with another profile's.",
        run = CopyFromMenu },
    { key = "rename", label = "Rename", tip = "Renames the profile in use.",
        run = function()
            local old = P.Active()
            AskName(TEXT.askRename:format(old), old, function(text) return P.Rename(old, text) end)
        end },
    { key = "delete", label = "Delete", tip = "Deletes the profile in use.",
        run = function()
            local old = P.Active()
            Confirm(TEXT.askDelete:format(old), function() return P.Delete(old) end)
        end },
    { key = "reset", label = "Reset", tip = "Removes every flyout from the profile in use.",
        run = function() Confirm(TEXT.askReset:format(P.Active()), function() return P.Reset() end) end },
}

local function ShowTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.label)
    GameTooltip:AddLine(self.tip, 1, 1, 1, true)
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

-- wide enough for the longest row
local function DropWidth()
    local widest = 0
    for _, entry in ipairs(P.Names()) do
        panel.measure:SetText(UI.Label(entry))
        widest = math.max(widest, panel.measure:GetStringWidth() or 0)
    end
    return math.max(DROP_FLOOR, widest + CHROME)
end

function UI.Refresh()
    if not (panel and panel.built) then return end
    local active = P.Active()
    panel.dropdown:SetWidth(DropWidth())
    panel.dropdown:GenerateMenu()
    local users = P.Users(active)
    if #users > 1 then
        panel.users:SetText(TEXT.users:format(table.concat(users, ", ")))
    else
        panel.users:SetText(TEXT.onlyMe)
    end
    panel.rename:SetEnabled(P.Kind(active) == nil)
    panel.delete:SetEnabled(active ~= P.Own())
    -- the size and the background belong to the profile in use
    local F = ns.Flyouts
    local percent = math.floor(F.Size() * 100 + 0.5)
    panel.syncing = true
    panel.slider:SetValue(percent)
    panel.opacity:SetValue(math.floor(F.BackAlpha() * 100 + 0.5))
    panel.syncing = nil
    panel.back:SetChecked(F.Back())
    panel.opacity:SetEnabled(F.Back())
    ns.Arrange.Refresh()
    UI.Fit()
end

-- What a page holds is as tall as it is, down to its lowest control: the scroll goes that far.
local function Fit(page, last)
    local content = page.content
    if not (content and last) then return end
    local top, bottom = content:GetTop(), last:GetBottom()
    if not (top and bottom) then return end
    content:SetHeight(math.max(1, top - bottom + EDGE))
    if page.scroll.UpdateScrollChildRect then page.scroll:UpdateScrollChildRect() end
end
ns.OptionsFit = Fit
function UI.Fit() Fit(panel, panel.arrange and panel.arrange.foot) end

-- A page scrolls inside the game's window (this one, and any other of the addon's): what it holds can
-- be taller than the window, and nothing of it is drawn outside. The game's own slim scroll bar, there
-- only when there is somewhere to scroll to; a controller's cursor scrolls the frame by itself.
local function Scroller(page)
    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -BAR_ROOM, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(math.max(1, scroll:GetWidth() or 1), 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width or 1)) end)
    if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
        local bar = CreateFrame("EventFrame", nil, page, "MinimalScrollBar")
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", BAR_GAP, -BAR_INSET)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", BAR_GAP, BAR_INSET)
        ScrollUtil.InitScrollFrameWithScrollBar(scroll, bar)
        bar:SetHideIfUnscrollable(true)
        page.bar = bar
    else
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, turn)
            local to = self:GetVerticalScroll() - turn * WHEEL
            self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), to)))
        end)
    end
    page.scroll, page.content = scroll, content
    return content
end
ns.OptionsScroller = Scroller

-- a size from the slider or its two buttons, in percent
function UI.SetSize(percent)
    if panel.syncing then return end
    percent = math.max(SIZE_LOW, math.min(SIZE_HIGH, math.floor(percent / SIZE_STEP + 0.5) * SIZE_STEP))
    local ok, why = ns.Flyouts.SetSize(percent / 100)
    if not ok then Warn(why) end
    UI.Refresh()
end

-- the background's opacity from its slider, in percent
function UI.SetOpacity(percent)
    if panel.syncing then return end
    percent = math.max(ALPHA_LOW, math.min(ALPHA_HIGH, math.floor(percent / ALPHA_STEP + 0.5) * ALPHA_STEP))
    local ok, why = ns.Flyouts.SetBackAlpha(percent / 100)
    if not ok then Warn(why) end
    UI.Refresh()
end

-- the background shown or not, from its check box
function UI.SetBack(on)
    local ok, why = ns.Flyouts.SetBack(on)
    if not ok then Warn(why) end
    UI.Refresh()
end

-- The game's slider with its steppers, its value in percent at its right; `run` is told each value it is
-- moved to. A row: its name, then the slider.
local function Slider(content, name, low, high, step, run)
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetText(name)
    local slider = CreateFrame("Frame", nil, content, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(SLIDER_W)
    slider:SetPoint("LEFT", label, "LEFT", NAME_W, 0)
    local right = MinimalSliderWithSteppersMixin.Label.Right
    slider:Init(low, low, high, (high - low) / step, {
        [right] = CreateMinimalSliderFormatter(right, function(value) return TEXT.percent:format(value) end),
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value) run(value) end,
        slider)
    slider.label = label
    return slider, label
end

function UI.Build()
    if panel.built then return end
    ns.Start()
    -- everything the page holds hangs on this, and scrolls with it
    local content = Scroller(panel)
    local head = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", content, "TOPLEFT", EDGE, -EDGE)
    head:SetText(TEXT.head)
    local intro = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intro:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
    intro:SetText(TEXT.intro)
    panel.measure = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.measure:Hide()

    local dropdown = CreateFrame("DropdownButton", nil, content, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -GAP * 2)
    dropdown:SetWidth(DropWidth())
    dropdown:SetupMenu(UI.Fill)
    panel.dropdown = dropdown

    local users = content:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    users:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -GAP)
    users:SetJustifyH("LEFT")
    panel.users = users

    local function Make(spec)
        local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        button:SetText(spec.label)
        button:SetSize(math.max(BUTTON_FLOOR, (button:GetTextWidth() or 0) + CHROME / 2), LINE)
        button.label, button.tip = spec.label, spec.tip
        button:SetScript("OnClick", spec.run)
        button:SetScript("OnEnter", ShowTip)
        button:SetScript("OnLeave", HideTip)
        panel[spec.key] = button
        return button
    end
    local last
    for _, spec in ipairs(BUTTONS) do
        local button = Make(spec)
        if last then
            button:SetPoint("LEFT", last, "RIGHT", GAP / 2, 0)
        else
            button:SetPoint("TOPLEFT", users, "BOTTOMLEFT", 0, -GAP * 2)
        end
        last = button
    end

    local sizeHead = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    sizeHead:SetPoint("TOPLEFT", panel.new, "BOTTOMLEFT", 0, -GAP * 3)
    sizeHead:SetText(TEXT.sizeHead)
    -- the size, and beside it a button for the bar's own icon size
    local sizeLabel
    panel.slider, sizeLabel = Slider(content, TEXT.size, SIZE_LOW, SIZE_HIGH, SIZE_STEP, UI.SetSize)
    sizeLabel:SetPoint("TOPLEFT", sizeHead, "BOTTOMLEFT", 0, -GAP * 3)
    local match = Make({ key = "match", label = TEXT.match, tip = TEXT.matchTip,
        run = function() UI.SetSize(ns.Flyouts.BarSize() * 100) end })
    match:SetPoint("LEFT", panel.slider, "RIGHT", GAP * 5, 0)
    local sizeNote = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sizeNote:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -GAP * 2)
    sizeNote:SetText(TEXT.sizeNote)
    -- the background: shown or not, and how opaque
    local back = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    back:SetPoint("TOPLEFT", sizeNote, "BOTTOMLEFT", -4, -GAP)
    local backText = back.Text or back.text
    if not backText then
        backText = back:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        backText:SetPoint("LEFT", back, "RIGHT", GAP / 2, 0)
    end
    backText:SetText(TEXT.back)
    back.label, back.tip = TEXT.back, TEXT.backTip
    back:SetScript("OnClick", function(self) UI.SetBack(self:GetChecked() and true or false) end)
    back:SetScript("OnEnter", ShowTip)
    back:SetScript("OnLeave", HideTip)
    panel.back = back
    local alphaLabel
    panel.opacity, alphaLabel = Slider(content, TEXT.alpha, ALPHA_LOW, ALPHA_HIGH, ALPHA_STEP, UI.SetOpacity)
    alphaLabel:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 4, -GAP * 2)
    -- under it: General and Flyout keys (Options/Arrange.lua), under the opacity's row
    local foot = CreateFrame("Frame", nil, content)
    foot:SetSize(1, 1)
    foot:SetPoint("TOPLEFT", alphaLabel, "BOTTOMLEFT", 0, -GAP)
    ns.Arrange.Build(panel, foot, content)
    panel.built = true
    P.OnChange(UI.Refresh)
end

function ns.OpenOptions()
    if InCombatLockdown() then return ns.Warn(TEXT.fight) end
    if category and Settings.OpenToCategory then Settings.OpenToCategory(category:GetID()) end
end

-- With a controller, as FlickChat's page does it. The game's own rows
-- stay under an addon's page and its cursor would stop on them: they are
-- marked as not the cursor's while this page is up. Out of a fight only.
local hushed = false
local function Hush(on)
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    if not list or not SmartNavigation_MarkFrameIgnored or not SmartNavigation_ClearIgnoreStatus then return end
    if InCombatLockdown() then
        -- a giving back owed is tried again until it is done
        if not on and hushed then
            C_Timer.After(1, function()
                if not panel:IsVisible() then Hush(false) end
            end)
        end
        return
    end
    if on and not hushed and not list.smartNavigationIgnored then
        hushed = true
        SmartNavigation_MarkFrameIgnored(list)
    elseif not on and hushed then
        hushed = false
        SmartNavigation_ClearIgnoreStatus(list)
    end
end

panel = CreateFrame("Frame")
panel:Hide()
panel.name = TITLE
-- A page of ours came up: the controller's cursor read the window before
-- the page's buttons were built, so it is asked again. Any page of the addon's.
function ns.OptionsPageShown(page)
    C_Timer.After(0, function()
        if not page:IsVisible() then return end
        Hush(true)
        local cursor = SmartNavigation
        if cursor and cursor.UpdateParent and not InCombatLockdown() then cursor:UpdateParent(page) end
    end)
end
function ns.OptionsPageHidden() Hush(false) end

panel:SetScript("OnShow", function()
    UI.Build()
    UI.Refresh()
    -- measured again once the game has placed the page in its window
    C_Timer.After(0, UI.Fit)
    ns.OptionsPageShown(panel)
end)
panel:SetScript("OnHide", ns.OptionsPageHidden)
UI.panel = panel

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, TITLE)
    Settings.RegisterAddOnCategory(category)
    -- for the pages under this one
    ns.OptionsCategory = category
end

-- its row in the game's addon list at the minimap
function FallensFlyouts_OnAddonCompartmentClick() ns.OpenOptions() end

SLASH_FALLENSFLYOUTS1 = "/ff"
SLASH_FALLENSFLYOUTS2 = "/flyouts"
-- /ff status (or feedback): the Feedback page; anything else, the settings
SlashCmdList.FALLENSFLYOUTS = function(msg)
    local word = type(msg) == "string" and msg:lower():match("^%s*(%a+)%s*$")
    if (word == "status" or word == "feedback") and ns.FeedbackUI then return ns.FeedbackUI.Open() end
    ns.OpenOptions()
end

-- The Feedback page, under the addon's own after Automatic Flyouts and Controller: a bug report or an idea
-- sent to GitHub with the details of the game filled in, what changed in this version, and the status
-- report (/ff status), all the addon knows of the setup, for a report. His words (2026-11-24): "we need an
-- extensive debug status that ppl can send to us, like the \"/fcui status\"", "autofilled things from bug
-- report in game are bis. make sure we add a \"Feedback\" tab to the fallens flyout settings dropdowns", and
-- "keep in mind these all need to be accessible via controller, at least in gamepad mode to start." Every
-- part of it is a button of the game's own, which a controller's cursor reaches. Issues are public: no
-- character's name or realm, no profile's name (one is a character's), and no macro's name or text.
do
    local FB = {}
    ns.FeedbackUI = FB
    local ISSUES = "https://github.com/fallenguards/fallens-flyouts/issues/new"
    -- the most letters of other addons' names a link carries: a browser takes a link of some length only
    local MAX_ADDONS = 600
    local SAY = {
        title = "Feedback",
        intro = "Something not working, or an idea? Tell us on GitHub. These buttons fill in the details of "
            .. "your game for you: you only say what happened, or what you would like.",
        bug = "Report a Bug",
        bugTip = "A link to a new bug report on GitHub, the Status below already in it.",
        idea = "Suggest an Idea",
        ideaTip = "A link to a new idea on GitHub, the Status below already in it.",
        news = "What's New",
        newsTip = "What changed in this version of Fallen's Flyouts.",
        copy = "Press Ctrl+C to copy this link, then open it in your browser.",
        statusHead = "Status",
        statusNote = "Everything the addon knows of your setup, with nothing of who you are. Report a Bug and "
            .. "Suggest an Idea put it in the report for you (on a very large setup, as much as a link holds). "
            .. "/ff status opens this page.",
        select = "Select All",
        fight = "The options open out of a fight.",
    }
    FB.TEXT = SAY
    local NAME_OF = { own = "this character's own", class = "this class's", all = "every character's" }

    -- what the game kept the addon from doing this session
    local blocked = {}
    local watch = CreateFrame("Frame")
    watch:RegisterEvent("ADDON_ACTION_BLOCKED")
    watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watch:SetScript("OnEvent", function(_, event, addon, func)
        if addon ~= "FallensFlyouts" then return end
        blocked[#blocked + 1] = ("%s %s %s%s"):format(date("%H:%M:%S"),
            event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", tostring(func),
            InCombatLockdown() and " (in combat)" or "")
    end)

    -- the other addons on, each with its version, by name; `limit`: the most letters
    local function AddonsOn(limit)
        local names = {}
        local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
        for i = 1, count do
            local name = C_AddOns.GetAddOnInfo(i)
            if type(name) == "string" and name ~= "FallensFlyouts" and not name:find("^Blizzard_")
                and C_AddOns.IsAddOnLoaded(i) then
                local ok, version = pcall(C_AddOns.GetAddOnMetadata, i, "Version")
                names[#names + 1] = (ok and type(version) == "string" and version ~= "") and (name .. " " .. version)
                    or name
            end
        end
        table.sort(names)
        if not limit then return names end
        local out, length = {}, 0
        for _, name in ipairs(names) do
            if length + #name > limit then
                out[#out + 1] = "..."
                break
            end
            out[#out + 1] = name
            length = length + #name + 2
        end
        return out
    end

    -- the settings that are not as shipped
    local function Changed()
        local F = ns.Flyouts
        local out = {}
        local function Note(on, words) if on then out[#out + 1] = words end end
        Note(F.Size() ~= 1, ("size %d%%"):format(math.floor(F.Size() * 100 + 0.5)))
        Note(not F.Hiding(), "hide items I have none of: off")
        Note(not F.Ranked(), "spell ranks in order: off")
        Note(F.Twice(), "press a flyout's key again for the last one used: on")
        Note(not F.Around(), "open around the button in gamepad mode: off")
        Note(F.Cross() ~= "opposite", "new flyouts pick with: " .. F.Cross())
        Note(F.Faces(), "flyouts made before 1.1.7 pick with the face buttons")
        Note(not F.Plate(), "round background: off")
        Note(not F.Back(), "flyout background: off")
        Note(F.BackAlpha() < 1, ("background opacity %d%%"):format(math.floor(F.BackAlpha() * 100 + 0.5)))
        Note(not P.Hints(), "hints in tooltips: off")
        return out
    end

    -- a flyout in a line: its button, what leads it, what it holds, how it opens
    local function FlyoutLine(flyout)
        local F = ns.Flyouts
        local counts, own, kinds = {}, 0, {}
        for _, entry in ipairs(F.Full(flyout)) do
            counts[entry.kind] = (counts[entry.kind] or 0) + 1
            if entry.key or entry.pad then own = own + 1 end
        end
        for kind, n in pairs(counts) do kinds[#kinds + 1] = kind .. " " .. n end
        table.sort(kinds)
        local main = flyout.main
        local lead = main and (main.kind == "macro" and "a macro" or (tostring(main.kind) .. " " .. tostring(main.id)))
            or "nothing"
        local unit = F.UnitOf(flyout)
        local shape = unit and (unit.radial and "around its button" or ("opens " .. tostring(unit.side) .. ", runs "
            .. tostring(unit.way))) or "not laid out"
        return ("%s: led by %s; %d icons (%s); %s%s%s%s"):format(tostring(flyout.host ~= "" and flyout.host or "?"),
            lead, #F.Full(flyout), table.concat(kinds, ", "), shape,
            own > 0 and ("; " .. own .. " own keys") or "",
            flyout.auto and ("; fills itself (" .. tostring(flyout.auto) .. ")") or "",
            F.Sleeps(flyout) and "; on another page of its bar" or "")
    end

    -- Everything, line by line. `cut`, for a link that would be too long (FB.Link): "addons", the other addons
    -- past MAX_ADDONS letters left out; "flyouts", the line of each flyout too. What was left out is said.
    function FB.Text(cut)
        local F = ns.Flyouts
        local lines = {}
        local function Add(text) lines[#lines + 1] = text end
        local version, build, _, toc = GetBuildInfo()
        Add("Fallen's Flyouts " .. (ns.Welcome and ns.Welcome.Version() or "?"))
        Add(("Client: %s (build %s, interface %s), %s"):format(tostring(version), tostring(build), tostring(toc),
            GetLocale and GetLocale() or "?"))
        local w, h = 0, 0
        if GetPhysicalScreenSize then w, h = GetPhysicalScreenSize() end
        Add(("Display: %sx%s, UI scale %.2f"):format(tostring(w), tostring(h), UIParent:GetEffectiveScale()))
        local _, class = UnitClass("player")
        Add(("Character: %s, level %s%s"):format(tostring(class), tostring(UnitLevel and UnitLevel("player") or "?"),
            InCombatLockdown() and ", in combat" or ""))
        local pad = C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
        Add(("Input: %s%s"):format(F.PadInUse() and "a controller" or "mouse and keyboard",
            pad and ", controller support on" or ""))
        Add(("Bars locked: %s"):format(F.BarsLocked() and "yes" or "no"))
        local active = P.Active()
        Add(("Profile: %s, of %d"):format(NAME_OF[P.Kind(active) or ""] or "one named by the player", #P.Names()))
        local changed = Changed()
        Add("Settings changed: " .. (#changed > 0 and table.concat(changed, "; ") or "none, all as shipped"))
        local list = F.List() or {}
        local _, used = F.Units()
        Add(("Flyouts: %d in the profile, %d laid on a button"):format(#list, used or 0))
        if cut ~= "flyouts" then
            for _, flyout in ipairs(list) do Add("    " .. FlyoutLine(flyout)) end
        end
        local hid = {}
        for what, seen in pairs(F.hid or {}) do
            if seen then hid[#hid + 1] = what end
        end
        table.sort(hid)
        Add("Values the game kept secret this session: " .. (#hid > 0 and table.concat(hid, ", ") or "none"))
        Add("Kept from the addon by the game this session: "
            .. (#blocked > 0 and table.concat(blocked, "; ") or "nothing"))
        local others = AddonsOn(cut and MAX_ADDONS or nil)
        Add(("Other addons on (%d): %s"):format(#AddonsOn(), #others > 0 and table.concat(others, ", ") or "none"))
        local left = {}
        if cut == "flyouts" and #list > 0 then left[#left + 1] = "the line of each flyout" end
        if others[#others] == "..." then left[#left + 1] = "some of the other addons" end
        if #left > 0 then
            Add(("Left out of this link for its length: %s. The Status on the addon's Feedback page (/ff status) "
                .. "has all of it."):format(table.concat(left, " and ")))
        end
        return table.concat(lines, "\n")
    end

    local function Encode(s)
        s = tostring(s):gsub("\r?\n", "\r\n")
        s = s:gsub("([^%w%-%.%_%~ ])", function(c) return ("%%%02X"):format(c:byte()) end)
        return (s:gsub(" ", "+"))
    end

    -- A new issue of that form on GitHub, the status in its Details from the addon box. His words
    -- (2026-11-24): "why doesnt the report a bug auto fill with the status info if it's already auto filling
    -- some of it?" All of it, while it fits: GitHub opens such a link with up to some 6,400 letters of
    -- details (measured 2026-11-24, signed out, where its sign-in page carries the link along, and a longer
    -- one fails there). Past LINK_MOST the other addons past MAX_ADDONS letters go first, then the line of
    -- each flyout, and the link says what it left out.
    local LINK_MOST = 6000
    function FB.Link(template)
        local url
        for _, cut in ipairs({ false, "addons", "flyouts" }) do
            url = ("%s?template=%s&details=%s"):format(ISSUES, template, Encode(FB.Text(cut or nil)))
            if #url <= LINK_MOST then return url end
        end
        return url
    end

    local page = CreateFrame("Frame")
    page:Hide()
    page.name = SAY.title
    FB.panel = page

    -- the link, in a box ready to copy; typing in it puts the link back
    local function ShowLink(template)
        local url = FB.Link(template)
        page.url = url
        page.copy:Show()
        page.link:Show()
        page.link:SetText(url)
        page.link:SetFocus()
        page.link:SetCursorPosition(0)
        page.link:HighlightText()
        FB.Fit()
    end

    function FB.Build()
        if page.built then return end
        ns.Start()
        local content = ns.OptionsScroller(page)
        local head = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        head:SetPoint("TOPLEFT", content, "TOPLEFT", EDGE, -EDGE)
        head:SetText(SAY.title)
        local intro = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        intro:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -GAP)
        intro:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
        intro:SetJustifyH("LEFT")
        intro:SetText(SAY.intro)
        local last
        for _, spec in ipairs({
            { key = "bug", label = SAY.bug, tip = SAY.bugTip, run = function() ShowLink("bug_report.yml") end },
            { key = "idea", label = SAY.idea, tip = SAY.ideaTip, run = function() ShowLink("feature_request.yml") end },
            { key = "news", label = SAY.news, tip = SAY.newsTip, run = function()
                if ns.Welcome then ns.Welcome.ShowChanges() end
            end },
        }) do
            local button = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            button:SetText(spec.label)
            button:SetSize(math.max(BUTTON_FLOOR, (button:GetTextWidth() or 0) + CHROME / 2), LINE)
            button.label, button.tip = spec.label, spec.tip
            button:SetScript("OnClick", spec.run)
            button:SetScript("OnEnter", ShowTip)
            button:SetScript("OnLeave", HideTip)
            if last then
                button:SetPoint("LEFT", last, "RIGHT", GAP / 2, 0)
            else
                button:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -GAP * 2)
            end
            page[spec.key] = button
            last = button
        end
        page.copy = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        page.copy:SetPoint("TOPLEFT", page.bug, "BOTTOMLEFT", 0, -GAP * 2)
        page.copy:SetText(SAY.copy)
        page.copy:Hide()
        page.link = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        page.link:SetPoint("TOPLEFT", page.copy, "BOTTOMLEFT", 6, -GAP)
        page.link:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
        page.link:SetHeight(LINE)
        page.link:SetAutoFocus(false)
        -- uncapped: a capped box would cut the details off the end of the link
        page.link:SetMaxLetters(0)
        page.link:SetMaxBytes(0)
        page.link:SetScript("OnTextChanged", function(self, typed)
            if typed then
                self:SetText(page.url or "")
                self:HighlightText()
            end
        end)
        page.link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        page.link:Hide()
        local statusHead = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        statusHead:SetPoint("TOPLEFT", page.copy, "BOTTOMLEFT", 0, -GAP * 3 - LINE)
        statusHead:SetText(SAY.statusHead)
        local note = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        note:SetPoint("TOPLEFT", statusHead, "BOTTOMLEFT", 0, -GAP)
        note:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
        note:SetJustifyH("LEFT")
        note:SetText(SAY.statusNote)
        page.select = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        page.select:SetText(SAY.select)
        page.select:SetSize(math.max(BUTTON_FLOOR, (page.select:GetTextWidth() or 0) + CHROME / 2), LINE)
        page.select:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -GAP * 2)
        page.select:SetScript("OnClick", function()
            page.status:SetFocus()
            page.status:HighlightText()
        end)
        -- the report: a box of the game's own to select from and copy, as long as its words
        page.status = CreateFrame("EditBox", nil, content)
        page.status:SetMultiLine(true)
        page.status:SetAutoFocus(false)
        page.status:SetFontObject("GameFontHighlightSmall")
        page.status:SetPoint("TOPLEFT", page.select, "BOTTOMLEFT", 0, -GAP)
        page.status:SetPoint("RIGHT", content, "RIGHT", -EDGE, 0)
        page.status:SetScript("OnTextChanged", function(self, typed)
            if typed then self:SetText(page.text or "") end
        end)
        page.status:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        page.measure = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        page.measure:SetPoint("TOPLEFT", page.status, "TOPLEFT")
        page.measure:SetPoint("RIGHT", page.status, "RIGHT")
        page.measure:SetJustifyH("LEFT")
        page.measure:SetAlpha(0)
        page.built = true
    end

    -- the page scrolls as far as its report
    function FB.Fit()
        if not page.built then return end
        page.measure:SetText(page.text or "")
        page.status:SetHeight(math.max(LINE, (page.measure:GetStringHeight() or 0) + GAP))
        ns.OptionsFit(page, page.status)
    end

    -- read afresh each time the page is up
    function FB.Refresh()
        if not page.built then return end
        page.text = FB.Text(false)
        page.status:SetText(page.text)
        FB.Fit()
    end

    page:SetScript("OnShow", function()
        FB.Build()
        FB.Refresh()
        C_Timer.After(0, FB.Fit)
        ns.OptionsPageShown(page)
    end)
    page:SetScript("OnHide", ns.OptionsPageHidden)

    -- listed by Options/Auto.lua after its own page and the Controller page
    function FB.Register()
        if Settings and Settings.RegisterCanvasLayoutSubcategory and ns.OptionsCategory then
            FB.category = Settings.RegisterCanvasLayoutSubcategory(ns.OptionsCategory, page, SAY.title)
        end
    end

    -- /ff status, /ff feedback
    function FB.Open()
        if InCombatLockdown() then return ns.Warn(SAY.fight) end
        local sub = FB.category
        if sub and sub.GetID and Settings.OpenToCategory then
            Settings.OpenToCategory(sub:GetID())
        else
            ns.OpenOptions()
        end
    end
end
