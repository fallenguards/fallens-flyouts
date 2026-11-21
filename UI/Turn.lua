local _, ns = ...
-- luacheck: read globals CreateFrame UIParent GetCursorPosition InCombatLockdown IsMouseButtonDown GameTooltip

-- Turning a flyout. Out of a fight an open flyout shows a grip at its far
-- end. Pulled to where the flyout should end, the flyout is laid again under
-- the mouse and snaps to the nearest of its shapes: straight out from any
-- side of its button, or lying along a side, running either way.
local T = {}
ns.Turn = T
local F, Art, Bars = ns.Flyouts, ns.Art, ns.Bars

-- the sides in the order the shapes are stepped through
local SIDES = { "UP", "RIGHT", "DOWN", "LEFT" }
-- the grip: the game's flyout arrow, in a square that is easy to catch
local ARROW_W, ARROW_H, GRIP_OUT = 18, 7, 2
local GRIP = Art.ICON * 2 / 3
-- a shape takes over once its end is this much nearer the mouse than the present one's
local NEARER = 0.8
local TEXT = {
    tip = "Drag to turn this flyout.",
    fight = F.TEXT.fight,
}
T.TEXT = TEXT

local grip, driver
-- the unit whose flyout is open, and the turn under way
local shown, turning

-- a frame's center and half width on the screen, in the screen's own units
local function OnScreen(frame)
    local x, y = frame:GetCenter()
    x, y = Bars.Plain(x), Bars.Plain(y)
    if not (x and y) then return nil end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale, y * scale, frame:GetWidth() * scale / 2, scale
end

-- Every shape a unit's flyout could take: where it would end (the middle of
-- its last icon) and whether all of it would be on the screen.
function T.Shapes(unit)
    local out = {}
    local hx, hy, half = OnScreen(unit.host)
    if not hx then return out end
    local ms = unit.menu:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local count = #unit.flyout.entries
    local long = (Art.FIRST + count * Art.ICON + (count - 1) * Art.NEXT + Art.PAD) * ms
    local last = (Art.FIRST + (count - 1) * (Art.ICON + Art.NEXT) + Art.ICON / 2) * ms
    local wide, over = Art.STRIP * ms, Art.OVERLAP * ms
    local right, top = UIParent:GetWidth(), UIParent:GetHeight()
    local function Add(sideName, runName)
        local side, along = Art.SIDES[sideName], Art.SIDES[runName]
        local x, y, x1, y1, x2, y2
        if sideName == runName then
            -- straight out: from the button's edge, as wide as the strip
            local from = half - over
            x, y = hx + side.x * (from + last), hy + side.y * (from + last)
            local ax, ay = math.abs(side.y) * wide / 2, math.abs(side.x) * wide / 2
            x1, y1 = hx + side.x * from - ax, hy + side.y * from - ay
            x2, y2 = hx + side.x * (from + long) + ax, hy + side.y * (from + long) + ay
        else
            -- along the side: a strip's width off the button, from the button's own start
            local off = half - over + wide / 2
            local cx, cy = hx + side.x * off - along.x * half, hy + side.y * off - along.y * half
            x, y = cx + along.x * last, cy + along.y * last
            local ax, ay = math.abs(side.x) * wide / 2, math.abs(side.y) * wide / 2
            x1, y1 = cx - ax, cy - ay
            x2, y2 = cx + along.x * long + ax, cy + along.y * long + ay
        end
        local fits = math.min(x1, x2) >= 0 and math.max(x1, x2) <= right
            and math.min(y1, y2) >= 0 and math.max(y1, y2) <= top
        out[#out + 1] = { side = sideName, run = runName, x = x, y = y, fits = fits }
    end
    for _, side in ipairs(SIDES) do
        Add(side, side)
        for _, across in ipairs(F.ACROSS[side]) do Add(side, across) end
    end
    return out
end

local function Is(shape, unit) return shape.side == unit.side and shape.run == unit.way end

-- a shape of the player's own, or none when it is the one the bar would give anyway
local function Set(unit, shape, live)
    local straight = shape.side == shape.run
    if straight and shape.side == unit.barWay then return F.SetShape(unit.flyout, nil, nil, live) end
    return F.SetShape(unit.flyout, shape.side, not straight and shape.run or nil, live)
end

local function Place()
    if not (grip and shown) then return end
    local unit = shown
    local side = Art.SIDES[unit.way]
    grip:SetScale(unit.menu:GetEffectiveScale() / UIParent:GetEffectiveScale())
    grip:ClearAllPoints()
    grip:SetPoint(side.point, unit.menu, side.to, side.x * GRIP_OUT, side.y * GRIP_OUT)
    Art.Set(grip.arrow, Art.NAMES[grip.over and "arrowOver" or "arrow"], Art.TURN[unit.way].arrow, ARROW_W, ARROW_H)
end

local function Grip()
    if grip then return grip end
    grip = CreateFrame("Button", nil, UIParent)
    grip:Hide()
    grip:SetFrameStrata("TOOLTIP")
    grip:SetSize(GRIP, GRIP)
    grip.arrow = grip:CreateTexture(nil, "OVERLAY")
    grip.arrow:SetPoint("CENTER")
    grip:SetScript("OnEnter", function(self)
        self.over = true
        Place()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TEXT.tip)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function(self)
        self.over = nil
        Place()
        GameTooltip:Hide()
    end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and shown then T.Start(shown) end
    end)
    grip:SetScript("OnMouseUp", function() T.Stop() end)
    return grip
