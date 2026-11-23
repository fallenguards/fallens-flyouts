local _, ns = ...
-- luacheck: read globals CreateFrame UIParent GetCursorPosition InCombatLockdown IsMouseButtonDown GameTooltip GetTime
-- luacheck: read globals GetCursorInfo

-- Turning a flyout. Out of a fight, with the mouse on an open flyout, a
-- grip shows at its far end: the game's own move icon. Pulled to where the
-- flyout should end, the flyout is laid again under the mouse and snaps to
-- the nearest of its shapes: straight out from any side of its button, or
-- lying along a side, running either way, from the button or centered on it. Opened by its key with the mouse
-- elsewhere, a flyout shows no grip: it is not a second arrow to wonder at.
-- Nor is there one while something is carried on the cursor.
local T = {}
ns.Turn = T
local F, Art, Bars = ns.Flyouts, ns.Art, ns.Bars

-- the sides in the order the shapes are stepped through
local SIDES = { "UP", "RIGHT", "DOWN", "LEFT" }
-- the grip: the game's own icon for a thing that is dragged about (its four arrows), else its
-- turn icon, else its flyout arrow, whichever this client knows first
local GRIP_ICONS = { "common-icon-move", "common-icon-rotateright" }
local ARROW_W, ARROW_H, GRIP_OUT, GRIP_OVER = 18, 7, 2, 30
local GRIP = Art.ICON * 2 / 3
-- how often the mouse is looked for, and how long the grip stays once it has left
local LOOK, LINGER = 0.1, 0.4
-- A shape takes over once its mark is this much nearer the mouse than the present one's (of the
-- distances squared: a good fifth nearer), and the mouse has stayed by it this long. Without the wait a
-- pull across the button laid the flyout out at every shape passed on the way.
local NEARER, LINGER_BY = 0.6, 0.08
-- centered on its button a flyout runs one way only: a row to the right, a column down
local CENTERED = { UP = "RIGHT", DOWN = "RIGHT", LEFT = "DOWN", RIGHT = "DOWN" }
local TEXT = {
    tip = "Drag to turn this flyout.",
    fight = F.TEXT.fight,
}
T.TEXT = TEXT

local grip, driver, watch
-- the unit whose flyout is open, and the turn under way
local shown, turning
-- when the mouse was last on the open flyout, its button or the grip
local seenAt

-- a frame's center and half width on the screen, in the screen's own units
local function OnScreen(frame)
    local x, y = frame:GetCenter()
    x, y = Bars.Plain(x), Bars.Plain(y)
    if not (x and y) then return nil end
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * scale, y * scale, frame:GetWidth() * scale / 2, scale
end

-- Every shape a unit's flyout could take, its mark and whether all of it would be on the screen. The
-- mark is where the mouse is pulled to for that shape: where the flyout would end (the middle of its
-- last icon), and for one centered on its button the middle of that side of the button, right by it.
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
    local function Add(sideName, runName, mid)
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
            -- along the side, a strip's width off the button: from the button's own start, or with its
            -- middle at the button's middle
            local off = half - over + wide / 2
            local back = mid and long / 2 or half
            local cx, cy = hx + side.x * off - along.x * back, hy + side.y * off - along.y * back
            x, y = cx + along.x * last, cy + along.y * last
            if mid then x, y = hx + side.x * off, hy + side.y * off end
            local ax, ay = math.abs(side.x) * wide / 2, math.abs(side.y) * wide / 2
            x1, y1 = cx - ax, cy - ay
            x2, y2 = cx + along.x * long + ax, cy + along.y * long + ay
        end
        local fits = math.min(x1, x2) >= 0 and math.max(x1, x2) <= right
            and math.min(y1, y2) >= 0 and math.max(y1, y2) <= top
        out[#out + 1] = { side = sideName, run = runName, mid = mid == true, x = x, y = y, fits = fits,
            key = sideName .. runName .. (mid and "mid" or "") }
    end
    for _, side in ipairs(SIDES) do
        Add(side, side)
        for _, across in ipairs(F.ACROSS[side]) do Add(side, across) end
        Add(side, CENTERED[side], true)
    end
    return out
end

local function Is(shape, unit)
    return shape.side == unit.side and shape.run == unit.way and shape.mid == (unit.mid == true)
end

-- a shape of the player's own, or none when it is the one the bar would give anyway
local function Set(unit, shape, live)
    local straight = shape.side == shape.run
    if straight and shape.side == unit.barWay then return F.SetShape(unit.flyout, nil, nil, live) end
    return F.SetShape(unit.flyout, shape.side, not straight and shape.run or nil, live, shape.mid)
end

