local _, ns = ...
-- luacheck: read globals UIParent CreateFrame InCombatLockdown GetCursorInfo ClearCursor GetMacroInfo GameTooltip
-- luacheck: read globals C_Timer

-- The plus on bar buttons while carrying: a drop there stacks.
local D = {}
ns.Drop = D
local F, Bars, Art = ns.Flyouts, ns.Bars, ns.Art

-- the plus, and how its slot grows under the cursor
local BADGE, BADGE_HIT, BADGE_OUT, BADGE_REACH = 18, 22, 4, 7
-- on a button that has a flyout the plus stands clear of its arrow, past the tip
local BADGE_PAST = 12
local GROW_FROM, GROW_TO, GROW_SPEED = 0.55, 1.1, 16
local TEXT = {
    add = "Add to flyout",
    how = "Drop here to stack it on this button.",
    full = "Flyout is full",
    kind = "Only spells, items and macros go in a flyout.",
}
D.GROW_FROM, D.BADGE_OUT, D.BADGE_PAST = GROW_FROM, BADGE_OUT, BADGE_PAST
-- While a spell is dragged the game lifts its bars to the top layer. The plus
-- stands there too, at a level over every bar button and the frames on it.
local LAYER, LEVEL = "TOOLTIP", 9000
D.LAYER, D.LEVEL = LAYER, LEVEL

local tabs = {}
local pop, lastKind

-- what the cursor carries, as a flyout entry
function D.Carried()
    local kind, a, _, c = GetCursorInfo()
    local id
    if kind == "spell" then
        id = c
    elseif kind == "item" then
        id = a
    elseif kind == "macro" then
        -- by its place in the macro list, so its text is known with its name
        local entry = ns.Macros.Entry(a)
        if entry then return entry end
        id = (GetMacroInfo(a))
    end
    if id then return { kind = kind, id = id } end
end

local function TakeDrop(tab)
    if not GetCursorInfo() then return end
    -- an icon dragged out of this button's own flyout and let go on its plus: it stays in
    local own = F.At(tab.button:GetName())
    if own and ns.Move and ns.Move.PutBack(own) then return ClearCursor() end
    local entry = D.Carried()
    if not entry then return ns.Warn(TEXT.kind) end
    local flyout, why = F.Stack(tab.button, entry)
    if not flyout then return ns.Warn(why) end
    ClearCursor()
end

-- the tab's mouse area: the plus alone, or the whole grown slot
local function Reach(tab, grown)
    local side = tab.side
    local upright = side.x == 0
    tab:ClearAllPoints()
    if not grown then
        local out = F.At(tab.host) and BADGE_PAST or BADGE_OUT
        tab:SetSize(BADGE_HIT, BADGE_HIT)
        tab:SetPoint("CENTER", tab.button, side.to, side.x * out, side.y * out)
        return
    end
    local size = F.Size()
    local long, wide = BADGE_REACH + Art.POP * GROW_TO * size, Art.STRIP * GROW_TO * size
    tab:SetSize(upright and wide or long, upright and long or wide)
    tab:SetPoint(side.point, tab.button, side.to, -side.x * BADGE_REACH, -side.y * BADGE_REACH)
end

local function Grow(to)
    pop.to = to
    if pop:GetScript("OnUpdate") then return end
    pop:SetScript("OnUpdate", function(self, elapsed)
        local at = self.at + (self.to - self.at) * math.min(1, elapsed * GROW_SPEED)
        if math.abs(self.to - at) < 0.01 then
            at = self.to
            self:SetScript("OnUpdate", nil)
        end
        self.at = at
        self:SetScale(at * F.Size())
    end)
end

