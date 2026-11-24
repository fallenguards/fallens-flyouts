local _, ns = ...
-- luacheck: read globals UIParent CreateFrame InCombatLockdown GetCursorPosition IsMouseButtonDown IsModifiedClick
-- luacheck: read globals GameTooltip GetCursorInfo ClearCursor

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
-- something carried, its flyout open for it with a gap where it would go (further down)
local preview
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
    elseif driver and not carried and not preview then
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

-- Something carried onto the plus of a button whose flyout runs as a strip: the flyout opens, the strip one
-- icon longer, and what is carried shows faintly in a gap where it would go, at the end to begin with, as a
-- drop on the plus has always put it there.
-- His words (2026-11-24): "is there a reason when adding spells to an existing flyout we don't show the
-- full preview so we can decide what order to put it in right away??", and of how a drop chooses between
-- putting it in and taking an icon's place, over the middle of an icon replacing it and anywhere else
-- putting it in: "obviously yes the way you said it.."
-- Off the plus, the gap follows the cursor along the strip and the icons part around it, as when an icon is
-- moved inside its flyout; over the middle of an icon that icon lights up instead, and a drop there takes
-- its place, as on a bar slot. Out of a fight, and not for icons around their button (no line to slide
-- along) nor a flyout that fills itself.
local catcher, ghost
-- As a phone's home screen does it, between dropping into an app and moving apps about. His words
-- (2026-11-24), of the first tuning, where an edge of an icon moved the gap at once: "when i try to replace,
-- it just bounces out of my way", then "honestly i feel like this is basically standard with app movement
-- on phones, no? ... so maybe we just need to tune our sensitvity." The way to an icon's middle crosses its
-- edge first, so nothing moves the moment the cursor passes: the icons part only after it rests between
-- two of them for REST seconds, and most of an icon (all but RIM of it at each end) takes a drop as a
-- replacement at once.
local RIM, REST = 0.15, 0.3
-- how long the cursor may be off the plus and the flyout before the flyout shuts again
local AWAY = 0.25
-- the catcher's reach past the strip, in the strip's measure
local CATCH = 12

local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:Hide()
    ghost:SetSize(Art.ICON, Art.ICON)
    ghost.back = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.back:SetAtlas(Art.NAMES.back)
    ghost.back:SetAllPoints()
    ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
    ghost.icon:SetAllPoints()
    Art.Dress(ghost, ghost.icon)
    ghost.frame = ghost:CreateTexture(nil, "OVERLAY")
    ghost.frame:SetAtlas(Art.NAMES.frame)
    ghost.frame:SetSize(Art.FRAME, Art.FRAME)
    ghost.frame:SetPoint("TOPLEFT")
    return ghost
end

