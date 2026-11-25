local _, ns = ...
-- luacheck: read globals UIParent CreateFrame GetTime InCombatLockdown C_Timer C_Spell C_Item GetMacroInfo
-- luacheck: read globals SetOverrideBindingClick ClearOverrideBindings GameTooltip C_GamePad GetBindingText
-- luacheck: read globals issecretvalue C_CVar C_Container GetMacroSpell GetMacroItem IsUsableItem geterrorhandler
-- luacheck: read globals Settings IsModifiedClick GetModifiedClick PickupSpell PickupItem PickupMacro IsMouseButtonDown
-- luacheck: read globals PlaceAction ClearCursor GetCursorInfo GetActionInfo
-- luacheck: read globals IsBindingForGamePad GetBindingKey GetNumBindings GetBinding ACTIONBAR_HOTKEY_FONT_COLOR
-- luacheck: read globals RED_FONT_COLOR RANGE_INDICATOR UnitExists C_ActionBar IsActionInRange IsUsableAction
-- luacheck: read globals RegisterStateDriver C_ToyBox C_MountJournal

-- Flyouts on bar buttons. One secure root owns every key.
local F = {}
ns.Flyouts = F
local P, Bars, Art, Binds, Macros = ns.Profiles, ns.Bars, ns.Art, ns.Binds, ns.Macros

-- A flyout holds as many as a bar has buttons, and picks with the bar's own keys: twelve, for those
-- with a mouse of twelve buttons as much as for the keyboard's number row.
local MAX = 12
local KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=" }
local PADS = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD3" }
-- Pad buttons go by where an icon sits: the two ends take the D-pad along
-- the flyout's line (top is up, bottom is down), the ones between the rest.
-- the D-pad by where an icon lies, then the face buttons for places past it
local PAD_PAST = { "PAD4", "PAD3" }
local PAD_UPRIGHT = { first = "PADDUP", last = "PADDDOWN", between = { "PADDRIGHT", "PADDLEFT" }, past = PAD_PAST }
local PAD_LEVEL = { first = "PADDLEFT", last = "PADDRIGHT", between = { "PADDUP", "PADDDOWN" }, past = PAD_PAST }
-- the D-pad has four directions
local DPAD = 4
-- The pad's two crosses of four, each from the top round by the right, and the button on the same side
-- of the other cross. A flyout around its button has its icons in that order, on those sides.
local DPAD_RING = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT" }
local FACE_RING = { "PAD4", "PAD2", "PAD1", "PAD3" }
local PADS_ALL = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD3", "PAD2", "PAD1" }
local OTHER_CROSS = { PADDUP = "PAD4", PADDRIGHT = "PAD2", PADDDOWN = "PAD1", PADDLEFT = "PAD3",
    PAD4 = "PADDUP", PAD2 = "PADDRIGHT", PAD1 = "PADDDOWN", PAD3 = "PADDLEFT" }
-- the ways the four of a ring lie from the button, and the room between the button and a ring
local RING = { { 0, 1 }, { 1, 0 }, { 0, -1 }, { -1, 0 } }
local RING_GAP = 6
-- how far the round plate behind them reaches past the outmost icons
local PLATE_PAD = 7
-- the pad symbol's size on a flyout icon
local GLYPH = 11
-- a controller's label style, as the game's key strings end
local PAD_STYLES = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }
local CLOSE_KEYS = { "ESCAPE", "PAD2" }
local ROOT, OPENER = "FallensFlyoutsRoot", "FallensFlyoutsOpener"
local MENU, ENTRY = "FallensFlyoutsMenu", "FallensFlyoutsEntry"
-- the game's arrow: 18 by 7, 4 out when shut, 2 when open
local ARROW_W, ARROW_H, ARROW_OUT, ARROW_OPEN, GRIP_W, GRIP_H, GRIP_OUT = 18, 7, 4, 2, 30, 14, 3
-- how many levels over its bar button the grip stands
local GRIP_OVER = 10
-- flyout size against the game's own, as a setting
local SIZE_MIN, SIZE_MAX = 0.5, 2
local TEXT = {
    fight = "Flyouts change only out of a fight.",
    full = "That flyout is full.",
    twice = "That is in the flyout already.",
    noPick = "That one cannot be picked up just now.",
    noLead = "That button's action cannot lead a flyout.",
    auto = "That flyout fills itself.",
    mount = "Mounts, pets and gear sets go in a flyout out of combat.",
    how = "Drag",
    howHeld = "%s-drag",
    remove = "%s to move it, or off the flyout to take it off.",
    removeLast = "%s to move it, or off the flyout to take it off, and the flyout with it: nothing else was added.",
    it = "It",
}
F.MAX, F.KEYS, F.PADS, F.CLOSE_KEYS, F.TEXT = MAX, KEYS, PADS, CLOSE_KEYS, TEXT
-- how much further out than its own size the arrow takes a drop (the plus stands there in a fight)
F.GRIP_REACH = 8

-- the open one hides; every key goes back to its opener
local SHUT = [[
    do
        local open = owner:GetAttribute("open")
        if open then
            owner:GetFrameRef("menu" .. open):Hide()
            owner:SetAttribute("open", nil)
        end
    end
]]
local SHOW = [[
    owner:SetAttribute("open", mine)
    owner:GetFrameRef("menu" .. mine):Show()
]]
-- openers, each key with the click name that says whether it may be held;
-- then the open one's shut keys, then its picks (listed by Rebind)
-- The root's attributes this reads are read by our key layers addon too, in
-- its own snippets: open, units, opener<f>, okeys<f>, okey<f>_<i>,
-- obtn<f>_<i>, pkeys<f>, pkey<f>_<i>, pentry<f>_<i>, ckeys, ckey<i>. Their
-- names and meanings stay as they are (a tracked test holds them).
-- Of that addon's root (frame ref "layers") this reads: layer and lkey<layer>_<KEY>, for the opener
-- keys; and hdown_<KEY>, true from the press of a modifier key that is HELD until it is let go. A key
-- held down so is that addon's: its release has to end the layer there. Up, and in every other state
-- of a layer, an open flyout's keys are the flyout's (agreed with its chat, 2026-11-22).
local BIND = [[
    owner:ClearBindings()
    local layers = owner:GetFrameRef("layers")
    local layer = layers and layers:GetAttribute("layer")
    for f = 1, owner:GetAttribute("units") or 0 do
        local name = owner:GetAttribute("opener" .. f)
        for i = 1, owner:GetAttribute("okeys" .. f) or 0 do
            local at = f .. "_" .. i
            local key = owner:GetAttribute("okey" .. at)
            if not (layer and layers:GetAttribute("lkey" .. layer .. "_" .. key)) then
                owner:SetBindingClick(true, key, name, owner:GetAttribute("obtn" .. at))
            end
        end
    end
    local open = owner:GetAttribute("open")
    if open then
        local name = owner:GetAttribute("opener" .. open)
        for i = 1, owner:GetAttribute("ckeys") or 0 do
            local key = owner:GetAttribute("ckey" .. i)
            if not (layers and layers:GetAttribute("hdown_" .. key)) then
                owner:SetBindingClick(true, key, name, "tap")
            end
        end
        for i = 1, owner:GetAttribute("pkeys" .. open) or 0 do
            local at = open .. "_" .. i
            local key = owner:GetAttribute("pkey" .. at)
            -- `own`: the key that is held down to keep this flyout open, when it is one of its picks too
            if key ~= own and not (layers and layers:GetAttribute("hdown_" .. key)) then
                owner:SetBindingClick(true, key, owner:GetAttribute("pentry" .. at), "Key")
            end
        end
        -- With the setting on (twice), the flyout's own key pressed again, once it is let go of, casts the
        -- icon picked last from it: a player's ask (2026-11-23), "double tapping a flyout keybind hits the
        -- last used spell from it". A key that is one of its picks stays that pick's.
        local last = owner:GetAttribute("twice") and held ~= open and owner:GetAttribute("last" .. open)
        local icon = last and owner:GetFrameRef(last)
        if icon and icon:IsShown() then
            for i = 1, owner:GetAttribute("okeys" .. open) or 0 do
                local key = owner:GetAttribute("okey" .. open .. "_" .. i)
                local pick
                for p = 1, owner:GetAttribute("pkeys" .. open) or 0 do
                    if owner:GetAttribute("pkey" .. open .. "_" .. p) == key then pick = true end
                end
                if key and not pick and not (layers and layers:GetAttribute("hdown_" .. key)) then
                    owner:SetBindingClick(true, key, last, "Key")
                end
            end
        end
    end
]]
-- A press opens its flyout or shuts the open one. Held, it stays open
-- through every pick and shuts on letting go; a "tap" click cannot be held.
-- A key that is one of its flyout's own picks can be held too (it used to be a tap: "holding a key to
-- keep a flyout open so can spam button is not working. it still just closes the flyout after the
-- first press of in-flyout key press", 2026-11-22). Its click is named "own<i>", i its place among the
-- opener's keys: while it is down it stays the opener's, so that its release comes here whichever way
-- the client sends a release, and it is its icon's key from the moment it is let go.
local OPENER_WRAP = [[
    local mine = self:GetAttribute("ffindex")
    if not down then
        if held == mine then
            held = nil
            local kept = own
            own = nil
            if picked then
                picked = nil
]] .. SHUT .. BIND .. [[
            elseif kept or owner:GetAttribute("twice") then
]] .. BIND .. [[
            end
        end
        return false
    end
    armed, picked = nil, nil
    local was = owner:GetAttribute("open")
]] .. SHUT .. [[
    if was ~= mine then
]] .. SHOW .. [[
        if button ~= "tap" then held = mine else held = nil end
        local at = strmatch(button, "^own(%d+)$")
        own = at and owner:GetAttribute("okey" .. mine .. "_" .. at) or nil
    else
        held, own = nil, nil
    end
]] .. BIND .. [[
    return false
]]
-- a click on the bar button itself does the same, on its release;
-- a button with no flyout, or a full cursor, goes to the bar as ever.
-- The right button is left to the icon window.
-- Every bar button's click is wrapped with this ahead of any fight, not only a flyout's own button:
-- the game wraps nothing in a fight, so a flyout dragged to another button in one could be opened there
-- by its key and its arrow only, and a click cast the button's ability ("it's no longer a flyout in its
-- new spot, until combat ends...", 2026-11-22). On a button with no flyout it lets the click through.
-- While a flyout has lost its button in a fight (`adrift`) it also says what the button held, and
-- CLICK_AFTER looks at the button once the game has dealt with the click.
local HOST_WRAP = [[
    local mine = owner:GetAttribute("host-" .. self:GetName())
    if not mine or owner:GetAttribute("carrying") then
        if not mine and owner:GetAttribute("adrift") and PlayerInCombat() then
            local slot = owner:GetAttribute("slot-" .. self:GetName())
            local kind, id
            if slot then kind, id = GetActionInfo(slot) end
            return nil, tostring(kind) .. ":" .. tostring(id)
        end
        return
    end
    if button == "RightButton" then return false end
    if down then return false end
    armed, held, picked, own = nil, nil, nil, nil
    local was = owner:GetAttribute("open")
]] .. SHUT .. [[
    if was ~= mine then
]] .. SHOW .. [[
    end
]] .. BIND .. [[
    return false
]]
-- A flyout's bar button dragged to another slot in a fight. His words (2026-11-22): "we need to fix not
-- being able to move flyouts in a fight. it's extremely annoying." In a fight the game lets no addon
-- code touch a bar button or a frame hung on one, so until now the flyout stayed behind until the
-- fight was over. Secure code may, when the game runs it: this runs on a drop on any bar button (READ
-- in the client's Blizzard_RestrictedAddOnEnvironment: OnReceiveDrag can be wrapped, a body before
-- that answers "message" lets the game place what is carried and then runs the body after; in it
-- GetActionInfo says what a slot holds). In a fight only: out of one the addon's own code follows.
-- The button dropped on: if it now holds the ability of a flyout whose own button no longer does,
-- the flyout, its grip and its keys go to this button, hung as they hung on the old one. A flyout
-- this button had, its ability carried off, has no button and no key (`adrift`) until its ability is
-- set down: by a click, which is what a swap leaves to do (CLICK_AFTER), or by the fight's end.
local DROP_BEFORE = [[
    return "message", "drop"
]]
-- the flyout `mine` hung on this button (`self`, `name`), with this button's keys
local HOME = [[
            on = mine
            if was then owner:SetAttribute("host-" .. was, nil) end
            owner:SetAttribute("host-" .. name, mine)
            owner:SetAttribute("hostof" .. mine, name)
            local grip, menu = owner:GetFrameRef("grip" .. mine), owner:GetFrameRef("menu" .. mine)
            grip:SetParent(self)
            grip:SetFrameLevel(self:GetFrameLevel() + owner:GetAttribute("gover"))
            grip:ClearAllPoints()
            grip:SetPoint(owner:GetAttribute("gp" .. mine), self, owner:GetAttribute("grp" .. mine),
                owner:GetAttribute("gx" .. mine), owner:GetAttribute("gy" .. mine))
            grip:Show()
            menu:ClearAllPoints()
            menu:SetPoint(owner:GetAttribute("mp" .. mine), self, owner:GetAttribute("mrp" .. mine),
                owner:GetAttribute("mx" .. mine), owner:GetAttribute("my" .. mine))
            -- its keys are this button's. Under a modifier of one of them the picks are listed too, as
            -- the addon's own code lists them.
            local keys = owner:GetAttribute("bkeys-" .. name) or 0
            local picks = owner:GetAttribute("pkeys" .. mine) or 0
            for i = 1, keys do
                local mod = strmatch(owner:GetAttribute("bkey-" .. name .. "_" .. i), "^(.*%-).")
                for p = 1, mod and picks or 0 do
                    local base = owner:GetAttribute("pkey" .. mine .. "_" .. p)
                    if not strmatch(base, "%-") then
                        local under, have = mod .. base, nil
                        for q = 1, owner:GetAttribute("pkeys" .. mine) do
                            if owner:GetAttribute("pkey" .. mine .. "_" .. q) == under then have = true end
                        end
                        if not have then
                            local last = owner:GetAttribute("pkeys" .. mine) + 1
                            owner:SetAttribute("pkey" .. mine .. "_" .. last, under)
                            owner:SetAttribute("pentry" .. mine .. "_" .. last,
                                owner:GetAttribute("pentry" .. mine .. "_" .. p))
                            owner:SetAttribute("pspot" .. mine .. "_" .. last,
                                owner:GetAttribute("pspot" .. mine .. "_" .. p))
                            owner:SetAttribute("pkeys" .. mine, last)
                        end
                    end
                end
            end
            -- a key that is one of the flyout's picks while open says so in its click's name
            for i = 1, keys do
                local key, how = owner:GetAttribute("bkey-" .. name .. "_" .. i), "LeftButton"
                for p = 1, owner:GetAttribute("pkeys" .. mine) or 0 do
                    if owner:GetAttribute("pkey" .. mine .. "_" .. p) == key then how = "own" .. i end
                end
                owner:SetAttribute("okey" .. mine .. "_" .. i, key)
                owner:SetAttribute("obtn" .. mine .. "_" .. i, how)
            end
            owner:SetAttribute("okeys" .. mine, keys)
]]
local DROP_AFTER = [[
    if not PlayerInCombat() then return end
    lifted = nil
    local name = self:GetName()
    local slot = owner:GetAttribute("slot-" .. name)
    local kind, id
    if slot then kind, id = GetActionInfo(slot) end
    local mine = kind and id and owner:GetAttribute("main-" .. kind .. ":" .. tostring(id))
    local had = owner:GetAttribute("host-" .. name)
    if mine == had then return end
    local off, on
    if had then
        off = had
        owner:SetAttribute("host-" .. name, nil)
        owner:SetAttribute("hostof" .. had, nil)
        owner:SetAttribute("okeys" .. had, 0)
        owner:GetFrameRef("grip" .. had):Hide()
        owner:SetAttribute("adrift", true)
    end
    if mine then
        local was = owner:GetAttribute("hostof" .. mine)
        -- a second one of the ability set down while the first is still on its button: the flyout stays
        local still
        if was then
            local at = owner:GetAttribute("slot-" .. was)
            local k, i
            if at then k, i = GetActionInfo(at) end
            still = k == kind and i == id
        end
        if not still then
]] .. HOME .. [[
        end
    end
    if not (off or on) then return end
    armed, held, picked, own = nil, nil, nil, nil
]] .. SHUT .. BIND .. [[
    owner:CallMethod("Rehomed", on or 0, name, off or 0)
]]
-- After a click on a button with no flyout, in a fight, while a flyout has no button (HOST_WRAP sent
-- what the button held as `message`). If the click changed what the button holds to the ability of a
-- flyout that has no button, it was that ability set down from the cursor: the flyout hangs here. A
-- click that only cast changes nothing, and a flyout that is on its button is never taken off it.
local CLICK_AFTER = [[
    if not PlayerInCombat() then return end
    local name = self:GetName()
    if owner:GetAttribute("host-" .. name) then return end
    local slot = owner:GetAttribute("slot-" .. name)
    local kind, id
    if slot then kind, id = GetActionInfo(slot) end
    if tostring(kind) .. ":" .. tostring(id) == message then return end
    local mine = kind and id and owner:GetAttribute("main-" .. kind .. ":" .. tostring(id))
    if not mine or owner:GetAttribute("hostof" .. mine) then return end
    local on, was
]] .. HOME .. [[
    armed, held, picked, own = nil, nil, nil, nil
]] .. SHUT .. BIND .. [[
    owner:CallMethod("Rehomed", on, name, 0)
]]
-- Action Bar 1 turned to another page: a druid's form, a stance, stealth, the bar's page arrows. His
-- words (2026-11-23): "ours is not working on druid forms... i make the flyout then click it and it takes
-- me out of form (casting the first ability immediately) instead of opening the flyout, and then i go back
-- into form and it's not even a flyout at all anymore"; "the flyouts on the same bar out of form have a
-- delay on showing the flyout symbol, and in fact even acting as a flyout"; "cant be having delays like
-- that". Seen on his druid (/ffdev forms): every shift left a button of the bar wrong for 0.4 to 0.9 s,
-- until the addon's once-a-second pass came round; in a fight nothing followed at all. The game turns
-- the bar by setting its "actionpage" (its ActionBarController, in a fight too). A wrap of the bar's own
-- OnAttributeChanged never ran: the game runs a wrapped body only for a frame that is protected itself
-- (SecureHandler_Other_Execute asks GetFrameHandle(frame, true), which only an explicitly protected
-- frame answers), and the bar is protected only through its buttons. So a state driver of the addon's own
-- (F.PageWrap), on the conditions the game turns the bar by, runs this as the root's own snippet. The page
-- is worked out by the game's own rule (ActionBarController_UpdateAll), from what secure code may ask in a
-- fight too, not read off the bar, which secure code may read only while the bar counts as protected. On
-- each button of the bar, the flyout of what it stands for now
-- (`page-<slot>`, written by Apply for every page, those out of view as much as the one in view) is hung
-- as a drop in a fight hangs one (HOME). The one there before is taken off, and kept for its page.
F.PAGE = [[
    local owner = self
    if not owner:GetAttribute("paging") then return end
    local page
    if HasVehicleActionBar() then
        page = GetVehicleBarIndex()
    elseif HasOverrideActionBar() then
        page = GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar() then
        page = GetTempShapeshiftBarIndex()
    elseif HasBonusActionBar() and GetActionBarPage() == 1 then
        page = GetBonusBarIndex()
    else
        page = GetActionBarPage()
    end
    page = tonumber(page)
    if not page then return end
    local changed, shut
    for i = 1, owner:GetAttribute("mainbuttons") or 0 do
        local button = owner:GetFrameRef("mainbutton" .. i)
        local name = button and not button:GetAttribute("action") and button:GetName()
        local slot = (page - 1) * 12 + i
        local left = name and owner:GetAttribute("slot-" .. name)
        if name and slot ~= left then
            owner:SetAttribute("slot-" .. name, slot)
            local kind, id = GetActionInfo(slot)
            local now
            if kind and id then now = kind .. ":" .. tostring(id) end
            local mine = owner:GetAttribute("page-" .. slot)
            local away = mine and owner:GetAttribute("hostof" .. mine)
            -- hung on another button since (a drop in a fight): it stays there
            if away and away ~= name then mine = nil end
            local had = owner:GetAttribute("host-" .. name)
            local lead = had and owner:GetAttribute("lead" .. had)
            -- off: one kept to a slot of the bar's pages (pslot), the page shows another; any other, the
            -- button no longer holds its ability
            if had and had ~= mine and (owner:GetAttribute("pslot" .. had) or (lead and lead ~= now)) then
                owner:SetAttribute("host-" .. name, nil)
                owner:SetAttribute("hostof" .. had, nil)
                owner:SetAttribute("okeys" .. had, 0)
                owner:GetFrameRef("grip" .. had):Hide()
                if owner:GetAttribute("main-" .. lead) == had then owner:SetAttribute("main-" .. lead, nil) end
                -- kept for the page it was on, to come back with it
                if left and not owner:GetAttribute("page-" .. left) then owner:SetAttribute("page-" .. left, had) end
                if owner:GetAttribute("open") == had then shut = true end
                changed = true
            end
            if mine and owner:GetAttribute("host-" .. name) ~= mine then
                local self, was, on = button, nil, nil
]] .. HOME .. [[
                if now then
                    owner:SetAttribute("main-" .. now, mine)
                    owner:SetAttribute("lead" .. mine, now)
                end
                changed = true
            end
        end
    end
    if not changed then return end
    if shut then
        armed, held, picked, own = nil, nil, nil, nil
]] .. SHUT .. [[
    end
]] .. BIND .. [[
    owner:CallMethod("Paged")
]]