-- one flyout slot, shared by every tab
local function Pop()
    if pop then return pop end
    pop = CreateFrame("Frame", nil, UIParent)
    pop:Hide()
    pop.strip = Art.Strip(pop)
    pop.glow = pop:CreateTexture(nil, "BACKGROUND")
    pop.glow:SetAtlas(Art.NAMES.glow)
    pop.slot = pop:CreateTexture(nil, "BORDER")
    pop.slot:SetAtlas(Art.NAMES.back)
    pop.slot:SetSize(Art.ICON, Art.ICON)
    pop.icon = pop:CreateTexture(nil, "ARTWORK")
    pop.icon:SetAllPoints(pop.slot)
    Art.Dress(pop, pop.icon)
    pop.frame = pop:CreateTexture(nil, "OVERLAY")
    pop.frame:SetAtlas(Art.NAMES.frame)
    pop.frame:SetSize(Art.FRAME, Art.FRAME)
    pop.frame:SetPoint("TOPLEFT", pop.slot)
    pop.ring = pop:CreateTexture(nil, "OVERLAY", nil, 1)
    pop.ring:SetAtlas(Art.NAMES.frameOver)
    pop.ring:SetSize(Art.OVER_W, Art.OVER_H)
    pop.ring:SetPoint("TOPLEFT", pop.slot)
    pop.plus = pop:CreateTexture(nil, "OVERLAY", nil, 2)
    pop.plus:SetPoint("CENTER", pop.slot, "TOPRIGHT", -2, -2)
    Art.Plus(pop.plus, BADGE)
    pop.pulse = pop.ring:CreateAnimationGroup()
    pop.pulse:SetLooping("BOUNCE")
    local fade = pop.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.4)
    fade:SetDuration(0.45)
    D.pop = pop
    return pop
end

-- the slot on this tab's button, the way its flyout grows
local function LayPop(tab)
    local button, side = tab.button, tab.side
    local upright = side.x == 0
    pop:SetParent(tab)
    pop:ClearAllPoints()
    pop:SetPoint(side.point, button, side.to, -side.x * Art.OVERLAP, -side.y * Art.OVERLAP)
    pop:SetSize(upright and Art.STRIP or Art.POP, upright and Art.POP or Art.STRIP)
    Art.LayStrip(pop.strip, pop, tab.way)
    pop.slot:ClearAllPoints()
    pop.slot:SetPoint(side.point, pop, side.point, side.x * Art.FIRST, side.y * Art.FIRST)
    pop.glow:ClearAllPoints()
    pop.glow:SetPoint("TOPLEFT", button, "TOPLEFT", -Art.GLOW, Art.GLOW)
    pop.glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", Art.GLOW, -Art.GLOW)
end

