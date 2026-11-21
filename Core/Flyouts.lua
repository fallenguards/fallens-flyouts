local _, ns = ...
-- luacheck: read globals UIParent CreateFrame GetTime InCombatLockdown C_Timer C_Spell C_Item GetMacroInfo
-- luacheck: read globals SetOverrideBindingClick ClearOverrideBindings GameTooltip C_GamePad GetBindingText
-- luacheck: read globals issecretvalue C_CVar C_Container GetMacroSpell IsUsableItem geterrorhandler
-- luacheck: read globals Settings IsModifiedClick GetModifiedClick PickupSpell PickupItem PickupMacro

-- Flyouts on bar buttons. One secure root owns every key.
local F = {}
ns.Flyouts = F
local P, Bars, Art = ns.Profiles, ns.Bars, ns.Art

local MAX = 6
local KEYS = { "1", "2", "3", "4", "5", "6" }
local PADS = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD3" }
-- a controller's label style, as the game's key strings end
local PAD_STYLES = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }
local CLOSE_KEYS = { "ESCAPE", "PAD2" }
local ROOT, OPENER = "FallensFlyoutsRoot", "FallensFlyoutsOpener"
local MENU, ENTRY = "FallensFlyoutsMenu", "FallensFlyoutsEntry"
local ARROW_W, ARROW_H, ARROW_OUT, GRIP_W, GRIP_H, GRIP_OUT = 18, 7, 4, 30, 14, 3
local TEXT = {
    fight = "Flyouts change only out of a fight.",
    full = "That flyout is full.",
    twice = "That is in the flyout already.",
    noLead = "That button's action cannot lead a flyout.",
    how = "Right-click or drag",
    howHeld = "Right-click or %s-drag",
    remove = "%s takes it off the flyout.",
    removeLast = "%s takes it off, and the flyout with it: nothing else was added.",
    took = "%s taken off the flyout.",
    gone = "%s taken off. Nothing else was added, so the flyout is gone.",
    it = "It",
}
F.MAX, F.KEYS, F.PADS, F.CLOSE_KEYS, F.TEXT = MAX, KEYS, PADS, CLOSE_KEYS, TEXT

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
-- then the open one's shut keys, then its picks, plain and under a held modifier
local BIND = [[
    owner:ClearBindings()
    for f = 1, owner:GetAttribute("units") or 0 do
        local name = owner:GetAttribute("opener" .. f)
        for i = 1, owner:GetAttribute("okeys" .. f) or 0 do
            local at = f .. "_" .. i
            owner:SetBindingClick(true, owner:GetAttribute("okey" .. at), name, owner:GetAttribute("obtn" .. at))
        end
    end
    local open = owner:GetAttribute("open")
    if open then
        local name = owner:GetAttribute("opener" .. open)
        for i = 1, owner:GetAttribute("ckeys") or 0 do
            owner:SetBindingClick(true, owner:GetAttribute("ckey" .. i), name, "tap")
        end
        for i = 1, owner:GetAttribute("count" .. open) or 0 do
            local entry = owner:GetAttribute("entry" .. open .. "_" .. i)
            owner:SetBindingClick(true, owner:GetAttribute("key" .. i), entry)
            owner:SetBindingClick(true, owner:GetAttribute("pad" .. i), entry)
        end
        for i = 1, owner:GetAttribute("mkeys" .. open) or 0 do
            local at = open .. "_" .. i
            owner:SetBindingClick(true, owner:GetAttribute("mkey" .. at), owner:GetAttribute("mentry" .. at))
        end
    end
]]
-- A press opens its flyout or shuts the open one. Held, it stays open
-- through every pick and shuts on letting go; a "tap" key cannot be held.
local OPENER_WRAP = [[
    local mine = self:GetAttribute("ffindex")
    if not down then
        if held == mine then
            held = nil
            if picked then
                picked = nil
]] .. SHUT .. BIND .. [[
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
    else
        held = nil
    end
]] .. BIND .. [[
    return false
]]
-- a click on the bar button itself does the same, on its release;
-- a button with no flyout, or a full cursor, goes to the bar as ever.
-- The right button is left to the icon window.
local HOST_WRAP = [[
    local mine = owner:GetAttribute("host-" .. self:GetName())
    if not mine or owner:GetAttribute("carrying") then return end
    if button == "RightButton" then return false end
    if down then return false end
    armed, held, picked = nil, nil, nil
    local was = owner:GetAttribute("open")
]] .. SHUT .. [[
    if was ~= mine then
]] .. SHOW .. [[
    end
]] .. BIND .. [[
    return false
]]
-- acts on the press, shuts on that pick's release, unless the flyout's
-- key is still held; the right button casts nothing: it takes the icon off
local ENTRY_WRAP = [[
    if button == "RightButton" then return false end
    if down then
        armed = self:GetName()
        return
    end
    if armed ~= self:GetName() then return false end
    armed = nil
    if held then
        picked = true
        return
    end
]] .. SHUT .. BIND

