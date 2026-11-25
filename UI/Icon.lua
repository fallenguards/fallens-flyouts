local _, ns = ...
-- luacheck: read globals UIParent CreateFrame InCombatLockdown issecretvalue Enum
-- luacheck: read globals IconSelectorPopupFrameTemplateMixin IconSelectorPopupFrameIconFilterTypes
-- luacheck: read globals InputUtil SmartNavigation
-- luacheck: read globals IconDataProviderMixin IconDataProviderExtraType CreateAndInitFromMixin GenerateClosure
-- luacheck: read globals C_SpellBook C_Spell C_Item C_Container GetNumMacros GetMacroInfo NUM_BAG_SLOTS GameTooltip
-- luacheck: read globals hooksecurefunc geterrorhandler
-- luacheck: globals FallensFlyouts_TooltipHint

-- The game's own icon window, for the icon a flyout shows on its bar button.
local I = {}
ns.Icon = I
local F = ns.Flyouts

local NAME = "FallensFlyoutsIconPopup"
local ACCOUNT_MACROS, SEARCH_LETTERS = 120, 40
-- the search box: its height, the room between it and what stands at its sides, and where it stands and
-- how wide it is in a window whose own words are not to be found
local SEARCH_H, SEARCH_GAP, SEARCH_X, SEARCH_Y, SEARCH_W = 20, 12, 130, 73, 190
-- the client lists icons by number, so names come from what the character has
local TEXT = {
    name = "Name on the button (optional)",
    search = "Search spells, items, macros",
    own = "Click to put this one on the bar button: its icon, tooltip and cooldown show there.",
    reset = "Reset to default icon",
    resetTip = "Back to the button's own ability and its icon.",
}
I.TEXT = TEXT
local BANK = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
-- The game's icon list in its window, as its template places it; and the row of the flyout's own icons
-- over it: how high, how far in its first icon stands, the gap between icons, the room over them.
local GRID_X, GRID_Y, GRID_W, GRID_H = 21, 97, 494, 361
local ROW, ROW_IN, ROW_GAP, ROW_TOP, SLOT = 52, 9, 12, 2, 36
local DIVIDER = "Interface/Common/UI-TooltipDivider-Transparent"
local DIVIDER_H, DIVIDER_UP = 8, 2
-- the reset button: at the window's bottom left, as high as Cancel
local RESET_X, RESET_Y, RESET_H, RESET_PAD = 12, 13, 22, 30

local popup, target
-- the row, the reset button, the search box, and the icon of the flyout picked in the row
local own, reset, search, pending

local function Usable(text)
    if issecretvalue and issecretvalue(text) then return false end
    return type(text) == "string" and text ~= ""
end

-- names this character can search by: its spells, bag items and macros
local function Named(flyout)
    local out = {}
    local function Add(name, icon)
        if Usable(name) and icon then out[#out + 1] = { name = name:lower(), icon = icon } end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            local offset = info and info.itemIndexOffset or 0
            for slot = offset + 1, offset + (info and info.numSpellBookItems or 0) do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, BANK)
                if item then Add(item.name, item.iconID) end
            end
        end
    end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then Add(C_Item.GetItemNameByID(info.itemID), info.iconFileID) end
            end
        end
    end
    local account, mine = GetNumMacros()
    for i = 1, account or 0 do Add(GetMacroInfo(i)) end
    for i = ACCOUNT_MACROS + 1, ACCOUNT_MACROS + (mine or 0) do Add(GetMacroInfo(i)) end
    -- what is in the flyout itself
    for _, entry in ipairs(flyout and flyout.entries or {}) do
        local name = entry.id
        if entry.kind == "spell" then
            name = C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
        elseif entry.kind == "item" then
            name = C_Item.GetItemNameByID(entry.id)
        elseif ns.Bars.Kinds[entry.kind] then
            name = ns.Bars.Kinds[entry.kind].Name(entry.id)
        end
        Add(name, F.Icon(entry))
    end
    return out
end

-- The game's icon list, narrowed to a search while one is typed.
local Provider = {}
Provider.__index = Provider

local function NewProvider()
    local self = setmetatable({}, Provider)
    self.base = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)
    return self
end

function Provider:GetNumIcons()
    if self.found then return #self.found end
    return self.base:GetNumIcons()
