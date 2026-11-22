local _, ns = ...
-- luacheck: read globals UIParent CreateFrame InCombatLockdown GetCursorPosition IsMouseButtonDown IsModifiedClick
-- luacheck: read globals GameTooltip GetCursorInfo

-- An icon moved inside its flyout, as icons move on a phone's home screen:
-- held, it lifts and grows; the others slide out of its way; it lands in the gap.
local M = {}
ns.Move = M
local F, Art = ns.Flyouts, ns.Art

-- how much the held icon grows, and how fast things move
local GROW, GROW_TIME, SLIDE, LAND_TIME = 1.25, 0.12, 16, 0.12
-- how far off the strip the cursor may stray before the icon is out of it
local REACH = Art.ICON * 0.75
-- a slide this close to its place is there
local NEAR = 0.25

local moving, landing
local lift, driver
local Driver
-- An icon dragged out of its flyout: on the cursor at once, off the flyout when the mouse lets go.
-- Till then its frame stays as it is, unseen. The game's drag lives only while the frame it began on is
-- shown, and with it gone a let-go over a bar button placed nothing: the spot had to be clicked.
local carried

-- the held icon's own picture: the game's small button, with its highlight
local function Lift()
    if lift then return lift end
    lift = CreateFrame("Frame", nil, UIParent)
    lift:Hide()
    lift:SetFrameStrata("TOOLTIP")
    lift:SetSize(Art.ICON, Art.ICON)
    lift.icon = lift:CreateTexture(nil, "ARTWORK")
    lift.icon:SetAllPoints()
    Art.Dress(lift, lift.icon)
    lift.frame = lift:CreateTexture(nil, "OVERLAY")
    lift.frame:SetAtlas(Art.NAMES.frame)
    lift.frame:SetSize(Art.FRAME, Art.FRAME)
    lift.frame:SetPoint("TOPLEFT")
    lift.ring = lift:CreateTexture(nil, "OVERLAY", nil, 1)
    lift.ring:SetAtlas(Art.NAMES.frameOver)
    lift.ring:SetSize(Art.OVER_W, Art.OVER_H)
    lift.ring:SetPoint("TOPLEFT")
    return lift
end

-- the held icon centred on a screen point, at the flyout's size times grow
local function Hold(state, x, y, grow)
    local held = Lift()
    held:SetScale(state.scale * grow)
    local s = held:GetEffectiveScale()
    held:ClearAllPoints()
    held:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
end

-- a frame's centre as a screen point
local function Centre(frame)
    local x, y = frame:GetCenter()
    if not (x and y) then return nil end
    local s = frame:GetEffectiveScale()
    return x * s, y * s
end