-- the place in the strip a point is at, as a number of places from its start (0.5 the first icon's middle),
-- nil off the strip
local function Along(unit, x, y)
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
    return (along - Art.FIRST + Art.NEXT / 2) / (Art.ICON + Art.NEXT)
end

-- where icon j is laid while the gap is at `gap` (no gap: in its own place)
local function Parted(j, gap)
    if not gap or j < gap then return j end
    return j + 1
end

-- What a drop does with the cursor at that point, the layout as drawn: over an icon's body that icon is to
-- be replaced; on the gap, it goes into the gap; between two icons (`between`, the place it would take) it
-- goes in there, and after a rest there the gap moves there and the icons part.
local function Aim(p, x, y, elapsed)
    -- on the plus it came by, till it first leaves it: the end
    if not p.left then
        local dx, dy = x - p.px, y - p.py
        if dx * dx + dy * dy <= p.pr * p.pr then return end
        p.left = true
    end
    local r = Along(p.unit, x, y)
    if not r then
        p.target, p.between = nil, nil
        return
    end
    local slots = p.n + (p.full and 0 or 1)
    local s, f
    if r >= slots then
        s, f = slots, 1
    else
        r = math.max(0, r)
        s = math.floor(r) + 1
        f = r - (s - 1)
    end
    -- the icon drawn at that place; none on the gap
    local icon = s
    if not p.full then
        if s == p.gap then icon = nil elseif s > p.gap then icon = s - 1 end
    end
    if not icon then
        p.target, p.between, p.rest = nil, nil, 0
        return
    end
    if f > RIM and f < 1 - RIM then
        p.target, p.between, p.rest = icon, nil, 0
        return
    end
    p.target = nil
    if p.full then
        p.between = nil
        return
    end
    -- before this icon, or after it
    local at = f <= RIM and icon or icon + 1
    if at == p.gap then
        p.between, p.rest = nil, 0
        return
    end
    if p.between ~= at then p.between, p.rest = at, 0 end
    p.rest = p.rest + (elapsed or 0)
    if p.rest >= REST then p.gap, p.between, p.rest = at, nil, 0 end
end

-- one frame of the icons parting round the gap, the gap's icon in it, and the icon to be replaced lit
local function Lay(p, elapsed)
    local unit = p.unit
    local step = math.min(1, (elapsed or 1) * SLIDE)
    for j, frame in ipairs(unit.entries) do
        if unit.flyout.entries[j] then
            local want = F.Slot(Parted(j, not p.full and p.gap or nil))
            local now = frame.slide or F.Slot(j)
            if now ~= want then
                now = now + (want - now) * step
                if math.abs(want - now) < NEAR then now = want end
                frame.slide = now
                F.Put(unit, frame, now)
            end
            if j == p.target then frame:LockHighlight() else frame:UnlockHighlight() end
        end
    end
    local shade = Ghost()
    shade:SetShown(not p.full and p.target == nil)
    if not p.full then F.Put(unit, shade, F.Slot(p.gap)) end
end

-- the flyout as it was: every icon in its place, the strip its length, the gap and its icon gone
local function Unpart(p)
    local unit = p.unit
    for j, frame in ipairs(unit.entries) do
        frame.slide = nil
        frame:UnlockHighlight()
        if unit.flyout.entries[j] then F.Put(unit, frame, F.Slot(j)) end
    end
    if p.w then unit.menu:SetSize(p.w, p.h) end
    if ghost then ghost:Hide() end
    if catcher then catcher:Hide() end
    p.tab.badge:Show()
end

-- `keep`: the flyout stays open, for what the drop does next
function M.PreviewEnd(keep)
    local p = preview
    if not p then return end
    preview = nil
    if not InCombatLockdown() then
        Unpart(p)
        if not keep then F.Shut() end
    else
        if ghost then ghost:Hide() end
        if catcher then catcher:Hide() end
        F.Apply()
    end
    ns.Log(("preview: %s ended"):format(tostring(p.flyout.host)))
end
function M.Preview() return preview end

-- A drop on the plus or on the open flyout: into the gap, or in the place of the icon lit.
function M.PreviewDrop()
    local p = preview
    if not p then return false end
    if InCombatLockdown() or not GetCursorInfo() then
        M.PreviewEnd()
        return true
    end
    local entry = ns.Drop.Carried()
    if p.target then
        local frame = p.unit.entries[p.target]
        M.PreviewEnd(true)
        F.Dropped(frame)
        return true
    end
    if p.full or not entry then
        M.PreviewEnd()
        ns.Warn(p.full and F.TEXT.full or ns.Drop.TEXT.kind)
        return true
    end
    -- between two icons that have not parted yet: in there all the same
    local gap, button = p.between or p.gap, p.button
    M.PreviewEnd(true)
    local flyout, why = F.Stack(button, entry)
    if not flyout then
        F.Shut()
        ns.Warn(why)
        return true
    end
    ClearCursor()
    -- it went in last: to the gap
    local at
    for i, other in ipairs(flyout.entries) do
        if F.Same(other, entry) then at = i end
    end
    if at and gap < at then F.Move(flyout, at, gap) end
    ns.Log(("preview: %s took it at place %d"):format(tostring(flyout.host), math.min(gap, at or gap)))
    -- left open, to see it there
    local unit = F.UnitOf(flyout)
    if unit then F.Show(unit.index) end
    return true
end

local function Catcher()
    if catcher then return catcher end
    catcher = CreateFrame("Frame", nil, UIParent)
    catcher:Hide()
    catcher:SetFrameStrata("TOOLTIP")
    catcher:SetFrameLevel(8000)
    catcher:EnableMouse(true)
    catcher:SetScript("OnReceiveDrag", function() M.PreviewDrop() end)
    catcher:SetScript("OnMouseUp", function() M.PreviewDrop() end)
    return catcher
end

-- one frame: the gap follows the cursor; the cursor away a while, or nothing carried, it ends
local function PreviewTick(elapsed)
    local p = preview
    if InCombatLockdown() or not GetCursorInfo() then return M.PreviewEnd() end
    if catcher:IsMouseOver() or p.tab:IsMouseOver() then
        p.away = 0
    else
        p.away = p.away + elapsed
        if p.away > AWAY then return M.PreviewEnd() end
    end
    local x, y = GetCursorPosition()
    Aim(p, x, y, elapsed)
    Lay(p, elapsed)
end

-- the cursor came onto a plus: true where its flyout is shown so
function M.PreviewStart(tab)
    if preview or moving or carried or landing or InCombatLockdown() then return false end
    local flyout, unit = F.At(tab.host)
    if not (flyout and unit and unit.host and not unit.radial and not flyout.auto) then return false end
    local entry = ns.Drop.Carried()
    if not entry then return false end
    local n = #flyout.entries
    local full = #F.Full(flyout) >= F.MAX
    F.Show(unit.index)
    local px, py = Centre(tab)
    if not px then px, py = GetCursorPosition() end
    local w, h = tab:GetSize()
    local p = { unit = unit, flyout = flyout, button = tab.button, tab = tab, n = n, full = full, gap = n + 1,
        px = px, py = py, pr = math.max(w, h) / 2 * tab:GetEffectiveScale(), away = 0 }
    preview = p
    -- the strip one icon longer, for the gap
    if not full then
        local menu = unit.menu
        p.w, p.h = menu:GetSize()
        local more = Art.ICON + Art.NEXT
        if unit.way == "UP" or unit.way == "DOWN" then menu:SetHeight(p.h + more) else menu:SetWidth(p.w + more) end
    end
    local shade = Ghost()
    p.ghost = shade
    shade:SetParent(unit.menu)
    shade:SetFrameLevel(unit.menu:GetFrameLevel() + 2)
    shade:SetAlpha(0.6)
    shade.icon:SetTexture(F.Icon(entry))
    local catch = Catcher()
    p.catcher = catch
    catch:ClearAllPoints()
    local s = unit.menu:GetEffectiveScale() / catch:GetEffectiveScale()
    catch:SetPoint("TOPLEFT", unit.menu, "TOPLEFT", -CATCH * s, CATCH * s)
    catch:SetPoint("BOTTOMRIGHT", unit.menu, "BOTTOMRIGHT", CATCH * s, -CATCH * s)
    catch:Show()
    Lay(p)
    Driver():Show()
    ns.Log(("preview: %s open for %s, the gap at place %d"):format(tostring(flyout.host), tostring(entry.kind), n + 1))
    return true
end

-- one frame: a move begun by the mouse follows it, and ends when it lets go
function M.Tick(elapsed)
    if preview then PreviewTick(elapsed) end
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
    -- icons around their button have no line to slide along: they are arranged in the settings
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
    if preview and preview.unit == unit then M.PreviewEnd(true) end
    if moving and moving.unit == unit then M.Cancel() end
    if landing and landing.unit == unit then Finish() end
end)

-- nothing in a flyout changes in a fight: this is the last moment to set it back
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function()
    M.Cancel()
    M.PreviewEnd()
end)