end

function Provider:GetIconByIndex(index)
    if self.found then return self.found[index] end
    return self.base:GetIconByIndex(index)
end

function Provider:GetIndexOfIcon(icon)
    if not self.found then return self.base:GetIndexOfIcon(icon) end
    for i, other in ipairs(self.found) do
        if other == icon then return i end
    end
end

function Provider:SetIconTypes(types)
    self.base:SetIconTypes(types)
    self.files = nil
    self:Search(self.text)
end

function Provider:Release() self.base:Release() end

-- icons the client lists by file name, lowered once
function Provider:Files()
    if self.files then return self.files end
    local files = {}
    for i = 1, self.base:GetNumIcons() do
        local icon = self.base:GetIconByIndex(i)
        if type(icon) == "string" then
            files[#files + 1] = { name = (icon:match("[^\\/]+$") or icon):lower(), icon = icon }
        end
    end
    self.files = files
    return files
end

function Provider:Search(text)
    text = type(text) == "string" and text:lower():match("^%s*(.-)%s*$") or ""
    self.text = text
    if text == "" then
        self.found = nil
        return
    end
    local found, seen = {}, {}
    local function Add(icon)
        if icon and not seen[icon] then
            seen[icon] = true
            found[#found + 1] = icon
        end
    end
    self.named = self.named or Named(target)
    for _, entry in ipairs(self.named) do
        if entry.name:find(text, 1, true) then Add(entry.icon) end
    end
    -- a spell or item number
    local id = tonumber(text)
    if id then
        Add((C_Spell.GetSpellTexture(id)))
        Add(C_Item.GetItemIconByID(id))
    end
    for _, entry in ipairs(self:Files()) do
        if entry.name:find(text, 1, true) then Add(entry.icon) end
    end
    self.found = found
end

-- narrows the window's icons to a search; returns how many are left
function I.Search(text)
    local provider = popup and popup.iconDataProvider
    if not provider then return 0 end
    provider:Search(text)
    popup.IconSelector:UpdateSelections()
    popup:ReevaluateSelectedIcon()
    return provider:GetNumIcons()
end

local function Chosen() return popup.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() end

-- a row button's icon and its mark, by whatever the game's template gave it
local function Draw(button, icon)
    if button.SetIconTexture then return button:SetIconTexture(icon) end
    button.art:SetTexture(icon)
end
local function Mark(button, on)
    if button.SelectedTexture then button.SelectedTexture:SetShown(on) end
end

-- One of the flyout's own icons picked in the row: Okay puts it on the bar button.
local function Pick(entry)
    pending = entry
    for _, button in ipairs(own.buttons) do Mark(button, button.entry == entry) end
    popup.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(F.Icon(entry))
    popup:SetSelectedIconText()
end
I.Pick = Pick

-- The row shows the flyout's icons, the one on the bar button marked; the game's list starts under
-- it. A flyout that fills itself has no row: its button is the kind's own.
local function Fill()
    pending = nil
    local entries = target and not target.auto and target.entries or {}
    local any = false
    -- the usual gap, or less where that many would run past the game's list
    local gap = ROW_GAP
    if #entries > 1 then gap = math.min(ROW_GAP, (GRID_W - 2 * ROW_IN - #entries * SLOT) / (#entries - 1)) end
    for i, button in ipairs(own.buttons) do
        local entry = entries[i]
        button.entry = entry
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", own, "TOPLEFT", ROW_IN + (i - 1) * (SLOT + gap), -ROW_TOP)
        button:SetShown(entry ~= nil)
        if entry then
            any = true
            Draw(button, F.Icon(entry))
            Mark(button, target.main ~= nil and F.Same(entry, target.main))
        end
    end
    own:SetShown(any)
    local list = popup.IconSelector
    if list.ClearAllPoints and list.SetPoint and list.SetHeight then
        local down = any and ROW or 0
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", popup, "TOPLEFT", GRID_X, -(GRID_Y + down))
        list:SetHeight(GRID_H - down)
    end
end

-- the window opens on the icon the button shows now
local function Update(self)
    local icon = target.icon or F.Icon(target.main or target.entries[1])
    local button = self.BorderBox.SelectedIconArea.SelectedIconButton
    self.IconSelector:SetSelectedIndex(self:GetIndexOfIcon(icon))
    button:SetIconTexture(icon)
    self.opened = button:GetIconTexture()
    self.IconSelector:SetSelectionsDataProvider(GenerateClosure(self.GetIconByIndex, self),
        GenerateClosure(self.GetNumIcons, self))
    self.IconSelector:ScrollToSelectedIndex()
    self:SetSelectedIconText()
    Fill()
end

-- The game's template's own OnShow and OnHide, all but one line each. They count the game's icon windows
-- shown, in a variable of the template's file (IconSelectorPopupFramesShown, SharedUIPanelTemplates.lua), and
-- every bar button reads that count at the start of a drag (IsAnyIconSelectorPopupFrameShown, in its
-- OnDragStart). Counted by this window, the count was the addon's from then on, and in a fight the game
-- refused the pickup of every drag off a bar. His error (2026-11-23), dragging a flyout's bar button in a
-- fight: "[ADDON_ACTION_BLOCKED] AddOn 'FallensFlyouts' tried to call the protected function
-- 'PickupAction()'". This window is never counted: an ability dragged off a bar while it is open is picked
-- up as by any drag, where the game's own windows have it copied.
local function TemplateShow(self)
    self:RegisterEvent("CURSOR_CHANGED")
    self:RegisterEvent("GLOBAL_MOUSE_UP")
    self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconSelector(self)
    self.BorderBox.IconSelectorEditBox:SetIconSelector(self)
    self:UpdateStateFromCursorType()
end
local function TemplateHide(self)
    self:UnregisterEvent("CURSOR_CHANGED")
    self:UnregisterEvent("GLOBAL_MOUSE_UP")
    if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then
        if self.iconSelectorFooter then self.iconSelectorFooter:HideAndDeactivateBindings() end
        SmartNavigation:LeaveFocusGroup()
        if self.oldButton then
            SmartNavigation:SelectButton(self.oldButton)
            self.oldButton = nil
        end
    end
end

local function OnShow(self)
    TemplateShow(self)
    self.iconDataProvider = NewProvider()
    self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
    self:Update()
    self.IconSelector:SetSelectedCallback(function(_, icon)
        -- an icon of the game's list: nothing of the row is picked any more
        pending = nil
        for _, button in ipairs(own.buttons) do Mark(button, false) end
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
        self:SetSelectedIconText()
    end)
    -- the reset button sits level with Cancel, wherever this client's window has it
    local cancel = self.BorderBox.CancelButton
    local up, high = RESET_Y, RESET_H
    if cancel and cancel.GetBottom and self.GetBottom and cancel:GetBottom() and self:GetBottom() then
        up, high = cancel:GetBottom() - self:GetBottom(), cancel:GetHeight()
    end
    reset:ClearAllPoints()
    reset:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", RESET_X, up)
    reset:SetSize((reset.GetTextWidth and reset:GetTextWidth() or 0) + RESET_PAD, high)
    -- the flyout's name, ready to be typed over, as the game's own window has a macro's
    local box = self.BorderBox.IconSelectorEditBox
    box:SetText(target.name or "")
    box:HighlightText()
    box:SetFocus()
    search:SetText("")
    self.BorderBox.OkayButton:Enable()
end

local function OnHide(self)
    TemplateHide(self)
    if self.iconDataProvider then
        self.iconDataProvider:Release()
        self.iconDataProvider = nil
    end
    target, pending = nil, nil
end

-- Okay with nothing picked or typed changes nothing. The name in the box is the flyout's from then on.
-- One of the flyout's own, picked in the row, goes onto the bar button itself; an icon of the game's
-- list is drawn over the button's.
local function Okay(self)
    local flyout, icon, opened, picked = target, Chosen(), self.opened, pending
    local name = self.BorderBox.IconSelectorEditBox:GetText()
    IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
    if not flyout then return end
    -- a kind of the player's own (from the settings page): its name and icon, kept with the kind
    if flyout.kindId then
        local QUESTION = 134400
        local pick = nil
        if icon ~= opened then pick = icon end
        if pick == QUESTION then pick = false end
        local ok, why = ns.Auto.Restyle(flyout.kindId, name, pick)
        if not ok and why then ns.Warn(why) end
        if ns.AutoUI then ns.AutoUI.Refresh() end
        return
    end
    local named, whyNot = F.SetName(flyout, name)
    if not named and whyNot then ns.Warn(whyNot) end
    if picked then
        local ok, why = F.Lead(flyout, picked)
        if not ok and why then ns.Warn(why) end
    elseif icon ~= opened then
        F.SetIcon(flyout, icon)
    end
end

local function Reset()
    local flyout = target
    popup:CancelButton_OnClick()
    if not flyout then return end
    local ok, why
    if flyout.kindId then
        ok, why = ns.Auto.Restyle(flyout.kindId, nil, false)
        if ns.AutoUI then ns.AutoUI.Refresh() end
    else
        ok, why = F.Reset(flyout)
    end
    if not ok and why then ns.Warn(why) end
end

local function RowTip(self)
    if not self.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(F.Name(self.entry))
    GameTooltip:AddLine(TEXT.own, 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-- The search: the game's own search box, between "Choose an Icon" and the list of kinds.
local function SearchBox()
    local border = popup.BorderBox
    local made, box = pcall(CreateFrame, "EditBox", nil, border, "SearchBoxTemplate")
    if not made or not box then box = CreateFrame("EditBox", nil, border, "InputBoxTemplate") end
    box:SetAutoFocus(false)
    box:SetMaxLetters(SEARCH_LETTERS)
    box:SetHeight(SEARCH_H)
    local words, kinds = border.IconSelectionText, border.IconTypeDropdown
    if words and kinds then
        box:SetPoint("LEFT", words, "RIGHT", SEARCH_GAP, 0)
        box:SetPoint("RIGHT", kinds, "LEFT", -SEARCH_GAP, 0)
    else
        box:SetPoint("TOPLEFT", popup, "TOPLEFT", SEARCH_X, -SEARCH_Y)
        box:SetWidth(SEARCH_W)
    end
    if box.Instructions and box.Instructions.SetText then box.Instructions:SetText(TEXT.search) end
    -- behind the box's own handling of its text (its prompt and its clear button)
    box:HookScript("OnTextChanged", function(self) I.Search(self:GetText()) end)
    return box
end

local function Build()
    if popup then return end
    popup = CreateFrame("Frame", NAME, UIParent, "IconSelectorPopupFrameTemplate")
    popup:Hide()
    popup:SetFrameStrata("HIGH")
    popup:SetToplevel(true)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "CENTER")
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup.Update, popup.OkayButton_OnClick = Update, Okay
    popup:SetScript("OnShow", OnShow)
    popup:SetScript("OnHide", OnHide)
    -- The window's name box holds the flyout's name, as it holds a macro's in the game's own use of
    -- this window: sixteen letters, written on the bar button. A flyout needs none, so Okay stays lit
    -- with the box empty (the game's own handler would put it out).
    local box = popup.BorderBox.IconSelectorEditBox
    popup.BorderBox.EditBoxHeaderText:SetText(TEXT.name)
    box:SetMaxLetters(F.NAME_LETTERS)
    box:SetScript("OnTextChanged", function() popup.BorderBox.OkayButton:Enable() end)
    box:SetScript("OnEnterPressed", function() popup:OkayButton_OnClick() end)
    box:SetScript("OnEscapePressed", function() popup:CancelButton_OnClick() end)
    search = SearchBox()
    -- the flyout's own icons in a row over the game's list, cut off from it by a line
    own = CreateFrame("Frame", nil, popup)
    own:SetPoint("TOPLEFT", popup, "TOPLEFT", GRID_X, -GRID_Y)
    own:SetSize(GRID_W, ROW)
    if popup.IconSelector.GetFrameLevel then own:SetFrameLevel(popup.IconSelector:GetFrameLevel() + 1) end
    own.buttons = {}
    for i = 1, F.MAX do
        local button = CreateFrame("Button", nil, own, "SelectorButtonTemplate")
        button:SetSize(SLOT, SLOT)
        button:SetPoint("TOPLEFT", own, "TOPLEFT", ROW_IN + (i - 1) * (SLOT + ROW_GAP), -ROW_TOP)
        if not button.SetIconTexture then
            button.art = button:CreateTexture(nil, "ARTWORK")
            button.art:SetAllPoints()
        end
        button:SetScript("OnClick", function(self)
            if self.entry then Pick(self.entry) end
        end)
        button:SetScript("OnEnter", RowTip)
        button:SetScript("OnLeave", HideTip)
        own.buttons[i] = button
    end
    own.line = own:CreateTexture(nil, "ARTWORK")
    own.line:SetTexture(DIVIDER)
    own.line:SetPoint("BOTTOMLEFT", own, "BOTTOMLEFT", 0, DIVIDER_UP)
    own.line:SetPoint("BOTTOMRIGHT", own, "BOTTOMRIGHT", 0, DIVIDER_UP)
    own.line:SetHeight(DIVIDER_H)
    -- and a way back to the button's own
    reset = CreateFrame("Button", nil, popup.BorderBox, "UIPanelButtonTemplate")
    reset:SetText(TEXT.reset)
    reset:SetScript("OnClick", Reset)
    reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TEXT.resetTip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    reset:SetScript("OnLeave", HideTip)
    I.popup, I.own, I.reset, I.search = popup, own, reset, search
end

-- The icon window for a kind of the player's own that fills itself, from its right-click on the settings
-- page: its name and its icon, as a flyout's are set from its bar button.
function I.OpenKind(kind)
    if not (kind and kind.own) then return end
    I.Open({ kindId = kind.id, auto = kind.id, icon = kind.icon, name = kind.name, entries = {} })
end

-- the icon window for one flyout
function I.Open(flyout)
    if InCombatLockdown() then return ns.Warn(F.TEXT.fight) end
    if not flyout then return end
    Build()
    popup:Hide()
    target = flyout
    popup:Show()
end

-- the flyout the window is open for, if it is up
function I.Target() return popup and popup:IsShown() and target or nil end

-- A hint at the foot of the game's own tooltip for a flyout's bar button, in gray, as the icons of a
-- flyout have theirs: how to open this window, by the right-click a mouse gives it or by RB in Edit Flyout
-- with a controller. Added after the game has filled the tooltip in, so on any bar's buttons. Not in a
-- fight (the window opens out of one only), and not where hints are turned off.
-- His words (2026-11-24): "for flyouts, can we have a message at bottom of the tooltip in gray like \"Right
-- click to change icon/name. Turn hint off in settings.\" and then obv add ability to hide in settings?",
-- "maybe right click to change tooltip/name. since icon doesnt really represent fact that it does/can
-- reprsent cd too", "what is the gamepad equivalent of right click to change/select icon etc? we need to
-- allow them to too.", and "i feel like we should switch show/hide background to lb and have rb be the one
-- to open this to be more consistent with mouse, esp for ppl that frequently swap btwn mouse keyboard and
-- controller". Then, of "(its icon, tooltip and cooldown) and its name" struck through in his snip: "nix
-- this red text".
do
    local HINT = {
        mouse = "Right-click to change what this button shows.",
        pad = "In Edit Flyout, RB changes what this button shows.",
        off = "Hints can be turned off in /ff.",
    }
    I.HINT = HINT
    local GRAY = 0.6
    local function Hint(tip)
        local owner = tip:GetOwner()
        local name = owner and owner.GetName and owner:GetName()
        if type(name) ~= "string" then return end
        local flyout, unit = F.At(name)
        if not flyout then return end
        -- a button showing the last one used (F.ShowLast) has that one's tooltip, in a fight too
        local last = unit and F.LastEntry(unit)
        if last then F.FillTip(tip, last) end
        if InCombatLockdown() or not (ns.Profiles and ns.Profiles.Hints()) then
            if last then tip:Show() end
            return
        end
        tip:AddLine(F.PadInUse() and HINT.pad or HINT.mouse, GRAY, GRAY, GRAY, true)
        tip:AddLine(HINT.off, GRAY, GRAY, GRAY, true)
        tip:Show()
    end
    -- Listened to once in a session, and what it runs is the copy of the addon loaded last: the test
    -- client loads the addon again at each login of one session, and the listeners stay.
    local first = FallensFlyouts_TooltipHint == nil
    FallensFlyouts_TooltipHint = Hint
    if first and GameTooltip and GameTooltip.SetAction then
        hooksecurefunc(GameTooltip, "SetAction", function(tip)
            xpcall(FallensFlyouts_TooltipHint, geterrorhandler(), tip)
        end)
    end
end