local root, list, open
local units, used = {}, 0
local pending, moved, ready, paused, rekey
local quiet, idle, patient = 0, 0, 0
local watchers = {}
-- bar buttons whose click we wrapped, and the ones with a flyout now
local wrapped, hosted = {}, {}
-- false once the game says the pad is not the input in use
local padMode
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

local function Tell(what, ...)
    for _, fn in ipairs(watchers) do fn(what, ...) end
end

-- fn(what, ...) as flyouts are built, laid out, opened and shut
function F.Watch(fn) watchers[#watchers + 1] = fn end

local function Same(a, b)
    return a ~= nil and b ~= nil and a.kind == b.kind and a.id == b.id
end

-- whether taking entry i off leaves only the button's own ability, or nothing
function F.Ends(flyout, i)
    local entries = flyout.entries
    if not entries[i] or #entries > 2 then return false end
    if #entries == 1 then return true end
    return Same(entries[3 - i], flyout.main)
end

function F.Icon(entry)
    if entry.kind == "spell" then return (C_Spell.GetSpellTexture(entry.id)) end
    if entry.kind == "item" then return C_Item.GetItemIconByID(entry.id) end
    local _, icon = GetMacroInfo(entry.id)
    return icon
end

-- the arrow points out when shut and back when open
local function Arrow(unit, art)
    unit.art = art or unit.art or "arrow"
    local turn = Art.TURN[unit.way or "UP"].arrow
    if unit.menu:IsShown() then turn = (turn + 180) % 360 end
    unit.turn = turn
    Art.Set(unit.arrow, Art.NAMES[unit.art], turn, ARROW_W, ARROW_H)
end

local function EntryTip(self)
    local entry = self.entry
    if not entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if entry.kind == "spell" then
        GameTooltip:SetSpellByID(entry.id)
    elseif entry.kind == "item" then
        GameTooltip:SetItemByID(entry.id)
    else
        GameTooltip:SetText(tostring(entry.id))
    end
    -- says so beforehand when the flyout would go with it
    if not InCombatLockdown() then
        local flyout = self.flyout
        local last = flyout and F.Ends(flyout, self.entryIndex)
        local how = TEXT.how
        local key = F.BarsLocked() and GetModifiedClick("PICKUPACTION")
        if key and key ~= "NONE" then how = TEXT.howHeld:format(key:sub(1, 1) .. key:sub(2):lower()) end
        GameTooltip:AddLine((last and TEXT.removeLast or TEXT.remove):format(how), 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

-- the game's own setting, asked as its flyout asks it: locked bars want the pick up key held
function F.BarsLocked()
    if Settings and Settings.GetValue then
        local ok, locked = pcall(Settings.GetValue, "lockActionBars")
        if ok then return locked == true end
    end
    return C_CVar.GetCVar("lockActionBars") == "1"
end

-- an entry's name for a chat line
local function Name(entry)
    local name = entry.id
    if entry.kind == "spell" then
        name = C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
    elseif entry.kind == "item" then
        name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
    end
    if issecretvalue and issecretvalue(name) then return TEXT.it end
    if type(name) == "string" and name ~= "" then return name end
    return TEXT.it
end

-- an icon taken off: chat says what went, and if the flyout went too
local function TakeOff(unit, i)
    local flyout = unit.flyout
    local entry = flyout and flyout.entries[i]
    if not entry then return nil end
    local ok, more = F.Remove(flyout, i)
    if not ok then
        ns.Warn(more)
        return nil
    end
    ns.Say((more and TEXT.gone or TEXT.took):format(Name(entry)))
    return entry
end

local function Pickup(entry)
    if entry.kind == "spell" then
        (C_Spell.PickupSpell or PickupSpell)(entry.id)
    elseif entry.kind == "item" then
        (C_Item.PickupItem or PickupItem)(entry.id)
    else
        PickupMacro(entry.id)
    end
end

-- dragged off as off a bar: out of the flyout and onto the cursor
local function DragOff(self)
    if F.BarsLocked() and not IsModifiedClick("PICKUPACTION") then return end
    local entry = TakeOff(self.flyoutUnit, self.entryIndex)
    if entry then Pickup(entry) end
end

local function Build()
    if root then return end
    root = CreateFrame("Frame", ROOT, UIParent, "SecureHandlerBaseTemplate")
    root:Hide()
    for i = 1, MAX do
        root:SetAttribute("key" .. i, KEYS[i])
        root:SetAttribute("pad" .. i, PADS[i])
    end
    for i, key in ipairs(CLOSE_KEYS) do root:SetAttribute("ckey" .. i, key) end
    root:SetAttribute("ckeys", #CLOSE_KEYS)
    root:SetAttribute("units", 0)
    F.root = root
end

-- the bar button's own numbers: the sweep's inset and shade, the dimming
local COOL_IN, COOL_SHADE = 3, 0.64
local READY, NO_POWER, UNUSABLE = { 1, 1, 1 }, { 0.5, 0.5, 1 }, { 0.4, 0.4, 0.4 }
-- set when the client hid a value in a fight: then it is handed on unread
F.hid = { cooldown = false, usable = false }

local function Hidden(v) return issecretvalue ~= nil and issecretvalue(v) end

-- what an entry casts, for its cooldown and its dimming: a macro's spell
local function Casts(entry)
    if entry.kind ~= "macro" then return entry.kind, entry.id end
    local spell = GetMacroSpell and GetMacroSpell(entry.id)
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

-- dimmed as a bar button: blue short of power, grey unusable
local function Dim(icon, kind, id)
    local usable, short = true, false
    if kind == "spell" then
        usable, short = C_Spell.IsSpellUsable(id)
    elseif kind == "item" then
        local ask = C_Item.IsUsableItem or IsUsableItem
        if ask then usable, short = ask(id) end
    end
    local color = READY
    if Hidden(usable) or Hidden(short) then
        F.hid.usable = true
    elseif not usable then
        color = short and NO_POWER or UNUSABLE
    end
    icon:SetVertexColor(color[1], color[2], color[3])
end

-- every icon of one flyout: its sweep and its dimming, now
local function State(unit)
    if not unit.flyout then return end
    local numbers = C_CVar.GetCVar("countdownForCooldowns") == "1"
    for _, frame in ipairs(unit.entries) do
        local entry = frame.entry
        if entry then
            local kind, id = Casts(entry)
            frame.cooldown:SetHideCountdownNumbers(not numbers)
            Sweep(frame.cooldown, kind, id)
            Dim(frame.icon, kind, id)
        end
    end
end

local function EntryButton(unit, i)
    local name = ENTRY .. unit.index .. "_" .. i
    local entry = CreateFrame("Button", name, unit.menu, "SecureActionButtonTemplate")
    entry:SetSize(Art.ICON, Art.ICON)
    entry:RegisterForClicks("AnyDown", "AnyUp")
    entry:SetAttribute("useOnKeyDown", true)
    entry:SetAttribute("checkselfcast", true)
    root:WrapScript(entry, "OnClick", ENTRY_WRAP)
    entry:SetScript("PostClick", function(_, button, down)
        Tell("pick", unit, i, button, down)
        if button == "RightButton" and not down then TakeOff(unit, i) end
    end)
    -- never a field called unit: the client takes that for a unit name
    entry.flyoutUnit, entry.entryIndex = unit, i
    entry:RegisterForDrag("LeftButton")
    entry:HookScript("OnDragStart", DragOff)
    entry:HookScript("OnEnter", EntryTip)
    entry:HookScript("OnLeave", HideTip)
    entry.icon = entry:CreateTexture(nil, "BACKGROUND")
    entry.icon:SetAllPoints()
    Art.Dress(entry, entry.icon)
    entry:SetNormalAtlas(Art.NAMES.frame)
    entry:SetPushedAtlas(Art.NAMES.frameDown)
    entry:SetHighlightAtlas(Art.NAMES.frameOver)
    for _, art in ipairs({ entry:GetNormalTexture(), entry:GetPushedTexture(), entry:GetHighlightTexture() }) do
        art:ClearAllPoints()
        art:SetPoint("TOPLEFT")
        art:SetSize(Art.FRAME_W, Art.FRAME_H)
    end
    entry.key = entry:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    entry.key:SetPoint("TOPRIGHT", -4, -5)
    entry.pad = entry:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallOutline")
    entry.pad:SetPoint("BOTTOM", 0, 2)
    -- the game's bar button sweep, at the icon's own level
    local cool = CreateFrame("Cooldown", nil, entry, "CooldownFrameTemplate")
    cool:SetPoint("TOPLEFT", entry.icon, "TOPLEFT", COOL_IN, -COOL_IN)
    cool:SetPoint("BOTTOMRIGHT", entry.icon, "BOTTOMRIGHT", -COOL_IN, COOL_IN)
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
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(Art.STRIP, Art.POP)
    unit.menu, unit.strip = menu, Art.Strip(menu)
    root:SetFrameRef("menu" .. f, menu)

    local opener = CreateFrame("Button", OPENER .. f, UIParent, "SecureActionButtonTemplate")
    opener:Hide()
    opener:RegisterForClicks("AnyDown", "AnyUp")
    -- never "unit": the client reads that one as a unit name
    opener:SetAttribute("ffindex", f)
    root:WrapScript(opener, "OnClick", OPENER_WRAP)
    root:SetAttribute("opener" .. f, OPENER .. f)
    opener:SetScript("PostClick", function(_, button, down) Tell("opener", unit, button, down) end)
    unit.opener = opener
    -- the game's flyout arrow, and its glow around the button
    unit.arrow = opener:CreateTexture(nil, "OVERLAY")
    -- a chosen icon, drawn over the bar button's own
    unit.face = opener:CreateTexture(nil, "BACKGROUND")
    unit.face:Hide()
    unit.glow = opener:CreateTexture(nil, "ARTWORK")
    unit.glow:SetAtlas(Art.NAMES.glow)
    unit.glow:Hide()
    opener:HookScript("OnEnter", function()
        Arrow(unit, "arrowOver")
        unit.glow:Show()
    end)
    opener:HookScript("OnLeave", function()
        Arrow(unit, "arrow")
        unit.glow:SetShown(menu:IsShown())
    end)
    opener:HookScript("OnMouseDown", function() Arrow(unit, "arrowDown") end)
    opener:HookScript("OnMouseUp", function() Arrow(unit, opener:IsMouseOver() and "arrowOver" or "arrow") end)

    -- These run inside the secure Show and Hide. An error here would stop
    -- the keys being bound, so the drawing runs guarded and is still reported.
    menu:HookScript("OnShow", function()
        open = unit
        quiet = math.max(quiet, GetTime() + 0.5)
        xpcall(function()
            Arrow(unit)
            unit.glow:Show()
            State(unit)
            Tell("open", unit)
        end, geterrorhandler())
    end)
    menu:HookScript("OnHide", function()
        if open == unit then open = nil end
        quiet = math.max(quiet, GetTime() + 0.5)
        xpcall(function()
            Arrow(unit)
            unit.glow:SetShown(opener:IsMouseOver())
            Tell("shut", unit)
        end, geterrorhandler())
    end)

    for i = 1, MAX do unit.entries[i] = EntryButton(unit, i) end
    Tell("built", unit)
    return unit
end

-- the controller in use, if the pad is the input in use
local function Pad()
    if padMode == false or not (C_GamePad and C_GamePad.GetActiveDeviceID) then return nil end
    return C_GamePad.GetActiveDeviceID()
end

-- a pad button as the game draws it for that controller; never words
local function Glyph(key, style)
    local text = style and _G["KEY_ABBR_" .. key .. style] or GetBindingText(key, 1)
    if type(text) == "string" and (text:find("|A", 1, true) or text:find("|T", 1, true)) then return text end
    return ""
end

-- pad symbols on the icons only while a controller is in use
local function Labels(unit)
    local id = Pad()
    local state = id and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(id)
    local style = state and PAD_STYLES[state.labelStyle]
    for i, frame in ipairs(unit.entries) do
        frame.pad:SetText(id and Glyph(PADS[i], style) or "")
    end
end

-- the flyout's chosen icon on its bar button: over the button's own icon,
-- under its key text and its cooldown; none chosen shows the button's own
local function Face(unit)
    local host, face = unit.host, unit.face
    local icon = host and unit.flyout and unit.flyout.icon
    if unit.mask then
        face:RemoveMaskTexture(unit.mask)
        unit.mask = nil
    end
    if not icon then
        face:Hide()
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
end

-- the "?" icon, as for a macro, means the ability's own icon
local QUESTION = 134400

function F.SetIcon(flyout, icon)
    if icon == QUESTION then icon = nil end
    flyout.icon = icon
    local unit = Run(flyout).unit
    if unit then Face(unit) end
end

-- a right-click on a flyout's bar button opens the icon window
local function HostClicked(self, button, down)
    if button ~= "RightButton" or down then return end
    local flyout = F.At(self:GetName())
    if flyout and not root:GetAttribute("carrying") then ns.Icon.Open(flyout) end
end

-- a unit placed, sized and turned for its bar
local function Lay(unit)
    local flyout, host = unit.flyout, unit.host
    local way, runs = Bars.Way(host)
    local scale = Bars.Scale(host)
    -- At login the bars are not placed yet, and a login in a fight cannot
    -- be laid again: the way and scale last used on this button stand in.
    local last = not ready and Laid()[flyout.host]
    if last and Art.SIDES[last.way] then way, runs, scale = last.way, "as last laid", last.scale or scale end
    local side, count = Art.SIDES[way], #flyout.entries
    local upright = side.x == 0
    local long = Art.FIRST + count * Art.ICON + (count - 1) * Art.NEXT + Art.PAD
    local opener, menu = unit.opener, unit.menu
    unit.way, unit.runs = way, runs
    -- the button's child: shows and hides with its bar
    opener:SetParent(host)
    opener:SetScale(Bars.Size(host))
    opener:SetFrameStrata(host:GetFrameStrata())
    opener:SetFrameLevel(host:GetFrameLevel() + 10)
    opener:ClearAllPoints()
    opener:SetSize(upright and GRIP_W or GRIP_H, upright and GRIP_H or GRIP_W)
    opener:SetPoint("CENTER", host, side.to, side.x * GRIP_OUT, side.y * GRIP_OUT)
    unit.arrow:ClearAllPoints()
    unit.arrow:SetPoint(side.to, host, side.to, side.x * ARROW_OUT, side.y * ARROW_OUT)
    unit.glow:ClearAllPoints()
    unit.glow:SetPoint("TOPLEFT", host, "TOPLEFT", -Art.GLOW, Art.GLOW)
    unit.glow:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", Art.GLOW, -Art.GLOW)
    Arrow(unit, "arrow")
    opener:Show()
    menu:SetScale(scale)
    menu:ClearAllPoints()
    menu:SetPoint(side.point, host, side.to, -side.x * Art.OVERLAP, -side.y * Art.OVERLAP)
    menu:SetSize(upright and Art.STRIP or long, upright and long or Art.STRIP)
    Art.LayStrip(unit.strip, menu, way)

    for i, frame in ipairs(unit.entries) do
        local entry = flyout.entries[i]
        local out = Art.FIRST + (i - 1) * (Art.ICON + Art.NEXT)
        frame.entry, frame.flyout = entry, flyout
        frame:ClearAllPoints()
        frame:SetPoint(side.point, menu, side.point, side.x * out, side.y * out)
        frame:SetAttribute("type", entry and entry.kind or nil)
        frame:SetAttribute("spell", nil)
        frame:SetAttribute("item", nil)
        frame:SetAttribute("macro", nil)
        if entry then
            frame:SetAttribute(entry.kind, entry.kind == "item" and ("item:" .. entry.id) or entry.id)
            frame.icon:SetTexture(F.Icon(entry))
            frame.key:SetText(KEYS[i])
        end
        frame:SetShown(entry ~= nil)
    end
    Labels(unit)
    Face(unit)
    State(unit)
    root:SetAttribute("count" .. unit.index, count)
    unit.placed = Bars.Placed(host)
    if ready then Laid()[flyout.host] = { way = way, scale = scale } end
end

-- whether a key is one of the first count picks, as it stands
local function Picks(key, count)
    for i = 1, count do
        if key == KEYS[i] or key == PADS[i] then return true end
    end
    return false
end

-- each button's keys click its opener, read fresh
local function Rebind()
    ClearOverrideBindings(root)
    Bars.KeyMap(true)
    for f = 1, used do
        local unit = units[f]
        local count = #unit.flyout.entries
        local mine, mods, under = {}, {}, 0
        unit.keys = Bars.Keys(unit.host)
        for _, key in ipairs(unit.keys) do mine[key] = true end
        for i, key in ipairs(unit.keys) do
            -- a key that is a pick while open cannot be held: its release may go to the pick
            local how = Picks(key, count) and "tap" or "LeftButton"
            root:SetAttribute("okey" .. f .. "_" .. i, key)
            root:SetAttribute("obtn" .. f .. "_" .. i, how)
            SetOverrideBindingClick(root, true, key, OPENER .. f, how)
            local mod = how ~= "tap" and key:match("^(.*%-).")
            if mod then mods[mod] = true end
        end
        -- held with a modifier, the number keys arrive under it: bound so too
        for mod in pairs(mods) do
            for i = 1, count do
                for _, base in ipairs({ KEYS[i], PADS[i] }) do
                    if not mine[mod .. base] then
                        under = under + 1
                        root:SetAttribute("mkey" .. f .. "_" .. under, mod .. base)
                        root:SetAttribute("mentry" .. f .. "_" .. under, ENTRY .. f .. "_" .. i)
                    end
                end
            end
        end
        root:SetAttribute("mkeys" .. f, under)
        root:SetAttribute("okeys" .. f, #unit.keys)
    end
    quiet = math.max(quiet, GetTime() + 0.5)
end

local function Signature()
    local parts = {}
    for f = 1, used do parts[f] = table.concat(units[f].keys, " ") end
    return table.concat(parts, "|")
end

-- keys changed elsewhere: a new one shows at once,
-- one taken off hides under ours, so bind afresh
local function Rekey()
    rekey = nil
    Bars.KeyMap(true)
    local grown = false
    for f = 1, used do
        if #Bars.Keys(units[f].host) ~= #units[f].keys then grown = true end
    end
    if not grown and GetTime() < patient then return end
    local was = Signature()
    Rebind()
    if Signature() == was then
        idle = idle + 1
        patient = GetTime() + math.min(300, 5 * 2 ^ idle)
    else
        idle, patient = 0, 0
        Tell("rekey")
    end
end

-- lays every flyout on its button; waits out a fight
function F.Apply()
    if InCombatLockdown() then
        pending = true
        return false
    end
    pending = nil
    Build()
    for _, unit in ipairs(units) do unit.menu:Hide() end
    root:SetAttribute("open", nil)
    -- no key counts as held or pressed across a layout
    root:Execute("armed, held, picked = nil, nil, nil")
    local taken = {}
    used = 0
    for _, flyout in ipairs(list or {}) do
        local state = Run(flyout)
        local name = flyout.host
        local host = not state.lost and Bars.Named(name)
        state.unit = nil
        if host and #flyout.entries > 0 and not taken[name] then
            taken[name] = true
            used = used + 1
            local unit = Unit(used)
            unit.flyout, unit.host = flyout, host
            state.unit = unit
            Lay(unit)
            -- its click opens the flyout: wrapped once, told which one each time
            if wrapped[name] == nil then
                wrapped[name] = pcall(root.WrapScript, root, host, "OnClick", HOST_WRAP)
                if wrapped[name] then host:HookScript("PostClick", HostClicked) end
            end
            root:SetAttribute("host-" .. name, used)
        end
    end
    for name in pairs(hosted) do
        if not taken[name] then root:SetAttribute("host-" .. name, nil) end
    end
    hosted = taken
    -- remembered layouts of buttons that no longer have a flyout go
    if ready then
        local laid = Laid()
        for name in pairs(laid) do
            if not taken[name] then laid[name] = nil end
        end
    end
    for f = used + 1, #units do
        local unit = units[f]
        unit.opener:SetParent(UIParent)
        unit.opener:Hide()
        unit.flyout, unit.host, unit.placed, unit.keys = nil, nil, nil, {}
        Face(unit)
        unit.face:SetParent(unit.opener)
        root:SetAttribute("okeys" .. f, 0)
        root:SetAttribute("mkeys" .. f, 0)
        root:SetAttribute("count" .. f, 0)
    end
    root:SetAttribute("units", used)
    Rebind()
    Tell("laid")
    return true
end

-- keeps each flyout on the button that holds its action
function F.Follow()
    if not list or InCombatLockdown() then return end
    local search, change, buttons = moved, false, nil
    moved = nil
    for _, flyout in ipairs(list) do
        local state, main = Run(flyout), flyout.main
        local held = Bars.Named(flyout.host)
        local on = main == nil or (held ~= nil and Bars.Holds(held, main))
        if main and not (on and held:IsVisible()) then
            -- off its button or its bar hidden: looked for once
            local why = on and "hidden" or "off"
            if search or state.sought ~= why then
                state.sought = why
                buttons = buttons or Bars.All(true)
                local found = Bars.Find(main, buttons)
                if found then
                    Tell("follow", flyout, flyout.host, found)
                    flyout.host, state.lost, state.sought, change = found, nil, nil, true
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
            end
        end
    end
    if change then return F.Apply() end
end

-- flyouts from saved data show only where their action is
function F.Settle()
    if InCombatLockdown() then
        pending = true
        return
    end
    for _, flyout in ipairs(list or {}) do
        local held, state = Bars.Named(flyout.host), Run(flyout)
        local on = flyout.main == nil or (held ~= nil and Bars.Holds(held, flyout.main))
        state.lost, state.sought = not on or nil, nil
        -- off its button, or on a hidden one: the bars are searched
        if flyout.main and not (on and held:IsVisible()) then moved = true end
    end
    F.Apply()
    F.Follow()
end

-- the profile in use; a damaged flyout is dropped, not patched
function F.Load()
    local data = P.Data()
    list = data and data.flyouts
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
            flyout.main = { kind = first.kind, id = first.id }
        end
    end
end

function F.List() return list end
function F.Units() return units, used end
function F.Open() return open end
function F.Lost(flyout) return Run(flyout).lost == true end
function F.UnitOf(flyout) return Run(flyout).unit end
function F.Pause(on) paused = on end
function F.Wrapped(name) return wrapped[name] == true end
function F.Moved() moved = true end

-- the flyout shown on a button
function F.At(name)
    for f = 1, used do
        local unit = units[f]
        if unit.host:GetName() == name then return unit.flyout, unit end
    end
end

-- the flyout an action leads, wherever it is
function F.Of(main)
    for _, flyout in ipairs(list or {}) do
        if Same(flyout.main, main) then return flyout end
    end
end

local function Has(flyout, entry)
    for _, other in ipairs(flyout.entries) do
        if Same(other, entry) then return true end
    end
    return false
end

-- adds to the button's flyout, making one if needed
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
    end
    if flyout then
        if #flyout.entries >= MAX then return nil, TEXT.full end
        if Has(flyout, entry) then return nil, TEXT.twice end
        flyout.host = name
        Run(flyout).lost = nil
    else
        if Same(main, entry) then return nil, TEXT.twice end
        flyout = { host = name, main = main, entries = { { kind = main.kind, id = main.id } } }
        list[#list + 1] = flyout
    end
    flyout.entries[#flyout.entries + 1] = { kind = entry.kind, id = entry.id }
    F.Apply()
    return flyout
end

local function Forget(flyout)
    for i = #list, 1, -1 do
        if list[i] == flyout then table.remove(list, i) end
    end
    run[flyout] = nil
end

-- takes an entry out; one left with only its lead goes
function F.Remove(flyout, i)
    if InCombatLockdown() then return false, TEXT.fight end
    if not (list and flyout and flyout.entries[i]) then return false end
    local shown = open ~= nil and open.flyout == flyout
    local gone = F.Ends(flyout, i)
    table.remove(flyout.entries, i)
    if gone then Forget(flyout) end
    F.Apply()
    -- still open, for the next one to take out
    local unit = shown and not gone and Run(flyout).unit
    if unit then F.Show(unit.index) end
    -- true, and whether the flyout went with it
    return true, gone
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
    F.Follow()
    if rekey and not open and not InCombatLockdown() then Rekey() end
end

-- something on the cursor: a click on a host goes to the bar, to place it
function F.Carrying(on)
    if root and not InCombatLockdown() then root:SetAttribute("carrying", on or nil) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
-- not every client has the pad's events
for _, event in ipairs({ "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_DISCONNECTED" }) do
    pcall(events.RegisterEvent, events, event)
end
-- what changes an open flyout's sweeps and dimming
local STATE_EVENTS = { SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_USABLE = true, BAG_UPDATE_COOLDOWN = true,
    ACTIONBAR_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true }
for event in pairs(STATE_EVENTS) do pcall(events.RegisterEvent, events, event) end
events:SetScript("OnEvent", function(_, event, on)
    if event == "ACTIONBAR_SLOT_CHANGED" then
        if ready and list and #list > 0 and not moved then
            moved = true
            C_Timer.After(0.1, Sync)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then F.Settle() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- the last moment it can be set: nothing is placed in a fight
        if root then root:SetAttribute("carrying", nil) end
        -- and the last moment a flyout can be laid for where its bar is now
        F.Follow()
    elseif event == "PLAYER_ENTERING_WORLD" then
        F.Follow()
    elseif event == "UPDATE_BINDINGS" then
        if ready and used > 0 and GetTime() >= quiet then rekey = true end
    elseif STATE_EVENTS[event] then
        -- only the open one can be seen
        if open then State(open) end
    else
        -- the pad became the input in use, or stopped being it
        if event == "GAME_PAD_ACTIVE_CHANGED" then padMode = on and true or false end
        for f = 1, used do Labels(units[f]) end
    end
end)

ns.OnStart(function()
    F.Load()
    P.OnChange(function()
        F.Load()
        if ready then F.Settle() end
    end)
    -- at once: a login in a fight is not locked yet
    F.Settle()
    -- bars are still being placed: laid again if one moved
    for step = 1, 11 do C_Timer.After(step * 0.25, F.Follow) end
    -- and once other addons have placed their bars and keys
    C_Timer.After(3, function()
        ready = true
        Adopt()
        F.Settle()
        C_Timer.NewTicker(1, Sync)
    end)
end)
