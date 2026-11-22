local _, ns = ...
-- luacheck: read globals C_Texture SpellFlyout unpack CreateFrame

-- The game's own flyout art: names, sizes and turns.
local A = {}
ns.Art = A

-- The game's own flyout, number for number: 30 icons on a 45 button,
-- 9 before the first, 4 between, 8 past the last, a strip 47 wide.
A.BUTTON, A.ICON, A.OVERLAP = 45, 30, 4
A.FIRST, A.NEXT, A.PAD, A.STRIP = 9, 4, 8, 47
-- its small button: mask, frame art, highlight, glow, key text, sweep.
-- The frame art is a ring with its shadow beside it: 35 draws a 31.6 ring.
A.MASK, A.FRAME, A.OVER_W, A.OVER_H, A.GLOW = 45, 35, 31.6, 30.9, 4
A.KEY_X, A.KEY_Y = -3, -4
-- a bar button's own mouseover ring
A.RING_W, A.RING_H = 46, 45
A.SWEEP = { 1.7, -1.7, -1, 1 }
-- one slot's length: the drop target shows it
A.POP = A.FIRST + A.ICON + A.PAD
local TINT = 0.7

A.NAMES = {
    arrow = "UI-HUD-ActionBar-Flyout",
    arrowDown = "UI-HUD-ActionBar-Flyout-Down",
    arrowOver = "UI-HUD-ActionBar-Flyout-Mouseover",
    glow = "UI-HUD-ActionBar-IconFrame-FlyoutBorderShadow",
    first = "UI-HUD-ActionBar-IconFrame-FlyoutBottom",
    last = "UI-HUD-ActionBar-IconFrame-FlyoutButton",
    upright = "!UI-HUD-ActionBar-IconFrame-FlyoutMid",
    level = "_UI-HUD-ActionBar-IconFrame-FlyoutMidLeft",
    -- a button off the bars wears the row frame, as the game's flyout does
    frame = "UI-HUD-ActionBar-IconFrame-AddRow",
    frameDown = "UI-HUD-ActionBar-IconFrame-AddRow-Down",
    frameOver = "UI-HUD-ActionBar-IconFrame-Mouseover",
    mask = "UI-HUD-ActionBar-IconFrame-Mask",
    -- the game's plain disc: tinted, it is a round plate
    disc = "common-mask-circle",
    back = "UI-HUD-ActionBar-IconFrame-Background",
}
local NAMES = A.NAMES

-- quarter turns of strip and arrow, per direction
A.TURN = {
    UP = { ends = 0, mid = 0, arrow = 0 },
    DOWN = { ends = 180, mid = 180, arrow = 180 },
    LEFT = { ends = 270, mid = 180, arrow = 270 },
    RIGHT = { ends = 90, mid = 0, arrow = 90 },
}
-- corners after each turn: UL, LL, UR, LR
A.CUT = {
    [0] = { 0, 0, 0, 1, 1, 0, 1, 1 },
    [90] = { 0, 1, 1, 1, 0, 0, 1, 0 },
    [180] = { 1, 1, 1, 0, 0, 1, 0, 0 },
    [270] = { 1, 0, 0, 0, 1, 1, 0, 1 },
}
-- where a flyout grows from its button
A.SIDES = {
    UP = { point = "BOTTOM", to = "TOP", x = 0, y = 1 },
    DOWN = { point = "TOP", to = "BOTTOM", x = 0, y = -1 },
    LEFT = { point = "RIGHT", to = "LEFT", x = -1, y = 0 },
    RIGHT = { point = "LEFT", to = "RIGHT", x = 1, y = 0 },
}
local PLUS_ART = { "Garr_Building-AddFollowerPlus", "communities-icon-addgroupplus" }
local PLUS_FILE = "Interface\\Buttons\\UI-PlusButton-Up"
local plusArt

function A.Known(atlas)
    return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(atlas) ~= nil
end