-- cursor on a tab: the slot grows, shows what goes in
local function TabEnter(tab)
    local entry = D.Carried()
    local flyout = F.At(tab.host)
    local full = flyout ~= nil and #F.Full(flyout) >= F.MAX
    local icon
    if entry and not full then icon = F.Icon(entry) end
    Pop()
    LayPop(tab)
    pop.tab = tab
    pop.icon:SetTexture(icon)
    pop.ring:SetVertexColor(1, full and 0.2 or 1, full and 0.2 or 1)
    pop.plus:SetShown(not full)
    tab.badge:Hide()
    pop.at = GROW_FROM
    pop:SetScale(GROW_FROM * F.Size())
    pop:Show()
    pop.pulse:Play()
    Grow(GROW_TO)
    Reach(tab, true)
    GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
    GameTooltip:SetText(full and TEXT.full or TEXT.add)
    if not full then GameTooltip:AddLine(TEXT.how, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function TabLeave(tab)
    if pop and pop.tab == tab then
        pop.tab = nil
        pop.pulse:Stop()
        pop:SetScript("OnUpdate", nil)
        pop:Hide()
    end
    tab.badge:Show()
    if tab.side then Reach(tab, false) end
    if GameTooltip:IsOwned(tab) then GameTooltip:Hide() end
end

local function Tab(button, name)
    local tab = tabs[name]
    if tab then
        tab:EnableMouse(true)
        return tab
    end
    tab = CreateFrame("Frame", nil, UIParent)
    tab:Hide()
    tab:SetFrameStrata(LAYER)
    tab:SetFrameLevel(LEVEL)
    tab:EnableMouse(true)
    tab.host, tab.button = name, button
    tab.badge = tab:CreateTexture(nil, "ARTWORK")
    tab.badge:SetPoint("CENTER")
    Art.Plus(tab.badge, BADGE)
    tab:SetScript("OnEnter", TabEnter)
    tab:SetScript("OnLeave", TabLeave)
    tab:SetScript("OnReceiveDrag", TakeDrop)
    tab:SetScript("OnMouseUp", TakeDrop)
    tabs[name] = tab
    return tab
end

-- A tab on its button's outer edge, the way its flyout grows: for a button with a flyout the side that
-- flyout opens from, which may be one the player turned it to; for any other, where a flyout opens by
-- itself. (It went by the bar alone: a flyout turned to open upward kept its plus under its button. His
-- words with a snip, 2026-11-23: "it didnt update either after changing the orientation up".)
local function Place(tab, button)
    local _, unit = F.At(button:GetName())
    tab.way = unit and Art.SIDES[unit.side] and unit.side or Bars.Way(button)
    tab.side = Art.SIDES[tab.way]
    tab:SetScale(Bars.Scale(button))
    Reach(tab, false)
end

function D.Hide()
    for _, tab in pairs(tabs) do
        TabLeave(tab)
        tab:Hide()
    end
end

-- In a fight addon code may add nothing to a flyout: the flyout's own secure code does, at a drop on
-- its arrow. The plus is then a mark and no more: it stands where it stands out of a fight, past the tip
-- of the arrow of each flyout that takes one more, and lets the drop through to the arrow, which takes a
-- drop that far out (F.GripReach). It stood on the arrow itself, pulled down onto the button's edge (his
-- snips, 2026-11-23: "'+' still getting compressed lower in combat").
local function ShowInFight()
    local shown = 0
    for _, unit in ipairs(F.Roomy()) do
        local button = unit.host
        local tab = Tab(button, button:GetName())
        tab:EnableMouse(false)
        -- a bar's measure may be kept from addons in a fight: the plus then keeps the size it had
        local ok, scale = pcall(Bars.Scale, button)
        if ok and Bars.Plain(scale) then tab:SetScale(scale) end
        tab:ClearAllPoints()
        tab:SetSize(BADGE_HIT, BADGE_HIT)
        local side = Art.SIDES[unit.side]
        if side then
            tab:SetPoint("CENTER", button, side.to, side.x * BADGE_PAST, side.y * BADGE_PAST)
        else
            tab:SetPoint("CENTER", unit.opener, "CENTER")
        end
        tab.badge:Show()
        tab:Show()
        shown = shown + 1
    end
    return shown
end

-- every button that has a flyout or whose action can lead one
function D.Show()
    D.Hide()
    if InCombatLockdown() then return ShowInFight() end
    local shown = 0
    for _, button in ipairs(Bars.All()) do
        local name = button:GetName()
        if Bars.Used(button) and (F.At(name) or Bars.Action(button)) then
            local tab = Tab(button, name)
            Place(tab, button)
            tab:Show()
            shown = shown + 1
        end
    end
    return shown
end

function D.Tab(name) return tabs[name] end

local function Refresh()
    local kind = GetCursorInfo()
    F.Carrying(kind ~= nil)
    if kind == lastKind then return end
    lastKind = kind
    if kind == "spell" or kind == "item" or kind == "macro" then
        D.Show()
    else
        D.Hide()
    end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "CURSOR_CHANGED", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- the plus is another in a fight: shown afresh for what is carried. A fight's first event
        -- comes a moment before the game calls it one: that one is looked at a moment later.
        lastKind = nil
        D.Hide()
        if event == "PLAYER_REGEN_DISABLED" then return C_Timer.After(0, Refresh) end
    end
    Refresh()
end)