end
function T.Grip() return grip end

-- the mouse on the screen, in the screen's own units
local function Mouse()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function Driver()
    if driver then return driver end
    driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    driver:SetScript("OnUpdate", function()
        if not turning then return driver:Hide() end
        if not IsMouseButtonDown("LeftButton") then return T.Stop() end
        T.At(Mouse())
    end)
    return driver
end

-- A turn begins: the flyout follows the mouse from here. Out of a fight.
function T.Start(unit)
    if turning or not (unit and unit.flyout and unit.menu:IsShown()) then return false end
    if InCombatLockdown() then
        ns.Warn(TEXT.fight)
        return false
    end
    if ns.Move and ns.Move.Moving and ns.Move.Moving() then return false end
    turning = { unit = unit, flyout = unit.flyout }
    GameTooltip:Hide()
    Driver():Show()
    ns.Log(("turn: %s grabbed, it opens %s running %s"):format(tostring(unit.flyout.host), tostring(unit.side),
        tostring(unit.way)))
    return true
end

-- The mouse is at x, y: the shape whose end is nearest takes over, laid at once.
function T.At(x, y)
    if not turning then return nil end
    local unit = turning.unit
    local best, bestD, nowD
    for _, shape in ipairs(T.Shapes(unit)) do
        local d = (shape.x - x) ^ 2 + (shape.y - y) ^ 2
        if Is(shape, unit) then nowD = d end
        if shape.fits and (not bestD or d < bestD) then best, bestD = shape, d end
    end
    if not best or Is(best, unit) then return best end
    -- not for a hair's breadth: the flyout would flicker between two
    if nowD and bestD > nowD * NEARER then return nil end
    if Set(unit, best, true) then
        Place()
        ns.Log(("turn: now %s running %s"):format(best.side, best.run))
    end
    return best
end

-- The grip is let go: the shape stays, and the flyout is open as it was.
function T.Stop()
    if not turning then return false end
    local unit = turning.unit
    turning = nil
    if driver then driver:Hide() end
    if InCombatLockdown() then return false end
    local flyout = unit.flyout
    -- laid for good: its keys and the D-pad follow the way it runs now
    F.SetShape(flyout, flyout.side, flyout.run)
    ns.Log(("turn: let go, saved as %s %s"):format(tostring(flyout.side), tostring(flyout.run)))
    return true
end

function T.Turning() return turning ~= nil end

-- The next shape that fits, for those with no mouse to pull the grip: a
-- flyout on the bars is stepped through its shapes one press at a time.
function T.Next(flyout)
    if InCombatLockdown() then return false, TEXT.fight end
    local unit = flyout and F.UnitOf(flyout)
    if not unit then return false end
    local shapes = T.Shapes(unit)
    local at = 0
    for i, shape in ipairs(shapes) do
        if Is(shape, unit) then at = i end
    end
    for step = 1, #shapes do
        local shape = shapes[(at + step - 1) % #shapes + 1]
        if shape.fits then
            Set(unit, shape, false)
            return true, shape
        end
    end
    return false
end

-- the grip comes and goes with the open flyout; it is never there in a fight
local function Offer(unit)
    shown = unit
    if InCombatLockdown() or not unit then
        if grip then grip:Hide() end
        return
    end
    Grip()
    Place()
    grip:Show()
end

F.Watch(function(what, unit)
    if what == "open" then
        Offer(unit)
    elseif what == "shut" then
        if turning and turning.unit == unit then
            turning = nil
            if driver then driver:Hide() end
        end
        if shown == unit then Offer(nil) end
    elseif what == "laid" and shown and not turning then
        if shown.flyout and shown.menu:IsShown() then Place() else Offer(nil) end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        -- nothing is laid in a fight: a turn under way stays where it got to
        turning = nil
        if driver then driver:Hide() end
        if grip then grip:Hide() end
    elseif shown and shown.menu:IsShown() then
        Offer(shown)
    end
end)