-- art in quarter turns; no size means its own
function A.Set(texture, atlas, degrees, w, h)
    texture:SetAtlas(atlas, w == nil)
    if w == nil then
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and info.width and info.height then w, h = info.width, info.height else w, h = texture:GetSize() end
    end
    -- set outright: a texture keeps its last cut, turns would add up
    texture:SetTexCoord(unpack(A.CUT[degrees]))
    if degrees == 90 or degrees == 270 then w, h = h, w end
    texture:SetSize(w, h)
end

-- the strip, read off the game's flyout when present
function A.Strip(frame)
    local live = SpellFlyout and SpellFlyout.Background
    local function Piece(key, atlas)
        local source = live and live[key]
        local piece = frame:CreateTexture(nil, "BACKGROUND")
        -- its own art's name (never a field called atlas: the test client keeps the shown one there)
        piece.art = source and source.GetAtlas and source:GetAtlas() or atlas
        piece:SetVertexColor(TINT, TINT, TINT)
        return piece
    end
    local strip = {
        first = Piece("Start", NAMES.first),
        last = Piece("End", NAMES.last),
        upright = Piece("VerticalMiddle", NAMES.upright),
        level = Piece("HorizontalMiddle", NAMES.level),
    }
    strip.upright:SetVertTile(true)
    strip.level:SetHorizTile(true)
    return strip
end

local OPPOSITE = { UP = "DOWN", DOWN = "UP", LEFT = "RIGHT", RIGHT = "LEFT" }