-- An icon moved to another spot of its flyout in a fight (asked which move he meant by the words above,
-- he named this one too). Out of a fight the addon's own code moves it, sliding the others out of its
-- way; in a fight that code may not touch an icon. This may: an icon's drag is wrapped, and a drop on
-- one. In a fight the drag puts the icon's ability on the cursor (the game then runs a drop on what it
-- is let go over) and takes the icon off its flyout at once, as a drag out does out of a fight. His
-- words (2026-11-23): "if i drag an ability out of a flyout mid combat, it does let me do so now
-- thankfully, but it doesn't actually disappear from the flyout itself. even worse, it NEVER does unless
-- i repeat it out of combat. ... i want it in real time anyway". The icons after it move up a spot, the
-- keys of the spot left empty are let go, and the strip is one icon shorter; the icon, hidden, waits on
-- that empty spot. Let go over an icon of the same flyout, it goes back in on that icon's spot (LAND);
-- let go anywhere else, the game does with what is on the cursor what it does with any ability. A
-- flyout left with no icon, or with only its button's own ability, is no flyout any more, as out of a
-- fight: its button is its own again. Not for a flyout that fills itself, nor one whose icons stand
-- around its button; and with the bars locked, only with the game's key for picking an ability up.
-- The keys a spot gets are known beforehand for every spot (from Rebind), and the list of a flyout's
-- pick keys holds those of its spots in use only (KEYS_OF).
-- Moves the icon `mover` of flyout `f` from spot `from` to spot `to`; those between move one spot over.
local SLIDE = [[
    do
        local menu = owner:GetFrameRef("menu" .. f)
        local step, at = from < to and 1 or -1, from
        while at ~= to do
            -- the icon on the next spot takes this one, and the moved icon the next
            local past = at + step
            local a, b = f .. "_" .. at, f .. "_" .. past
            local other = owner:GetFrameRef(owner:GetAttribute("at" .. b))
            other:ClearAllPoints()
            other:SetPoint(owner:GetAttribute("sp" .. a), menu, owner:GetAttribute("srp" .. a),
                owner:GetAttribute("sx" .. a), owner:GetAttribute("sy" .. a))
            other:SetAttribute("ffspot", at)
            owner:SetAttribute("at" .. a, other:GetName())
            mover:ClearAllPoints()
            mover:SetPoint(owner:GetAttribute("sp" .. b), menu, owner:GetAttribute("srp" .. b),
                owner:GetAttribute("sx" .. b), owner:GetAttribute("sy" .. b))
            mover:SetAttribute("ffspot", past)
            owner:SetAttribute("at" .. b, mover:GetName())
            at = past
        end
    end
]]
-- the strip of flyout `f`, `by` icons longer (or shorter)
local GROW = [[
    do
        local long, grows = owner:GetAttribute("mlong" .. f), owner:GetAttribute("mstep" .. f)
        if long and grows then
            long = long + grows * by
            local strip = owner:GetFrameRef("menu" .. f)
            if owner:GetAttribute("mup" .. f) then strip:SetHeight(long) else strip:SetWidth(long) end
            owner:SetAttribute("mlong" .. f, long)
        end
    end
]]
-- The pick keys of flyout `f`, written afresh from what stands on its spots now, as Rebind writes them:
-- for each spot in use, the key and the pad button of the icon on it, its own where it has one (ffkey,
-- ffpad: they go wherever the icon goes) and else the spot's (xkey, xpad); then each of those under each
-- modifier of the flyout's own keys. An opener key that is one of them is marked so (obtn "own<i>").
local KEYS_OF = [[
    do
        local listed, count, seen = 0, owner:GetAttribute("count" .. f) or 0, ";"
        for spot = 1, count do
            local name = owner:GetAttribute("at" .. f .. "_" .. spot)
            local icon = name and owner:GetFrameRef(name)
            local key = icon and icon:GetAttribute("ffkey") or owner:GetAttribute("xkey" .. f .. "_" .. spot)
            local pad = icon and icon:GetAttribute("ffpad") or owner:GetAttribute("xpad" .. f .. "_" .. spot)
            for j = 1, 2 do
                local one = key
                if j == 2 then one = pad end
                if one and not strfind(seen, ";" .. one .. ";", 1, true) then
                    seen = seen .. one .. ";"
                    listed = listed + 1
                    owner:SetAttribute("pkey" .. f .. "_" .. listed, one)
                    owner:SetAttribute("pentry" .. f .. "_" .. listed, name)
                    owner:SetAttribute("pspot" .. f .. "_" .. listed, spot)
                end
            end
        end
        local plain = listed
        for m = 1, owner:GetAttribute("mods" .. f) or 0 do
            local mod = owner:GetAttribute("mod" .. f .. "_" .. m)
            for k = 1, plain do
                local base = owner:GetAttribute("pkey" .. f .. "_" .. k)
                local under = mod .. base
                if not strfind(base, "-", 1, true) and not strfind(seen, ";" .. under .. ";", 1, true) then
                    seen = seen .. under .. ";"
                    listed = listed + 1
                    owner:SetAttribute("pkey" .. f .. "_" .. listed, under)
                    owner:SetAttribute("pentry" .. f .. "_" .. listed, owner:GetAttribute("pentry" .. f .. "_" .. k))
                    owner:SetAttribute("pspot" .. f .. "_" .. listed, owner:GetAttribute("pspot" .. f .. "_" .. k))
                end
            end
        end
        for k = listed + 1, owner:GetAttribute("pkeys" .. f) or 0 do
            owner:SetAttribute("pkey" .. f .. "_" .. k, nil)
            owner:SetAttribute("pentry" .. f .. "_" .. k, nil)
            owner:SetAttribute("pspot" .. f .. "_" .. k, nil)
        end
        owner:SetAttribute("pkeys" .. f, listed)
        for i = 1, owner:GetAttribute("okeys" .. f) or 0 do
            local key = owner:GetAttribute("okey" .. f .. "_" .. i)
            if key and strfind(seen, ";" .. key .. ";", 1, true) then
                owner:SetAttribute("obtn" .. f .. "_" .. i, "own" .. i)
            else
                owner:SetAttribute("obtn" .. f .. "_" .. i, "LeftButton")
            end
        end
    end
]]
local LIFT = [[
    if not PlayerInCombat() then return end
    lifted = nil
    local f = self:GetAttribute("fffly")
    if not f or owner:GetAttribute("still" .. f) then return false end
    if owner:GetAttribute("barslocked") and not IsModifiedClick("PICKUPACTION") then return false end
    local kind = self:GetAttribute("type")
    local what = kind and self:GetAttribute(kind)
    if not what then return false end
    local mover, from, count = self, self:GetAttribute("ffspot"), owner:GetAttribute("count" .. f) or 0
    if from and from <= count then
        local to = count
]] .. SLIDE .. [[
        self:Hide()
        count = count - 1
        owner:SetAttribute("count" .. f, count)
        owner:SetAttribute("room" .. f, (owner:GetAttribute("room" .. f) or 0) + 1)
        local mark = self:GetAttribute("ffmark")
        local has = owner:GetAttribute("holds" .. f) or ";"
        local a, b
        if mark then a, b = strfind(has, ";" .. mark .. ";", 1, true) end
        if a then owner:SetAttribute("holds" .. f, strsub(has, 1, a) .. strsub(has, b + 1)) end
]] .. KEYS_OF .. [[
        local by = -1
]] .. GROW .. [[
        -- none left, or only the button's own ability: the button is its own again
        local first = count >= 1 and owner:GetFrameRef(owner:GetAttribute("at" .. f .. "_1"))
        local lead = first and first:GetAttribute("ffmark")
        local gone = count == 0 or (count == 1 and lead ~= nil and owner:GetAttribute("main-" .. lead) == f)
        if gone then
            local host = owner:GetAttribute("hostof" .. f)
            if host then owner:SetAttribute("host-" .. host, nil) end
            owner:SetAttribute("hostof" .. f, nil)
            owner:SetAttribute("okeys" .. f, 0)
            if lead then owner:SetAttribute("main-" .. lead, nil) end
            owner:GetFrameRef("grip" .. f):Hide()
            if owner:GetAttribute("open") == f then
]] .. SHUT .. [[
            end
        end
]] .. BIND .. [[
        owner:CallMethod("Lifted", f, from, gone or nil)
    end
    lifted = self:GetName()
    -- a toy onto the cursor as an item by its number, which the game picks up from the Toy Box
    if kind == "toy" then return "item", what end
    return kind, what
]]
-- An ability added to a flyout in a fight. His words (2026-11-23): "flyout swaps in combat work. but i
-- cant add to a flyout in combat still." Addon code may not touch an icon in a fight; this may. Every
-- flyout has its twelve icons made and each spot's place told beforehand (Lay), and the keys an added
-- icon would get (Rebind). What is carried is dropped on the flyout's arrow, where the plus stands in a
-- fight: the next free icon is given the ability, shown on its spot, the strip made one icon longer, and
-- its keys bound. The addon is then told (Added), to save it and draw it. Refused, with a word in red:
-- one the flyout holds already, a full flyout, and a flyout that fills itself or whose icons stand around
-- its button.
-- What a drop in a fight carries, for ADD and SWAP below (`f`: the flyout): `id` (a spell's or an
-- item's, or a macro's place in the list), `casts` (what an icon is given to cast it), `mark` (its name
-- in holds<f>), whom the game's Mouseover Cast sends it to, and `has` (what the flyout holds). One the
-- flyout holds already is refused here.
local CARRIED = [[
    lifted = nil
    if not f then return end
    local id, casts, base, how = value, value, nil, kind
    if kind == "spell" then
        local _, spell, under = ...
        id, casts, base = spell, spell, under
    elseif kind == "item" then
        casts = "item:" .. tostring(value)
        -- a toy of the player's own, used as the Toy Box uses it (told beforehand: those in the flyouts
        -- and on the bars)
        if owner:GetAttribute("toy" .. tostring(value)) then how, casts = "toy", value end
    elseif kind == "mount" or kind == "battlepet" or kind == "equipmentset" then
        -- its name and its line to cast it are the addon's own code to look up, out of a fight
        owner:CallMethod("Refused", "mount")
        return
    elseif kind ~= "macro" then
        return
    end
    -- a number, or it is nothing a flyout takes
    if not id or tonumber(id) ~= id then return end
    local mark = kind .. ":" .. id
    -- dropped on the icon that holds it: nothing to do but let go of it
    if self:GetAttribute("ffmark") == mark then return "clear" end
    local help, harm
    if kind == "spell" then
        help, harm = IsSpellHelpful(id), IsSpellHarmful(id)
        if not help and not harm then help, harm = true, true end
    elseif kind == "item" then
        help, harm = IsHelpfulItem(id), IsHarmfulItem(id)
    end
    local has = owner:GetAttribute("holds" .. f) or ";"
    if strfind(has, ";" .. mark .. ";", 1, true) or (base and strfind(has, ";spell:" .. base .. ";", 1, true)) then
        owner:CallMethod("Refused", "twice")
        return
    end
]]
local ADD = CARRIED .. [[
    if owner:GetAttribute("still" .. f) then
        owner:CallMethod("Refused", owner:GetAttribute("auto" .. f) and "auto" or "fight")
        return
    end
    local room, n = owner:GetAttribute("room" .. f) or 0, (owner:GetAttribute("count" .. f) or 0) + 1
    local name = owner:GetAttribute("at" .. f .. "_" .. n)
    local icon = name and owner:GetFrameRef(name)
    if room < 1 or not icon then
        owner:CallMethod("Refused", "full")
        return
    end
    -- an icon taken off and added again keeps its own key; one given another ability has none
    if icon:GetAttribute("ffmark") ~= mark then
        icon:SetAttribute("ffkey", nil)
        icon:SetAttribute("ffpad", nil)
    end
    icon:SetAttribute("type", how)
    icon:SetAttribute("spell", nil)
    icon:SetAttribute("item", nil)
    icon:SetAttribute("macro", nil)
    icon:SetAttribute("toy", nil)
    icon:SetAttribute("macrotext", nil)
    icon:SetAttribute(how, casts)
    icon:SetAttribute("ffmark", mark)
    icon:SetAttribute("fhelp", help or nil)
    icon:SetAttribute("fharm", harm or nil)
    owner:SetAttribute("count" .. f, n)
    owner:SetAttribute("room" .. f, room - 1)
    owner:SetAttribute("holds" .. f, has .. mark .. ";")
]] .. KEYS_OF .. [[
    icon:Show()
]] .. BIND .. [[
    owner:CallMethod("Added", f, n, kind, id)
    -- the strip, one icon longer
    local by = 1
]] .. GROW .. [[
    return "clear"
]]
-- An ability dropped on an icon takes that icon's place, as one dropped on a bar slot takes the slot:
-- his words (2026-11-23): "flyouts not allowing me to drop and replace spells like how we can on normal
-- action bar slots." The icon (`self`) casts what was dropped from then on, on its spot and with its
-- keys, and what it held goes onto the cursor in its stead. The addon is told (Swapped), to save and
-- draw it. Not in a flyout that fills itself.
local SWAP = CARRIED .. [[
    if owner:GetAttribute("auto" .. f) then
        owner:CallMethod("Refused", "auto")
        return
    end
    local was, gone = self:GetAttribute("type"), self:GetAttribute("ffmark")
    local back = was and self:GetAttribute(was)
    if not back then return end
    if gone then
        local from, to = strfind(has, ";" .. gone .. ";", 1, true)
        if from then has = strsub(has, 1, from) .. strsub(has, to + 1) end
    end
    self:SetAttribute("type", how)
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("macro", nil)
    self:SetAttribute("toy", nil)
    self:SetAttribute("macrotext", nil)
    self:SetAttribute(how, casts)
    self:SetAttribute("ffmark", mark)
    self:SetAttribute("fhelp", help or nil)
    self:SetAttribute("fharm", harm or nil)
    owner:SetAttribute("holds" .. f, has .. mark .. ";")
    owner:CallMethod("Swapped", self:GetName(), kind, id)
    -- a toy comes onto the cursor as an item by its number, which the game picks up from the Toy Box
    if was == "toy" then return "clear", "item", back end
    return "clear", was, back
]]
-- A drop on an icon in a fight. The icon lifted off this flyout, still on the cursor, goes back in on
-- this icon's spot: this one and those after it move down a spot. Anything else on the cursor comes from
-- the spellbook, the bags, a bar or another flyout: it takes this icon's place. An icon lifted earlier
-- and let go elsewhere is told from what is carried now by its ability.
local LAND = [[
    if not (kind and PlayerInCombat()) then return end
    local f = self:GetAttribute("fffly")
    local mover = lifted and owner:GetFrameRef(lifted)
    lifted = nil
    local moving = mover and f and not mover:IsShown() and mover:GetAttribute("fffly") == f
        and (mover:GetAttribute("type") == kind or (kind == "item" and mover:GetAttribute("type") == "toy"))
    if moving then
        local what = mover:GetAttribute(kind)
        if kind == "spell" then
            local _, spell, under = ...
            moving = what == spell or what == under
        elseif kind == "item" then
            moving = mover:GetAttribute("ffmark") == "item:" .. tostring(value)
        else
            -- a macro's icon runs it by its name while no other macro has that name: no telling then
            moving = tonumber(what) ~= what or what == value
        end
    end
    if not moving then
]] .. SWAP .. [[
    end
    local from, to = mover:GetAttribute("ffspot"), self:GetAttribute("ffspot")
]] .. SLIDE .. [[
    mover:Show()
    local n = (owner:GetAttribute("count" .. f) or 0) + 1
    owner:SetAttribute("count" .. f, n)
    owner:SetAttribute("room" .. f, (owner:GetAttribute("room" .. f) or 1) - 1)
    local mark = mover:GetAttribute("ffmark")
    if mark then owner:SetAttribute("holds" .. f, (owner:GetAttribute("holds" .. f) or ";") .. mark .. ";") end
]] .. KEYS_OF .. [[
    local by = 1
]] .. GROW .. BIND .. [[
    owner:CallMethod("Landed", f, to)
    return "clear"
]]
-- A pick key acts on its press and shuts on its release, unless the
-- flyout's key is still held. The mouse acts on its release, as on the
-- game's own flyouts: its press may be the start of a move, and a press
-- that cast (a wrapped button takes a mouse press for a key's) would cast
-- what is being dragged away. The two are told apart by the click's name:
-- pick keys click as "Key". The right button casts nothing: it takes the
-- icon off.
-- The game's Mouseover Cast, which its own bar buttons obey: with it on, and its key held where one is
-- set, a helpful ability goes to the friend under the mouse and a harmful one to the foe there; one
-- that is neither goes to whoever is there. The game's own code for this asks a bar button for its
-- slot, which an icon of ours has none of, so the icon is told its unit here, at each click.
local MOUSECAST = [[
    local unit
    if owner:GetAttribute("mousecast") and UnitExists("mouseover")
        and (owner:GetAttribute("mousefree") or IsModifiedClick("MOUSEOVERCAST")) then
        local help, harm = self:GetAttribute("fhelp"), self:GetAttribute("fharm")
        if (help and harm) or (help and PlayerCanAssist("mouseover")) or (harm and PlayerCanAttack("mouseover")) then
            unit = "mouseover"
        end
    end
    self:SetAttribute("unit", unit)
]]

-- A right-click casts as a left-click does, on the release, as on a bar button: the click goes on with its
-- button, so a macro's [button:2] runs. An icon comes off by a drag off the flyout, as off a bar.
-- A player's word (2026-11-24): "There are macros that will do one thing if you left click and another thing
-- if you right click. With your addon, right clicking removes the macro of the menu", with a macro of
-- "/use [button:1] 16; [button:2] 17". His answer: "I'll switch the default to just not have right click
-- remove since can just shift drag to remove like usual anyway."
local ENTRY_WRAP = [[
    -- out of a fight a mouse click with something carried sets it down on this icon, as on a bar slot,
    -- and casts nothing (in a fight nothing says what the cursor holds)
    if button == "LeftButton" and owner:GetAttribute("carrying") and not PlayerInCombat() then return false end
]] .. MOUSECAST .. [[
    if button == "LeftButton" or button == "RightButton" then
        if down then
            self:SetAttribute("useOnKeyDown", false)
            armed = self:GetName()
            return false
        end
    elseif down then
        self:SetAttribute("useOnKeyDown", true)
        armed = self:GetName()
        return
    end
    if armed ~= self:GetName() then return false end
    armed = nil
    -- the icon picked last from its flyout, cast again by the flyout's key pressed twice where that is set
    local mine = self:GetAttribute("fffly")
    if mine then owner:SetAttribute("last" .. mine, self:GetName()) end
    if held then
        picked = true
        return
    end
]] .. SHUT .. BIND

local root, list, open
local units, used = {}, 0
local pending, moved, ready, paused, rekey
local quiet, idle, patient = 0, 0, 0
-- keys changed inside the quiet spell after our own binding: looked at when it ends
local late
local watchers = {}
-- each says when the bars are put away for a moment: no flyout looks for a button then
local stills = {}
-- bar buttons whose click we wrapped, and the ones with a flyout now
local wrapped, hosted, mains = {}, {}, {}
-- what the game last said of the pad being the input in use; nil: nothing yet
local padMode
-- a game command bound to a key and a pad button both, and whether one was sought
local witness, sought
-- our rows' keys in the game's key menu, as last bound
local menuKeys
local Labels
-- what is true of a flyout on this character's bars only
local run = setmetatable({}, { __mode = "k" })

local function Run(flyout)
    local state = run[flyout]
    if not state then
        state = {}
        run[flyout] = state
    end
    return state
end

-- this character's last way and scale per button, kept across logins
local function Laid()
    local record = P.Mine()
    if type(record.laid) ~= "table" then record.laid = {} end
    return record.laid
end

-- A listener's error is its own. It is reported, and it stops neither the lay it was told of nor the
-- listeners after it. (2026-11-22: a listener that broke at every lay cut each lay short and kept the
-- addon from finishing its start, so flyouts stayed on buttons their abilities had left.)
local function Tell(what, ...)
    for _, fn in ipairs(watchers) do xpcall(fn, geterrorhandler(), what, ...) end
end

-- fn(what, ...) as flyouts are built, laid out, opened and shut
function F.Watch(fn) watchers[#watchers + 1] = fn end

-- two entries are one thing; macros of one name are told apart by their text
local function Same(a, b)
    if a == nil or b == nil or a.kind ~= b.kind or a.id ~= b.id then return false end
    return a.kind ~= "macro" or Macros.Same(a, b)
end
-- an entry of its own for a flyout to keep
local function Copy(entry) return { kind = entry.kind, id = entry.id, text = entry.text } end

-- whether taking entry i off leaves only the button's own ability, or nothing
function F.Ends(flyout, i)
    local entry = flyout.entries[i]
    local full = flyout.all or flyout.entries
    if not entry or #full > 2 then return false end
    if #full == 1 then return true end
    local other = full[1]
    if other == entry then other = full[2] end
    return Same(other, flyout.main)
end

function F.Icon(entry)
    if entry.kind == "spell" then return (C_Spell.GetSpellTexture(entry.id)) end
    if entry.kind == "item" then return C_Item.GetItemIconByID(entry.id) end
    if Bars.Kinds[entry.kind] then return Bars.Kinds[entry.kind].Icon(entry.id) end
    local _, icon = GetMacroInfo(Macros.Ref(entry))
    return icon
end

-- the arrow points out when shut and back when open
local function Arrow(unit, art)
    unit.art = art or unit.art or "arrow"
    local turn = Art.TURN[unit.side or unit.way or "UP"].arrow
    if unit.menu:IsShown() then turn = (turn + 180) % 360 end
    unit.turn = turn
    -- as much larger as its button is now than when it was laid
    local grown = unit.grown or 1
    Art.Set(unit.arrow, Art.NAMES[unit.art], turn, ARROW_W * grown, ARROW_H * grown)
    -- the game draws it 2 closer while open; left as it is in a fight
    local side, host = Art.SIDES[unit.side or unit.way or "UP"], unit.host
    if host and not InCombatLockdown() then
        local out = (unit.menu:IsShown() and ARROW_OPEN or ARROW_OUT) * grown
        unit.arrow:ClearAllPoints()
        unit.arrow:SetPoint(side.to, host, side.to, side.x * out, side.y * out)
    end
end

-- A flyout's button changed size under its marks: the game grows a group of gamepad mode as it is
-- picked, and lets it shrink again. The dots or the arrow are sized again at once, not at the next
-- laying out. They are plain textures, so this is done in a fight too.
local function Remark(unit)
    local host, scale = unit.host, unit.opener:GetScale()
    if not host or not unit.flyout then return end
    local now = Bars.Size(host)
    unit.grown = (scale and scale > 0) and now / scale or 1
    -- written down when it has changed by a tenth or more since last written
    if math.abs(unit.grown - (unit.grownSaid or 1)) >= 0.1 then
        unit.grownSaid = unit.grown
        ns.Log(("marks: %s is now %.2f of the size it was laid at; its marks follow at once"):format(
            tostring(host:GetName()), unit.grown))
    end
    Art.LayDots(unit.dots, host, unit.radial, unit.grown)
    if not unit.dots.shown then Arrow(unit) end
end

-- An entry's own tooltip in `tip`, as a bar button holding it shows it; for its icon in a flyout, and for the
-- bar button that shows it as the last one used (F.ShowLast)
function F.FillTip(tip, entry)
    if entry.kind == "spell" then
        -- with its rank, as the spellbook and the bars show it
        tip:SetSpellByID(entry.id, false, true)
    elseif entry.kind == "item" and Bars.OwnToy(entry.id) and tip.SetToyByItemID then
        -- as the Toy Box and a bar button show a toy: what it does, not the item that teaches it
        tip:SetToyByItemID(entry.id)
    elseif entry.kind == "item" then
        tip:SetItemByID(entry.id)
    elseif Bars.Kinds[entry.kind] then
        Bars.Kinds[entry.kind].Tip(tip, entry.id)
    else
        -- as a bar button shows a macro: the spell or the item it stands for just now, else its name
        local ref = Macros.Ref(entry)
        local spell = GetMacroSpell and GetMacroSpell(ref)
        local link
        if not spell and GetMacroItem then link = select(2, GetMacroItem(ref)) end
        if spell and not (issecretvalue and issecretvalue(spell)) then
            tip:SetSpellByID(spell, false, true)
        elseif type(link) == "string" and not (issecretvalue and issecretvalue(link)) then
            tip:SetHyperlink(link)
        else
            tip:SetText(Macros.Name(entry) or tostring(entry.id))
        end
    end
end

local function EntryTip(self)
    local entry = self.entry
    if not entry then return end
    -- something carried onto an icon of the open flyout: the preview of adding it begins (UI/Move.lua)
    local move = ns.Move
    if move and GetCursorInfo() and move.EnterOpen(self) then return end
    -- none while an icon is moved, carried off its flyout or added: they covered the icons being aimed at
    -- (his recording, 2026-11-24)
    if move and (move.Moving() or move.Carried() or move.Preview()) then return end
    -- while keys are being set, a hover says how instead
    if ns.Keys and ns.Keys.Enter(self) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    F.FillTip(GameTooltip, entry)
    -- says so beforehand when the flyout would go with it; a hint, so not where hints are turned off
    if not InCombatLockdown() and P.Hints() then
        local flyout = self.flyout
        local last = flyout and F.Ends(flyout, self.entryIndex)
        local how = TEXT.how
        local key = F.BarsLocked() and GetModifiedClick("PICKUPACTION")
        if key and key ~= "NONE" then how = TEXT.howHeld:format(key:sub(1, 1) .. key:sub(2):lower()) end
        GameTooltip:AddLine((last and TEXT.removeLast or TEXT.remove):format(how), 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
    if ns.Keys then ns.Keys.Leave() end
end

-- the game's own setting, asked as its flyout asks it: locked bars want the pick up key held
function F.BarsLocked()
    if Settings and Settings.GetValue then
        local ok, locked = pcall(Settings.GetValue, "lockActionBars")
        if ok then return locked == true end
    end
    return C_CVar.GetCVar("lockActionBars") == "1"
end

-- How an icon casts what it holds, as the game's own buttons do: its type, the attribute that names what it
-- casts, and that. A toy of the player's own is used as the Toy Box uses it (the item calls take it for one
-- in the bags: the game's item tooltip, "Use: Adds this toy to your Toy Box."); a mount and a battle pet by
-- the slash command the game has for each.
function F.Casting(entry)
    if entry.kind == "item" and Bars.OwnToy(entry.id) then return "toy", "toy", entry.id end
    if entry.kind == "item" then return "item", "item", "item:" .. entry.id end
    if entry.kind == "macro" then return "macro", "macro", Macros.Run(entry) end
    if Bars.Kinds[entry.kind] then return "macro", "macrotext", Bars.Kinds[entry.kind].Macro(entry.id) end
    return entry.kind, entry.kind, entry.id
end

-- an entry's name for a chat line
local function Name(entry)
    local name = entry.id
    if entry.kind == "spell" then
        name = C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
    elseif entry.kind == "item" then
        name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
    elseif entry.kind == "macro" then
        name = Macros.Name(entry)
    elseif Bars.Kinds[entry.kind] then
        name = Bars.Kinds[entry.kind].Name(entry.id)
    end
    if issecretvalue and issecretvalue(name) then return TEXT.it end
    if type(name) == "string" and name ~= "" then return name end
    return TEXT.it
end

-- an icon taken off; a refusal is said in red, and nothing is said of what was plainly done
local function TakeOff(unit, i)
    local flyout = unit.flyout
    local entry = flyout and flyout.entries[i]
    if not entry then return nil end
    local ok, more = F.Remove(flyout, i)
    if not ok then
        ns.Warn(more)
        return nil
    end
    return entry
end

-- A toy as the Toy Box picks it up, a mount and a battle pet as their journals do: the bags hold no toy,
-- and neither a mount nor a pet is in a spellbook.
local function Pickup(entry)
    if Bars.Kinds[entry.kind] then
        Bars.Kinds[entry.kind].Pickup(entry.id)
    elseif entry.kind == "spell" then
        (C_Spell.PickupSpell or PickupSpell)(entry.id)
    elseif entry.kind == "item" and Bars.OwnToy(entry.id) and C_ToyBox and C_ToyBox.PickupToyBoxItem then
        C_ToyBox.PickupToyBoxItem(entry.id)
    elseif entry.kind == "item" then
        (C_Item.PickupItem or PickupItem)(entry.id)
    else
        PickupMacro(Macros.Ref(entry))
    end
end

F.Name, F.TakeOff, F.Pickup, F.Same = Name, TakeOff, Pickup, Same

-- dragged out as off a bar: off the flyout and onto the cursor
function F.CarryOff(unit, i)
    local entry = TakeOff(unit, i)
    if entry then Pickup(entry) end
    return entry
end

-- a drag on an icon moves it: UI/Move.lua, loaded after this file
local function DragStart(self) ns.Move.Start(self) end
local function DragStop() ns.Move.Released() end

-- what the secure code calls when it has moved a flyout in a fight (written further down); F.Added,
-- F.Refused, F.Swapped, F.Lifted and F.Landed, further down too, for what it does to a flyout's icons
local Rehomed

local function Build()
    if root then return end
    root = CreateFrame("Frame", ROOT, UIParent, "SecureHandlerBaseTemplate")
    root:Hide()
    root.Rehomed = function(_, ...) xpcall(Rehomed, geterrorhandler(), ...) end
    root.Lifted = function(_, ...) xpcall(F.Lifted, geterrorhandler(), ...) end
    root.Landed = function(_, ...) xpcall(F.Landed, geterrorhandler(), ...) end
    root.Added = function(_, ...) xpcall(F.Added, geterrorhandler(), ...) end
    root.Refused = function(_, ...) xpcall(F.Refused, geterrorhandler(), ...) end
    root.Swapped = function(_, ...) xpcall(F.Swapped, geterrorhandler(), ...) end
    root.Paged = function(_, ...) xpcall(F.Paged, geterrorhandler(), ...) end
    for i, key in ipairs(CLOSE_KEYS) do root:SetAttribute("ckey" .. i, key) end
    root:SetAttribute("ckeys", #CLOSE_KEYS)
    root:SetAttribute("units", 0)
    F.root = root
end

-- A flyout's name on its bar button: the game's lettering for a macro's name there, how far over the
-- button's foot it stands where the button has no such text of its own, and the most letters, as for
-- a macro.
local NAME_FONT, NAME_UP, NAME_LETTERS = "GameFontHighlightSmallOutline", 2, 16
-- the bar button's own numbers: the sweep's inset and shade, the dimming
local COOL_SHADE = 0.64
-- the most an icon's corner says in digits, and what stands for more
local COUNT_MOST, COUNT_OVER = 999, "*"
local READY, NO_POWER, UNUSABLE = { 1, 1, 1 }, { 0.5, 0.5, 1 }, { 0.4, 0.4, 0.4 }
-- how often an open flyout asks its icons' range, as the bars asked theirs; the dot the game shows
-- for the range of a bar button with no key
local RANGE_EVERY, RANGE_DOT = 0.2, RANGE_INDICATOR or "\226\151\143"
-- set when the client hid a value in a fight: then it is handed on unread
F.hid = { cooldown = false, usable = false, range = false }

local function Hidden(v) return issecretvalue ~= nil and issecretvalue(v) end

-- what an entry casts, for its cooldown and its dimming: a macro's spell
local function Casts(entry)
    if entry.kind ~= "macro" then return entry.kind, entry.id end
    local spell = GetMacroSpell and GetMacroSpell(Macros.Ref(entry))
    if Hidden(spell) or not spell then return nil end
    return "spell", spell
end

-- plain numbers to the sweep. A hidden one is never passed: the client
-- refuses it from addon code, and the error would stop the flyout opening.
local function Numbers(cool, start, duration)
    if Hidden(start) or Hidden(duration) then
        F.hid.cooldown = true
        return cool:Clear()
    end
    if not (start and duration) then return cool:Clear() end
    cool:SetCooldown(start, duration)
end

-- the sweep, as the bar draws it; it carries the global cooldown too
local function Sweep(cool, kind, id)
    if kind == "spell" then
        -- in a fight the numbers are hidden: the client's duration object carries them
        if C_Spell.GetSpellCooldownDuration and cool.SetCooldownFromDurationObject then
            local duration = C_Spell.GetSpellCooldownDuration(id)
            if not duration then return cool:Clear() end
            return cool:SetCooldownFromDurationObject(duration, true)
        end
        local info = C_Spell.GetSpellCooldown(id)
        if not info then return cool:Clear() end
        Numbers(cool, info.startTime, info.duration)
    elseif kind == "item" then
        local ask = C_Item.GetItemCooldown or (C_Container and C_Container.GetItemCooldown)
        if not ask then return cool:Clear() end
        Numbers(cool, ask(id))
    else
        cool:Clear()
    end
end

-- dimmed as a bar button: blue short of power, gray unusable; says whether it is neither
local function Dim(icon, kind, id)
    local usable, short = true, false
    if kind == "spell" then
        usable, short = C_Spell.IsSpellUsable(id)
    elseif kind == "item" and Bars.OwnToy(id) then
        -- the item calls take a toy for one in the bags, and say it is unusable
        usable = Bars.ToyUsable(id)
    elseif kind == "item" then
        local ask = C_Item.IsUsableItem or IsUsableItem
        if ask then usable, short = ask(id) end
    elseif Bars.Kinds[kind] then
        usable = Bars.Kinds[kind].Usable(id)
    end
    local color = READY
    if Hidden(usable) or Hidden(short) then
        F.hid.usable = true
    elseif not usable then
        color = short and NO_POWER or UNUSABLE
    end
    icon:SetVertexColor(color[1], color[2], color[3])
    return color == READY
end

-- An open flyout's icons show their range (the helpers keep to a block of their own: the file's own
-- chunk has no local variables to spare).
local Ranges
do
    -- Whether an ability is out of range of the target, as a bar button knows it: true or false, and nil
    -- where it asks no range or there is no target. An item's range is asked outside a fight only: in
    -- one the client keeps that call from addons.
    local function Far(kind, id)
        if not UnitExists("target") then return nil end
        local near
        if kind == "spell" and C_Spell.IsSpellInRange then
            near = C_Spell.IsSpellInRange(id, "target")
        elseif kind == "item" and C_Item.IsItemInRange and not InCombatLockdown() then
            near = C_Item.IsItemInRange(id, "target")
        end
        if Hidden(near) then
            F.hid.range = true
            return nil
        end
        if near == nil then return nil end
        return near == false or near == 0
    end

    -- What this client's bars do to the icon of a usable ability out of range. The game leaves the icon as
    -- it is and reddens the key; where the bars are made to tint the icon as well, a flyout's icons take
    -- the same tint. It is read off a bar button that is out of range right now: nil until one was seen,
    -- false once the bars were seen to leave theirs alone.
    local farTint, farPlain = nil, 0
    local PLAIN_TIMES, SAME = 3, 0.01
    local function Like(r, g, b, color)
        return math.abs(r - color[1]) < SAME and math.abs(g - color[2]) < SAME and math.abs(b - color[3]) < SAME
    end
    -- `ours`: a texture of the addon's own, for its plain calls. Says whether the button had a word on it.
    local function Sample(button, ours)
        local slot, icon = Bars.Slot(button), button.icon
        if not slot or type(icon) ~= "table" or not UIParent.IsVisible(button) then return false end
        local inRange = C_ActionBar and C_ActionBar.IsActionInRange or IsActionInRange
        local usableAt = C_ActionBar and C_ActionBar.IsUsableAction or IsUsableAction
        if not inRange or not usableAt then return false end
        local near = inRange(slot)
        if Hidden(near) or not (near == false or near == 0) then return false end
        local usable = usableAt(slot)
        if Hidden(usable) or not usable then return false end
        local r, g, b = ours.GetVertexColor(icon)
        local gray = ours.IsDesaturated(icon)
        if Hidden(r) or Hidden(g) or Hidden(b) or Hidden(gray) or type(r) ~= "number" then return false end
        -- the game's own dimming, caught between two of its looks: no word on the range
        if Like(r, g, b, NO_POWER) or Like(r, g, b, UNUSABLE) then return false end
        if Like(r, g, b, READY) and not gray then
            farPlain = farPlain + 1
            if farTint == nil or farPlain >= PLAIN_TIMES then farTint = false end
        else
            farTint, farPlain = { r, g, b, gray == true }, 0
        end
        return true
    end
    function F.FarTint() return farTint end

    -- One icon's range on its key, as a bar button shows it: the key red out of range, and with no key
    -- the game's dot for an ability that asks a range.
    local function Ranged(frame, kind, id)
        local far = Far(kind, id)
        local key = frame.key
        local text = key:GetText()
        if text == nil or text == "" or text == RANGE_DOT then key:SetText(far ~= nil and RANGE_DOT or "") end
        local color = far and RED_FONT_COLOR or ACTIONBAR_HOTKEY_FONT_COLOR
        if color then key:SetVertexColor(color:GetRGB()) end
        frame.far = far == true
        return frame.far
    end
    -- and on its icon, where this client's bars tint theirs: never over the game's own dimming
    local function Tinted(frame)
        local tint = frame.far and frame.clear and farTint or nil
        if tint then
            frame.icon:SetVertexColor(tint[1], tint[2], tint[3])
            frame.icon:SetDesaturated(tint[4])
            frame.tinted = true
        elseif frame.tinted then
            frame.tinted = nil
            frame.icon:SetDesaturated(false)
            if frame.clear then frame.icon:SetVertexColor(READY[1], READY[2], READY[3]) end
        end
    end
    -- every icon of one flyout: its range, now
    function Ranges(unit)
        if not unit.flyout then return end
        local any, ours = false, nil
        for _, frame in ipairs(unit.entries) do
            local entry = frame.entry
            if entry then
                ours = ours or frame.icon
                if Ranged(frame, Casts(entry)) then any = true end
            end
        end
        -- the flyout's own button first: it is the one next to these icons
        if any and not (unit.host and Sample(unit.host, ours)) and farTint == nil then
            for _, button in ipairs(Bars.Known() or {}) do
                if Sample(button, ours) then break end
            end
        end
        for _, frame in ipairs(unit.entries) do
            if frame.entry then Tinted(frame) end
        end
    end
end

-- whether an item's number is shown: one that is used up or comes in stacks, as on a bar button
local function Counted(id)
    local eaten = C_Item.IsConsumableItem and C_Item.IsConsumableItem(id)
    if not Hidden(eaten) and eaten == true then return true end
    local most = C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(id)
    return type(most) == "number" and not Hidden(most) and most > 1
end

-- How many there are, in the icon's corner as a bar button has it: of an item, those in the bags; of a
-- spell, its charges or uses in the client's own words (hidden in a fight, so handed on unread).
local function Count(text, kind, id)
    local shown = ""
    if kind == "item" and C_Item.GetItemCount then
        local many = C_Item.GetItemCount(id, false, true)
        if Hidden(many) then
            shown = many
        elseif type(many) == "number" and Counted(id) then
            shown = many > COUNT_MOST and COUNT_OVER or tostring(many)
        end
    elseif kind == "spell" and C_Spell.GetSpellDisplayCount then
        local ok, words = pcall(C_Spell.GetSpellDisplayCount, id, COUNT_MOST, COUNT_OVER)
        if ok and words ~= nil then shown = words end
    end
    -- a value the client will not show for us must not stop the flyout opening
    if not pcall(text.SetText, text, shown) then text:SetText("") end
end

-- every icon of one flyout: its sweep, its dimming, its number and its range, now
local function State(unit)
    if not unit.flyout then return end
    local numbers = C_CVar.GetCVar("countdownForCooldowns") == "1"
    for _, frame in ipairs(unit.entries) do
        local entry = frame.entry
        if entry then
            local kind, id = Casts(entry)
            frame.cooldown:SetHideCountdownNumbers(not numbers)
            Sweep(frame.cooldown, kind, id)
            frame.clear = Dim(frame.icon, kind, id)
            Count(frame.count, kind, id)
        end
    end
    Ranges(unit)
end

-- Whether an ability is one for friends, one for foes, or neither (a spell that is neither counts as
-- both, as the game counts it for Mouseover Cast). A macro says for itself whom it is for.
local function Leaning(entry)
    if not entry or entry.kind == "macro" then return nil, nil end
    local help, harm
    if entry.kind == "spell" then
        if not (C_Spell.IsSpellHelpful and C_Spell.IsSpellHarmful) then return nil, nil end
        help, harm = C_Spell.IsSpellHelpful(entry.id), C_Spell.IsSpellHarmful(entry.id)
        if Hidden(help) or Hidden(harm) then return nil, nil end
        if not help and not harm then return true, true end
    elseif entry.kind == "item" then
        if not (C_Item.IsHelpfulItem and C_Item.IsHarmfulItem) then return nil, nil end
        help, harm = C_Item.IsHelpfulItem(entry.id), C_Item.IsHarmfulItem(entry.id)
        if Hidden(help) or Hidden(harm) then return nil, nil end
    else
        return nil, nil
    end
    if help ~= true then help = nil end
    if harm ~= true then harm = nil end
    return help, harm
end

-- The game's Mouseover Cast setting and whether it wants a key held, kept where a click can read them.
local function CastSettings()
    if not root or InCombatLockdown() then return end
    local on = C_CVar.GetCVar("enableMouseoverCast") == "1"
    local free = on and GetModifiedClick("MOUSEOVERCAST") == "NONE"
    if on then root:SetAttribute("mousecast", true) else root:SetAttribute("mousecast", nil) end
    if free then root:SetAttribute("mousefree", true) else root:SetAttribute("mousefree", nil) end
    -- with the bars locked an icon is lifted only with the game's key for it, in a fight as out of one
    root:SetAttribute("barslocked", F.BarsLocked() or nil)
end
F.CastSettings = CastSettings

local function EntryButton(unit, i)
    local name = ENTRY .. unit.index .. "_" .. i
    local entry = CreateFrame("Button", name, unit.menu, "SecureActionButtonTemplate")
    entry:SetSize(Art.ICON, Art.ICON)
    entry:RegisterForClicks("AnyDown", "AnyUp")
    entry:SetAttribute("useOnKeyDown", true)
    -- the game's self cast and focus cast keys, as on its own bar buttons
    entry:SetAttribute("checkselfcast", true)
    entry:SetAttribute("checkfocuscast", true)
    root:WrapScript(entry, "OnClick", ENTRY_WRAP)
    -- by the place it stands in now: in a fight the secure code may have moved it
    entry:SetScript("PostClick", function(self, button, down)
        Tell("pick", unit, self.entryIndex, button, down)
        F.NoteLast(unit)
        if button == "LeftButton" and not down and GetCursorInfo() then xpcall(F.Dropped, geterrorhandler(), self) end
    end)
    -- never a field called unit: the client takes that for a unit name
    entry.flyoutUnit, entry.entryIndex = unit, i
    entry:RegisterForDrag("LeftButton")
    entry:HookScript("OnDragStart", DragStart)
    entry:HookScript("OnDragStop", DragStop)
    -- in a fight the secure code moves an icon: it knows each by its name, and is run at an icon's drag
    -- and at a drop on one
    entry.made = i
    root:SetFrameRef(name, entry)
    root:WrapScript(entry, "OnDragStart", LIFT)
    -- what is dropped on an icon out of a fight is the addon's to deal with; in a fight the secure code's
    entry:SetScript("OnReceiveDrag", function(self) xpcall(F.Dropped, geterrorhandler(), self) end)
    root:WrapScript(entry, "OnReceiveDrag", LAND)
    entry:HookScript("OnEnter", EntryTip)
    entry:HookScript("OnLeave", HideTip)
    -- the game's dark slot, seen at the icon's cut corners
    entry.back = entry:CreateTexture(nil, "BACKGROUND", nil, -1)
    entry.back:SetAtlas(Art.NAMES.back)
    entry.back:SetAllPoints()
    entry.icon = entry:CreateTexture(nil, "BACKGROUND")
    entry.icon:SetAllPoints()
    Art.Dress(entry, entry.icon)
    entry:SetNormalAtlas(Art.NAMES.frame)
    entry:SetPushedAtlas(Art.NAMES.frameDown)
    entry:SetHighlightAtlas(Art.NAMES.frameOver)
    -- sized as the game's small flyout button sizes them
    for _, art in ipairs({ entry:GetNormalTexture(), entry:GetPushedTexture() }) do
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT")
        art:SetSize(Art.FRAME, Art.FRAME)
    end
    local over = entry:GetHighlightTexture()
    over:ClearAllPoints()
    over:SetPoint("TOPLEFT")
    over:SetSize(Art.OVER_W, Art.OVER_H)
    -- one label, where the game puts a small button's key: the key, or the pad's symbol
    entry.key = entry:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    entry.key:SetPoint("TOPRIGHT", Art.KEY_X, Art.KEY_Y)
    -- the font's own gray is darker than the one the game's bars show a key in
    if ACTIONBAR_HOTKEY_FONT_COLOR then entry.key:SetVertexColor(ACTIONBAR_HOTKEY_FONT_COLOR:GetRGB()) end
    -- how many there are, in the game's own font for it and the corner its small buttons use
    entry.count = entry:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    entry.count:SetPoint("BOTTOMRIGHT")
    entry.count:SetJustifyH("RIGHT")
    -- the game's small button sweep, at the icon's own level
    local cool = CreateFrame("Cooldown", nil, entry, "CooldownFrameTemplate")
    cool:SetPoint("TOPLEFT", entry.icon, "TOPLEFT", Art.SWEEP[1], Art.SWEEP[2])
    cool:SetPoint("BOTTOMRIGHT", entry.icon, "BOTTOMRIGHT", Art.SWEEP[3], Art.SWEEP[4])
    cool:SetDrawBling(false)
    cool:SetDrawEdge(false)
    cool:SetSwipeColor(0, 0, 0, COOL_SHADE)
    if cool.SetUsingParentLevel then cool:SetUsingParentLevel(true) end
    entry.cooldown = cool
    root:SetAttribute("entry" .. unit.index .. "_" .. i, name)
    return entry
end

-- one flyout's frames: strip, arrow, icons
local function Unit(f)
    local unit = units[f]
    if unit then return unit end
    unit = { index = f, keys = {}, entries = {} }
    units[f] = unit

    local menu = CreateFrame("Frame", MENU .. f, UIParent, "SecureHandlerBaseTemplate")
    menu:Hide()
    menu:SetSize(Art.STRIP, Art.POP)
    unit.menu, unit.strip = menu, Art.Strip(menu)
    -- for icons standing around the button: a round plate behind them, and on it the button's own
    -- icon, which the plate would else hide
    unit.plate = Art.Disc(menu)
    unit.hub = Art.Token(menu)
    unit.hub:SetPoint("CENTER", menu, "CENTER")
    unit.hub:Hide()
    root:SetFrameRef("menu" .. f, menu)
    -- an open flyout asks its icons' range a few times a second; a frame in it runs only while it shows
    local tick, waited = CreateFrame("Frame", nil, menu), 0
    local function Pass() Ranges(unit) end
    tick:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < RANGE_EVERY then return end
        waited = 0
        xpcall(Pass, geterrorhandler())
    end)

    local opener = CreateFrame("Button", OPENER .. f, UIParent, "SecureActionButtonTemplate")
    opener:Hide()
    opener:RegisterForClicks("AnyDown", "AnyUp")
    -- never "unit": the client reads that one as a unit name
    opener:SetAttribute("ffindex", f)
    root:WrapScript(opener, "OnClick", OPENER_WRAP)
    -- in a fight what is dropped on the arrow is added to the flyout
    root:WrapScript(opener, "OnReceiveDrag", [[
        if not (kind and PlayerInCombat()) then return end
        local f = self:GetAttribute("ffindex")
    ]] .. ADD)
    root:SetAttribute("opener" .. f, OPENER .. f)
    opener:SetScript("PostClick", function(_, button, down) Tell("opener", unit, button, down) end)
    unit.opener = opener
    root:SetFrameRef("grip" .. f, opener)
    -- the game's flyout arrow, and its glow around the button
    unit.arrow = opener:CreateTexture(nil, "OVERLAY")
    -- in the arrow's place for a flyout that opens around its button
    unit.dots = Art.Dots(opener)
    -- a chosen icon, drawn over the bar button's own
    unit.face = opener:CreateTexture(nil, "BACKGROUND")
    unit.face:Hide()
    -- with "Show the last one used on its button": that one's sweep and number over the button's own (F.LastLook)
    unit.lastCool = CreateFrame("Cooldown", nil, opener, "CooldownFrameTemplate")
    unit.lastCool:Hide()
    unit.lastCount = opener:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    unit.lastCount:SetJustifyH("RIGHT")
    unit.lastCount:Hide()
    -- a name given to the flyout, written on the bar button where the game writes a macro's
    unit.label = opener:CreateFontString(nil, "OVERLAY", NAME_FONT)
    unit.label:Hide()
    unit.glow = opener:CreateTexture(nil, "ARTWORK")
    unit.glow:SetAtlas(Art.NAMES.glow)
    unit.glow:Hide()
    -- the game's own mouseover ring on the bar button, lit to point it out
    unit.ring = opener:CreateTexture(nil, "OVERLAY")
    unit.ring:SetAtlas(Art.NAMES.frameOver)
    unit.ring:Hide()
    -- The arrow's look, from what is so right now: pressed only while a mouse button that went down on
    -- it is still down. The mouse-up is not always handed to this frame (the flyout opens over it on the
    -- press), and an arrow left waiting for it stayed dimmed.
    local pressed, watching = false, false
    local function Held() return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") end
    local function Look()
        if pressed and not Held() then pressed = false end
        if pressed then return "arrowDown" end
        return opener:IsMouseOver() and "arrowOver" or "arrow"
    end
    local function Watch(tries)
        watching = false
        if not pressed then return end
        if Held() and tries < 300 then
            watching = true
            return C_Timer.After(0.1, function() Watch(tries + 1) end)
        end
        pressed = false
        Arrow(unit, Look())
    end
    unit.look = Look
    opener:HookScript("OnEnter", function()
        Arrow(unit, Look())
        unit.glow:Show()
    end)
    opener:HookScript("OnLeave", function()
        Arrow(unit, Look())
        unit.glow:SetShown(menu:IsShown())
    end)
    opener:HookScript("OnMouseDown", function()
        pressed = true
        Arrow(unit, "arrowDown")
        if not watching then
            watching = true
            C_Timer.After(0.1, function() Watch(1) end)
        end
    end)
    opener:HookScript("OnMouseUp", function()
        pressed = false
        Arrow(unit, Look())
    end)

    -- These run inside the secure Show and Hide. An error here would stop
    -- the keys being bound, so the drawing runs guarded and is still reported.
    menu:HookScript("OnShow", function()
        open = unit
        quiet = math.max(quiet, GetTime() + 0.5)
        xpcall(function()
            Arrow(unit, Look())
            unit.glow:Show()
            -- keys or pad symbols, as the game's bars show right now
            Labels(unit)
            State(unit)
            Tell("open", unit)
        end, geterrorhandler())
    end)
    menu:HookScript("OnHide", function()
        if open == unit then open = nil end
        quiet = math.max(quiet, GetTime() + 0.5)
        xpcall(function()
            Arrow(unit, Look())
            unit.glow:SetShown(opener:IsMouseOver())
            Tell("shut", unit)
        end, geterrorhandler())
    end)

    for i = 1, MAX do unit.entries[i] = EntryButton(unit, i) end
    Tell("built", unit)
    return unit
end

-- whether the keys given hold both a pad button and another key
local function Mixed(...)
    local pad, other = false, false
    for n = 1, select("#", ...) do
        local key = select(n, ...)
        if type(key) == "string" and key ~= "" then
            if IsBindingForGamePad(key) then pad = true else other = true end
        end
    end
    return pad and other
end

-- A command with a key and a pad button both. Of the two the game lists
-- first the one for the input in use: that is the one its own bars show.
local function Witness()
    if witness and Mixed(GetBindingKey(witness)) then return witness end
    witness = nil
    if sought then return nil end
    sought = true
    for n = 1, GetNumBindings() do
        local command = GetBinding(n)
        if command and Mixed(GetBindingKey(command)) then
            witness = command
            break
        end
    end
    return witness
end

-- Whether the pad is the input in use, judged as the game's own bars judge
-- it. A controller that is plugged in but idle is not in use.
local function PadInUse()
    if not (C_GamePad and IsBindingForGamePad and GetBindingKey and GetNumBindings and GetBinding) then return false end
    if C_GamePad.IsEnabled and not C_GamePad.IsEnabled() then return false end
    local command = Witness()
    if command then return IsBindingForGamePad((GetBindingKey(command))) == true end
    -- no command tells: what the game last said, and keys until it says
    return padMode == true
end

-- a pad button as the game draws it for that controller, small; never words
local function Glyph(key, style, size)
    local text = style and _G["KEY_ABBR_" .. key .. style] or GetBindingText(key, 1)
    if type(text) ~= "string" or not (text:find("|A", 1, true) or text:find("|T", 1, true)) then return "" end
    size = size or GLYPH
    return (text:gsub("(|A:[^:|]+):%d+:%d+", "%1:" .. size .. ":" .. size))
end

-- a pad button's symbol for the controller in hand, at a size; "" when the game has none
function F.PadGlyph(key, size)
    local id = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    local state = id and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(id)
    return Glyph(key, state and PAD_STYLES[state.labelStyle], size)
end

-- a key as the bars write it: a number as it is, the rest shortened by the game
local function KeyText(key)
    if not key then return "" end
    if #key == 1 then return key end
    local text = GetBindingText(key, 1)
    if type(text) == "string" and text ~= "" then return text end
    return key
end

-- The pad buttons by place, counted from the bar button. The D-pad takes
-- the four places nearest the button, each direction where its icon lies, so
-- the four stay together. Places past those take the face buttons.
local function PadsFor(way, count)
    local set = Art.SIDES[way].x == 0 and PAD_UPRIGHT or PAD_LEVEL
    local fromStart = way == "DOWN" or way == "RIGHT"
    local group = math.min(count, DPAD)
    local out = {}
    for i = 1, count do
        -- where the icon lies among the four, from the top or the left
        local at = fromStart and i or group + 1 - i
        if i > group then
            out[i] = set.past[i - group]
        elseif at == 1 then
            out[i] = set.first
        elseif at == group then
            out[i] = set.last
        else
            out[i] = set.between[at - 1]
        end
    end
    return out
end
F.PadsFor = PadsFor

-- the one wanted if it is free, else the first free of the rest
local function Free(wanted, rest, taken)
    if wanted and not taken[wanted] then
        taken[wanted] = true
        return wanted
    end
    for _, key in ipairs(rest) do
        if not taken[key] then
            taken[key] = true
            return key
        end
    end
end

-- Each icon's key and pad button: its own where one was set, else by its
-- place. No key twice in one flyout; other flyouts and the bars do not count.
-- Our key layers addon, if it is there: ordinary keys that act as
-- modifiers while held. It says which keys those are and when one is down.
local layers

-- the keys it holds layers with: never an opener's, never a pick's
local function HoldKeys()
    local out = {}
    if not (layers and type(layers.HoldKeys) == "function") then return out end
    local ok, keys = pcall(layers.HoldKeys)
    for _, key in ipairs(ok and type(keys) == "table" and keys or {}) do
        if type(key) == "string" then out[key] = true end
    end
    return out
end

-- one of them is down: its layer has the bars' keys, and nothing is read off them
local function LayerHeld()
    if not (layers and type(layers.Held) == "function") then return false end
    local ok, held = pcall(layers.Held)
    return ok and held == true
end

-- The pad button for each place of a unit's flyout. Around its button: the first four on one cross of the
-- pad, each on its own side, any more on the other cross. As a strip: by where each lies along it. The
-- D-pad comes first, or the face buttons where the flyout or the profile says so.
-- Where each icon of a flyout stands around its button: a spot of the dial, 1 to 4 on the first ring
-- (up, right, down, left), 5 to 8 on the second and 9 to 12 on a third. An icon stands where it was
-- put (entry.spot, set in the pad's flyout editor); the others take the free spots in their order. Of
-- two put on one spot the first keeps it. `entries`: the icons, or how many there are.
local RINGS = 3
local SPOTS = RINGS * DPAD
local function Spots(entries)
    local out, taken = {}, {}
    if type(entries) == "number" then
        for i = 1, entries do out[i] = i end
        return out
    end
    for i, entry in ipairs(entries) do
        local spot = entry.spot
        if type(spot) == "number" and spot >= 1 and spot <= SPOTS and spot % 1 == 0 and not taken[spot] then
            out[i], taken[spot] = spot, true
        end
    end
    local free = 1
    for i in ipairs(entries) do
        if not out[i] then
            while taken[free] do free = free + 1 end
            out[i], taken[free] = free, true
        end
    end
    return out
end
-- the outermost spot in use
local function TopSpot(entries)
    local top = 0
    for _, spot in ipairs(Spots(entries)) do top = math.max(top, spot) end
    return top
end
F.Spots, F.TopSpot, F.SPOTS = Spots, TopSpot, SPOTS
-- around a button: a spot of the first ring is picked by one cross of the pad, each button on its own
-- side, a spot of the second ring by the other cross. A third ring has no cross left: none for it here.
local function RingPads(entries, faces)
    local first, second = DPAD_RING, FACE_RING
    if faces then first, second = FACE_RING, DPAD_RING end
    local out = {}
    for i, spot in ipairs(Spots(entries)) do
        if spot <= DPAD then
            out[i] = first[spot]
        elseif spot <= 2 * DPAD then
            out[i] = second[spot - DPAD]
        end
    end
    return out
end
F.RingPads, F.RING_GAP = RingPads, RING_GAP
-- where spot i of the dial is: how far across and up from the button's middle, the first ring `reach` out
function F.RingSpot(i, reach)
    local way = RING[(i - 1) % DPAD + 1]
    local out = reach + math.floor((i - 1) / DPAD) * (Art.ICON + RING_GAP)
    return way[1] * out, way[2] * out
end
-- the first ring's distance from the button's middle, in the flyout's own measure; and the plate's
-- reach where `top` is the outermost spot in use
function F.RingReach() return Art.BUTTON / 2 / F.Size() + RING_GAP + Art.ICON / 2 end
function F.Rings(top) return math.max(1, math.min(RINGS, math.ceil(top / DPAD))) end
function F.PlateReach(top, reach)
    local rings = F.Rings(top)
    return reach + (rings - 1) * (Art.ICON + RING_GAP) + Art.ICON / 2 + PLATE_PAD
end

local function PadsOf(unit, count)
    local faces = F.Faces(unit.flyout)
    local out = {}
    if unit.radial then
        -- by place: an icon of the third ring has none, and those after it keep theirs
        local pads = RingPads(unit.flyout.entries, faces)
        for i = 1, count do out[i] = pads[i] end
        return out
    end
    for i, pad in ipairs(PadsFor(unit.way or "UP", count)) do out[i] = faces and OTHER_CROSS[pad] or pad end
    return out
end
F.PadsOf = PadsOf

local function Picks(unit)
    local entries = unit.flyout.entries
    local pads = PadsOf(unit, #entries)
    local pool = F.Faces(unit.flyout) and PADS_ALL or PADS
    -- An open flyout's keys are the flyout's, a key that holds a layer of the key layers addon among
    -- them. His words (2026-11-22): "we should always respect our in-flyout keys. if someone opened the
    -- flyout, they want THOSE keys to take precedence. they can close the flyout if they want other
    -- behavior." Shut, every key is whoever's it was.
    local picks, taken = {}, {}
    for i, entry in ipairs(entries) do
        local key = type(entry.key) == "string" and entry.key or nil
        local pad = type(entry.pad) == "string" and entry.pad or nil
        if key and taken[key] then key = nil end
        if pad and taken[pad] then pad = nil end
        if key then taken[key] = true end
        if pad then taken[pad] = true end
        picks[i] = { key = key, pad = pad }
    end
    -- then the keys set in the game's key menu for the spots of every flyout
    for i, pick in ipairs(picks) do
        local key, pad = Binds.Pick(i)
        if not pick.key and key and not taken[key] then pick.key, taken[key] = key, true end
        if not pick.pad and pad and not taken[pad] then pick.pad, taken[pad] = pad, true end
    end
    for i, pick in ipairs(picks) do
        pick.key = pick.key or Free(KEYS[i], KEYS, taken)
        -- Around a button a pad button names a side: an icon of the third ring, which no cross of the
        -- pad is left for, is given none in its stead.
        if not pick.pad and (pads[i] or not unit.radial) then pick.pad = Free(pads[i], pool, taken) end
    end
    return picks
end
-- The keys an icon added in a fight would get, by the place it would take: the secure code that adds it
-- cannot work them out. As Picks gives them: the key set for that spot of every flyout, else the next
-- free one. None for a flyout nothing is added to in a fight.
local function Defaults(unit)
    local flyout, out, taken = unit.flyout, {}, {}
    if flyout.auto or unit.radial then return out end
    for _, entry in ipairs(flyout.all or flyout.entries) do
        if type(entry.key) == "string" then taken[entry.key] = true end
        if type(entry.pad) == "string" then taken[entry.pad] = true end
    end
    local count = #flyout.entries
    local pads = PadsOf(unit, count)
    local pool = F.Faces(flyout) and PADS_ALL or PADS
    for i = 1, MAX do
        local key, pad = Binds.Pick(i)
        local d = {}
        if key and not taken[key] then d.key, taken[key] = key, true end
        if pad and not taken[pad] then d.pad, taken[pad] = pad, true end
        out[i] = d
    end
    for i = 1, MAX do
        local d = out[i]
        d.key = d.key or Free(KEYS[i], KEYS, taken)
        local want = pads[i]
        if i > count then want = PadsOf(unit, i)[i] end
        d.pad = d.pad or Free(want, pool, taken)
    end
    return out
end
-- An icon's key and pad button as the secure code has written them in a fight, for its label: its own
-- where it has one, else its spot's.
local function Repick(unit)
    local defaults = unit.defaults
    if not defaults then return end
    local picks = {}
    for i, frame in ipairs(unit.entries) do
        local d = defaults[i] or {}
        picks[i] = { key = frame:GetAttribute("ffkey") or d.key, pad = frame:GetAttribute("ffpad") or d.pad }
    end
    unit.picks = picks
end

-- one label per icon: the pad's symbol while the pad is the input in use, else the key
-- the label style of the pad in use, and a pad button's symbol in it
local function PadStyle()
    local id = C_GamePad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    local state = id and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(id)
    return state and PAD_STYLES[state.labelStyle]
end
function F.PadText(pad, size) return Glyph(pad, PadStyle(), size) end

function Labels(unit)
    if not unit.picks then return end
    local pad = PadInUse()
    local style = pad and PadStyle()
    for i, frame in ipairs(unit.entries) do
        local pick = unit.picks[i]
        local text = ""
        if pick then
            text = pad and pick.pad and Glyph(pick.pad, style) or ""
            if text == "" then text = KeyText(pick.key) end
        end
        frame.key:SetText(text)
    end
end

-- the flyout's chosen icon on its bar button: over the button's own icon,
-- under its key text and its cooldown; none chosen shows the button's own.
-- With "Show the last one used on its button" (F.ShowLast), the icon picked from it last, once there is one.
local function Face(unit)
    local host, face = unit.host, unit.face
    local last = host and F.LastEntry(unit)
    local icon = host and ((last and F.Icon(last)) or (unit.flyout and unit.flyout.icon))
    if unit.mask then
        face:RemoveMaskTexture(unit.mask)
        unit.mask = nil
    end
    if not icon then
        face:Hide()
        F.LastLook(unit)
        return
    end
    local own = host.icon or host.Icon
    if type(own) ~= "table" or type(own.GetDrawLayer) ~= "function" then own = nil end
    local layer, level = "BACKGROUND", 0
    if own then layer, level = own:GetDrawLayer() end
    face:SetParent(host)
    face:SetDrawLayer(layer, math.min(7, (level or 0) + 1))
    face:ClearAllPoints()
    face:SetAllPoints(own or host)
    face:SetTexture(icon)
    -- cut to the button's shape where the button has one
    local mask = host.IconMask
    if type(mask) == "table" and type(mask.GetObjectType) == "function" then
        face:AddMaskTexture(mask)
        unit.mask = mask
    end
    face:Show()
    F.LastLook(unit)
end

-- The flyout's name on its bar button: where the game writes a macro's name, and in its lettering. A
-- name the game has written there itself (the button's own macro) gives way while the flyout has one.
-- His words (2026-11-22): "we need ability to put a name to the icon too, just like we can with macros."
local function Named(unit)
    local host, label = unit.host, unit.label
    local name = host and unit.flyout and unit.flyout.name
    -- the game's own text is seen again on a button this left, or whose flyout has no name any more
    -- (as it was seen before: another addon may have dimmed or hidden it)
    if unit.under then
        unit.under:SetAlpha(unit.underAlpha or 1)
        unit.under, unit.underAlpha = nil, nil
    end
    if type(name) ~= "string" or name == "" then
        label:Hide()
        return
    end
    local theirs = host.Name
    if type(theirs) ~= "table" or type(theirs.GetObjectType) ~= "function" then theirs = nil end
    label:SetParent(host)
    label:ClearAllPoints()
    if theirs then
        label:SetFontObject(theirs:GetFontObject() or NAME_FONT)
        label:SetAllPoints(theirs)
        unit.under, unit.underAlpha = theirs, theirs:GetAlpha()
        theirs:SetAlpha(0)
    else
        -- a bar button with no such text of its own: at its foot, as wide as the button
        label:SetFontObject(NAME_FONT)
        label:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, NAME_UP)
        label:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, NAME_UP)
    end
    label:SetText(name)
    label:Show()
end

-- A name for the flyout, as a macro has one: written on its bar button. An empty one takes it away.
function F.SetName(flyout, text)
    if InCombatLockdown() then return false, TEXT.fight end
    if not flyout then return false end
    local name = ""
    if type(text) == "string" then
        -- as the game does with a macro's name
        name = text:gsub('"', "")
        name = name:match("^%s*(.-)%s*$")
    end
    if name == "" then name = nil end
    flyout.name = name
    local unit = Run(flyout).unit
    if unit then Named(unit) end
    return true
end
F.NAME_LETTERS = NAME_LETTERS

-- the "?" icon, as for a macro, means the ability's own icon
local QUESTION = 134400

function F.SetIcon(flyout, icon)
    if icon == QUESTION then icon = nil end
    flyout.icon = icon
    local unit = Run(flyout).unit
    if unit then Face(unit) end
end

-- a right-click on a flyout's bar button opens the icon window
-- while keys are being set, a hover on the bar button opens its flyout
-- Another of a flyout's own icons goes onto its bar button, in the place of the one there. The button
-- then is that one: its icon, tooltip, cooldown and count, shown by the game itself. What was there
-- stays in the flyout, and the first one so replaced is remembered as the button's own, for a reset.
function F.Lead(flyout, entry)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout and entry) or flyout.auto or Run(flyout).lost then return false end
    local host = Bars.Named(flyout.host)
    local slot = host and Bars.Slot(host)
    if not slot then return false end
    flyout.icon = nil
    local was = flyout.main
    if was and Same(was, entry) then
        F.Apply()
        return true
    end
    ClearCursor()
    Pickup(entry)
    if not GetCursorInfo() then return false, TEXT.noPick end
    flyout.main = Copy(entry)
    PlaceAction(slot)
    ClearCursor()
    if was and not flyout.first then flyout.first = Copy(was) end
    if flyout.first and Same(flyout.first, entry) then flyout.first = nil end
    ns.Log(("lead: %s now holds %s:%s of its flyout"):format(tostring(flyout.host), tostring(entry.kind),
        tostring(entry.id)))
    F.Apply()
    return true
end

-- The button's own again: no icon of the player's choosing, and the ability it had before another of
-- the flyout's was put on it, when that one is still in the flyout.
function F.Reset(flyout)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout) then return false end
    flyout.icon = nil
    local first = flyout.first
    for _, entry in ipairs(first and F.Full(flyout) or {}) do
        if Same(entry, first) then
            local ok, why = F.Lead(flyout, entry)
            flyout.first = nil
            return ok, why
        end
    end
    flyout.first = nil
    F.Apply()
    return true
end

local function HostSized(self)
    local _, unit = F.At(self:GetName())
    if unit then Remark(unit) end
end
local function HostEntered(self)
    if not (ns.Keys and ns.Keys.On()) then return end
    local _, unit = F.At(self:GetName())
    if unit and open ~= unit then F.Show(unit.index) end
end

local function HostClicked(self, button, down)
    if button ~= "RightButton" or down then return end
    local flyout = F.At(self:GetName())
    if flyout and not root:GetAttribute("carrying") then ns.Icon.Open(flyout) end
end

-- A bar button's click opens the flyout hung on it: wrapped once, and told which flyout at each click.
-- Out of a fight only: the game wraps nothing in one.
local function HostWrap(host, name)
    if wrapped[name] ~= nil or InCombatLockdown() then return end
    wrapped[name] = pcall(root.WrapScript, root, host, "OnClick", HOST_WRAP, CLICK_AFTER)
    if wrapped[name] then
        host:HookScript("PostClick", HostClicked)
        host:HookScript("OnEnter", HostEntered)
        host:HookScript("OnSizeChanged", HostSized)
    end
end

-- where the icon in place i starts, along the flyout from the bar button
function F.Slot(i) return Art.FIRST + (i - 1) * (Art.ICON + Art.NEXT) end
-- how far past its button's edge the arrow takes a drop
function F.GripReach() return GRIP_OUT + GRIP_H / 2 + F.GRIP_REACH end

-- an icon frame that far along its flyout; out of a fight only
function F.Put(unit, frame, out)
    local side = Art.SIDES[unit.way]
    frame:ClearAllPoints()
    frame:SetPoint(side.point, unit.menu, side.point, side.x * out, side.y * out)
end
-- icon i in its place: along the strip, or on its spot around the button
function F.Seat(unit, frame, i)
    if not unit.radial then return F.Put(unit, frame, F.Slot(i)) end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", unit.menu, "CENTER", F.RingSpot(unit.spots and unit.spots[i] or i, unit.reach))
end

-- a unit placed, sized and turned for its bar
-- the ways a flyout can lie along each side of its button
local ACROSS = {
    UP = { "LEFT", "RIGHT" }, DOWN = { "LEFT", "RIGHT" },
    LEFT = { "UP", "DOWN" }, RIGHT = { "UP", "DOWN" },
}
F.ACROSS = ACROSS

-- A flyout's shape: the side of its button it opens on, the way its icons
-- run, and, lying along that side, whether it is centered on the button
-- (else its first icon is by the button and the rest run on). The player's
-- own choice; with none, straight out the bar's way.
function F.Shape(flyout, auto)
    local side = flyout.side
    if not Art.SIDES[side] then return auto, auto, false end
    for _, across in ipairs(ACROSS[side]) do
        if across == flyout.run then return side, across, flyout.mid == true end
    end
    return side, side, false
end

-- The flyout is in its bar's layer, just over every bar button of that layer, so a window that is
-- over the bars is over the flyout too. (It used to be in the layer of the game's own flyout, over
-- most windows, and showed through them.) The game lifts the bars for a spell on the cursor: the
-- flyout goes with them.
-- Over the buttons means over what they hold as well: the game keeps a button's key and count
-- texts on a frame of their own, 500 levels up, and a flyout only just over the buttons had the key
-- of the button under it showing through its icon (his snip, 2026-11-22: "keybinds from abilities
-- under a flyout show through the flyout").
local OVER_BARS = 20
local function Layer(unit)
    local host, menu = unit.host, unit.menu
    if not (host and menu) or InCombatLockdown() then return end
    local strata, level = host:GetFrameStrata(), host:GetFrameLevel()
    for _, button in ipairs(Bars.All()) do
        if button:GetFrameStrata() == strata then
            level = math.max(level, button:GetFrameLevel())
            -- frames that are not ours are asked through a plain frame's own calls
            for _, held in ipairs({ UIParent.GetChildren(button) }) do
                if UIParent.GetFrameStrata(held) == strata then
                    level = math.max(level, UIParent.GetFrameLevel(held))
                end
            end
        end
    end
    menu:SetFrameStrata(strata)
    menu:SetFrameLevel(level + OVER_BARS)
end
local function Layers()
    for f = 1, used do Layer(units[f]) end
end

-- Where a flyout and its grip hang on their button: kept for the secure code that hangs them on
-- another button in a fight (it cannot ask a frame for this in a fight).
local function Hung(unit)
    local f = unit.index
    root:SetAttribute("gover", GRIP_OVER)
    local point, _, to, x, y = unit.opener:GetPoint(1)
    root:SetAttribute("gp" .. f, point)
    root:SetAttribute("grp" .. f, to or point)
    root:SetAttribute("gx" .. f, x or 0)
    root:SetAttribute("gy" .. f, y or 0)
    point, _, to, x, y = unit.menu:GetPoint(1)
    root:SetAttribute("mp" .. f, point)
    root:SetAttribute("mrp" .. f, to or point)
    root:SetAttribute("mx" .. f, x or 0)
    root:SetAttribute("my" .. f, y or 0)
end

-- Where each icon stands in its flyout, and which icon stands there: kept for the secure code that
-- moves icons in a fight.
local function Spotted(unit, frame, i)
    local at = unit.index .. "_" .. i
    local point, _, to, x, y = frame:GetPoint(1)
    root:SetAttribute("sp" .. at, point)
    root:SetAttribute("srp" .. at, to or point)
    root:SetAttribute("sx" .. at, x or 0)
    root:SetAttribute("sy" .. at, y or 0)
    root:SetAttribute("at" .. at, frame:GetName())
    frame:SetAttribute("fffly", unit.index)
    frame:SetAttribute("ffspot", i)
end

local function Lay(unit)
    local flyout, host = unit.flyout, unit.host
    local way, runs = Bars.Way(host)
    local scale = Bars.Scale(host)
    -- At login the bars are not placed yet, and a login in a fight cannot
    -- be laid again: the way and scale last used on this button stand in.
    local last = not ready and Laid()[flyout.host]
    if last and Art.SIDES[last.way] then way, runs, scale = last.way, "as last laid", last.scale or scale end
    local sideName, runName, centered = F.Shape(flyout, way)
    local side, along, count = Art.SIDES[sideName], Art.SIDES[runName], #flyout.entries
    -- the strip stands or lies by the way its icons run; the grip and arrow go by the button's side
    local upright, edge = along.x == 0, side.x == 0
    local long = Art.FIRST + count * Art.ICON + (count - 1) * Art.NEXT + Art.PAD
    local opener, menu = unit.opener, unit.menu
    unit.way, unit.side, unit.barWay, unit.runs, unit.mid = runName, sideName, way, runs, centered
    -- On a bar of gamepad mode, with no shape of the player's own: around the button, as the pad's
    -- buttons lie around its middle.
    unit.radial = flyout.side == nil and Bars.Pad(host) and F.Around()
    -- the button's child: shows and hides with its bar
    opener:SetParent(host)
    opener:SetScale(Bars.Size(host))
    unit.grown = 1
    opener:SetFrameStrata(host:GetFrameStrata())
    opener:SetFrameLevel(host:GetFrameLevel() + GRIP_OVER)
    opener:ClearAllPoints()
    opener:SetSize(edge and GRIP_W or GRIP_H, edge and GRIP_H or GRIP_W)
    opener:SetPoint("CENTER", host, side.to, side.x * GRIP_OUT, side.y * GRIP_OUT)
    -- In a fight only the arrow may take a drop that adds to the flyout, and the plus stands past its tip,
    -- where it stands out of one: the arrow takes a drop that far out. His snips (2026-11-23): "'+' still
    -- getting compressed lower in combat". A click there opens the flyout, as one on the arrow does.
    local reach = F.GRIP_REACH
    opener:SetHitRectInsets(side.x < 0 and -reach or 0, side.x > 0 and -reach or 0, side.y > 0 and -reach or 0,
        side.y < 0 and -reach or 0)
    unit.arrow:ClearAllPoints()
    unit.arrow:SetPoint(side.to, host, side.to, side.x * ARROW_OUT, side.y * ARROW_OUT)
    unit.glow:ClearAllPoints()
    unit.glow:SetPoint("TOPLEFT", host, "TOPLEFT", -Art.GLOW, Art.GLOW)
    unit.glow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", Art.GLOW, -Art.GLOW)
    unit.ring:ClearAllPoints()
    unit.ring:SetPoint("TOPLEFT", host, "TOPLEFT")
    unit.ring:SetSize(Art.RING_W, Art.RING_H)
    Arrow(unit, "arrow")
    -- Around its button a flyout has no way it opens: four dots mark its button, where an arrow would
    -- seem to name a button of the D-pad.
    Art.LayDots(unit.dots, host, unit.radial)
    unit.arrow:SetShown(not unit.dots.shown)
    opener:Show()
    -- the bar's scale times the size picked in the settings (1 is the game's own)
    menu:SetScale(scale * F.Size())
    Layer(unit)
    menu:ClearAllPoints()
    if unit.radial then
        -- the first ring a step off the button, in the menu's own measure; the frame holds two rings,
        -- and a third when icons stand on it
        unit.reach = F.RingReach()
        unit.spots = Spots(flyout.entries)
        local rings = math.max(2, F.Rings(TopSpot(flyout.entries)))
        local span = 2 * (unit.reach + (rings - 1) * (Art.ICON + RING_GAP) + Art.ICON / 2)
        menu:SetPoint("CENTER", host, "CENTER")
        menu:SetSize(span, span)
        Art.HideStrip(unit.strip)
        -- the plate, where wanted, and the button's icon at its middle, as large as the button
        Art.LayDisc(unit.plate, menu, F.Plate() and F.Back() and F.PlateReach(TopSpot(flyout.entries), unit.reach)
            or nil)
        unit.hub:SetShown(unit.plate.radius ~= nil)
        unit.hub:SetScale(Art.BUTTON / F.Size() / Art.ICON)
        unit.hub.icon:SetTexture(flyout.icon or (flyout.main and F.Icon(flyout.main)) or nil)
    elseif sideName == runName or centered then
        -- straight out, or lying along the side with its middle at the button's middle
        menu:SetPoint(side.point, host, side.to, -side.x * Art.OVERLAP, -side.y * Art.OVERLAP)
    else
        -- lying along the button's side: its first icon by the button, the rest running on
        local mine, its = along.point .. side.point, along.point .. side.to
        if edge then mine, its = side.point .. along.point, side.to .. along.point end
        menu:SetPoint(mine, host, its, -side.x * Art.OVERLAP, -side.y * Art.OVERLAP)
    end
    if not unit.radial then
        Art.LayDisc(unit.plate, menu, nil)
        unit.hub:Hide()
        menu:SetSize(upright and Art.STRIP or long, upright and long or Art.STRIP)
        -- lying along the side, neither end opens onto the button: both are closed
        Art.LayStrip(unit.strip, menu, runName, sideName ~= runName)
        if not F.Back() then Art.HideStrip(unit.strip) end
    end
    Art.Fade(unit.strip, unit.plate, F.BackAlpha())

    for i, frame in ipairs(unit.entries) do
        local entry = flyout.entries[i]
        frame.entry, frame.flyout = entry, flyout
        F.Seat(unit, frame, i)
        Spotted(unit, frame, i)
        local how, attribute, casts
        if entry then how, attribute, casts = F.Casting(entry) end
        frame:SetAttribute("type", how)
        frame:SetAttribute("spell", nil)
        frame:SetAttribute("item", nil)
        frame:SetAttribute("macro", nil)
        frame:SetAttribute("toy", nil)
        frame:SetAttribute("macrotext", nil)
        if entry then
            frame:SetAttribute(attribute, casts)
            frame.icon:SetTexture(F.Icon(entry))
        end
        local help, harm = Leaning(entry)
        frame:SetAttribute("fhelp", help)
        frame:SetAttribute("fharm", harm)
        -- its name in what the flyout holds, for the secure code (a macro by its place in the list)
        local marked = entry and entry.id
        if entry and entry.kind == "macro" then marked = Macros.Find(entry) end
        frame:SetAttribute("ffmark", marked and (entry.kind .. ":" .. tostring(marked)) or nil)
        frame:SetShown(entry ~= nil)
    end
    Face(unit)
    Named(unit)
    State(unit)
    root:SetAttribute("count" .. unit.index, count)
    -- for an icon added in a fight: what the flyout holds (a macro by its place in the list, as the
    -- cursor names it), how many more it takes, and how its strip grows by one
    local whole, holds = flyout.all or flyout.entries, { "" }
    for _, entry in ipairs(whole) do
        local id = entry.id
        if entry.kind == "macro" then id = Macros.Find(entry) end
        if id then holds[#holds + 1] = entry.kind .. ":" .. tostring(id) end
    end
    holds[#holds + 1] = ""
    root:SetAttribute("holds" .. unit.index, table.concat(holds, ";"))
    for _, entry in ipairs(whole) do
        if entry.kind == "item" and Bars.OwnToy(entry.id) then root:SetAttribute("toy" .. entry.id, true) end
    end
    root:SetAttribute("room" .. unit.index, MAX - #whole)
    root:SetAttribute("mup" .. unit.index, upright or nil)
    root:SetAttribute("mlong" .. unit.index, long)
    root:SetAttribute("mstep" .. unit.index, Art.ICON + Art.NEXT)
    root:SetAttribute("auto" .. unit.index, flyout.auto and true or nil)
    unit.placed = Bars.Placed(host)
    if ready then Laid()[flyout.host] = { way = way, scale = scale } end
    Hung(unit)
    -- one that fills itself, or stands around its button, has no icon moved in a fight
    local still
    if unit.radial or flyout.auto then still = true end
    root:SetAttribute("still" .. unit.index, still)
end

-- Before 1.1.4 each flyout on the bars had a heading in the game's key menu with a row for each of six
-- spots (flyout.number said which heading). Those rows are no longer listed. A key someone set on one
-- becomes that icon's own key, once: it goes on working, and it can be seen and changed where an
-- icon's own key is set, by a hover in Quick Keybind Mode. The old row keeps its key in the game's
-- bindings: nothing of the game's is rewritten.
local function Carry()
    for _, flyout in ipairs(list or {}) do
        local n = flyout.number
        if n ~= nil then
            if type(n) == "number" then
                for i = 1, Binds.PLACES do
                    local entry = flyout.entries[i]
                    local key, pad = Binds.Spot(n, i)
                    if entry and key and entry.key == nil then entry.key = key end
                    if entry and pad and entry.pad == nil then entry.pad = pad end
                end
            end
            flyout.number = nil
        end
    end
end

-- the keys that open a flyout: its bar button's own
local function OpenKeys(unit)
    local keys, hold = {}, HoldKeys()
    -- asleep on a page of the bar out of view (F.PAGE): none
    if not unit.host then return keys end
    for _, key in ipairs(Bars.Keys(unit.host)) do
        if not hold[key] then keys[#keys + 1] = key end
    end
    return keys
end

-- What the secure code has to know of every bar button, should a flyout's ability be dropped on it
-- in a fight: its slot, and its keys. Written only where it changed, and the keys read only when the
-- key map did. Each button's drop is wrapped once, and its click, which opens whatever flyout the
-- secure code hangs on it. None of it during the login: the buttons are looked
-- for once the bars have settled, and after that a button new to the bars is taken up when the list of
-- them is next read for something else.
local reached, dropWrapped, reachedKeys = {}, {}, nil
local reachList, reachSeen
local function Reach()
    if not ready then return end
    local read = Bars.Known()
    if reachList == nil then
        reachList = Bars.Scan()
    elseif read and read ~= reachSeen then
        reachList = read
    end
    reachSeen = read
    local parts = {}
    for action, keys in pairs(Bars.KeyMap()) do parts[#parts + 1] = action .. "=" .. table.concat(keys, ",") end
    for key in pairs(HoldKeys()) do parts[#parts + 1] = "hold=" .. key end
    table.sort(parts)
    local now = table.concat(parts, ";")
    local same = now == reachedKeys
    reachedKeys = now
    for _, button in ipairs(reachList) do
        local name = button:GetName()
        if name then
            local known = reached[name]
            if not known then
                known = {}
                reached[name] = known
            end
            local slot = Bars.Slot(button)
            if known.slot ~= slot then
                known.slot = slot
                root:SetAttribute("slot-" .. name, slot)
            end
            if not same or known.keys == nil then
                local keys = OpenKeys({ host = button })
                local text = table.concat(keys, " ")
                if known.keys ~= text then
                    known.keys = text
                    for i, key in ipairs(keys) do root:SetAttribute("bkey-" .. name .. "_" .. i, key) end
                    root:SetAttribute("bkeys-" .. name, #keys)
                end
            end
            if dropWrapped[name] == nil and not InCombatLockdown() then
                dropWrapped[name] = pcall(root.WrapScript, root, button, "OnReceiveDrag", DROP_BEFORE, DROP_AFTER)
            end
            HostWrap(button, name)
        end
    end
end
F.DropWrapped = function(name) return dropWrapped[name] == true end

-- Each button's keys click its opener, read fresh. Each flyout's picks are
-- listed for the snippet, also under the modifiers of a key that can be held.
local function Rebind()
    ClearOverrideBindings(root)
    Bars.KeyMap(true)
    for f = 1, used do
        local unit = units[f]
        local mods, plain, listed = {}, {}, 0
        local function List(key, i)
            listed = listed + 1
            root:SetAttribute("pkey" .. f .. "_" .. listed, key)
            root:SetAttribute("pentry" .. f .. "_" .. listed, ENTRY .. f .. "_" .. i)
            root:SetAttribute("pspot" .. f .. "_" .. listed, i)
        end
        unit.picks = Picks(unit)
        for i, pick in ipairs(unit.picks) do
            for _, key in ipairs({ pick.key, pick.pad }) do
                List(key, i)
                plain[key] = true
            end
        end
        unit.keys = OpenKeys(unit)
        -- An opener key with a modifier: while the modifier is held, a plain pick key arrives
        -- under it, so the picks are bound under it too. That goes for the opener's own key:
        -- pressed again with the flyout open it picks its spot, as a plain key does (a shoulder
        -- and D-pad down opens, the same again picks the spot D-pad down stands for).
        for _, key in ipairs(unit.keys) do
            local mod = key:match("^(.*%-).")
            if mod then mods[mod] = true end
        end
        for mod in pairs(mods) do
            for i, pick in ipairs(unit.picks) do
                for _, base in ipairs({ pick.key, pick.pad }) do
                    local under = mod .. base
                    if not base:find("-", 1, true) and not plain[under] then
                        List(under, i)
                        plain[under] = true
                    end
                end
            end
        end
        -- For the secure code, which writes the pick keys afresh when an icon is taken off, put back or
        -- added in a fight: each spot's key and pad button (those it has when its icon has none of its
        -- own), each icon's own, and the modifiers of the flyout's own keys.
        unit.defaults = Defaults(unit)
        for i = 1, MAX do
            local d = unit.defaults[i] or {}
            root:SetAttribute("xkey" .. f .. "_" .. i, d.key)
            root:SetAttribute("xpad" .. f .. "_" .. i, d.pad)
        end
        for i, frame in ipairs(unit.entries) do
            local entry, pick = frame.entry, unit.picks[i]
            local key, pad
            if entry and pick and entry.key ~= nil and entry.key == pick.key then key = pick.key end
            if entry and pick and entry.pad ~= nil and entry.pad == pick.pad then pad = pick.pad end
            frame:SetAttribute("ffkey", key)
            frame:SetAttribute("ffpad", pad)
        end
        local modList = {}
        for mod in pairs(mods) do modList[#modList + 1] = mod end
        table.sort(modList)
        for j, mod in ipairs(modList) do root:SetAttribute("mod" .. f .. "_" .. j, mod) end
        root:SetAttribute("mods" .. f, #modList)
        for i, key in ipairs(unit.keys) do
            -- a key that is a pick while open says so in its click's name: held, it is kept from its
            -- icon until it is let go, so that its release comes to the opener
            local how = plain[key] and ("own" .. i) or "LeftButton"
            root:SetAttribute("okey" .. f .. "_" .. i, key)
            root:SetAttribute("obtn" .. f .. "_" .. i, how)
            SetOverrideBindingClick(root, true, key, OPENER .. f, how)
        end
        root:SetAttribute("pkeys" .. f, listed)
        root:SetAttribute("okeys" .. f, #unit.keys)
        Labels(unit)
    end
    Reach()
    menuKeys = Binds.State()
    quiet = math.max(quiet, GetTime() + 0.5)
end

local function Signature()
    local parts = {}
    for f = 1, used do parts[f] = table.concat(units[f].keys, " ") end
    parts[#parts + 1] = menuKeys or ""
    return table.concat(parts, "|")
end

-- keys changed elsewhere: a new one shows at once,
-- one taken off hides under ours, so bind afresh
local function Rekey()
    rekey = nil
    Bars.KeyMap(true)
    local grown = false
    for f = 1, used do
        if #OpenKeys(units[f]) ~= #units[f].keys then grown = true end
    end
    -- a key set or taken off in the game's key menu counts at once
    if Binds.State() ~= menuKeys then grown = true end
    if not grown and GetTime() < patient then return end
    local was = Signature()
    Carry()
    Rebind()
    if Signature() == was then
        idle = idle + 1
        patient = GetTime() + math.min(300, 5 * 2 ^ idle)
    else
        idle, patient = 0, 0
        Tell("rekey")
    end
end

-- the spell a macro stands for just now, by the game's own word; nil when it names none
function F.Stands(entry)
    local spell = GetMacroSpell and GetMacroSpell(Macros.Ref(entry))
    if Hidden(spell) or type(spell) ~= "number" then return nil end
    return spell
end

-- A spell's name, its rank and its number, for telling the ranks of one spell: of a spell, and of a
-- macro that stands for one. Nil for anything else.
local function RankOf(entry)
    local spell
    if entry.kind == "spell" then
        spell = entry.id
    elseif entry.kind == "macro" then
        spell = F.Stands(entry)
    end
    if not spell then return nil end
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spell)
    if Hidden(name) or type(name) ~= "string" or name == "" then return nil end
    local sub = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(spell)
    if Hidden(sub) or type(sub) ~= "string" then return name, nil, spell end
    return name, tonumber(sub:match("%d+")), spell
end

-- The ranks of one spell stand in rank order, in the places they hold
-- between them, whichever of them the button has. The rest stay put.
local function Order(entries)
    local groups = {}
    for place, entry in ipairs(entries) do
        local name, rank, spell = RankOf(entry)
        if name then
            local group = groups[name]
            if not group then
                group = { places = {}, members = {}, ranked = true }
                groups[name] = group
            end
            group.places[#group.places + 1] = place
            group.members[#group.members + 1] = { entry = entry, rank = rank, spell = spell, at = place }
            if not rank then group.ranked = false end
        end
    end
    local changed = false
    for _, group in pairs(groups) do
        if #group.members > 1 then
            -- by the rank the game names for each; where it names none, by the spells' own numbers
            for _, member in ipairs(group.members) do
                member.key = member.spell
                if group.ranked then member.key = member.rank end
            end
            table.sort(group.members, function(a, b)
                if a.key ~= b.key then return a.key < b.key end
                return a.at < b.at
            end)
            local shifted = false
            for k, place in ipairs(group.places) do
                local entry = group.members[k].entry
                if entries[place] ~= entry then entries[place], shifted = entry, true end
            end
            if shifted then
                changed = true
                ns.Log(("ranks: %d of one spell put in order by %s"):format(#group.members,
                    group.ranked and "the ranks the game names" or "the spells' own numbers"))
            end
        end
    end
    return changed
end

-- The whole of a flyout. One set to show only what the player has keeps
-- the whole in `all` while it is in use, and shows the rest as its entries.
local function Full(flyout) return flyout.all or flyout.entries end
F.Full = Full

-- An item the player has none of; a spell, a macro, a mount or a pet is never lacking, nor a toy of the
-- player's own: it is kept in the Toy Box, and the bags hold none of it. Until 1.1.6 a toy was left out
-- the moment it was added, and dropped again it was refused as one the flyout held already.
local function Lacks(entry)
    if entry.kind ~= "item" or not C_Item.GetItemCount then return false end
    if Bars.OwnToy(entry.id) then return false end
    local count = C_Item.GetItemCount(entry.id)
    if Hidden(count) or type(count) ~= "number" then return false end
    return count == 0
end

-- what a flyout shows of its whole when it leaves out what the player lacks
function F.Held(flyout)
    local out = {}
    for _, entry in ipairs(Full(flyout)) do
        if not Lacks(entry) then out[#out + 1] = entry end
    end
    return out
end

-- the shown ones were put in a new order: the whole takes it, the hidden ones staying where they are
local function Mirror(flyout)
    local all = flyout.all
    if not all then return end
    local shown, k = {}, 0
    for _, entry in ipairs(flyout.entries) do shown[entry] = true end
    for place, entry in ipairs(all) do
        if shown[entry] then
            k = k + 1
            all[place] = flyout.entries[k]
        end
    end
end

-- saved data holds the whole of every flyout, as its entries
local function Whole(flyouts)
    for _, flyout in ipairs(flyouts or {}) do
        if type(flyout) == "table" and type(flyout.all) == "table" then flyout.entries, flyout.all = flyout.all, nil end
    end
end

-- lays every flyout on its button; waits out a fight
function F.Apply()
    if InCombatLockdown() then
        pending = true
        return false
    end
    pending = nil
    -- the macro list is read afresh for every laying out
    Macros.Changed()
    Build()
    -- what was picked last from each flyout, before its icons are laid anew
    F.KeepLast()
    CastSettings()
    for _, unit in ipairs(units) do
        if unit.shuffled then
            -- moved by the secure code in a fight: in the order they were made in again, laid below
            local frames = unit.entries
            unit.entries, unit.shuffled = {}, nil
            for _, frame in ipairs(frames) do
                unit.entries[frame.made] = frame
                frame.entryIndex = frame.made
            end
        end
    end
    for _, unit in ipairs(units) do unit.menu:Hide() end
    root:SetAttribute("open", nil)
    -- no key counts as held or pressed across a layout
    root:Execute("armed, held, picked = nil, nil, nil")
    local taken, leads, pages, sleeping = {}, {}, {}, {}
    used = 0
    local ranked, hiding = F.Ranked(), F.Hiding()
    for _, flyout in ipairs(list or {}) do
        -- one that fills itself: what is in the bags now
        if flyout.auto and ns.Auto then
            flyout.entries = (ns.Auto.Entries(flyout.auto))
        else
            local full = Full(flyout)
            if ranked then Order(full) end
            flyout.have = nil
            if hiding then
                -- only what the player has now; the whole is kept beside it
                flyout.all = full
                flyout.entries = F.Held(flyout)
            elseif flyout.all then
                flyout.entries, flyout.all = full, nil
            end
        end
        local state = Run(flyout)
        local name = flyout.host
        local host = not state.lost and Bars.Named(name)
        state.unit = nil
        -- On a button of Action Bar 1 that the bar turns by its page, its ability on one of the button's
        -- pages: laid on its button whichever page is in view, asleep while its own is not (no arrow, no
        -- key, a click there for the bar), for the secure code to wake the moment the bar turns to its
        -- page (F.PAGE).
        local slots, sleeps = F.PageSlots(flyout), false
        if slots and #slots > 0 then
            host = Bars.Named(name)
            sleeps = host ~= nil and Bars.Slot(host) ~= slots[1]
            state.lost = nil
        end
        if host and #flyout.entries > 0 and (sleeps or not taken[name]) then
            used = used + 1
            local unit = Unit(used)
            unit.flyout, unit.host, unit.asleep = flyout, host, nil
            state.unit = unit
            Lay(unit)
            -- its click opens the flyout (wrapped already, with every bar button's, once the bars settled)
            HostWrap(host, name)
            local last = F.LastIcon(unit)
            root:SetAttribute("last" .. used, last and last:GetName() or nil)
            for _, slot in ipairs(slots or {}) do pages[slot] = used end
            root:SetAttribute("pslot" .. used, slots and slots[1] or nil)
            if sleeps then
                unit.asleep, unit.host = true, nil
                unit.opener:Hide()
                Face(unit)
                Named(unit)
                sleeping[name] = true
                root:SetAttribute("hostof" .. used, nil)
                root:SetAttribute("lead" .. used, nil)
            else
                taken[name] = true
                root:SetAttribute("host-" .. name, used)
                root:SetAttribute("hostof" .. used, name)
                -- what the game says the button holds: by this the secure code knows the flyout's
                -- ability on another button, should it be dragged there in a fight
                local slot = Bars.Slot(host)
                local kind, id
                if slot then kind, id = GetActionInfo(slot) end
                local lead
                if type(kind) == "string" and (type(id) == "number" or type(id) == "string") then
                    lead = kind .. ":" .. tostring(id)
                    leads[lead] = true
                    root:SetAttribute("main-" .. lead, used)
                end
                root:SetAttribute("lead" .. used, lead)
            end
        end
    end
    for name in pairs(hosted) do
        if not taken[name] then root:SetAttribute("host-" .. name, nil) end
    end
    hosted = taken
    -- each slot of Action Bar 1's pages that leads a flyout there, for F.PAGE
    for slot in pairs(F.pages or {}) do
        if not pages[slot] then root:SetAttribute("page-" .. slot, nil) end
    end
    for slot, f in pairs(pages) do root:SetAttribute("page-" .. slot, f) end
    F.pages = pages
    for i = 1, Bars.MAIN_COUNT do
        local button = _G[Bars.MAIN_BUTTON .. i]
        local name = button and Bars.MainIndex(Bars.MAIN_BUTTON .. i) and Bars.MAIN_BUTTON .. i
        if name then root:SetAttribute("slot-" .. name, Bars.Slot(button)) end
    end
    root:SetAttribute("paging", Bars.MainBar() ~= nil or nil)
    root:SetAttribute("twice", F.Twice() or nil)
    F.PageWrap()
    for lead in pairs(mains) do
        if not leads[lead] then root:SetAttribute("main-" .. lead, nil) end
    end
    mains = leads
    -- remembered layouts of buttons that no longer have a flyout go
    if ready then
        local laid = Laid()
        for name in pairs(laid) do
            if not taken[name] and not sleeping[name] then laid[name] = nil end
        end
    end
    for f = used + 1, #units do
        local unit = units[f]
        unit.opener:SetParent(UIParent)
        unit.opener:Hide()
        unit.flyout, unit.host, unit.placed, unit.keys = nil, nil, nil, {}
        Face(unit)
        unit.face:SetParent(unit.opener)
        Named(unit)
        unit.label:SetParent(unit.opener)
        root:SetAttribute("okeys" .. f, 0)
        root:SetAttribute("pkeys" .. f, 0)
        root:SetAttribute("count" .. f, 0)
        root:SetAttribute("hostof" .. f, nil)
        root:SetAttribute("lead" .. f, nil)
        root:SetAttribute("pslot" .. f, nil)
        root:SetAttribute("last" .. f, nil)
        unit.asleep = nil
    end
    root:SetAttribute("units", used)
    root:SetAttribute("adrift", nil)
    Carry()
    Rebind()
    Tell("laid")
    return true
end

-- fn() true while the bars are put away for a moment; flyouts stay put till it is over
function F.StillWhile(fn) stills[#stills + 1] = fn end

-- keeps each flyout on the button that holds its action
function F.Follow()
    if not list or InCombatLockdown() then return end
    for _, still in ipairs(stills) do
        if still() then return end
    end
    local search, change, buttons = moved, false, nil
    moved = nil
    for _, flyout in ipairs(list) do
        local state, main = Run(flyout), flyout.main
        local held = Bars.Named(flyout.host)
        local on = main == nil or (held ~= nil and Bars.Holds(held, main))
        -- asleep on a page of its button out of view: on its button, not off it
        local asleep = main ~= nil and F.Sleeps(flyout)
        if asleep then on = true end
        if main and not asleep and not (on and held:IsVisible()) then
            -- off its button or its bar hidden: looked for once
            local why = on and "hidden" or "off"
            if search or state.sought ~= why then
                state.sought = why
                buttons = buttons or Bars.All(true)
                -- its saved button gone for good (a bar addon taken off): a hidden bar of the game's will do
                local found = Bars.Find(main, buttons, held == nil)
                if found then
                    Tell("follow", flyout, flyout.host, found)
                    flyout.host, state.lost, state.sought, change = found, nil, nil, true
                    flyout.slot = F.SlotOn(Bars.Named(found))
                elseif not on and not state.lost then
                    Tell("follow", flyout, flyout.host, nil)
                    state.lost, change = true, true
                end
            end
            -- a hidden bar's button still holds it: it stays there
            if on and state.lost then state.lost, change = nil, true end
        else
            state.sought = nil
            if state.lost then
                state.lost, change = nil, true
            elseif state.unit and held and Bars.Placed(held) ~= state.unit.placed then
                change = true
            elseif state.unit and (state.unit.asleep == true) ~= asleep then
                -- awake on a page out of view, or asleep on the one in view: the secure code missed a
                -- turn of the bar
                change = true
            end
        end
    end
    if change then return F.Apply() end
end

-- flyouts from saved data show only where their action is
-- The secure code moved a flyout to another button in a fight, or took one off its button: what addon
-- code may still do then. Where the flyout sits is saved, and the marks on the button follow, which
-- are drawings and no frames. All of it is laid afresh when the fight is over.
Rehomed = function(f, name, off)
    if not InCombatLockdown() then return F.Settle() end
    pending = true
    local gone = units[off]
    if gone and gone.flyout then
        -- off its button: its marks went with its grip; what was drawn on the button itself goes too
        gone.host = nil
        Face(gone)
        Named(gone)
    end
    local unit, host = units[f], Bars.Named(name)
    if not (unit and unit.flyout and host) then return end
    local flyout = unit.flyout
    local laid, old = Laid(), flyout.host
    laid[name], laid[old] = laid[old] or laid[name], nil
    flyout.host, unit.host = name, host
    flyout.slot = F.SlotOn(host)
    hosted[name] = true
    unit.keys = OpenKeys(unit)
    local side = Art.SIDES[unit.side]
    if side then
        unit.arrow:ClearAllPoints()
        unit.arrow:SetPoint(side.to, host, side.to, side.x * ARROW_OUT, side.y * ARROW_OUT)
    end
    unit.glow:ClearAllPoints()
    unit.glow:SetPoint("TOPLEFT", host, "TOPLEFT", -Art.GLOW, Art.GLOW)
    unit.glow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", Art.GLOW, -Art.GLOW)
    unit.ring:ClearAllPoints()
    unit.ring:SetPoint("TOPLEFT", host, "TOPLEFT")
    Art.LayDots(unit.dots, host, unit.radial)
    Face(unit)
    Named(unit)
    State(unit)
    ns.Log(("in a fight %s was dropped on %s: its flyout went along"):format(Name(flyout.main), name))
    Tell("moved", unit)
end

-- The slot of a flyout on a button of Action Bar 1 that the bar turns by its page, while it holds the
-- flyout's ability, as a list of one (none when it no longer does); nil for a flyout on any other button.
-- Each page is a bar of its own: a flyout is kept to the one slot it was made on. His words (2026-11-23):
-- "bear form vs no form is supposed to be completely separate bar. yet if i make flyout on no stance bar,
-- and have the same ability in that slot in bear form, it auto makes the bear form version of it a flyout
-- too". A flyout saved with no slot (made before this) takes the first of its button's pages that holds
-- its ability: the bar out of form before a form's.
function F.PageSlots(flyout)
    local i = flyout and flyout.main and Bars.MainIndex(flyout.host)
    if not i then return nil end
    local slot = flyout.slot
    if type(slot) ~= "number" or (slot - 1) % Bars.MAIN_COUNT + 1 ~= i then
        slot = Bars.PageSlots(i, flyout.main)[1]
        if not slot then return {} end
        flyout.slot = slot
    end
    if not Bars.HoldsAt(slot, flyout.main) then return {} end
    return { slot }
end

-- the slot a button of Action Bar 1 stands for now, kept with a flyout hung on it; nil for any other button
function F.SlotOn(button)
    local name = button and button:GetName()
    if not (name and Bars.MainIndex(name)) then return nil end
    return Bars.Slot(button)
end

-- asleep: on its button of Action Bar 1, its slot on a page of the button out of view (the page in view
-- may hold the same ability: that is another bar's)
function F.Sleeps(flyout)
    local slots = F.PageSlots(flyout)
    if not (slots and #slots > 0) then return false end
    local held = Bars.Named(flyout.host)
    return held ~= nil and Bars.Slot(held) ~= slots[1]
end

-- The bar's turns are followed by F.PAGE, run by a state driver of the addon's own on the conditions the
-- game turns the bar by (Bars.PAGE_STATES): set up once, out of a fight, with the bar and its buttons
-- known to the root. The driver's frame is hidden: a state driver runs on a hidden frame as on one shown.
do
    local PAGER, pager = "FallensFlyoutsPager", nil
    function F.PageWrap()
        if pager or InCombatLockdown() or not root then return end
        local bar = _G[Bars.MAIN_BAR]
        if type(bar) ~= "table" then return end
        local count = 0
        for i = 1, Bars.MAIN_COUNT do
            local button = _G[Bars.MAIN_BUTTON .. i]
            if type(button) == "table" then
                root:SetFrameRef("mainbutton" .. i, button)
                count = i
            end
        end
        root:SetAttribute("mainbuttons", count)
        root:SetAttribute("ffpage", F.PAGE)
        pager = CreateFrame("Frame", PAGER, UIParent, "SecureHandlerStateTemplate")
        pager:Hide()
        pager:SetFrameRef("root", root)
        pager:SetAttribute("_onstate-ffpage", [[self:GetFrameRef("root"):RunAttribute("ffpage")]])
        local ok = pcall(RegisterStateDriver, pager, "ffpage", Bars.PAGE_STATES)
        ns.Log(("pages: Action Bar 1's turns are followed by a state driver: %s, over %d buttons"):format(
            tostring(ok), count))
    end
end

-- The secure code turned Action Bar 1's flyouts with the bar's page (F.PAGE): which are asleep and which
-- awake is read off it. What is drawn on the bar's buttons follows, in a fight too (drawings, no
-- frames): the woken flyout's own icon and name on its button, and its keys' text; the one gone to sleep
-- takes its own away, first, so that the button's own name is given back before it is covered again.
function F.Paged()
    for f = 1, used do
        local unit = units[f]
        if unit.flyout and unit.host and not root:GetAttribute("hostof" .. f) then
            unit.asleep, unit.host, unit.keys = true, nil, {}
            Face(unit)
            Named(unit)
        end
    end
    for f = 1, used do
        local unit = units[f]
        local name = root:GetAttribute("hostof" .. f)
        local host = name and Bars.Named(name)
        if unit.flyout and not unit.host and host then
            unit.asleep, unit.host = nil, host
            unit.keys = OpenKeys(unit)
            Face(unit)
            Named(unit)
            State(unit)
            Labels(unit)
        end
    end
    if InCombatLockdown() then pending = true end
    Tell("paged")
end

-- The secure code took an icon off its flyout in a fight (`from`: its place; `gone`: the flyout is no
-- flyout any more): what is saved follows, and the addon's own list of the flyout's icons, whose frames
-- stand in the order of their spots (the hidden one after those in use), so that each is still read
-- with what it casts. When the fight is over all of it is laid afresh; a flyout that is gone is removed.
function F.Lifted(f, from, gone)
    local unit = units[f]
    local flyout = unit and unit.flyout
    if not (flyout and flyout.entries[from]) then return end
    local count = #flyout.entries
    local entry = table.remove(flyout.entries, from)
    for place = #(flyout.all or {}), 1, -1 do
        if flyout.all[place] == entry then table.remove(flyout.all, place) end
    end
    local frame = table.remove(unit.entries, from)
    table.insert(unit.entries, count, frame)
    for i, one in ipairs(unit.entries) do one.entryIndex = i end
    unit.lifted = { frame = frame, entry = entry }
    unit.shuffled = true
    Repick(unit)
    pending = true
    if gone then
        Run(flyout).forget = true
        unit.host = nil
        Face(unit)
        Named(unit)
    end
    if not InCombatLockdown() then return F.Settle() end
    Labels(unit)
    State(unit)
    ns.Log(("in a fight %s was taken off the flyout on %s, from place %d%s"):format(Name(entry), tostring(flyout.host),
        from, gone and "; the flyout is gone with it" or ""))
    Tell("lifted", unit, from)
end

-- The secure code put the icon it took off back in, on spot `to` of the same flyout.
function F.Landed(f, to)
    local unit = units[f]
    local flyout, held = unit and unit.flyout, unit and unit.lifted
    if not (flyout and held) then return end
    unit.lifted = nil
    table.insert(flyout.entries, to, held.entry)
    if flyout.all then
        -- in the whole, right after the one shown before it
        local before, place = flyout.entries[to - 1], 1
        for i, other in ipairs(flyout.all) do
            if other == before then place = i + 1 end
        end
        table.insert(flyout.all, place, held.entry)
    end
    for i, frame in ipairs(unit.entries) do
        if frame == held.frame then
            table.remove(unit.entries, i)
            break
        end
    end
    table.insert(unit.entries, to, held.frame)
    for i, one in ipairs(unit.entries) do one.entryIndex = i end
    Repick(unit)
    pending = true
    if not InCombatLockdown() then return F.Settle() end
    Labels(unit)
    State(unit)
    ns.Log(("in a fight %s went back into the flyout on %s, at place %d"):format(Name(held.entry),
        tostring(flyout.host), to))
    Tell("moved", unit)
end

function F.Settle()
    if InCombatLockdown() then
        pending = true
        return
    end
    for f = 1, used do units[f].lifted = nil end
    for i = #(list or {}), 1, -1 do
        -- (Forget is written further down)
        if Run(list[i]).forget then F.Forget(list[i]) end
    end
    for _, flyout in ipairs(list or {}) do
        local held, state = Bars.Named(flyout.host), Run(flyout)
        local on = flyout.main == nil or (held ~= nil and Bars.Holds(held, flyout.main)) or F.Sleeps(flyout)
        state.lost, state.sought = not on or nil, nil
        -- off its button, or on a hidden one: the bars are searched
        if flyout.main and not (on and held:IsVisible()) then moved = true end
    end
    F.Apply()
    F.Follow()
end

-- the profile in use; a damaged flyout is dropped, not patched
function F.Load()
    Whole(list)
    local data = P.Data()
    list = data and data.flyouts
    Whole(list)
    if type(list) ~= "table" then
        list = nil
        return
    end
    for i = #list, 1, -1 do
        local flyout = list[i]
        if type(flyout) ~= "table" or type(flyout.entries) ~= "table" then
            table.remove(list, i)
        else
            flyout.lost = nil
        end
    end
end

-- an old save with no lead: its first entry leads
local function Adopt()
    if InCombatLockdown() then return end
    for _, flyout in ipairs(list or {}) do
        local held, first = Bars.Named(flyout.host), flyout.entries[1]
        if not flyout.main and held and first and Bars.Holds(held, first) then
            flyout.main = Copy(first)
        end
    end
end

function F.List() return list end
function F.Units() return units, used end
-- the flyouts an ability can be added to in a fight, each as its frames: made by hand, in a row, with
-- room, and on a button
function F.Roomy()
    local out = {}
    for f = 1, used do
        local unit = units[f]
        local flyout = unit.flyout
        if flyout and unit.host and not flyout.auto and not unit.radial and #Full(flyout) < MAX then
            out[#out + 1] = unit
        end
    end
    return out
end
function F.Open() return open end
function F.Lost(flyout) return Run(flyout).lost == true end
function F.UnitOf(flyout)
    local unit = Run(flyout).unit
    -- asleep on a page of Action Bar 1 out of view: no button to be shown, turned or edited on
    if unit and unit.asleep then return nil end
    return unit
end
function F.Pause(on) paused = on end
-- whether the pad is the input in use right now, and the command that tells
function F.PadInUse() return PadInUse(), witness end
function F.Wrapped(name) return wrapped[name] == true end

-- flyout size against the game's own (1), kept with the profile
F.SIZE_MIN, F.SIZE_MAX = SIZE_MIN, SIZE_MAX
function F.Size()
    local data = P.Data()
    local size = data and tonumber(data.size) or 1
    return math.max(SIZE_MIN, math.min(SIZE_MAX, size))
end

function F.SetSize(size)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    size = math.max(SIZE_MIN, math.min(SIZE_MAX, tonumber(size) or 1))
    if size == 1 then
        data.size = nil
    else
        data.size = size
    end
    F.Apply()
    return true
end

-- An icon's own key (or pad button) inside its flyout; nil gives it back
-- its place's. Only its own flyout must not use the key twice.
function F.SetKey(flyout, i, key, pad)
    if InCombatLockdown() then return false, TEXT.fight end
    local entry = flyout and flyout.entries[i]
    if not entry then return false end
    local field = pad and "pad" or "key"
    for _, other in ipairs(Full(flyout)) do
        if other ~= entry and other[field] == key then other[field] = nil end
    end
    entry[field] = key
    local unit = Run(flyout).unit
    local shown = unit ~= nil and open == unit
    if root then Rebind() end
    -- the open one's picks are bound by the snippet: run it again
    if shown then F.Show(unit.index) end
    return true
end

-- the key and pad button each icon of a flyout on the bars is picked with
-- Gives a flyout a shape of the player's own: a side of its button, and a
-- way to lie along it or none for straight out. No side: the bar's way
-- again. `live`: laid again at once and left open, while it is being turned.
-- `mid`: lying along the side, centered on the button.
function F.SetShape(flyout, side, lie, live, mid)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout) or (side ~= nil and not Art.SIDES[side]) then return false end
    flyout.side, flyout.run, flyout.mid = side, nil, nil
    for _, across in ipairs(side and ACROSS[side] or {}) do
        if across == lie then flyout.run = lie end
    end
    if flyout.run and mid then flyout.mid = true end
    local unit = Run(flyout).unit
    if live and unit then
        Lay(unit)
        return true
    end
    local shown = unit ~= nil and open == unit
    F.Apply()
    unit = Run(flyout).unit
    if shown and unit then F.Show(unit.index) end
    return true
end

-- Whether flyouts leave out the items the player has none of, and take
-- them back when there are some again: the profile's, on unless turned off.
-- Off, such an item stays in its place, grayed. One that fills itself hides them anyway.
function F.Hiding()
    local data = P.Data()
    return not (data and data.showLacking)
end
function F.SetHiding(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.showLacking = not on or nil
    F.Apply()
    return true
end

-- Whether a flyout on a bar of gamepad mode opens around its button, each icon on the side its pad
-- button is: the profile's, on unless turned off. One with a shape of its own keeps that shape.
function F.Around()
    local data = P.Data()
    return not (data and data.padStrip)
end
function F.SetAround(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.padStrip = not on or nil
    F.Apply()
    return true
end

-- Whether a flyout that stands around its button has a round plate behind it, to tell at a glance
-- that it is open: the profile's, on unless turned off.
function F.Plate()
    local data = P.Data()
    return not (data and data.padBare)
end

-- Whether a flyout's background is drawn (the game's strip behind its icons, and the round plate behind
-- icons around a button), and how opaque it is: the profile's, shown and whole unless set otherwise.
-- His words (2026-11-24): "bro what is this \"smaller, larger\" lmao. just throwing away ui principles? why
-- not just follow the api's scroll anyway?" with a snip of the game's own stepper slider, and "i feel like
-- we should have a button for \"match base icon size\" (which does what you would think) and maybe a box
-- nearby to toggle whether the flyout background is shown at all, and an opacity for the flyout
-- background."
function F.Back()
    local data = P.Data()
    return not (data and data.noBack)
end
function F.SetBack(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.noBack = not on or nil
    F.Apply()
    return true
end
function F.BackAlpha()
    local data = P.Data()
    local alpha = data and tonumber(data.backAlpha) or 1
    return math.max(0, math.min(1, alpha))
end
function F.SetBackAlpha(alpha)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    alpha = math.max(0, math.min(1, tonumber(alpha) or 1))
    data.backAlpha = alpha < 1 and alpha or nil
    F.Apply()
    return true
end
-- the size at which a flyout's icons are as large as its bar button's own icon
function F.BarSize() return Art.BUTTON / Art.ICON end
function F.SetPlate(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.padBare = not on or nil
    local was = open
    F.Apply()
    -- left open, to see it change
    if was and was.flyout then
        local unit = Run(was.flyout).unit
        if unit then F.Show(unit.index) end
    end
    return true
end

-- Which cross of the pad presses a button: "dpad", "face", or nil (another pad button, a key, or none).
-- A button of the game's gamepad bars stands on one side of its bar, the D-pad's (Left, its square slots)
-- or the face buttons' (Right, its round ones), as the game's own edit view draws them; a button of the
-- other bars goes by the pad button bound to it, with or without a modifier.
F.SIDE_CROSS = { Left = "dpad", Right = "face" }
F.KEY_CROSS = { PADDUP = "dpad", PADDDOWN = "dpad", PADDLEFT = "dpad", PADDRIGHT = "dpad",
    PAD1 = "face", PAD2 = "face", PAD3 = "face", PAD4 = "face" }
function F.ButtonCross(button)
    if type(button) ~= "table" then return nil end
    if Bars.Pad(button) then
        local parent = button:GetParent()
        local up = parent
        for _ = 1, 4 do
            if type(up) ~= "table" then return nil end
            for side, cross in pairs(F.SIDE_CROSS) do
                local group = up[side]
                if type(group) == "table" then
                    if group == parent then return cross end
                    for _, held in pairs(group) do
                        if held == button then return cross end
                    end
                end
            end
            up = type(up.GetParent) == "function" and up:GetParent() or nil
        end
        return nil
    end
    for _, key in ipairs(Bars.Keys(button)) do
        local cross = F.KEY_CROSS[key:match("([^%-]+)$") or key]
        if cross then return cross end
    end
    return nil
end

-- How a flyout made from now on picks (one made since 1.1.7 carries `cross`). His words (2026-11-24):
-- "shouldnt we have the flyout start d pad for face button bases and face buttons for d pad bases? can
-- have option in settings to always start with d or always with face or always d with d and face with
-- face though too", then "we shouldnt override existing players stuff for that. just have the default
-- change going forward". So the profile's padCross: "opposite" (the usual one), "dpad", "face" or "same".
-- One who had Pick with the face buttons on before (padFace) is given "face" till they choose.
F.CROSSES = { opposite = true, dpad = true, face = true, same = true }
function F.Cross()
    local data = P.Data()
    local cross = data and data.padCross
    if cross and F.CROSSES[cross] then return cross end
    if data and data.padFace == true then return "face" end
    return "opposite"
end
function F.SetCross(cross)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not (data and F.CROSSES[cross]) then return false end
    -- the usual one is kept as nothing, unless an older choice would speak in its stead
    data.padCross = (cross ~= "opposite" or data.padFace == true) and cross or nil
    F.Apply()
    return true
end

-- Whether a controller picks a flyout's icons with its face buttons before its D-pad: the flyout's own
-- word where it has one; for one made since 1.1.7, the profile's padCross by the cross of its button; for
-- one made before, as it always has: the profile's Pick with the face buttons, the D-pad unless that was
-- turned on. Without a flyout: that older choice.
function F.Faces(flyout)
    if flyout and flyout.face ~= nil then return flyout.face == true end
    if flyout and flyout.cross then
        local rule = F.Cross()
        if rule == "dpad" or rule == "face" then return rule == "face" end
        local on = F.ButtonCross(Bars.Named(flyout.host))
        if rule == "same" then return on == "face" end
        return on == "dpad"
    end
    local data = P.Data()
    return data ~= nil and data.padFace == true
end
-- one flyout's own word on it; nil gives it the profile's again
function F.SetFace(flyout, on)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout) then return false end
    flyout.face = on
    local unit = Run(flyout).unit
    local shown = unit ~= nil and open == unit
    F.Apply()
    unit = Run(flyout).unit
    if shown and unit then F.Show(unit.index) end
    return true
end

-- Whether a flyout's key pressed again while it is open casts the icon picked last from it: the
-- profile's, off unless turned on. A player's ask (2026-11-23): "double tapping a flyout keybind hits the
-- last used spell from it". The secure code has no clock: a second press while open, as such addons do.
function F.Twice()
    local data = P.Data()
    return data ~= nil and data.twice == true
end
function F.SetTwice(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.twice = on and true or nil
    F.Apply()
    return true
end

-- The icon of each flyout picked last, as the secure code knows it (in a fight too), kept with the
-- flyout, so that it lasts through a layout and a login.
function F.KeepLast()
    if not root then return end
    for f = 1, used do
        local unit = units[f]
        local name = root:GetAttribute("last" .. f)
        local frame = name and _G[name]
        if unit.flyout and frame and frame.entry then unit.flyout.last = Copy(frame.entry) end
    end
end
-- the icon of a laid out flyout that holds what was picked last from it
function F.LastIcon(unit)
    local last = unit.flyout and unit.flyout.last
    if type(last) ~= "table" then return nil end
    for i, frame in ipairs(unit.entries) do
        local entry = unit.flyout.entries[i]
        if entry and Same(entry, last) then return frame end
    end
end

-- A player's ask, passed on by him (2026-11-25): "someone requested the flyout icon to change to be whatever
-- the last-casted spell from the flyout is."
-- With this on, a flyout's bar button shows the icon picked from it last, as a bar button holding that one shows
-- it: its icon, cooldown, dimming, number and tooltip. The profile's, off as shipped. What was picked last is
-- kept with the flyout (F.KeepLast, F.NoteLast), so it shows from the first moment it is turned on.
function F.ShowLast()
    local data = P.Data()
    return data ~= nil and data.showLast == true
end
function F.SetShowLast(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.showLast = on and true or nil
    F.Apply()
    return true
end
-- the entry a flyout's bar button shows as the last one used, while that is on and the flyout still holds it
function F.LastEntry(unit)
    local flyout = unit and unit.flyout
    local last = flyout and flyout.last
    if not (type(last) == "table" and F.ShowLast()) then return nil end
    for _, entry in ipairs(flyout.entries or {}) do
        if Same(entry, last) then return entry end
    end
end
-- A pick from a flyout, in a fight too: the one the secure code says was picked last is kept with the flyout,
-- and its bar button shows it at once where that is on.
function F.NoteLast(unit)
    if not (root and unit and unit.flyout) then return end
    local name = root:GetAttribute("last" .. unit.index)
    local frame = name and _G[name]
    local entry = frame and frame.entry
    if not entry then return end
    local was = unit.flyout.last
    if type(was) == "table" and Same(was, entry) then return end
    unit.flyout.last = Copy(entry)
    if F.ShowLast() then Face(unit) end
end
-- The bar button showing the last one used looks as a button holding it: that one's sweep, dimming and number,
-- drawn over the button's own; those of the button (what its slot holds) are put out of sight meanwhile, and
-- given back as they were. Drawings only: in a fight too.
do
    local OWN = { "cooldown", "chargeCooldown", "Count" }
    local function GiveBack(unit)
        local on, was = unit.hushedOn, unit.hushed
        for part, alpha in pairs(on and was or {}) do
            local region = on[part]
            if type(region) == "table" and region.SetAlpha then region:SetAlpha(alpha) end
        end
        unit.hushedOn, unit.hushed = nil, nil
    end
    function F.LastLook(unit)
        local host, entry = unit.host, F.LastEntry(unit)
        local cool, count = unit.lastCool, unit.lastCount
        if not (host and entry and unit.face:IsShown()) then
            GiveBack(unit)
            cool:Clear()
            cool:Hide()
            count:Hide()
            unit.face:SetVertexColor(1, 1, 1)
            return
        end
        if unit.hushedOn ~= host then
            GiveBack(unit)
            unit.hushedOn, unit.hushed = host, {}
            for _, part in ipairs(OWN) do
                local region = host[part]
                if type(region) == "table" and region.GetAlpha and region.SetAlpha then
                    unit.hushed[part] = region:GetAlpha()
                    region:SetAlpha(0)
                end
            end
        end
        -- the sweep where the button's own is, at its level; the number where the button writes its own
        local own, mark = host.cooldown, host.Count
        cool:ClearAllPoints()
        cool:SetAllPoints(unit.face)
        if type(own) == "table" and own.GetFrameLevel then cool:SetFrameLevel(own:GetFrameLevel()) end
        local kind, id = Casts(entry)
        cool:SetHideCountdownNumbers(C_CVar.GetCVar("countdownForCooldowns") ~= "1")
        Sweep(cool, kind, id)
        cool:Show()
        Dim(unit.face, kind, id)
        count:ClearAllPoints()
        if type(mark) == "table" and mark.GetPoint then
            count:SetAllPoints(mark)
        else
            count:SetPoint("BOTTOMRIGHT", unit.face, "BOTTOMRIGHT", -2, 2)
        end
        Count(count, kind, id)
        count:Show()
    end
    -- every button showing the last one used, after a cooldown, a cast or the bags changed
    function F.LastLooks()
        for f = 1, used do
            if units[f].hushedOn then F.LastLook(units[f]) end
        end
    end
end

-- whether the ranks of one spell are kept in rank order: the profile's, on unless turned off
function F.Ranked()
    local data = P.Data()
    return not (data and data.unranked)
end
function F.SetRanked(on)
    if InCombatLockdown() then return false, TEXT.fight end
    local data = P.Data()
    if not data then return false end
    data.unranked = not on or nil
    F.Apply()
    return true
end

function F.Picks(flyout)
    local unit = Run(flyout).unit
    return unit and unit.picks
end
-- the key and the pad button icon i of a flyout on the bars is picked with, and whether either is the
-- icon's own (set for it in this flyout) and not its spot's
function F.Picked(flyout, i)
    local unit, entry = Run(flyout).unit, flyout.entries[i]
    local pick = unit and unit.picks and unit.picks[i]
    if not (pick and entry) then return nil end
    return pick.key, pick.pad, entry.key ~= nil or entry.pad ~= nil
end
function F.Moved() moved = true end

-- the flyout shown on a button
function F.At(name)
    for f = 1, used do
        local unit = units[f]
        -- one knocked off its button in a fight has none until its ability is set down
        if unit.host and unit.host:GetName() == name then return unit.flyout, unit end
    end
end

-- the flyout an action leads, wherever it is
function F.Of(main)
    local asleep
    for _, flyout in ipairs(list or {}) do
        if Same(flyout.main, main) then
            -- one asleep on a page of Action Bar 1 out of view gives way to one in view
            if not F.Sleeps(flyout) then return flyout end
            asleep = asleep or flyout
        end
    end
    return asleep
end

local function Has(flyout, entry)
    for _, other in ipairs(Full(flyout)) do
        if Same(other, entry) then return true end
    end
    return false
end

-- adds to the button's flyout, making one if needed
-- One more icon for a flyout. Where its icons have been put on spots of the dial, the new one is held
-- to the first free spot from the start: taking another off later must not shift it.
local function Append(flyout, entry)
    local full, new = Full(flyout), Copy(entry)
    local taken, held = {}, false
    for _, other in ipairs(full) do
        if other.spot then taken[other.spot], held = true, true end
    end
    if held then
        local free = 1
        while taken[free] do free = free + 1 end
        new.spot = free
    end
    full[#full + 1] = new
end

function F.Stack(button, entry)
    if InCombatLockdown() then return nil, TEXT.fight end
    if not list then return nil end
    local name = button:GetName()
    local flyout = F.At(name)
    local main
    if not flyout then
        main = Bars.Action(button)
        if not main then return nil, TEXT.noLead end
        flyout = F.Of(main)
        -- one asleep on another page of the bar is that page's: this page gets one of its own
        if flyout and F.Sleeps(flyout) then flyout = nil end
    end
    if flyout then
        if flyout.auto then return nil, TEXT.auto end
        if #Full(flyout) >= MAX then return nil, TEXT.full end
        if Has(flyout, entry) then return nil, TEXT.twice end
        flyout.host, flyout.slot = name, F.SlotOn(button)
        Run(flyout).lost = nil
    else
        if Same(main, entry) then return nil, TEXT.twice end
        -- made now: it picks by New flyouts pick with (F.Faces)
        flyout = { host = name, main = main, entries = { Copy(main) }, slot = F.SlotOn(button), cross = true }
        list[#list + 1] = flyout
    end
    Append(flyout, entry)
    F.Apply()
    return flyout
end

-- Adds to the flyout an action leads, making one if needed. `button` is where
-- the lead sits when that is known; without one the flyout finds its button.
function F.StackLed(main, entry, button)
    if InCombatLockdown() then return nil, TEXT.fight end
    if not (list and main and entry) then return nil end
    if Same(main, entry) then return nil, TEXT.twice end
    local name = button and button:GetName()
    local flyout = name and F.At(name)
    if not (flyout and Same(flyout.main, main)) then flyout = F.Of(main) end
    -- one asleep on another page of the bar is that page's: a button in view gets one of its own
    if flyout and name and F.Sleeps(flyout) then flyout = nil end
    if flyout and flyout.auto then return nil, TEXT.auto end
    if flyout then
        if not Has(flyout, entry) then
            if #Full(flyout) >= MAX then return nil, TEXT.full end
            Append(flyout, entry)
        end
    else
        flyout = { host = name or "", main = Copy(main), entries = { Copy(main), Copy(entry) }, cross = true }
        list[#list + 1] = flyout
    end
    if name then
        flyout.host, flyout.slot = name, F.SlotOn(button)
        Run(flyout).lost = nil
    end
    -- its button is looked for at the next pass
    moved = true
    F.Apply()
    return flyout
end

-- The secure code added an icon to a flyout in a fight: it is saved, and drawn, which addon code may
-- still do then (an icon's picture, its key's text). `n`: its place; `id`: a spell or an item, or a
-- macro's place in the list. All of it is laid afresh when the fight is over.
function F.Added(f, n, kind, id)
    local unit = units[f]
    local flyout, frame = unit and unit.flyout, unit and unit.entries[n]
    if not (flyout and frame) then return end
    local entry = { kind = kind, id = id }
    if kind == "macro" then entry = Macros.Entry(id) or { kind = kind, id = (GetMacroInfo(id)) } end
    local held = unit.lifted
    unit.lifted = nil
    local new
    if held and held.frame == frame and Same(held.entry, entry) then
        new = held.entry
        local whole = Full(flyout)
        whole[#whole + 1] = new
    else
        Append(flyout, entry)
        local whole = Full(flyout)
        new = whole[#whole]
    end
    if flyout.all then flyout.entries[#flyout.entries + 1] = new end
    frame.entry, frame.flyout, frame.entryIndex = new, flyout, n
    frame.icon:SetTexture(F.Icon(new))
    Repick(unit)
    pending = true
    if not InCombatLockdown() then return F.Settle() end
    Labels(unit)
    State(unit)
    ns.Log(("in a fight %s was added to the flyout on %s, at place %d"):format(Name(new), tostring(flyout.host), n))
    Tell("added", unit, n)
end
-- and refused to: said in red, as out of a fight
function F.Refused(why) ns.Warn(TEXT[why] or TEXT.fight) end

-- An ability takes the place of the icon at `i`, as on a bar slot: on its spot, with the keys the icon
-- had there. Returns the one that gave way, and the new one. `done`: the secure code has made the icon
-- cast it already, in a fight, and this only saves it.
function F.Replace(flyout, i, entry, done)
    if not done and InCombatLockdown() then return nil, TEXT.fight end
    local old = list and flyout and flyout.entries[i]
    if not old then return nil end
    if not done then
        if flyout.auto then return nil, TEXT.auto end
        if Has(flyout, entry) then return nil, TEXT.twice end
    end
    local new = Copy(entry)
    new.spot, new.key, new.pad = old.spot, old.key, old.pad
    flyout.entries[i] = new
    for place, other in ipairs(flyout.all or {}) do
        if other == old then flyout.all[place] = new end
    end
    if done then return old, new end
    local shown = open ~= nil and open.flyout == flyout
    F.Apply()
    -- still open, as it was
    local unit = shown and Run(flyout).unit
    if unit then F.Show(unit.index) end
    return old, new
end

-- Something carried was let go on an icon, out of a fight: it takes the icon's place, and what the icon
-- held is on the cursor in its stead.
function F.Dropped(frame)
    if InCombatLockdown() or not GetCursorInfo() then return end
    local unit, i = frame.flyoutUnit, frame.entryIndex
    local flyout = unit and unit.flyout
    local old = flyout and flyout.entries[i]
    if not old then return end
    -- An icon carried off this flyout is off it, as anything carried from elsewhere (UI/Move.lua, M.Detach):
    -- its old place goes first, and then it takes this icon's place as anything carried in does. Let go on
    -- its own old place, unseen, it is off.
    local had = ns.Move and ns.Move.Detach(flyout)
    if had then
        if had == i then return end
        if had > 0 and had < i then i = i - 1 end
        if not F.UnitOf(flyout) then return end
        old = flyout.entries[i]
        if not old then return end
    end
    local entry = ns.Drop and ns.Drop.Carried()
    if not entry then return end
    if Same(old, entry) then return ClearCursor() end
    local was, why = F.Replace(flyout, i, entry)
    if not was then
        if why then ns.Warn(why) end
        return
    end
    ClearCursor()
    Pickup(was)
    ns.Log(("%s took the place of %s in the flyout on %s"):format(Name(entry), Name(was), tostring(flyout.host)))
    Tell("swapped", Run(flyout).unit, i)
end

-- The secure code did the same in a fight: saved, and drawn. `name`: the icon's frame.
function F.Swapped(name, kind, id)
    local frame = _G[name]
    local unit, i = frame and frame.flyoutUnit, frame and frame.entryIndex
    local flyout = unit and unit.flyout
    if not (flyout and flyout.entries[i]) then return end
    local entry = { kind = kind, id = id }
    if kind == "macro" then entry = Macros.Entry(id) or { kind = kind, id = (GetMacroInfo(id)) } end
    local old, new = F.Replace(flyout, i, entry, true)
    if not new then return end
    frame.entry = new
    frame.icon:SetTexture(F.Icon(new))
    pending = true
    if not InCombatLockdown() then return F.Settle() end
    State(unit)
    ns.Log(("in a fight %s took the place of %s in the flyout on %s"):format(Name(new), Name(old),
        tostring(flyout.host)))
    Tell("swapped", unit, i)
end

local function Forget(flyout)
    for i = #list, 1, -1 do
        if list[i] == flyout then table.remove(list, i) end
    end
    run[flyout] = nil
end
-- for a flyout whose kind is done away with (one of the player's own that fills itself)
F.Forget = Forget

-- A button done away with by hand takes its flyout with it. His words (2026-11-22): "if someone
-- explicitly destroys a flyout by dragging off/erasing, it shouldnt auto pop back onto that spell next
-- time its dragged from spellbook". So: a flyout's ability carried off its button on the cursor is in
-- the hand. Set down on a button, the flyout goes with it, as ever; let go of anywhere else, with no
-- button left that holds it, the flyout is removed. An ability that leaves the bars in any other way
-- (a talent change, another character of the profile) keeps its flyout waiting for it, as before.
local inHand = {}
local LET_GO = 0.2
-- with its ability on no button at all, in view or not, the flyout is removed; true when it was
function F.Discard(flyout)
    if InCombatLockdown() or not (list and flyout and flyout.main) then return false end
    -- one of the profile in use, not of a profile left since
    local mine = false
    for _, own in ipairs(list) do mine = mine or own == flyout end
    if not mine then
        inHand[flyout] = nil
        return false
    end
    for _, button in ipairs(Bars.All()) do
        if Bars.Holds(button, flyout.main) then return false end
    end
    -- on a page of Action Bar 1 out of view it is on a button still
    if F.Sleeps(flyout) then
        inHand[flyout] = nil
        return false
    end
    inHand[flyout] = nil
    ns.Log(("the button of %s was done away with: its flyout is removed"):format(Name(flyout.main)))
    Forget(flyout)
    F.Apply()
    return true
end
-- A slot changed: a flyout's ability now on the cursor and no longer on its button was lifted off it.
-- Not while the pad's bind dialog is up: that one lifts and holds abilities itself, with choices of
-- its own still to come (add to the flyout, swap out), and says for itself when a button is unbound.
local function Lifted()
    for _, still in ipairs(stills) do
        if still() then return end
    end
    local carried = ns.Drop and ns.Drop.Carried()
    if not carried then return end
    for _, flyout in ipairs(list) do
        -- off its button just now: one that was waiting already (its ability carried in from the
        -- spellbook) was lifted off nothing
        if flyout.main and Same(flyout.main, carried) and not Run(flyout).lost and not F.Sleeps(flyout) then
            local held = Bars.Named(flyout.host)
            if not (held and Bars.Holds(held, flyout.main)) then inHand[flyout] = true end
        end
    end
end
-- the cursor let go of something: each ability that was in the hand and is not any more is looked for
local function LetGo()
    if not list or not next(inHand) or InCombatLockdown() then return end
    for _, still in ipairs(stills) do
        if still() then return end
    end
    local carried = ns.Drop and ns.Drop.Carried()
    local kept = {}
    for flyout in pairs(inHand) do
        if carried and flyout.main and Same(flyout.main, carried) then kept[flyout] = true end
    end
    for flyout in pairs(inHand) do
        if not kept[flyout] then
            inHand[flyout] = nil
            F.Discard(flyout)
        end
    end
end

-- takes an entry out; one left with only its lead goes
function F.Remove(flyout, i)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout and flyout.entries[i]) then return false end
    if flyout.auto then return false, TEXT.auto end
    local shown = open ~= nil and open.flyout == flyout
    local gone = F.Ends(flyout, i)
    local entry = table.remove(flyout.entries, i)
    for place = #(flyout.all or {}), 1, -1 do
        if flyout.all[place] == entry then table.remove(flyout.all, place) end
    end
    if gone then Forget(flyout) end
    F.Apply()
    -- still open, for the next one to take out
    local unit = shown and not gone and Run(flyout).unit
    if unit then F.Show(unit.index) end
    -- true, and whether the flyout went with it
    return true, gone
end

-- an entry to another place in its flyout; the rest close up around it
-- An icon put on a spot of the dial, taken or empty. From then on every icon of the flyout is held to
-- the spot it stands on, so nothing else shifts; an icon standing on that spot takes the one left.
function F.Place(flyout, i, spot)
    if InCombatLockdown() then return false, TEXT.fight end
    local entries = flyout and flyout.entries
    if not (list and entries and entries[i]) then return false end
    if type(spot) ~= "number" or spot < 1 or spot > SPOTS or spot % 1 ~= 0 then return false end
    if flyout.auto then return false, TEXT.auto end
    local spots = Spots(entries)
    local from = spots[i]
    local taken = {}
    for k, entry in ipairs(entries) do
        entry.spot = spots[k]
        if k ~= i and spots[k] == spot then entry.spot = from end
        if k == i then entry.spot = spot end
        taken[entry.spot] = true
    end
    -- an icon out of sight just now (an item not held) gets a spot of its own too, clear of these
    local free = 1
    for _, entry in ipairs(Full(flyout)) do
        if not taken[entry.spot or 0] then
            while taken[free] do free = free + 1 end
            entry.spot = free
        end
        taken[entry.spot] = true
    end
    local shown = open ~= nil and open.flyout == flyout
    F.Apply()
    local unit = shown and Run(flyout).unit
    if unit then F.Show(unit.index) end
    return true
end

-- two icons of a flyout trade places, each with its own key
function F.Swap(flyout, a, b)
    if InCombatLockdown() then return false, TEXT.fight end
    local entries = flyout and flyout.entries
    if not (list and entries and entries[a] and entries[b]) then return false end
    if flyout.auto then return false, TEXT.auto end
    if a == b then return true end
    local shown = open ~= nil and open.flyout == flyout
    entries[a], entries[b] = entries[b], entries[a]
    Mirror(flyout)
    F.Apply()
    local unit = shown and Run(flyout).unit
    if unit then F.Show(unit.index) end
    return true
end

function F.Move(flyout, from, to)
    if InCombatLockdown() then return false, TEXT.fight end
    local entries = flyout and flyout.entries
    if not (list and entries and entries[from] and entries[to]) then return false end
    if flyout.auto then return false, TEXT.auto end
    if from == to then return true end
    local shown = open ~= nil and open.flyout == flyout
    table.insert(entries, to, table.remove(entries, from))
    Mirror(flyout)
    F.Apply()
    -- still open: it was being arranged
    local unit = shown and Run(flyout).unit
    if unit then F.Show(unit.index) end
    return true
end

-- by code, out of a fight only: code clicks are refused
function F.Show(index)
    if InCombatLockdown() or not root or index > used then return false end
    root:Execute(("local owner, mine = self, %d\n"):format(index) .. SHUT .. SHOW .. BIND)
    return true
end

function F.Shut()
    if InCombatLockdown() or not root then return false end
    root:Execute("local owner = self\n" .. SHUT .. BIND)
    return true
end

local function Sync()
    if not ready or paused then return end
    -- a layer of keys is held: what the keys and bars say now is its doing, and passes
    if LayerHeld() then return end
    if late and GetTime() >= quiet then late, rekey = nil, true end
    F.Follow()
    if rekey and not open and not InCombatLockdown() then Rekey() end
end

-- something on the cursor: a click on a host goes to the bar, to place it
function F.Carrying(on)
    if root and not InCombatLockdown() then root:SetAttribute("carrying", on or nil) end
end

-- flyouts stay on their buttons while a layer is held, whoever asks
F.StillWhile(LayerHeld)

-- FOR OUR KEY LAYERS ADDON. A key bound to what this returns acts as the
-- button's own key: the opener of the flyout the button hosts, and the
-- click to send it ("tap" for a key that is one of that flyout's picks:
-- such a key cannot be held). Nothing for a button with no flyout.
function FallensFlyouts_KeyTarget(buttonName, key)
    local _, unit = F.At(buttonName)
    if not unit then return nil end
    local how = "LeftButton"
    for _, pick in ipairs(unit.picks or {}) do
        if pick.key == key or pick.pad == key then how = "tap" end
    end
    return OPENER .. unit.index, how
end

-- fn() after every lay: flyouts made, moved or gone, or the bars changed. Never in a fight.
function FallensFlyouts_Watch(fn)
    F.Watch(function(what)
        if what == "laid" then fn() end
    end)
end

-- its hold keys changed: ours are bound afresh, at once or when the fight is over
function FallensFlyouts_LayersChanged()
    if not root then return end
    if InCombatLockdown() then
        rekey = true
        return
    end
    -- its root, where its snippets say which layer is on and which keys that layer has: an
    -- opener key of ours that is such a key just now is left to it (the BIND snippet reads it)
    local theirs = layers and type(layers.Root) == "function" and layers.Root() or nil
    if type(theirs) == "table" and theirs.GetAttribute then
        root:SetFrameRef("layers", theirs)
    else
        root:SetAttribute("frameref-layers", nil)
    end
    Rebind()
end

-- { Held = function, HoldKeys = function, Root = function }, or nil when it is gone
function FallensFlyouts_Layers(provider)
    layers = provider
    FallensFlyouts_LayersChanged()
end

-- A macro's text was changed in the macro window: an entry that knew it by its old text learns the new
-- one. Told from the macro list before and after: of one name, one text gone and one come.
local macrosBefore
local function MacroTexts()
    local out = {}
    for _, m in ipairs(Macros.List()) do
        if m.text then
            local texts = out[m.name] or {}
            out[m.name] = texts
            texts[m.text] = (texts[m.text] or 0) + 1
        end
    end
    return out
end
local function Retext(name, gone, come)
    local function Mend(entry)
        if entry and entry.kind == "macro" and entry.id == name and entry.text == gone then entry.text = come end
    end
    for _, flyout in ipairs(list or {}) do
        Mend(flyout.main)
        for _, entry in ipairs(flyout.entries or {}) do Mend(entry) end
        for _, entry in ipairs(flyout.all or {}) do Mend(entry) end
    end
end
local function MacrosChanged()
    Macros.Changed()
    local now = MacroTexts()
    for name, texts in pairs(macrosBefore or {}) do
        local new = now[name] or {}
        local gone, come
        local lost, gained = 0, 0
        for text, count in pairs(texts) do
            local fewer = count - (new[text] or 0)
            if fewer > 0 then gone, lost = text, lost + fewer end
        end
        for text, count in pairs(new) do
            local more = count - (texts[text] or 0)
            if more > 0 then come, gained = text, gained + more end
        end
        if lost == 1 and gained == 1 then Retext(name, gone, come) end
    end
    macrosBefore = now
    if not ready then return end
    -- places in the list shift with a change: flyouts that hold a macro are laid out again
    for _, flyout in ipairs(list or {}) do
        local holds = flyout.main ~= nil and flyout.main.kind == "macro"
        for _, entry in ipairs(Full(flyout)) do holds = holds or entry.kind == "macro" end
        if holds then return F.Apply() end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("UPDATE_MACROS")
-- the game lifts the bars to another layer for a spell on the cursor, and lets them down after
pcall(events.RegisterEvent, events, "ACTIONBAR_SHOWGRID")
pcall(events.RegisterEvent, events, "ACTIONBAR_HIDEGRID")
pcall(events.RegisterEvent, events, "CURSOR_CHANGED")
pcall(events.RegisterEvent, events, "CVAR_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("UPDATE_BINDINGS")
-- not every client has the pad's events
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED" }) do
    pcall(events.RegisterEvent, events, event)
end
-- what changes an open flyout's sweeps, dimming, numbers and range
local STATE_EVENTS = { SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_USABLE = true, BAG_UPDATE_COOLDOWN = true,
    ACTIONBAR_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true, BAG_UPDATE_DELAYED = true, SPELL_UPDATE_USES = true,
    PLAYER_TARGET_CHANGED = true }
for event in pairs(STATE_EVENTS) do pcall(events.RegisterEvent, events, event) end
events:SetScript("OnEvent", function(_, event, on)
    if event == "ACTIONBAR_SLOT_CHANGED" then
        if ready and list and #list > 0 then Lifted() end
        if ready and list and #list > 0 and not moved then
            moved = true
            C_Timer.After(0.1, Sync)
        end
    elseif event == "CVAR_UPDATE" then
        if on == "enableMouseoverCast" then CastSettings() end
    elseif event == "CURSOR_CHANGED" then
        if next(inHand) then C_Timer.After(LET_GO, LetGo) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then F.Settle() end
        CastSettings()
        -- what was let go of in the fight is settled now
        if next(inHand) then C_Timer.After(LET_GO, LetGo) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- the last moment it can be set: nothing is placed in a fight
        if root then root:SetAttribute("carrying", nil) end
        CastSettings()
        -- and the last moment a flyout can be laid for where its bar is now
        F.Follow()
    elseif event == "PLAYER_ENTERING_WORLD" then
        macrosBefore = macrosBefore or MacroTexts()
        F.Follow()
    elseif event == "UPDATE_MACROS" then
        MacrosChanged()
    elseif event == "ACTIONBAR_SHOWGRID" or event == "ACTIONBAR_HIDEGRID" then
        -- whether the bars are moved before or after this is told is not ours to know: looked at twice
        C_Timer.After(0, Layers)
        C_Timer.After(0.2, Layers)
        -- the cursor holds no ability any more: one lifted off a flyout's button was set down or let go of
        if event == "ACTIONBAR_HIDEGRID" and next(inHand) then C_Timer.After(LET_GO, LetGo) end
    elseif event == "PLAYER_LOGOUT" then
        -- what is saved is the whole of each flyout, with what was picked last from it
        F.KeepLast()
        Whole(list)
    elseif event == "UPDATE_BINDINGS" then
        -- the key Mouseover Cast wants held is saved with the bindings
        CastSettings()
        if ready and used > 0 then
            if GetTime() >= quiet then rekey = true else late = true end
        end
        -- the game's bars relabel on this too
        sought = nil
        if open then Labels(open) end
    elseif STATE_EVENTS[event] then
        -- only the open one can be seen; and the bar buttons showing the last one used
        if open then State(open) end
        F.LastLooks()
    else
        -- the pad became the input in use, or stopped being it
        if event == "GAME_PAD_ACTIVE_CHANGED" then padMode = on == true end
        for f = 1, used do Labels(units[f]) end
        ns.Log(("pad: %s %s; the input in use: %s, told by %s"):format(event, tostring(on), tostring(PadInUse()),
            tostring(witness or "the game's last word")))
    end
end)

ns.OnStart(function()
    F.Load()
    P.OnChange(function()
        F.Load()
        if ready then F.Settle() end
    end)
    -- What comes later is asked for first: whatever the first lay runs into, the bars are still
    -- followed and the addon still becomes ready.
    -- bars are still being placed: laid again if one moved
    for step = 1, 11 do C_Timer.After(step * 0.25, F.Follow) end
    -- and once other addons have placed their bars and keys
    C_Timer.After(3, function()
        ready = true
        C_Timer.NewTicker(1, Sync)
        Adopt()
        F.Settle()
    end)
    -- at once: a login in a fight is not locked yet
    F.Settle()
end)