local function Place()
    if not (grip and shown) then return end
    local unit = shown
    local side = Art.SIDES[unit.way]
    grip:SetScale(unit.menu:GetEffectiveScale() / UIParent:GetEffectiveScale())
    -- in the flyout's own layer, just over it: a window over the flyout is over its grip too
    grip:SetFrameStrata(unit.menu:GetFrameStrata())
    grip:SetFrameLevel(unit.menu:GetFrameLevel() + GRIP_OVER)
    grip:ClearAllPoints()
    grip:SetPoint(side.point, unit.menu, side.to, side.x * GRIP_OUT, side.y * GRIP_OUT)
    if grip.icon then
        grip.arrow:SetAlpha(grip.over and 1 or 0.8)
    else
        Art.Set(grip.arrow, Art.NAMES[grip.over and "arrowOver" or "arrow"], Art.TURN[unit.way].arrow, ARROW_W, ARROW_H)
    end
end

local function Grip()
    if grip then return grip end
    grip = CreateFrame("Button", nil, UIParent)
    grip:Hide()
    grip:SetFrameStrata("TOOLTIP")
    grip:SetSize(GRIP, GRIP)
    grip.arrow = grip:CreateTexture(nil, "OVERLAY")
    grip.arrow:SetPoint("CENTER")
    for _, atlas in ipairs(GRIP_ICONS) do
        if not grip.icon and Art.Known(atlas) then grip.icon = atlas end
    end
    if grip.icon then
        grip.arrow:SetAtlas(grip.icon)
        grip.arrow:SetSize(GRIP, GRIP)
    end
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
        local x, y = Mouse()
        T.At(x, y, true)
    end)
    return driver
end

-- A turn begins: the flyout follows the mouse from here. Out of a fight.
function T.Start(unit)
    if turning or not (unit and unit.flyout and unit.menu:IsShown()) or unit.radial then return false end
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
-- The mouse is there now: the flyout takes the shape whose mark is nearest. `lingering` (a real pull):
-- only once the mouse has stayed by that mark a moment.
function T.At(x, y, lingering)
    if not turning then return nil end
    local unit = turning.unit
    local best, bestD, nowD
    for _, shape in ipairs(T.Shapes(unit)) do
        local d = (shape.x - x) ^ 2 + (shape.y - y) ^ 2
        if Is(shape, unit) then nowD = d end
        if shape.fits and (not bestD or d < bestD) then best, bestD = shape, d end
    end
    if not best or Is(best, unit) then
        turning.want = nil
        return best
    end
    -- not for a hair's breadth: the flyout would flicker between two
    if nowD and bestD > nowD * NEARER then
        turning.want = nil
        return nil
    end
    if lingering then
        local now = GetTime()
        if turning.want ~= best.key then turning.want, turning.since = best.key, now end
        if now - turning.since < LINGER_BY then return nil end
    end
    turning.want = nil
    if Set(unit, best, true) then
        Place()
        ns.Log(("turn: now %s running %s%s"):format(best.side, best.run, best.mid and ", centered" or ""))
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
    F.SetShape(flyout, flyout.side, flyout.run, nil, flyout.mid)
    ns.Log(("turn: let go, saved as %s %s%s"):format(tostring(flyout.side), tostring(flyout.run),
        flyout.mid and ", centered" or ""))
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

-- whether the mouse is on the open flyout, its bar button or the grip itself
local function Over()
    if not shown then return false end
    if shown.menu:IsMouseOver() or (shown.host and shown.host:IsMouseOver()) then return true end
    return grip ~= nil and grip:IsShown() and grip:IsMouseOver()
end

-- The grip is there while the mouse is on an open flyout out of a fight,
-- and through a turn; it goes a moment after the mouse has left.
function T.Poll()
    local now = GetTime()
    local want = false
    -- a flyout around its button has no end to pull
    if shown and shown.flyout and shown.menu:IsShown() and not shown.radial and not InCombatLockdown() then
        if turning or Over() then seenAt = now end
        want = seenAt ~= nil and now - seenAt <= LINGER
        -- not while something is carried to the flyout or an icon of it is being moved: it is in the way
        if not turning and (GetCursorInfo() ~= nil or (ns.Move and ns.Move.Moving and ns.Move.Moving())) then
            want, seenAt = false, nil
        end
    end
    if want then
        Grip()
        Place()
        grip:Show()
    elseif grip then
        grip:Hide()
    end
    return want
end

-- an open flyout is watched for the mouse; shut, nothing is
local function Offer(unit)
    shown, seenAt = unit, nil
    if not watch then
        watch = CreateFrame("Frame", nil, UIParent)
        watch:Hide()
        watch.wait = 0
        watch:SetScript("OnUpdate", function(self, elapsed)
            self.wait = self.wait + elapsed
            if self.wait < LOOK then return end
            self.wait = 0
            T.Poll()
        end)
    end
    watch:SetShown(unit ~= nil)
    T.Poll()
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
        if shown.flyout and shown.menu:IsShown() then T.Poll() else Offer(nil) end
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
    else
        T.Poll()
    end
end)