-- `capped`: the strip does not open onto its button (it lies along the button's side), so its near
-- end is closed like its far end: the end art, turned about.
function A.LayStrip(strip, frame, way, capped)
    local side, turn = A.SIDES[way], A.TURN[way]
    local upright = side.x == 0
    local mid = upright and strip.upright or strip.level
    strip.upright:SetShown(upright)
    strip.level:SetShown(not upright)
    strip.first:ClearAllPoints()
    strip.last:ClearAllPoints()
    mid:ClearAllPoints()
    if capped then
        A.Set(strip.first, strip.last.art, A.TURN[OPPOSITE[way]].ends)
    else
        A.Set(strip.first, strip.first.art, turn.ends)
    end
    strip.capped = capped == true
    A.Set(strip.last, strip.last.art, turn.ends)
    strip.first:Show()
    strip.last:Show()
    A.Set(mid, mid.art, turn.mid)
    strip.first:SetPoint(side.point, frame, side.point)
    strip.last:SetPoint(side.to, frame, side.to)
    mid:SetPoint(side.point, strip.first, side.to)
    mid:SetPoint(side.to, strip.last, side.point)
    for _, piece in ipairs({ strip.first, strip.last, mid }) do
        if upright then piece:SetWidth(A.STRIP) else piece:SetHeight(A.STRIP) end
    end
end

-- A round plate with a rim, behind icons that stand around a button: two of the game's discs, the
-- rim's a little the larger. Its colors are those of the game's own gamepad bar plate.
local RIM, PLATE = { 0.62, 0.6, 0.55 }, { 0.09, 0.07, 0.06 }
A.RIM_W = 2
function A.Disc(owner)
    local disc = {
        rim = owner:CreateTexture(nil, "BACKGROUND", nil, -8),
        fill = owner:CreateTexture(nil, "BACKGROUND", nil, -7),
    }
    disc.known = A.Known(NAMES.disc)
    if disc.known then
        disc.rim:SetAtlas(NAMES.disc)
        disc.fill:SetAtlas(NAMES.disc)
        disc.rim:SetVertexColor(RIM[1], RIM[2], RIM[3])
        disc.fill:SetVertexColor(PLATE[1], PLATE[2], PLATE[3])
    end
    disc.rim:Hide()
    disc.fill:Hide()
    return disc
end
-- the plate that far out from the frame's middle; no radius: none
function A.LayDisc(disc, frame, radius)
    local on = disc.known and radius ~= nil
    disc.rim:SetShown(on)
    disc.fill:SetShown(on)
    disc.radius = on and radius or nil
    if not on then return end
    for piece, r in pairs({ [disc.rim] = radius, [disc.fill] = radius - A.RIM_W }) do
        piece:ClearAllPoints()
        piece:SetPoint("CENTER", frame, "CENTER")
        piece:SetSize(2 * r, 2 * r)
    end
end
-- A mark for a button whose flyout opens around it: four small gold dots in a cross, as the pad's
-- buttons lie. It points no way, where the bar arrow would seem to name a D-pad button.
local DOT, DOT_RIM, DOT_OUT, DOT_IN = 6, 1, 6, 10
local GOLD, DARK = { 1, 0.82, 0.25 }, { 0.08, 0.05, 0.02 }
local DOT_WAYS = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
function A.Dots(owner)
    local dots = { known = A.Known(NAMES.disc), pieces = {} }
    for i = 1, #DOT_WAYS do
        local rim, dot = owner:CreateTexture(nil, "OVERLAY", nil, 5), owner:CreateTexture(nil, "OVERLAY", nil, 6)
        if dots.known then
            rim:SetAtlas(NAMES.disc)
            dot:SetAtlas(NAMES.disc)
            rim:SetVertexColor(DARK[1], DARK[2], DARK[3])
            dot:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
        end
        rim:SetSize(DOT + 2 * DOT_RIM, DOT + 2 * DOT_RIM)
        dot:SetSize(DOT, DOT)
        rim:Hide()
        dot:Hide()
        dots.pieces[i] = { rim = rim, dot = dot }
    end
    return dots
end
-- At the top right corner of that button, or put away. `grown`: how much larger the button is now than
-- when its marks were last laid (the game grows a group of gamepad mode while it is picked).
function A.LayDots(dots, host, on, grown)
    grown = grown or 1
    dots.shown = on == true and dots.known
    for i, piece in ipairs(dots.pieces) do
        piece.rim:SetShown(dots.shown)
        piece.dot:SetShown(dots.shown)
        if dots.shown then
            local x, y = -DOT_IN + DOT_WAYS[i][1] * DOT_OUT, -DOT_IN + DOT_WAYS[i][2] * DOT_OUT
            piece.rim:SetSize((DOT + 2 * DOT_RIM) * grown, (DOT + 2 * DOT_RIM) * grown)
            piece.dot:SetSize(DOT * grown, DOT * grown)
            for _, texture in ipairs({ piece.rim, piece.dot }) do
                texture:ClearAllPoints()
                texture:SetPoint("CENTER", host, "TOPRIGHT", x * grown, y * grown)
            end
        end
    end
end

-- one of a flyout's icons as a picture alone: the icon in the game's small button frame
function A.Token(owner)
    local token = CreateFrame("Frame", nil, owner)
    token:SetSize(A.ICON, A.ICON)
    token.icon = token:CreateTexture(nil, "ARTWORK")
    token.icon:SetAllPoints()
    A.Dress(token, token.icon)
    token.frame = token:CreateTexture(nil, "OVERLAY")
    token.frame:SetAtlas(NAMES.frame)
    token.frame:SetSize(A.FRAME, A.FRAME)
    token.frame:SetPoint("TOPLEFT")
    return token
end

-- no strip at all: a flyout whose icons stand around their button
function A.HideStrip(strip)
    for _, piece in ipairs({ strip.first, strip.last, strip.upright, strip.level }) do piece:Hide() end
end

-- an icon cut to the game's bar button shape
function A.Dress(owner, icon)
    local mask = owner:CreateMaskTexture()
    mask:SetAtlas(NAMES.mask)
    mask:SetSize(A.MASK, A.MASK)
    mask:SetPoint("CENTER", icon)
    icon:AddMaskTexture(mask)
end

-- the game's own plus art, the first it has
function A.Plus(texture, size)
    if plusArt == nil then
        plusArt = false
        for _, atlas in ipairs(PLUS_ART) do
            if not plusArt and A.Known(atlas) then plusArt = atlas end
        end
    end
    if plusArt then texture:SetAtlas(plusArt) else texture:SetTexture(PLUS_FILE) end
    texture:SetSize(size, size)
end
