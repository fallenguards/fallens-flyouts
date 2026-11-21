local _, ns = ...
-- luacheck: read globals UIParent CreateFrame InCombatLockdown issecretvalue Enum
-- luacheck: read globals IconSelectorPopupFrameTemplateMixin IconSelectorPopupFrameIconFilterTypes
-- luacheck: read globals IconDataProviderMixin IconDataProviderExtraType CreateAndInitFromMixin GenerateClosure
-- luacheck: read globals C_SpellBook C_Spell C_Item C_Container GetNumMacros GetMacroInfo NUM_BAG_SLOTS

-- The game's own icon window, for the icon a flyout shows on its bar button.
local I = {}
ns.Icon = I
local F = ns.Flyouts

local NAME = "FallensFlyoutsIconPopup"
local ACCOUNT_MACROS, SEARCH_LETTERS = 120, 40
-- the client lists icons by number, so names come from what the character has
local TEXT = { search = "Search your spells, items and macros" }
local BANK = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0

local popup, target

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
    local account, own = GetNumMacros()
    for i = 1, account or 0 do Add(GetMacroInfo(i)) end
    for i = ACCOUNT_MACROS + 1, ACCOUNT_MACROS + (own or 0) do Add(GetMacroInfo(i)) end
    -- what is in the flyout itself
    for _, entry in ipairs(flyout and flyout.entries or {}) do
        local name = entry.id
        if entry.kind == "spell" then
            name = C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
        elseif entry.kind == "item" then
            name = C_Item.GetItemNameByID(entry.id)
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
end

local function OnShow(self)
    IconSelectorPopupFrameTemplateMixin.OnShow(self)
    self.iconDataProvider = NewProvider()
    self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
    self:Update()
    self.IconSelector:SetSelectedCallback(function(_, icon)
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
        self:SetSelectedIconText()
    end)
    local box = self.BorderBox.IconSelectorEditBox
    box:SetText("")
    box:SetFocus()
    self.BorderBox.OkayButton:Enable()
end

local function OnHide(self)
    IconSelectorPopupFrameTemplateMixin.OnHide(self)
    if self.iconDataProvider then
        self.iconDataProvider:Release()
        self.iconDataProvider = nil
    end
    target = nil
end

-- Okay with nothing picked changes nothing
local function Okay(self)
    local flyout, icon, opened = target, Chosen(), self.opened
    IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
    if flyout and icon ~= opened then F.SetIcon(flyout, icon) end
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
    -- the window's name box is the search here: a flyout has no name
    local box = popup.BorderBox.IconSelectorEditBox
    popup.BorderBox.EditBoxHeaderText:SetText(TEXT.search)
    box:SetMaxLetters(SEARCH_LETTERS)
    box:SetScript("OnTextChanged", function(self) I.Search(self:GetText()) end)
    box:SetScript("OnEnterPressed", function() popup:OkayButton_OnClick() end)
    box:SetScript("OnEscapePressed", function() popup:CancelButton_OnClick() end)
    I.popup = popup
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