-- the place under a screen point; nil when the point is off the flyout
local function Where(unit, x, y)
    local menu = unit.menu
    local left, right, top, bottom = menu:GetLeft(), menu:GetRight(), menu:GetTop(), menu:GetBottom()
    if not (left and right and top and bottom) then return nil end
    local s = menu:GetEffectiveScale()
    x, y = x / s, y / s
    if x < left - REACH or x > right + REACH or y < bottom - REACH or y > top + REACH then return nil end
    local along = y - bottom
    if unit.way == "DOWN" then
        along = top - y
    elseif unit.way == "RIGHT" then
        along = x - left
    elseif unit.way == "LEFT" then
        along = right - x
    end
    local place = math.floor((along - Art.FIRST + Art.NEXT / 2) / (Art.ICON + Art.NEXT)) + 1
    return math.max(1, math.min(#unit.flyout.entries, place))
end
M.Where = Where

-- the place icon j takes while icon `from` is held over place `at`
local function Place(j, from, at)
    local rank = j < from and j or j - 1
    return rank < at and rank or rank + 1
end

-- every icon a step nearer its place; true while any is still on its way
local function Slide(unit, elapsed, from, at)
    local busy = false
    local step = math.min(1, elapsed * SLIDE)
    for j, frame in ipairs(unit.entries) do
        if j ~= from and unit.flyout.entries[j] then
            local want = F.Slot(from and Place(j, from, at) or j)
            local now = frame.slide or F.Slot(j)
            if now ~= want then
                now = now + (want - now) * step
                if math.abs(want - now) < NEAR then now = want end
                frame.slide = now
                F.Put(unit, frame, now)
                busy = busy or now ~= want
            end
        end
    end
    return busy
end

-- every icon seen again and back in its own place
local function Still(unit)
    local locked = InCombatLockdown()
    for j, frame in ipairs(unit.entries) do
        frame:SetAlpha(1)
        frame.slide = nil
        if not locked and unit.flyout and unit.flyout.entries[j] then F.Put(unit, frame, F.Slot(j)) end
    end
    -- a fight began mid-move: the layout is set right when it ends
    if locked then F.Apply() end
end

local function Finish()
    local was = landing
    landing = nil
    if lift then lift:Hide() end
    if was then Still(was.unit) end
end

-- lets go without moving anything; an icon on its way out stays in its flyout
function M.Cancel()
    local was = moving
    moving = nil
    if was then
        if lift then lift:Hide() end
        Still(was.unit)
    end
    if carried then
        was, carried = carried, nil
        Still(was.unit)
    end
    if landing then Finish() end
end

function M.Moving() return moving end
function M.Landing() return landing end
function M.Carried() return carried end

-- The mouse let go of an icon dragged out: the game has placed it by now, or not, and it comes off its
-- flyout.
local function EndCarry()
    local was = carried
    carried = nil
    if not was then return end
    local unit, at = F.UnitOf(was.flyout), nil
    for i, entry in ipairs(was.flyout.entries) do
        if entry == was.entry then at = i end
    end
    ns.Log(("move: %s the mouse let go of the icon dragged out; the cursor holds %s"):format(tostring(was.flyout.host),
        tostring((GetCursorInfo()) or "nothing")))
    -- every frame seen again first: the one kept unseen shows the next icon once this one is off
    Still(was.unit)
    if unit and at and not InCombatLockdown() then F.TakeOff(unit, at) end
end

-- Dropped back on the plus of its own flyout's button while on its way out: it stays where it was.
function M.PutBack(flyout)
    local was = carried
    if not (was and was.flyout == flyout) then return false end
    carried = nil
    Still(was.unit)
    ns.Log(("move: %s the icon dragged out was put back on its own button"):format(tostring(flyout.host)))
    return true
end

-- let go: the icon lands in the gap, the rest stay where they slid to
function M.Drop()
    local was = moving
    if not was then return false end
    local unit, flyout, from, at = was.unit, was.flyout, was.from, was.at
    -- where each icon is drawn just now, by the place it ends in
    local drawn = {}
    for j, frame in ipairs(unit.entries) do
        if j ~= from and frame.slide then drawn[Place(j, from, at)] = frame.slide end
    end
    moving = nil
    for _, frame in ipairs(unit.entries) do
        frame:SetAlpha(1)
        frame.slide = nil
    end
    local ok, why = F.Move(flyout, from, at)
    unit = ok and F.UnitOf(flyout)
    if not unit then
        if lift then lift:Hide() end
        Still(was.unit)
        if why then ns.Warn(why) end
        return false
    end
    ns.Log(("move: %s from place %d to %d"):format(tostring(flyout.host), from, at))
    landing = { unit = unit, at = at, x = was.x, y = was.y, grown = was.grown, scale = was.scale, t = 0 }
    for place, out in pairs(drawn) do
        if unit.entries[place] then unit.entries[place].slide = out end
    end
    unit.entries[at]:SetAlpha(0)
    return true
end

-- the gap goes to that place; nil takes the icon out, onto the cursor
function M.Aim(place)
    local was = moving
    if not was then return end
    if place then
        was.at = place
        return
    end
    M.Cancel()
    ns.Log(("move: %s place %d dragged out"):format(tostring(was.flyout.host), was.from))
    local entry = was.flyout.entries[was.from]
    -- a move run by code, and a flyout that gives nothing up: off at once, or refused, as ever
    if was.driven or was.flyout.auto or not entry then
        F.CarryOff(was.unit, was.from)
        return
    end
    F.Pickup(entry)
    carried = { unit = was.unit, flyout = was.flyout, entry = entry }
    was.unit.entries[was.from]:SetAlpha(0)
    Driver():Show()
end

-- the held icon is at that screen point now
function M.At(x, y)
    if not moving then return end
    moving.x, moving.y = x, y
    M.Aim(Where(moving.unit, x, y))
end

-- one frame of growing, sliding and landing
function M.Step(elapsed)
    if (moving or landing) and InCombatLockdown() then return M.Cancel() end
    if moving then
        moving.grown = math.min(1, moving.grown + elapsed / GROW_TIME)
        Slide(moving.unit, elapsed, moving.from, moving.at)
        Hold(moving, moving.x, moving.y, 1 + (GROW - 1) * moving.grown)
    elseif landing then
        local l = landing
        l.t = l.t + elapsed
        local done = math.min(1, l.t / LAND_TIME)
        local busy = Slide(l.unit, elapsed)
        local x, y = Centre(l.unit.entries[l.at])
        if x then x, y = l.x + (x - l.x) * done, l.y + (y - l.y) * done else x, y = l.x, l.y end
        Hold(l, x, y, 1 + (GROW - 1) * l.grown * (1 - done))
        if done >= 1 and not busy then Finish() end
    elseif driver and not carried then
        driver:Hide()
    end
end

function Driver()
    if driver then return driver end
    driver = CreateFrame("Frame", nil, UIParent)
    driver:Hide()
    driver:SetScript("OnUpdate", function(_, elapsed) M.Tick(elapsed) end)
    return driver
end

-- one frame: a move begun by the mouse follows it, and ends when it lets go
function M.Tick(elapsed)
    if moving and not moving.driven then
        if IsMouseButtonDown("LeftButton") then M.At(GetCursorPosition()) else M.Drop() end
    end
    if carried then
        -- the frame after the let-go: the game's own drop has been dealt with by then
        if carried.let then
            EndCarry()
        elseif not IsMouseButtonDown("LeftButton") then
            carried.let = true
        end
    end
    M.Step(elapsed)
end

-- A drag began on a flyout icon. Bars locked want the pick up key held, as
-- the game's bars do. `driven` is a move run by code: no mouse is read.
function M.Start(frame, driven)
    local unit, i = frame.flyoutUnit, frame.entryIndex
    local flyout = unit and unit.flyout
    if moving or not (flyout and flyout.entries[i]) then return false end
    -- icons around their button have no line to slide along: gamepad mode's Edit Flyout places them
    if unit.radial then return false end
    if not driven and F.BarsLocked() and not IsModifiedClick("PICKUPACTION") then return false end
    if InCombatLockdown() then
        ns.Warn(F.TEXT.fight)
        return false
    end
    if landing then Finish() end
    GameTooltip:Hide()
    if ns.Keys then ns.Keys.Leave() end
    local x, y = Centre(frame)
    if not x then x, y = GetCursorPosition() end
    moving = { unit = unit, flyout = flyout, from = i, at = i, driven = driven, x = x, y = y, grown = 0,
        scale = unit.menu:GetEffectiveScale() / UIParent:GetEffectiveScale() }
    frame:SetAlpha(0)
    local held = Lift()
    held.icon:SetTexture(F.Icon(flyout.entries[i]))
    Hold(moving, x, y, 1)
    held:Show()
    Driver():Show()
    ns.Log(("move: %s place %d lifted"):format(tostring(flyout.host), i))
    return true
end

-- the mouse let go of a drag
function M.Released()
    if moving and not moving.driven then M.Drop() end
    if carried then carried.let = true end
end

-- a flyout shut under a move ends it where it stands
F.Watch(function(what, unit)
    if what ~= "shut" then return end
    if moving and moving.unit == unit then M.Cancel() end
    if landing and landing.unit == unit then Finish() end
end)

-- nothing in a flyout changes in a fight: this is the last moment to set it back
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() M.Cancel() end)
