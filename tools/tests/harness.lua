-- The fake client the tests run the addon in: frames, bindings, secure snippets, the cursor, three kinds of
-- action bars (the game's, bars that send keys through a helper child, bars of their own buttons), reloads
-- between sessions. Loaded by run.lua in one chunk with a test file, so its locals are the test's too.
-- MODEL: "captured" (a key's release goes to the frame its press went to) or "relookup".

-- survives a reload; a test that switches addons fills these
local enabled, installed = {}, {}
-- the bars of the session being booted: "game", "helper" or "own"
local barWorld = function() return "game" end
local wantReload, fails = false, 0
-- who is logged in: one saved table serves every character of the account
local char = { guid = "Player-1-0000000A", class = "MAGE", name = "Tester A" }
FallensFlyoutsDB = nil
-- the addon's own table, as the last session made it
local NS

-- one session
local W

local function check(ok, what)
    if ok then
        print("  ok   " .. what)
    else
        fails = fails + 1
        print("  FAIL " .. what)
    end
end

-- an event reaches only the frames that asked for it
local function fire(event, ...)
    for _, f in ipairs(W.all) do
        if f.scripts.OnEvent and f.events and f.events[event] then f.scripts.OnEvent(f, event, ...) end
    end
end

local Frame = {}
Frame.__index = Frame
local function noop() end
for _, m in ipairs({ "ClearAllPoints", "RegisterForClicks", "EnableMouse",
    "SetHighlightTexture", "SetAllPoints", "SetColorTexture",
    "SetJustifyH", "HighlightText", "SetHorizTile", "SetVertTile",
    "SetDrawBling", "SetDrawEdge", "SetSwipeColor", "SetHideCountdownNumbers", "SetUsingParentLevel",
    "AddMaskTexture", "SetLooping",
    "SetFromAlpha", "SetToAlpha", "SetDuration", "Play", "Stop", "RemoveMaskTexture", "SetDrawLayer",
    "SetToplevel", "SetMovable", "SetClampedToScreen", "RegisterForDrag", "SetMaxLetters", "SetFocus",
    "Enable", "Disable", "SetValueStep", "SetObeyStepOnDrag", "SetAutoFocus", "SetFontObject", "EnableGamePadButton",
    "SetPropagateKeyboardInput" }) do
    Frame[m] = noop
end
local function region() return setmetatable({ scripts = {}, attrs = {}, shown = true }, Frame) end
-- a button listens for presses, releases or both: a plain button's click runs on the press only when it
-- listens for presses
function Frame:RegisterForClicks(...)
    self.clicksOnPress = false
    for _, what in ipairs({ ... }) do
        if type(what) == "string" and what:find("Down", 1, true) then self.clicksOnPress = true end
    end
end
function Frame:RegisterEvent(event)
    self.events = self.events or {}
    self.events[event] = true
end
Frame.RegisterUnitEvent = Frame.RegisterEvent
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetSize() return self.w or 10, self.h or 10 end
function Frame:SetAtlas(atlas) self.atlas = atlas end
function Frame:GetAtlas() return self.atlas end
unpack = table.unpack
function Frame:SetTexCoord(...) self.cut = { ... } end
function Frame:GetTexCoord()
    if self.cut then return table.unpack(self.cut) end
    return 0, 0, 0, 1, 1, 0, 1, 1
end
function Frame:GetScaledRect() return nil end
-- seen or not, and a rectangle a test gives it: left, right, top, bottom
function Frame:SetAlpha(v) self.alpha = v end
-- the last anchor given: point, frame, its point, x, y
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint()
    if self.point then return table.unpack(self.point) end
end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:GetLeft() return self.rect and self.rect[1] end
function Frame:GetRight() return self.rect and self.rect[2] end
function Frame:GetTop() return self.rect and self.rect[3] end
-- a window that can be dragged: whether it may be, whether it is being, and that it was
function Frame:SetMovable(v) self.movable = v == true end
function Frame:IsMovable() return self.movable == true end
function Frame:SetClampedToScreen(v) self.clamped = v == true end
function Frame:StartMoving() if self.movable then self.moving = true end end
function Frame:StopMovingOrSizing()
    if self.moving then self.moved = true end
    self.moving = nil
end
-- words on as many lines as their width makes of them: seven wide a letter, twelve high a line
function Frame:GetStringHeight()
    local wide = self.w or 0
    local long = #(self.text or "") * 7
    return 12 * math.max(1, wide > 0 and math.ceil(long / wide) or 1)
end
-- a scroll frame: what scrolls in it, how far it can go (its child's height over its own), where it is
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:GetScrollChild() return self.scrollChild end
function Frame:UpdateScrollChildRect() end
function Frame:EnableMouseWheel() end
function Frame:GetVerticalScrollRange()
    local child = self.scrollChild
    return math.max(0, (child and child.h or 0) - (self.h or 0))
end
function Frame:GetVerticalScroll() return self.scrolled or 0 end
function Frame:SetVerticalScroll(v) self.scrolled = v end
-- the game's scroll bar
function Frame:SetHideIfUnscrollable(v) self.hideIfUnscrollable = v end
function Frame:GetBottom() return self.rect and self.rect[4] end
-- the layer a frame is drawn on: its own when given one, else that of its parent
function Frame:SetFrameStrata(strata) self.strata = strata end
-- The game lifts its own action bars to the top layer while a spell is on the
-- cursor (ActionBarMixin:UpdateFrameStrata); their buttons go up with them.
function Frame:GetFrameStrata()
    if self.raises and W.cursor and W.cursor[1] == "spell" then return "TOOLTIP" end
    return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
end
function Frame:SetFrameLevel(level) self.level = level end
-- the frames a frame holds
function Frame:GetChildren()
    local out = {}
    for _, f in ipairs(W.all) do
        if f.parent == self then out[#out + 1] = f end
    end
    return table.unpack(out)
end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetScale(v) self.scale = v end
function Frame:GetScale() return self.scale or 1 end
function Frame:SetTexture(v) self.texture = v end
function Frame:GetTexture() return self.texture end
function Frame:SetText(v) self.text = v end
function Frame:SetVertexColor(r, g, b) self.color = { r, g, b } end
-- a slider tells its script each value it is given
function Frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
function Frame:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end
end
function Frame:GetValue() return self.value end
-- a typing box: one holds the focus at a time, and a hidden one cannot
function Frame:SetFocus() W.focus = self end
function Frame:ClearFocus()
    if W.focus ~= self then return end
    W.focus = nil
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
-- a cooldown sweep: what it was last told, nil when cleared
-- as his client (2026-11-21): a hidden number from addon code is refused with an error
function Frame:SetCooldown(start, duration, rate)
    local hidden = issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(rate))
    assert(not hidden, "Secret values are only allowed during untainted execution for this argument.")
    self.sweep = { start, duration, rate }
end
-- the client's own way for an addon: an object that carries the numbers unseen
function Frame:SetCooldownFromDurationObject(object, clearIfZero)
    if clearIfZero and not object.active then
        self.sweep = nil
    else
        self.sweep = { object.start, object.duration, object = true }
    end
end
function geterrorhandler() return function(msg) W.caught[#W.caught + 1] = tostring(msg) end end
function Frame:Clear() self.sweep = nil end
function Frame:GetText() return self.text end
function Frame:GetStringWidth() return #(self.text or "") * 7 end
function Frame:GetTextWidth() return #(self.text or "") * 7 end
function Frame:SetEnabled(v) self.off = not v end
function Frame:IsEnabled() return not self.off end
-- a drop down: its rows are asked for anew each time, the picked one is its text
function Frame:SetupMenu(fill) self.fill = fill; self:GenerateMenu() end
function Frame:GenerateMenu()
    local drop = self
    drop.rows, drop.Text = {}, drop.Text or region()
    drop.fill(drop, { CreateRadio = function(_, label, isOn, pick, data)
        drop.rows[#drop.rows + 1] = { label = label, pick = function() pick(data) end }
        if isOn(data) then drop.Text:SetText(label) end
    end })
end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:IsMouseOver() return self.over == true end
for _, m in ipairs({ "CreateMaskTexture", "CreateAnimationGroup", "CreateAnimation" }) do
    Frame[m] = region
end
-- a button's own art: one texture per state, wearing the atlas set on it
for _, kind in ipairs({ "Normal", "Pushed", "Highlight" }) do
    local key = "art" .. kind
    local function Art(self)
        self[key] = self[key] or region()
        return self[key]
    end
    Frame["Get" .. kind .. "Texture"] = Art
    Frame["Set" .. kind .. "Atlas"] = function(self, atlas) Art(self).atlas = atlas end
end
-- as the client: the scripts run only when the frame's own state changes
function Frame:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetChecked(on) self.checked = on and true or false end
function Frame:GetChecked() return self.checked == true end
function Frame:GetName() return self.name end
-- a button's number on its bar; on the bars of gamepad mode it is the button's slot
function Frame:GetID() return self.id or 0 end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:IsForbidden() return false end
function Frame:IsObjectType(t) return self.otype == t end
function Frame:IsProtected() return self.protected or false end
function Frame:GetWidth() return self.w or 100 end
function Frame:GetHeight() return self.h or 40 end
function Frame:GetCenter() return self.cx or 500, self.cy or 30 end
function Frame:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
-- the client reads a secure button's "unit" as a unit name and breaks on anything else
-- (his client, 2026-11-21: SecureTemplates.lua:154, attempt to index local 'unit' (a number value))
function Frame:SetAttribute(k, v)
    assert(k ~= "unit" or v == nil or type(v) == "string", "a unit attribute must be a unit name")
    self.attrs[k] = v
end
function Frame:GetAttribute(k) return self.attrs[k] end
-- as the client: a frame kept for the snippets under an attribute of its own
function Frame:SetFrameRef(label, frame) self.attrs["frameref-" .. label] = frame end
function Frame:GetFrameRef(label) return self.attrs["frameref-" .. label] end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:HookScript(k, fn)
    local old = self.scripts[k]
    self.scripts[k] = function(...) if old then old(...) end fn(...) end
end
function Frame:CreateTexture() return region() end
function Frame:CreateFontString() return region() end
function Frame:WrapScript(frame, _, body) frame.wrap, frame.header = body, self end

-- override bindings: priority ones win, then the latest set
local function setOverride(owner, priority, key, action)
    W.overrides[owner] = W.overrides[owner] or {}
    W.seq = W.seq + 1
    W.overrides[owner][key] = { action = action, priority = priority and true or false, seq = W.seq }
end
function Frame:ClearBindings() W.overrides[self] = {} end
function Frame:SetBindingClick(priority, key, name, button)
    assert(type(key) == "string" and type(name) == "string", "SetBindingClick wants a key and a name")
    setOverride(self, priority, key, "CLICK " .. name .. ":" .. (button or "LeftButton"))
end

-- The game's icon window, as much of it as the addon leans on. Its list: the "?" first, then
-- icons by number and by file name, as the client's own provider can hand either.
local QUESTION_PATH = "INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK"
IconSelectorPopupFrameIconFilterTypes = { All = 1, Spell = 2, Item = 3 }
IconDataProviderExtraType = { None = 1, Spellbook = 2, Equipment = 3 }
IconDataProviderMixin = {}
function IconDataProviderMixin:Init()
    self.icons = { QUESTION_PATH, 600001, "INTERFACE\\ICONS\\Spell_Fire_Fireball", "INTERFACE\\ICONS\\Spell_Frost_Bolt",
        600002 }
end
function IconDataProviderMixin:SetIconTypes() end
function IconDataProviderMixin:GetNumIcons() return #self.icons end
function IconDataProviderMixin:GetIconByIndex(i) return self.icons[i] end
function IconDataProviderMixin:GetIndexOfIcon(icon)
    if icon == 134400 then return 1 end
    for i, other in ipairs(self.icons) do
        if other == icon then return i end
    end
end
function IconDataProviderMixin:Release() W.released = (W.released or 0) + 1 end
function CreateAndInitFromMixin(mixin, ...)
    local made = setmetatable({}, { __index = mixin })
    made:Init(...)
    return made
end
function GenerateClosure(fn, first) return function(...) return fn(first, ...) end end
IconSelectorPopupFrameTemplateMixin = {
    OnShow = function() end,
    OnHide = function() end,
    OkayButton_OnClick = function(self) self:Hide() end,
    CancelButton_OnClick = function(self) self:Hide() end,
    SetIconFilter = function() end,
    GetIconByIndex = function(self, i) return self.iconDataProvider:GetIconByIndex(i) end,
    GetIndexOfIcon = function(self, icon) return self.iconDataProvider:GetIndexOfIcon(icon) end,
    GetNumIcons = function(self) return self.iconDataProvider:GetNumIcons() end,
    SetSelectedIconText = function() end,
    ReevaluateSelectedIcon = function() end,
}
local function iconWindow(f)
    for k, v in pairs(IconSelectorPopupFrameTemplateMixin) do f[k] = v end
    -- as the client: a texture set by path reads back as its number
    local chosen = {
        SetIconTexture = function(self, v) self.v = v == QUESTION_PATH and 134400 or v end,
        GetIconTexture = function(self) return self.v end,
    }
    f.BorderBox = { EditBoxHeaderText = region(), OkayButton = region(), CancelButton = region(),
        IconSelectorEditBox = region(), SelectedIconArea = { SelectedIconButton = chosen } }
    f.IconSelector = {
        SetSelectedCallback = function(self, fn) self.picked = fn end,
        SetSelectedIndex = function(self, i) self.index = i end,
        GetSelectedIndex = function(self) return self.index end,
        SetSelectionsDataProvider = function(self, get, num) self.get, self.num = get, num end,
        ScrollToSelectedIndex = noop,
        UpdateSelections = function(self) self.updates = (self.updates or 0) + 1 end,
        -- the list can be moved and sized, as any frame
        ClearAllPoints = function(self) self.point = nil end,
        SetPoint = function(self, ...) self.point = { ... } end,
        SetHeight = function(self, h) self.height = h end,
        GetFrameLevel = function() return 2 end,
    }
end

function CreateFrame(otype, name, parent, template)
    local protected = template ~= nil and template:find("Secure") ~= nil
    local f = setmetatable({ name = name, scripts = {}, attrs = {}, shown = true, otype = otype, parent = parent,
        protected = protected, template = template }, Frame)
    if template == "IconSelectorPopupFrameTemplate" then iconWindow(f) end
    -- the game's flat panel: its title is a text of its own in the bar at its top
    if template == "DefaultPanelFlatTemplate" then f.TitleContainer = { TitleText = region() } end
    -- the game's icon button of its selector lists: an icon and a mark for the one picked
    if template == "SelectorButtonTemplate" then
        f.Icon, f.SelectedTexture = f:CreateTexture(), f:CreateTexture()
        f.SelectedTexture:Hide()
        f.SetIconTexture = function(self, v) self.Icon:SetTexture(v) end
        f.GetIconTexture = function(self) return self.Icon.texture end
    end
    if name then W.frames[name] = f; _G[name] = f end
    W.all[#W.all + 1] = f
    return f
end
function EnumerateFrames(prev)
    if not prev then return W.all[1] end
    for i, f in ipairs(W.all) do
        if f == prev then return W.all[i + 1] end
    end
end

DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) W.chat[#W.chat + 1] = msg end }
UIErrorsFrame = { AddMessage = function(_, msg) W.errors[#W.errors + 1] = msg end }
function GetTime() return W.clock end
function InCombatLockdown() return W.combat end
-- the game's own tie between a scroll frame and its bar (ScrollUtil.lua)
ScrollUtil = { InitScrollFrameWithScrollBar = function(scroll, bar) scroll.bar, bar.scrolls = bar, scroll end }
C_Timer = {
    After = function(_, fn) W.queue[#W.queue + 1] = fn end,
    NewTicker = function(_, fn) W.ticker = fn end,
}
local function flush()
    local q = W.queue
    W.queue = {}
    W.clock = W.clock + 10
    for _, fn in ipairs(q) do fn() end
    -- a run that asks for it has the once-a-second ticker pass with the time
    if PUMP_TICKER and W.ticker then W.ticker() end
    -- drawn frames between timers: a third of a second of them
    for _ = 1, 6 do
        for _, f in ipairs(W.all) do
            if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.05) end
        end
    end
end
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    IsOwned = function(self, owner) return self.owner == owner end,
    Hide = function(self) self.owner = nil end,
    SetText = noop, AddLine = noop, Show = noop, SetItemByID = noop,
    -- the spell asked for, and whether its rank was asked for with it
    SetSpellByID = function(_, id, _, subtext) W.tip = { id = id, rank = subtext == true } end,
}
-- The game's button frame art, by its own size: a ring of 46 by 45, alone
-- on a bar, or in a 51 square with its shadow for a button off the bars.
local ART_SIZE = {
    ["UI-HUD-ActionBar-IconFrame"] = { 46, 45 }, ["UI-HUD-ActionBar-IconFrame-Down"] = { 46, 45 },
    ["UI-HUD-ActionBar-IconFrame-AddRow"] = { 51, 51 }, ["UI-HUD-ActionBar-IconFrame-AddRow-Down"] = { 51, 51 },
    ["UI-HUD-ActionBar-IconFrame-Mouseover"] = { 46, 45 }, ["UI-HUD-ActionBar-IconFrame-Background"] = { 46, 45 },
    ["common-mask-circle"] = { 256, 256 },
}
RING_W, RING_H = 46, 45
-- the gray the game's bar buttons show a key in; the key font's own is 0.6
ACTIONBAR_HOTKEY_FONT_COLOR = { GetRGB = function() return 0.8, 0.8, 0.8 end }
C_Texture = { GetAtlasInfo = function(atlas)
    if W.noArt == atlas then return nil end
    local size = ART_SIZE[atlas]
    return size and { width = size[1], height = size[2] } or {}
end }
local function flushAll()
    for _ = 1, 400 do
        if #W.queue == 0 then return end
        flush()
    end
    error("timers never ran dry")
end
-- The macro list as the game keeps it: by place, in name order, names shared freely. W.macros: name to
-- icon and text, for macros with a name of their own; W.shared: more macros, each { name, icon, text },
-- which may share a name. With neither set, any macro asked for by name exists.
local function macroList()
    local out = {}
    for name, m in pairs(W.macros or {}) do out[#out + 1] = { name = name, icon = m[1], body = m[2], own = m, order = 0 } end
    for i, m in ipairs(W.shared or {}) do out[#out + 1] = { name = m[1], icon = m[2], body = m[3], own = m, order = i } end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.order < b.order
    end)
    return out
end
local function macroAt(x)
    local list = macroList()
    if type(x) == "number" then return list[x], x end
    for i, m in ipairs(list) do
        if m.name == x then return m, i end
    end
end
local function macroPlace(own)
    for i, m in ipairs(macroList()) do
        if m.own == own then return i end
    end
end
function GetCursorInfo()
    local c = W.cursor
    if not c then return end
    -- a carried macro is known by its place in the list
    if c[1] == "macro" and c.own then return "macro", macroPlace(c.own) end
    return c[1], c[2], c[3], c[4], c[5]
end
function ClearCursor()
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
end
-- A controller: W.pad is the one plugged in, nil for none. Plugged in is not
-- in use: W.padInUse is the game's own word on which input is in use.
C_GamePad = {
    GetActiveDeviceID = function() return W.pad end,
    GetDeviceMappedState = function() return { labelStyle = "Letters" } end,
    IsEnabled = function() return W.padOff ~= true end,
}
function IsBindingForGamePad(key) return type(key) == "string" and key:find("PAD", 1, true) ~= nil end
-- a command's keys, those of the input in use first: what the game's bars show
function GetBindingKey(command)
    local first, rest = {}, {}
    for key, action in pairs(W.base) do
        if action == command then
            local list = IsBindingForGamePad(key) == (W.padInUse == true) and first or rest
            list[#list + 1] = key
        end
    end
    table.sort(first)
    table.sort(rest)
    for _, key in ipairs(rest) do first[#first + 1] = key end
    return table.unpack(first)
end
-- every command the game knows: ours come from Bindings.xml, bound or not
local DEFINED = {}
do
    local file = io.open("Bindings.xml")
    if file then
        -- a row marked hidden is a command like any other, and no row of the key menu
        for row in file:read("a"):gmatch("<Binding [^>]+>") do
            if not row:find('hidden="true"', 1, true) then DEFINED[#DEFINED + 1] = row:match('name="([%w_]+)"') end
        end
        file:close()
    end
end
local function commands()
    local seen, out = {}, {}
    for _, action in ipairs(DEFINED) do
        seen[action] = true
        out[#out + 1] = action
    end
    for _, action in pairs(W.base) do
        if not seen[action] then
            seen[action] = true
            out[#out + 1] = action
        end
    end
    table.sort(out)
    return out
end
function GetNumBindings() return #commands() end
-- a command and its heading, as the key menu lists it; ours are the rows of Bindings.xml
function GetBinding(n)
    local command = commands()[n]
    return command, command and command:find("^FALLENSFLYOUTS_") and "BINDING_HEADER_FALLENSFLYOUTS" or nil
end
-- a key given to a command by code, as the key menu gives it
function SetBinding(key, command)
    W.base[key] = command
    fire("UPDATE_BINDINGS")
    return true
end
-- a pad button comes back as its symbol, any other key shortened
function GetBindingText(key)
    if key:find("PAD", 1, true) then return "|A:Gamepad_Gen_" .. key .. ":14:14|a" end
    return (key:gsub("SHIFT%-", "s-"):gsub("CTRL%-", "c-"):gsub("ALT%-", "a-"))
end
KEY_ABBR_PADDUP_LTR = "|A:Gamepad_Ltr_Up:14:14|a"
-- a key with no symbol of its own: the game hands back words
KEY_ABBR_PAD3_LTR = "X button"
-- a character's own bars: swap trades slots 1 and 2, shift gives it other spells
local function own(slot)
    if char.swap and slot <= 2 then return 3 - slot end
    return slot
end
-- a slot holds its bar's own spell unless something was placed on it by hand (W.placed)
function HasAction(slot)
    local placed = W.placed and W.placed[slot]
    if placed ~= nil then return placed ~= false end
    return (slot >= 1 and slot <= 3) or (slot >= 13 and slot <= 15)
end
function GetActionInfo(slot)
    local placed = W.placed and W.placed[slot]
    -- a macro: its place in the list, and no word on what it stands for (seen on Forever: "macro", 6, "")
    if type(placed) == "table" then
        local place = placed.own and macroPlace(placed.own)
        if not place and (W.macros or W.shared) then place = select(2, macroAt(placed[2])) end
        return placed[1], place or 1, ""
    end
    if placed then return "spell", placed, "spell" end
    if placed == false or not HasAction(slot) then return nil end
    return "spell", 100 + own(slot) + (char.shift or 0), "spell"
end
-- the cursor's spell goes onto the slot; what the slot held comes onto the cursor
function PlaceAction(slot)
    local carried = W.cursor
    if not (carried and (carried[1] == "spell" or carried[1] == "macro")) then return end
    local kind, had = GetActionInfo(slot)
    local name = GetActionText(slot)
    W.placed = W.placed or {}
    local was = W.placed[slot]
    if carried[1] == "macro" then
        W.placed[slot] = { "macro", carried[2], own = carried.own }
    else
        W.placed[slot] = carried[4]
    end
    if kind == "macro" then
        W.cursor = { "macro", name, own = type(was) == "table" and was.own or nil }
    else
        W.cursor = had and { "spell", 7, "spell", had, had } or nil
    end
    fire("ACTIONBAR_SLOT_CHANGED", slot)
    -- the cursor left empty, the bars' empty slots hide again
    if not W.cursor then fire("ACTIONBAR_HIDEGRID") end
end
-- what a slot holds comes onto the cursor and the slot is left empty
function PickupAction(slot)
    local kind, had = GetActionInfo(slot)
    if not kind then return end
    local name = GetActionText(slot)
    local was = W.placed and W.placed[slot]
    W.placed = W.placed or {}
    W.placed[slot] = false
    if kind == "macro" then
        W.cursor = { "macro", name, own = type(was) == "table" and was.own or nil }
    else
        W.cursor = { "spell", 7, "spell", had, had }
    end
    fire("ACTIONBAR_SLOT_CHANGED", slot)
end
-- a call runs after another's, as the client lets an addon listen in
function hooksecurefunc(holder, name, after)
    local first = holder[name]
    holder[name] = function(...)
        local out = { first(...) }
        after(...)
        return table.unpack(out)
    end
end
-- a slot's icon: a macro's own, a spell's
function GetActionTexture(slot)
    local placed = W.placed and W.placed[slot]
    if type(placed) == "table" then
        local place = placed.own and macroPlace(placed.own)
        local m = macroAt(place or placed[2])
        return m and m.icon or 1234
    end
    local kind, id = GetActionInfo(slot)
    if kind == "spell" then return id end
end
-- a macro on a slot is known to the bars by its name
function GetActionText(slot)
    local placed = W.placed and W.placed[slot]
    return type(placed) == "table" and placed[2] or nil
end
-- W.macroSpell: the spell the game names for a macro just now, by the macro's text; with none set, no macro
-- stands for a spell
function GetMacroSpell(x)
    if not W.macroSpell then return nil end
    local m = macroAt(x)
    return m and W.macroSpell[m.body] or nil
end
-- a macro by its place in the list or by its name (the first of that name)
function GetMacroInfo(x)
    if W.macros or W.shared then
        local m = macroAt(x)
        if m then return m.name, m.icon, m.body end
        return nil
    end
    return "Macro" .. tostring(x), 1234
end
function GetNumMacros()
    if W.macros or W.shared then return #macroList(), 0 end
    return 0, 0
end
function CreateMacro(name, icon, body)
    assert(not W.combat, "CreateMacro in a fight")
    if W.macroFull then error("the macro list is full") end
    W.macros = W.macros or {}
    local own = { icon, body }
    if W.macros[name] or macroAt(name) then
        -- a second macro of a name: the game makes it all the same
        W.shared = W.shared or {}
        own = { name, icon, body }
        W.shared[#W.shared + 1] = own
    else
        W.macros[name] = own
    end
    W.macroCount = (W.macroCount or 0) + 1
    fire("UPDATE_MACROS")
    return macroPlace(own)
end
function DeleteMacro(x)
    local m = macroAt(x)
    if not m then return end
    if W.macros and W.macros[m.name] == m.own then
        W.macros[m.name] = nil
    else
        for i, own in ipairs(W.shared or {}) do
            if own == m.own then
                table.remove(W.shared, i)
                break
            end
        end
    end
    fire("UPDATE_MACROS")
end
function UnitLevel() return W.level or 10 end
-- W.bags: the items in the bags, one stack each; W.items: what the game knows of an item
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #(W.bags or {}) or 0 end,
    GetContainerItemID = function(bag, slot) return bag == 0 and (W.bags or {})[slot] or nil end,
}
C_Spell = {
    PickupSpell = function(id) W.cursor = { "spell", 7, "spell", id, id } end,
    -- W.helpful, W.harmful: the spells that are for friends, for foes; one in neither is for anyone
    IsSpellHelpful = function(id) return W.helpful ~= nil and W.helpful[id] == true end,
    -- W.uses: a spell's charges or uses; the client answers in words, a star past the most asked for
    GetSpellDisplayCount = function(id, most, over)
        local n = W.uses and W.uses[id]
        if not n then return "" end
        return n > (most or 9999) and (over or "*") or tostring(n)
    end,
    IsSpellHarmful = function(id) return W.harmful ~= nil and W.harmful[id] == true end,
    GetSpellTexture = function(id) return id end,
    -- W.ranks: spells that are ranks of one spell, id to its name and rank
    GetSpellName = function(id)
        local ranked = W.ranks and W.ranks[id]
        return ranked and ranked[1] or ("Spell " .. id)
    end,
    GetSpellSubtext = function(id)
        local ranked = W.ranks and W.ranks[id]
        return ranked and ranked[2] and ("Rank " .. ranked[2]) or ""
    end,
    -- a spell's own cooldown, else the global one, else none
    GetSpellCooldown = function(id)
        return W.cooling[id] or W.gcd or { startTime = 0, duration = 0, isActive = false, modRate = 1 }
    end,
    IsSpellUsable = function(id)
        assert(not W.breakDrawing, "TEST: drawing breaks")
        return not (W.short[id] or W.unusable[id]), W.short[id] or false
    end,
}
-- plain numbers inside, never read by the addon
function C_Spell.GetSpellCooldownDuration(id)
    local info = W.cooling[id] or W.gcd
    if not info then return { start = 0, duration = 0, active = false } end
    return { start = info.startTime, duration = info.duration, active = true }
end
C_Item = {
    IsHelpfulItem = function(id) return W.helpful ~= nil and W.helpful[id] == true end,
    IsHarmfulItem = function(id) return W.harmful ~= nil and W.harmful[id] == true end,
    GetItemIconByID = function(id) return id end,
    GetItemNameByID = function(id) return "Item " .. id end,
    GetItemCooldown = function() return 0, 0, 1 end,
    -- with bags set, an item not in them is one the player has none of
    -- W.counts: how many of an item there are; W.stacks: how many go in one stack (1: it does not stack)
    IsConsumableItem = function(id) return W.items ~= nil and W.items[id] ~= nil end,
    GetItemMaxStackSizeByID = function(id) return W.stacks and W.stacks[id] or 1 end,
    GetItemCount = function(id)
        if W.counts and W.counts[id] ~= nil then return W.counts[id] end
        if not W.bags then return 1 end
        for _, held in ipairs(W.bags) do
            if held == id then return 1 end
        end
        return 0
    end,
    -- class 0 is a consumable; its kind is the item's `sub` (5 food and drink, 1 potion, 2 elixir)
    GetItemInfoInstant = function(id)
        local item = W.items and W.items[id]
        if not item then return id, "Miscellaneous", "Junk", "", id, 15, 0 end
        return id, "Consumable", "Kind", "", id, 0, item.sub
    end,
    -- name, link, quality, level, the level it needs; nothing while the game has no word on it
    GetItemInfo = function(id)
        local item = W.items and W.items[id]
        if not item or item.unknown then return nil end
        return "Item " .. id, "link", 1, item.level or 1, item.needs or 1
    end,
    -- what using it casts: eating is spell 433, drinking 430
    GetItemSpell = function(id)
        local item = W.items and W.items[id]
        if not item or item.unknown then return nil end
        if item.sub ~= 5 then return "Use", 9000 end
        if item.drink then return "Drink", 430 end
        return "Food", 433
    end,
    IsUsableItem = function() return true, false end,
}
-- the game's controller cursor and its Options window, as far as the page leans on them
SettingsPanel = { Container = { SettingsList = {} } }
SmartNavigation = { UpdateParent = function(_, frame) W.cursorRead = frame end }
function SmartNavigation_MarkFrameIgnored(frame) frame.smartNavigationIgnored = true end
function SmartNavigation_ClearIgnoreStatus(frame) frame.smartNavigationIgnored = nil end
-- picking up: the bars' lock, the pick up key, and what lands on the cursor
Settings = { GetValue = function(name) return name == "lockActionBars" and W.locked == true end }
-- the unit under the mouse, where a test puts one there
function UnitExists(unit) return unit == "player" or (unit == "mouseover" and W.mouseover ~= nil) end
-- the keys the game's modified clicks want: Mouseover Cast wants none unless a test sets one
function IsModifiedClick(what)
    if what == "PICKUPACTION" then return W.shift == true end
    return W.modHeld ~= nil and W.modHeld[what] == true
end
function GetModifiedClick(what)
    if W.modKeys and W.modKeys[what] then return W.modKeys[what] end
    if what == "MOUSEOVERCAST" then return "NONE" end
    return "SHIFT"
end
function C_Spell.PickupSpell(id)
    W.cursor = { "spell", 0, "spell", id, id }
    fire("ACTIONBAR_SHOWGRID")
end
function C_Item.PickupItem(id)
    W.cursor = { "item", id }
    fire("ACTIONBAR_SHOWGRID")
end
function PickupMacro(x)
    local m = (W.macros or W.shared) and macroAt(x) or nil
    W.cursor = { "macro", m and m.name or x, own = m and m.own or nil }
    fire("ACTIONBAR_SHOWGRID")
end
C_CVar = { GetCVar = function(name)
    if W.cvars and W.cvars[name] ~= nil then return W.cvars[name] end
    return "1"
end }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
function IsKeyDown(key) return W.keyDown[key] or false end
function IsMouseButtonDown() return W.mouseDown == true end
function GetCursorPosition() return W.mouseX or 0, W.mouseY or 0 end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(line) return { itemIndexOffset = (line - 1) * 4, numSpellBookItems = 4 } end,
    GetSpellBookItemInfo = function(slot)
        return { itemType = 1, spellID = 600 + slot, isPassive = slot % 4 == 0, name = "Spell " .. (600 + slot),
            iconID = 600 + slot }
    end,
    PickupSpellBookItem = function(slot)
        W.cursor = { "spell", slot, "spell", 600 + slot, 600 + slot }
        fire("ACTIONBAR_SHOWGRID")
    end,
}
C_AddOns = {
    IsAddOnLoaded = function(name) return W.loaded[name] or false end,
    DoesAddOnExist = function(name) return installed[name] or false end,
    -- The client knows a character here by its GUID alone, as its own addon list passes it. Given
    -- a name it reads every installed addon as on and switches nothing (his client, 2026-11-21).
    GetAddOnEnableState = function(name, character)
        if character ~= char.guid then return installed[name] and 2 or 0 end
        return enabled[name] and 2 or 0
    end,
    EnableAddOn = function(name, character) if character == char.guid then enabled[name] = true end end,
    DisableAddOn = function(name, character) if character == char.guid then enabled[name] = false end end,
}
function GetBuildInfo() return "12.0.0", "70009", "Nov 1 2026", 16001 end
function UnitClass() return char.class, char.class end
function UnitName() return "Tester", "Surname" end
function GetUnitName() return char.name end
function UnitGUID() return char.guid end
function GetRealmName() return "Realm" end
function GetActionBarToggles() return true, false, false, false end
function GetBindingAction(key, withOverrides)
    if withOverrides then
        local best
        for _, set in pairs(W.overrides) do
            local o = set[key]
            if o and (not best or (o.priority and not best.priority) or (o.priority == best.priority and o.seq > best.seq)) then
                best = o
            end
        end
        if best then return best.action end
    end
    return W.base[key] or ""
end
function SetOverrideBindingClick(owner, priority, key, name, button) owner:SetBindingClick(priority, key, name, button) end
function ClearOverrideBindings(owner) W.overrides[owner] = {} end
StaticPopupDialogs = {}
function StaticPopup_Show(which, text)
    W.popup = { which = which, text = text }
    local dialog = StaticPopupDialogs[which]
    if dialog and dialog.OnShow then dialog.OnShow(region(), nil) end
end
function StaticPopup_Hide(which)
    local dialog = StaticPopupDialogs[which]
    if W.popup and W.popup.which == which then W.popup = nil end
    if dialog and dialog.OnHide then dialog.OnHide(region()) end
end
DONE = "Done"
-- the game's Quick Keybind Mode, and the modifiers held
function KeybindFrames_InQuickKeybindMode() return W.quick == true end
-- its window takes every key in that mode; a key that only goes with another is no binding
function IsKeyPressIgnoredForBinding(key) return key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" end
function IsShiftKeyDown() return W.shiftKey == true end
function IsControlKeyDown() return W.ctrlKey == true end
function IsAltKeyDown() return W.altKey == true end
function ReloadUI() wantReload = true end

local function actionButton(name, slot, parent)
    local b = CreateFrame("CheckButton", name, parent, "ActionBarButtonTemplate, SecureActionButtonTemplate")
    b.attrs.type, b.attrs.action, b.action = "action", slot, slot
    return b
end

-- the files the addon's toc lists, in its order
local function tocFiles()
    local files = {}
    for line in io.lines("FallensFlyouts.toc") do
        line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end

-- a new session: the bars, then the addon (and a driver, when a test names one) and a login
local unplaced = false
local function boot(alone)
    -- the last session's frames are gone
    for name in pairs(W and W.frames or {}) do _G[name] = nil end
    W = { frames = {}, all = {}, overrides = {}, queue = {}, casts = {}, chat = {}, errors = {}, keyDown = {}, held = {},
        base = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "ACTIONBUTTON3", ESCAPE = "TOGGLEGAMEMENU",
            E = "ACTIONBUTTON1", Q = "ACTIONBUTTON2" },
        seq = 0, clock = 0, combat = false, loaded = {}, cooling = {}, short = {}, unusable = {}, caught = {} }
    W.base["CTRL-6"] = "ACTIONBUTTON1"
    -- as the game's defaults: one command with a key and a pad button both
    W.base.SPACE, W.base.PAD1 = "JUMP", "JUMP"
    for name, on in pairs(enabled) do W.loaded[name] = on and installed[name] or false end
    wantReload = false
    SlashCmdList = {}
    UIParent = CreateFrame("Frame", "UIParent")
    -- the game's Quick Keybind window: it has its own handlers for every key
    local quickFrame = CreateFrame("Button", "QuickKeybindFrame", UIParent)
    quickFrame.scripts.OnKeyDown, quickFrame.scripts.OnGamePadButtonDown = noop, noop
    UIParent.w, UIParent.h = 1920, 1080
    local kind = barWorld()
    local other = kind ~= "game"
    local main = CreateFrame("Frame", "MainActionBar", UIParent)
    main.raises = true
    main.w, main.h = 500, 40
    main.shown = not other
    -- not placed yet, as at a login before the UI addon has moved its bars
    if unplaced then main.w, main.h = 40, 500 end
    for i = 1, 12 do actionButton("ActionButton" .. i, i, main) end
    if kind == "helper" then
        local bar = CreateFrame("Frame", "SideBarFrame2", UIParent)
        bar.w, bar.h = 500, 40
        for i = 13, 15 do
            local name = "SideBarButton" .. i
            local b = actionButton(name, i, bar)
            b.attrs.commandName = "CLICK " .. name .. ":HOTKEY"
            local hot = CreateFrame("Button", name .. "Hotkey", b, "SecureActionButtonTemplate")
            hot.attrs.type = "action"
            W.base["F" .. (i - 12)] = "CLICK " .. name .. ":HOTKEY"
            setOverride(hot, false, "F" .. (i - 12), "CLICK " .. name .. "Hotkey:HOTKEY")
        end
    end
    if kind == "own" then
        local bar = CreateFrame("Frame", "OwnBar1", UIParent)
        bar.w, bar.h = 40, 500
        for i = 1, 3 do
            local b = actionButton("OwnBarButton" .. i, i, bar)
            b.cx, b.cy = 1880, 300 + i * 40
            setOverride(bar, false, tostring(i), "CLICK OwnBarButton" .. i .. ":Keybind")
        end
    end
    -- one snippet world per session, as the client keeps per header
    -- what the game lets a secure snippet ask: the unit under the mouse (W.mouseover: "friend", "foe" or
    -- "other"), whether the player can help or attack it, and whether a modified click's key is held
    local asks = {
        UnitExists = function(unit) return unit == "mouseover" and W.mouseover ~= nil end,
        PlayerCanAssist = function(unit) return unit == "mouseover" and W.mouseover == "friend" end,
        PlayerCanAttack = function(unit) return unit == "mouseover" and W.mouseover == "foe" end,
        IsModifiedClick = function(what) return IsModifiedClick(what) end,
        strmatch = string.match,
    }
    W.env = setmetatable({}, { __index = function(t, k)
        if k == "armed" or k == "held" or k == "picked" or k == "own" then return rawget(t, k) end
        if asks[k] then return asks[k] end
        error("snippet read of a missing global: " .. tostring(k))
    end })
    NS = {}
    for _, file in ipairs(tocFiles()) do
        assert(loadfile(file))("FallensFlyouts", NS)
    end
    -- alone: the dev folder is off, as for anyone who downloads the addon
    if DRIVER and not alone then assert(loadfile(DRIVER))() end
    -- a test's to set: what another addon registers ahead of the login
    if type(BEFORE_LOGIN) == "function" then BEFORE_LOGIN() end
    fire("PLAYER_LOGIN")
end

local function click(frame, down, button)
    button = button or "LeftButton"
    if not frame.wrap then
        -- a plain button of an addon's runs its own click: on the press when it listens for presses
        if frame.scripts.OnClick and not frame.attrs.type then
            if down == (frame.clicksOnPress == true) then frame.scripts.OnClick(frame, button, down) end
            return
        end
        if down then W.casts[#W.casts + 1] = "bar:" .. frame.name end
        return
    end
    local fn = assert(load("local self, button, down, owner = ...; " .. frame.wrap, frame.name, "t", W.env))
    local verdict = fn(frame, button, down, frame.header)
    -- as the client's secure button: it acts on the press, or on the release when told not to
    local onPress = frame.attrs.useOnKeyDown ~= false
    local cast = verdict ~= false and frame.attrs.type and down == onPress
    if cast then
        -- as the game's secure button picks its unit: the one it was told, else the focus when that key is held
        local unit = frame.attrs.unit
        if not unit and frame.attrs.checkfocuscast and IsModifiedClick("FOCUSCAST") then unit = "focus" end
        W.casts[#W.casts + 1] = frame.attrs.type .. ":" .. tostring(frame.attrs[frame.attrs.type]) .. (unit and ("@" .. unit) or "")
    end
    if frame.scripts.PostClick then frame.scripts.PostClick(frame, button, down) end
    if cast then fire("UNIT_SPELLCAST_SENT", "player", "", "", 1) end
end
-- the client refuses a wrapped click made by addon code (proven on build 70959, 2026-11-20)
function Frame:Click(_, down)
    if self.wrap then error("Invalid 'header' frame handle") end
    click(self, down)
end
function Frame:Execute(body)
    assert(not W.combat, "Execute in a fight")
    assert(load("local self = ...; " .. body, "execute", "t", W.env))(self)
end

-- the frame a key clicks, its binding, and the click's own name
local function target(key)
    local action = GetBindingAction(key, true)
    local name, how = action:match("^CLICK (.-):(.*)$")
    return name and W.frames[name], action, how
end
local function press(key)
    local frame, action, how = target(key)
    W.held[key] = { frame, how }
    W.keyDown[key] = true
    if frame then click(frame, true, how) elseif action ~= "" then W.casts[#W.casts + 1] = "bar:" .. action end
end
local function release(key)
    local frame, how
    if MODEL == "captured" then
        frame, how = W.held[key][1], W.held[key][2]
    else
        local _
        frame, _, how = target(key)
    end
    W.held[key] = nil
    W.keyDown[key] = nil
    if frame then click(frame, false, how) end
end
local function tap(key) press(key); release(key) end
local function rightClick(frame) click(frame, true, "RightButton"); click(frame, false, "RightButton") end
local function tabOf(host)
    for _, f in ipairs(W.all) do
        if f.host == host then return f end
    end
end
local function acceptPopup()
    local p = W.popup
    assert(p, "no popup to accept")
    W.popup = nil
    StaticPopupDialogs[p.which].OnAccept()
    return p.text
end
local function lastChat(pattern)
    for i = #W.chat, 1, -1 do
        if W.chat[i]:find(pattern) then return W.chat[i] end
    end
end
local function allPass(lines, label)
    local n, bad = 0, 0
    for _, line in ipairs(lines) do
        if not label or line:find("[" .. label .. "]", 1, true) then
            n = n + 1
            if not line:find("PASS ", 1, true) then
                bad = bad + 1
                print("    " .. line)
            end
        end
    end
    return n, bad
end
-- the flyout a key opens, by its number
local function opener(key)
    local f = GetBindingAction(key, true):match("^CLICK FallensFlyoutsOpener(%d+):")
    return f and tonumber(f)
end
local function opens(key) return opener(key) ~= nil end
local function root() return W.frames.FallensFlyoutsRoot end
local function menuOf(f) return W.frames["FallensFlyoutsMenu" .. f] end
local function entry(f, i) return W.frames["FallensFlyoutsEntry" .. tostring(f) .. "_" .. i] end
local function count(f) return root().attrs["count" .. tostring(f)] end
local function stack(host, id)
    W.cursor = { "spell", 7, "spell", id, id }
    fire("ACTIONBAR_SHOWGRID")
    local tab = tabOf(host)
    tab.scripts.OnReceiveDrag(tab)
    flushAll()
end
local function testProfiles()
    local n = 0
    for name in pairs(FallensFlyoutsDB.profiles) do
        if name:find("TEST", 1, true) then n = n + 1 end
    end
    return n
end
local function login(guid, class, bars)
    char.guid, char.class, char.name = guid, class or "MAGE", "Tester " .. guid:sub(-1)
    char.swap, char.shift = bars == "swap", bars == "shift" and 50 or nil
    boot()
    flushAll()
end
-- a pick from the Profiles page's own drop down
local function pick(label)
    NS.ProfileUI.Build()
    NS.ProfileUI.Refresh()
    for _, row in ipairs(NS.ProfileUI.panel.dropdown.rows) do
        if row.label == label then
            row.pick()
            flushAll()
            return true
        end
    end
    return false
end
local function reads() return NS.ProfileUI.panel.dropdown.Text:GetText() end
-- the spell a key's flyout holds second
local function second(key)
    local f = opener(key)
    return f and entry(f, 2).attrs.spell
end
local function way(key)
    local units = NS.Flyouts.Units()
    return units[opener(key)].way
end
