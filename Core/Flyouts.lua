local _, ns = ...
-- luacheck: read globals UIParent CreateFrame GetTime InCombatLockdown C_Timer C_Spell C_Item GetMacroInfo
-- luacheck: read globals SetOverrideBindingClick ClearOverrideBindings GameTooltip C_GamePad GetBindingText
-- luacheck: read globals issecretvalue C_CVar C_Container GetMacroSpell IsUsableItem geterrorhandler
-- luacheck: read globals Settings IsModifiedClick GetModifiedClick PickupSpell PickupItem PickupMacro
-- luacheck: read globals IsBindingForGamePad GetBindingKey GetNumBindings GetBinding ACTIONBAR_HOTKEY_FONT_COLOR

-- Flyouts on bar buttons. One secure root owns every key.
local F = {}
ns.Flyouts = F
local P, Bars, Art, Binds = ns.Profiles, ns.Bars, ns.Art, ns.Binds

local MAX = 6
local KEYS = { "1", "2", "3", "4", "5", "6" }
local PADS = { "PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PAD4", "PAD3" }
-- Pad buttons go by where an icon sits: the two ends take the D-pad along
-- the flyout's line (top is up, bottom is down), the ones between the rest.
local PAD_UPRIGHT = { first = "PADDUP", last = "PADDDOWN", between = { "PADDRIGHT", "PADDLEFT", "PAD4", "PAD3" } }
local PAD_LEVEL = { first = "PADDLEFT", last = "PADDRIGHT", between = { "PADDUP", "PADDDOWN", "PAD4", "PAD3" } }
-- the pad symbol's size on a flyout icon
local GLYPH = 11
-- a controller's label style, as the game's key strings end
local PAD_STYLES = { Letters = "_LTR", Shapes = "_SHP", Reverse = "_REV" }
local CLOSE_KEYS = { "ESCAPE", "PAD2" }
local ROOT, OPENER = "FallensFlyoutsRoot", "FallensFlyoutsOpener"
local MENU, ENTRY = "FallensFlyoutsMenu", "FallensFlyoutsEntry"
-- the game's arrow: 18 by 7, 4 out when shut, 2 when open
local ARROW_W, ARROW_H, ARROW_OUT, ARROW_OPEN, GRIP_W, GRIP_H, GRIP_OUT = 18, 7, 4, 2, 30, 14, 3
-- flyout size against the game's own, as a setting
local SIZE_MIN, SIZE_MAX = 0.5, 2
local TEXT = {
    fight = "Flyouts change only out of a fight.",
    full = "That flyout is full.",
    twice = "That is in the flyout already.",
    noLead = "That button's action cannot lead a flyout.",
    how = "Drag",
    howHeld = "%s-drag",
    remove = "%s to move it. Right-click takes it off the flyout.",
    removeLast = "%s to move it. Right-click takes it off, and the flyout with it: nothing else was added.",
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
-- then the open one's shut keys, then its picks (listed by Rebind)
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
        for i = 1, owner:GetAttribute("pkeys" .. open) or 0 do
            local at = open .. "_" .. i
            owner:SetBindingClick(true, owner:GetAttribute("pkey" .. at), owner:GetAttribute("pentry" .. at))
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
    -- the game draws it 2 closer while open; left as it is in a fight
    local side, host = Art.SIDES[unit.way or "UP"], unit.host
    if host and not InCombatLockdown() then
        local out = unit.menu:IsShown() and ARROW_OPEN or ARROW_OUT
        unit.arrow:ClearAllPoints()
        unit.arrow:SetPoint(side.to, host, side.to, side.x * out, side.y * out)
    end
end

local function EntryTip(self)
    local entry = self.entry
    if not entry then return end
    -- while keys are being set, a hover says how instead
    if ns.Keys and ns.Keys.Enter(self) then return end
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

-- dragged out as off a bar: off the flyout and onto the cursor
function F.CarryOff(unit, i)
    local entry = TakeOff(unit, i)
    if entry then Pickup(entry) end
    return entry
end

-- a drag on an icon moves it: UI/Move.lua, loaded after this file
local function DragStart(self) ns.Move.Start(self) end
local function DragStop() ns.Move.Released() end

local function Build()
    if root then return end
    root = CreateFrame("Frame", ROOT, UIParent, "SecureHandlerBaseTemplate")
    root:Hide()
    for i, key in ipairs(CLOSE_KEYS) do root:SetAttribute("ckey" .. i, key) end
    root:SetAttribute("ckeys", #CLOSE_KEYS)
    root:SetAttribute("units", 0)
    F.root = root
end

-- the bar button's own numbers: the sweep's inset and shade, the dimming
local COOL_SHADE = 0.64
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
    entry:HookScript("OnDragStart", DragStart)
    entry:HookScript("OnDragStop", DragStop)
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
    -- the game's own mouseover ring on the bar button, lit to point it out
    unit.ring = opener:CreateTexture(nil, "OVERLAY")
    unit.ring:SetAtlas(Art.NAMES.frameOver)
    unit.ring:Hide()
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
            Arrow(unit)
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
local function Glyph(key, style)
    local text = style and _G["KEY_ABBR_" .. key .. style] or GetBindingText(key, 1)
    if type(text) ~= "string" or not (text:find("|A", 1, true) or text:find("|T", 1, true)) then return "" end
    return (text:gsub("(|A:[^:|]+):%d+:%d+", "%1:" .. GLYPH .. ":" .. GLYPH))
end

-- a key as the bars write it: a number as it is, the rest shortened by the game
local function KeyText(key)
    if not key then return "" end
    if #key == 1 then return key end
    local text = GetBindingText(key, 1)
    if type(text) == "string" and text ~= "" then return text end
    return key
end

-- The pad buttons by place: entry 1 is by the bar button, so it is the
-- bottom of a flyout that grows up and the top of one that grows down.
local function PadsFor(way, count)
    local set = Art.SIDES[way].x == 0 and PAD_UPRIGHT or PAD_LEVEL
    local fromStart = way == "DOWN" or way == "RIGHT"
    local out = {}
    for i = 1, count do
        local at = fromStart and i or count + 1 - i
        if at == 1 then
            out[i] = set.first
        elseif at == count then
            out[i] = set.last
        else
            out[i] = set.between[at - 1]
        end
    end
    return out
end

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
local function Picks(unit)
    local entries = unit.flyout.entries
    local pads = PadsFor(unit.way or "UP", #entries)
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
    -- then the keys set for the places in the game's key menu
    for i, pick in ipairs(picks) do
        local key, pad = Binds.Pick(i)
        if not pick.key and key and not taken[key] then pick.key, taken[key] = key, true end
        if not pick.pad and pad and not taken[pad] then pick.pad, taken[pad] = pad, true end
    end
    for i, pick in ipairs(picks) do
        pick.key = pick.key or Free(KEYS[i], KEYS, taken)
        pick.pad = pick.pad or Free(pads[i], PADS, taken)
    end
    return picks
end

-- one label per icon: the pad's symbol while the pad is the input in use, else the key
function Labels(unit)
    if not unit.picks then return end
    local pad = PadInUse()
    local id = pad and C_GamePad.GetActiveDeviceID and C_GamePad.GetActiveDeviceID()
    local state = id and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(id)
    local style = state and PAD_STYLES[state.labelStyle]
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
-- while keys are being set, a hover on the bar button opens its flyout
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

-- where the icon in place i starts, along the flyout from the bar button
function F.Slot(i) return Art.FIRST + (i - 1) * (Art.ICON + Art.NEXT) end

-- an icon frame that far along its flyout; out of a fight only
function F.Put(unit, frame, out)
    local side = Art.SIDES[unit.way]
    frame:ClearAllPoints()
    frame:SetPoint(side.point, unit.menu, side.point, side.x * out, side.y * out)
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
    unit.ring:ClearAllPoints()
    unit.ring:SetPoint("TOPLEFT", host, "TOPLEFT")
    unit.ring:SetSize(Art.RING_W, Art.RING_H)
    Arrow(unit, "arrow")
    opener:Show()
    -- the bar's scale times the size picked in the settings (1 is the game's own)
    menu:SetScale(scale * F.Size())
    menu:ClearAllPoints()
    menu:SetPoint(side.point, host, side.to, -side.x * Art.OVERLAP, -side.y * Art.OVERLAP)
    menu:SetSize(upright and Art.STRIP or long, upright and long or Art.STRIP)
    Art.LayStrip(unit.strip, menu, way)

    for i, frame in ipairs(unit.entries) do
        local entry = flyout.entries[i]
        frame.entry, frame.flyout = entry, flyout
        F.Put(unit, frame, F.Slot(i))
        frame:SetAttribute("type", entry and entry.kind or nil)
        frame:SetAttribute("spell", nil)
        frame:SetAttribute("item", nil)
        frame:SetAttribute("macro", nil)
        if entry then
            frame:SetAttribute(entry.kind, entry.kind == "item" and ("item:" .. entry.id) or entry.id)
            frame.icon:SetTexture(F.Icon(entry))
        end
        frame:SetShown(entry ~= nil)
    end
    Face(unit)
    State(unit)
    root:SetAttribute("count" .. unit.index, count)
    unit.placed = Bars.Placed(host)
    if ready then Laid()[flyout.host] = { way = way, scale = scale } end
end

-- the keys that open a flyout: its bar button's, and its own row's in the key menu
local function OpenKeys(unit)
    local keys, seen = {}, {}
    for _, key in ipairs(Bars.Keys(unit.host)) do
        keys[#keys + 1], seen[key] = key, true
    end
    for _, key in ipairs(Binds.Open(unit.flyout.number)) do
        if not seen[key] then keys[#keys + 1], seen[key] = key, true end
    end
    return keys
end

-- Each button's keys click its opener, read fresh. Each flyout's picks are
-- listed for the snippet, also under the modifiers of a key that can be held.
local function Rebind()
    ClearOverrideBindings(root)
    Bars.KeyMap(true)
    for f = 1, used do
        local unit = units[f]
        local mine, mods, plain, listed = {}, {}, {}, 0
        local function List(key, i)
            listed = listed + 1
            root:SetAttribute("pkey" .. f .. "_" .. listed, key)
            root:SetAttribute("pentry" .. f .. "_" .. listed, ENTRY .. f .. "_" .. i)
        end
        unit.picks = Picks(unit)
        for i, pick in ipairs(unit.picks) do
            for _, key in ipairs({ pick.key, pick.pad }) do
                List(key, i)
                plain[key] = true
            end
        end
        unit.keys = OpenKeys(unit)
        for _, key in ipairs(unit.keys) do mine[key] = true end
        for i, key in ipairs(unit.keys) do
            -- a key that is a pick while open cannot be held: its release may go to the pick
            local how = plain[key] and "tap" or "LeftButton"
            root:SetAttribute("okey" .. f .. "_" .. i, key)
            root:SetAttribute("obtn" .. f .. "_" .. i, how)
            SetOverrideBindingClick(root, true, key, OPENER .. f, how)
            local mod = how ~= "tap" and key:match("^(.*%-).")
            if mod then mods[mod] = true end
        end
        -- held with a modifier, a plain pick key arrives under it: bound so too
        for mod in pairs(mods) do
            for i, pick in ipairs(unit.picks) do
                for _, base in ipairs({ pick.key, pick.pad }) do
                    local under = mod .. base
                    if not base:find("-", 1, true) and not mine[under] and not plain[under] then List(under, i) end
                end
            end
        end
        root:SetAttribute("pkeys" .. f, listed)
        root:SetAttribute("okeys" .. f, #unit.keys)
        Labels(unit)
    end
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
    Rebind()
    if Signature() == was then
        idle = idle + 1
        patient = GetTime() + math.min(300, 5 * 2 ^ idle)
    else
        idle, patient = 0, 0
        Tell("rekey")
    end
end

-- Each flyout has a number of its own, kept for good: its row in the
-- game's key menu. The rows are named after the abilities they sit on.
local function Number()
    local taken = {}
    for _, flyout in ipairs(list or {}) do
        local n = flyout.number
        if type(n) == "number" and n >= 1 and n <= Binds.SLOTS and not taken[n] then
            taken[n] = flyout
        else
            flyout.number = nil
        end
    end
    for _, flyout in ipairs(list or {}) do
        local n = 1
        while not flyout.number and n <= Binds.SLOTS do
            if not taken[n] then flyout.number, taken[n] = n, flyout end
            n = n + 1
        end
    end
    for n = 1, Binds.SLOTS do
        Binds.Name(n, taken[n] and Name(taken[n].main) or nil)
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
    Number()
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
                if wrapped[name] then
                    host:HookScript("PostClick", HostClicked)
                    host:HookScript("OnEnter", HostEntered)
                end
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
        root:SetAttribute("pkeys" .. f, 0)
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
                -- its saved button gone for good (a bar addon taken off): a hidden bar of the game's will do
                local found = Bars.Find(main, buttons, held == nil)
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
-- whether the pad is the input in use right now, and the command that tells
function F.PadInUse() return PadInUse(), witness end
function F.Wrapped(name) return wrapped[name] == true end

-- Lights the bar button of flyout number n, to show where it is; nil puts
-- the light out. Returns the unit lit.
local pointed
function F.Point(n)
    if pointed then
        pointed.ring:Hide()
        pointed.glow:SetShown(pointed.menu:IsShown() or pointed.opener:IsMouseOver())
        pointed = nil
    end
    for f = 1, used do
        local unit = units[f]
        if n and unit.flyout and unit.flyout.number == n then
            pointed = unit
            unit.ring:Show()
            unit.glow:Show()
        end
    end
    return pointed
end

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
    for _, other in ipairs(flyout.entries) do
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
function F.Picks(flyout)
    local unit = Run(flyout).unit
    return unit and unit.picks
end
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

-- an entry to another place in its flyout; the rest close up around it
function F.Move(flyout, from, to)
    if InCombatLockdown() then return false, TEXT.fight end
    local entries = flyout and flyout.entries
    if not (list and entries and entries[from] and entries[to]) then return false end
    if from == to then return true end
    local shown = open ~= nil and open.flyout == flyout
    table.insert(entries, to, table.remove(entries, from))
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
        -- the game's bars relabel on this too
        sought = nil
        if open then Labels(open) end
    elseif STATE_EVENTS[event] then
        -- only the open one can be seen
        if open then State(open) end
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
