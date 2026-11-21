local _, ns = ...
-- luacheck: read globals C_Texture SpellFlyout unpack

-- The game's own flyout art: names, sizes and turns.
local A = {}
ns.Art = A

-- The game's own flyout, number for number: 30 icons on a 45 button,
-- 9 before the first, 4 between, 8 past the last, a strip 47 wide.
A.BUTTON, A.ICON, A.OVERLAP = 45, 30, 4
A.FIRST, A.NEXT, A.PAD, A.STRIP = 9, 4, 8, 47
-- its small button: mask, frame art, highlight, glow, key text, sweep
A.MASK, A.FRAME, A.OVER_W, A.OVER_H, A.GLOW = 45, 35, 31.6, 30.9, 4
A.KEY_X, A.KEY_Y = -3, -4
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
    frame = "UI-HUD-ActionBar-IconFrame",
    frameDown = "UI-HUD-ActionBar-IconFrame-Down",
    frameOver = "UI-HUD-ActionBar-IconFrame-Mouseover",
    mask = "UI-HUD-ActionBar-IconFrame-Mask",
    slot = "ui-hud-actionbar-iconframe-slot",
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
        piece.atlas = source and source.GetAtlas and source:GetAtlas() or atlas
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

function A.LayStrip(strip, frame, way)
    local side, turn = A.SIDES[way], A.TURN[way]
    local upright = side.x == 0
    local mid = upright and strip.upright or strip.level
    strip.upright:SetShown(upright)
    strip.level:SetShown(not upright)
    strip.first:ClearAllPoints()
    strip.last:ClearAllPoints()
    mid:ClearAllPoints()
    A.Set(strip.first, strip.first.atlas, turn.ends)
    A.Set(strip.last, strip.last.atlas, turn.ends)
    A.Set(mid, mid.atlas, turn.mid)
    strip.first:SetPoint(side.point, frame, side.point)
    strip.last:SetPoint(side.to, frame, side.to)
    mid:SetPoint(side.point, strip.first, side.to)
    mid:SetPoint(side.to, strip.last, side.point)
    for _, piece in ipairs({ strip.first, strip.last, mid }) do
        if upright then piece:SetWidth(A.STRIP) else piece:SetHeight(A.STRIP) end
    end
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
