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
for _, m in ipairs({ "ClearAllPoints", "RegisterForClicks", "EnableMouse", "SetWordWrap", "LockHighlight",
    "UnlockHighlight", "SetNormalFontObject",
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
function Frame:UnregisterEvent(event) if self.events then self.events[event] = nil end end
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
-- A frame's anchors: every one set since they were last cleared (points), and the last of them (point).
function Frame:SetPoint(...)
    self.point = { ... }
    self.points = self.points or {}
    self.points[#self.points + 1] = self.point
end
function Frame:ClearAllPoints() self.points = {} end
function Frame:GetPoint()
    if self.point then return table.unpack(self.point) end
end
function Frame:GetAlpha() return self.alpha or 1 end
-- as the client: a frame's alpha times its parents'
function Frame:GetEffectiveAlpha() return (self.alpha or 1) * (self.parent and self.parent:GetEffectiveAlpha() or 1) end
function Frame:GetLeft() return self.rect and self.rect[1] end
function Frame:GetRight() return self.rect and self.rect[2] end
function Frame:GetTop() return self.rect and self.rect[3] end
-- a text's lettering, and the most letters a box takes
function Frame:GetObjectType() return self.otype or "Region" end
-- a button lit or put out
function Frame:Enable() self.off = false end
function Frame:Disable() self.off = true end
function Frame:SetFontObject(v) self.font = v end
function Frame:GetFontObject() return self.font end
function Frame:SetMaxLetters(n) self.maxLetters = n end
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
-- whether the mouse reaches it: a frame it does not reach lets clicks and drops through to what is under it
function Frame:EnableMouse(v) self.mouse = v end
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
-- a texture's color as it was last set, full color until then; and whether it is drawn in gray
function Frame:GetVertexColor()
    local c = self.color
    if not c then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], 1
end
function Frame:SetDesaturated(v) self.gray = v == true end
function Frame:IsDesaturated() return self.gray == true end
-- a slider tells its script each value it is given
function Frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
function Frame:SetValue(v)
    self.value = v
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v, false) end
end
function Frame:GetValue() return self.value end
-- a typing box: one holds the focus at a time, and a hidden one cannot
function Frame:SetFocus() W.focus = self end
function Frame:HasFocus() return W.focus == self end
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
    local boxes, ticked = false, {}
    drop.fill(drop, { CreateRadio = function(_, label, isOn, pick, data)
        drop.rows[#drop.rows + 1] = { label = label, pick = function() pick(data) end }
        if isOn(data) then drop.Text:SetText(label) end
    end,
    -- a box to tick: any number may be ticked, and the drop down reads what is, or its own words
    CreateCheckbox = function(_, label, isOn, pick, data)
        boxes = true
        drop.rows[#drop.rows + 1] = { label = label, box = true, on = function() return isOn(data) == true end,
            pick = function() pick(data) end }
        if isOn(data) then ticked[#ticked + 1] = label end
    end })
    if boxes then drop.Text:SetText(#ticked > 0 and table.concat(ticked, ", ") or drop.defaultText or "") end
end
function Frame:SetDefaultText(text) self.defaultText = text end
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
    -- a wrap of the frame's OnAttributeChanged: its body runs for any name but one starting "_"
    -- (the client's Wrapped_Attribute)
    local wrapped = self.wraps and self.wraps.OnAttributeChanged
    if wrapped and type(k) == "string" and not k:find("^_") then RunAttributeWrap(self, wrapped, k, v) end
    -- a state handler frame (SecureHandler_StateOnAttributeChanged): its snippet for that state
    local stateid = type(k) == "string" and k:match("^state%-(.+)")
    local onstate = stateid and self.protected and self.attrs["_onstate-" .. stateid]
    if onstate then RunAttributeWrap(self, { before = onstate }, stateid, v) end
end
function Frame:GetAttribute(k) return self.attrs[k] end
-- the game's icon window's parts are told which window they belong to
function Frame:SetIconSelector(owner) self.selector = owner end
-- the mouse area's insets: left, right, top, bottom (a negative one reaches past the frame)
function Frame:SetHitRectInsets(l, r, t, b) self.hit = { l, r, t, b } end
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
-- a click's wrap is run by click(); any other script's is kept under the script's name, with the body
-- the client runs after its own handler
function Frame:WrapScript(frame, script, body, after)
    if script == "OnClick" then
        frame.wrap, frame.header, frame.wrapAfter = body, self, after
        return
    end
    frame.wraps = frame.wraps or {}
    frame.wraps[script] = { before = body, after = after, header = self }
end
-- secure code calls a function of the addon's: that one runs as addon code does
function Frame:CallMethod(name, ...)
    local was = W.secure
    W.secure = false
    local ok, err = pcall(self[name], self, ...)
    W.secure = was
    if not ok then error(err, 0) end
end

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
-- The template's own OnShow and OnHide count the game's icon windows shown (W.iconWindowsShown), as the
-- game's do in a variable every bar button's drag reads: a window of ours that counts makes that count the
-- addon's, and the game then refuses a drag's pickup in a fight.
IconSelectorPopupFrameTemplateMixin = {
    OnShow = function() W.iconWindowsShown = (W.iconWindowsShown or 0) + 1 end,
    OnHide = function() W.iconWindowsShown = (W.iconWindowsShown or 0) - 1 end,
    UpdateStateFromCursorType = function() end,
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
        SetIconSelector = function(self, owner) self.selector = owner end,
    }
    -- as the game's template: the words and the box for a name, the words over the list, the list of kinds
    -- (a frame of the window's own, as in the game: what is made on it is in view while the window is)
    f.BorderBox = region()
    f.BorderBox.parent = f
    for k, v in pairs({ EditBoxHeaderText = region(), OkayButton = region(), CancelButton = region(),
        IconSelectorEditBox = region(), SelectedIconArea = { SelectedIconButton = chosen },
        IconSelectionText = region(), IconTypeDropdown = region() }) do
        f.BorderBox[k] = v
    end
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

-- The game's slider with a stepper at each end (MinimalSliderWithSteppersTemplate, MinimalSlider.lua): Init
-- sets its ends and step and its value, then listens; each value it is moved to is written in its labels
-- by their formatters and told to those registered for it; a stepper moves it one step, not past an end.
MinimalSliderWithSteppersMixin = {
    Event = { OnValueChanged = "OnValueChanged", OnInteractStart = "OnInteractStart", OnInteractEnd = "OnInteractEnd" },
    Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 },
}
function CreateMinimalSliderFormatter(_, value)
    if type(value) == "function" then return value end
    return function(v) return value == nil and v or value end
end
local function minimalSlider(f)
    f.Slider = CreateFrame("Slider", nil, f)
    f.Back, f.Forward = CreateFrame("Button", nil, f), CreateFrame("Button", nil, f)
    f.LeftText, f.RightText = f:CreateFontString(), f:CreateFontString()
    f.Labels = { [1] = f.LeftText, [2] = f.RightText }
    f.callbacks = {}
    function f:RegisterCallback(event, fn, owner) self.callbacks[event] = { fn, owner } end
    function f:Init(value, low, high, steps, formatters)
        self.Slider:SetMinMaxValues(low, high)
        self.step, self.formatters = (high - low) / steps, formatters
        self.Slider.scripts.OnValueChanged = nil
        self.Slider:SetValue(value)
        for id, format in pairs(formatters or {}) do self.Labels[id]:SetText(format(value)) end
        self.Slider.scripts.OnValueChanged = function(_, v)
            for id, format in pairs(self.formatters or {}) do self.Labels[id]:SetText(format(v)) end
            local told = self.callbacks.OnValueChanged
            if told then told[1](told[2], v) end
        end
    end
    function f:SetValue(v) self.Slider:SetValue(v) end
    function f:GetValue() return self.Slider:GetValue() end
    function f:SetEnabled(on)
        self.sliderEnabled = on
        self.Slider:SetEnabled(on)
        self.Back:SetEnabled(on)
        self.Forward:SetEnabled(on)
    end
    function f:IsSliderEnabled() return self.sliderEnabled ~= false end
    f.Back.scripts.OnClick = function()
        f.Slider:SetValue(math.max(f.Slider.low, f.Slider:GetValue() - f.step))
    end
    f.Forward.scripts.OnClick = function()
        f.Slider:SetValue(math.min(f.Slider.high, f.Slider:GetValue() + f.step))
    end
end

function CreateFrame(otype, name, parent, template)
    local protected = template ~= nil and template:find("Secure") ~= nil
    local f = setmetatable({ name = name, scripts = {}, attrs = {}, shown = true, otype = otype, parent = parent,
        protected = protected, template = template }, Frame)
    if template == "IconSelectorPopupFrameTemplate" then iconWindow(f) end
    if template == "MinimalSliderWithSteppersTemplate" then minimalSlider(f) end
    -- the game's search box: a prompt of its own inside it
    if template == "SearchBoxTemplate" then f.Instructions = region() end
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
            if f.scripts.OnUpdate and f:IsVisible() then f.scripts.OnUpdate(f, 0.05) end
        end
    end
end
-- The game's tooltip. SetAction fills it with what a bar slot holds and shows it (tip.action). An addon
-- listening in on that call does so from its load on: here each login loads the addon again, so the
-- listeners of earlier logins listen still, each to its own copy of the addon.
local function setAction(self, slot)
    self.action, self.shown = slot, true
    return HasAction(slot)
end
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    GetOwner = function(self) return self.owner end,
    IsOwned = function(self, owner) return self.owner == owner end,
    IsShown = function(self) return self.shown == true end,
    Hide = function(self) self.owner, self.shown, self.action = nil, false, nil end,
    Show = function(self) self.shown = true end,
    SetAction = setAction,
    -- its lines, each with the color it was given (W.tipLines)
    SetText = function(_, text, r, g, b) W.tipLines = { { text, r, g, b } } end,
    AddLine = function(_, text, r, g, b)
        W.tipLines = W.tipLines or {}
        W.tipLines[#W.tipLines + 1] = { text, r, g, b }
    end,
    -- what the tooltip was asked to show, by which of the game's calls
    SetItemByID = function(_, id) W.tip = { item = id } end,
    SetToyByItemID = function(_, id) W.tip = { toy = id } end,
    SetMountBySpellID = function(_, id) W.tip = { mount = id } end,
    SetCompanionPet = function(_, guid) W.tip = { pet = guid } end,
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
-- the red the game writes a bar key in out of range, and its dot for the range of a button with no key
RED_FONT_COLOR = { GetRGB = function() return 1, 0.1, 0.1 end }
RANGE_INDICATOR = "\226\151\143"
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
    -- a toy, as "item", or a mount, as "summonmount", with its number
    if type(placed) == "table" and placed[1] ~= "macro" then return placed[1], placed[2] end
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
-- Toys and mounts. W.toys: the player's own toys, by number. W.mounts: the player's mounts in the mount
-- journal's list, each { id, spell, name, icon }. As seen on Forever (/ffdev toys, 2026-11-23): the Toy Box
-- puts a toy on the cursor as "item" and its number, the journal a mount as "mount", its number and its
-- place in the list; a bar slot keeps a toy as "item" and a mount as "summonmount", each with its number.
-- The bags hold no toy: W.bags says what they hold.
do
    local function mountBy(field, value)
        for i, m in ipairs(W.mounts or {}) do
            if m[field] == value then return m, i end
        end
    end
    function PlayerHasToy(id) return W.toys ~= nil and W.toys[id] == true end
    C_ToyBox = {
        GetToyInfo = function(id)
            if W.toys and W.toys[id] then return id, "toy " .. id, id end
        end,
        IsToyUsable = function(id) return W.toys ~= nil and W.toys[id] == true and not (W.toyUnusable and W.toyUnusable[id]) end,
        PickupToyBoxItem = function(id)
            if W.toys and W.toys[id] then W.cursor = { "item", id, "link" } end
        end,
    }
    C_MountJournal = {
        GetMountInfoByID = function(id)
            local m = mountBy("id", id)
            if m then return m.name, m.spell, m.icon, false, m.usable ~= false, 0, false, false, nil, false, true, m.id end
        end,
        GetMountFromSpell = function(spell)
            local m = mountBy("spell", spell)
            return m and m.id or nil
        end,
        GetNumDisplayedMounts = function() return #(W.mounts or {}) end,
        GetDisplayedMountInfo = function(i)
            local m = (W.mounts or {})[i]
            if m then return m.name, m.spell, m.icon, false, true, 0, false, false, nil, false, true, m.id, false end
        end,
        Pickup = function(i)
            local m = (W.mounts or {})[i]
            if m then W.cursor = { "mount", m.id, i } end
        end,
    }
    -- W.pets: the player's battle pets, each { guid, name, icon }. The Pet Journal puts one on the cursor as
    -- "battlepet" and its GUID; a bar slot keeps it as "summonpet" and the GUID (seen on his client).
    local function petBy(guid)
        for _, p in ipairs(W.pets or {}) do
            if p.guid == guid then return p end
        end
    end
    C_PetJournal = {
        GetPetInfoByPetID = function(guid)
            local p = petBy(guid)
            if p then return 1, p.custom, 25, 0, 0, 1, false, p.name, p.icon end
        end,
        PetIsSummonable = function(guid) return petBy(guid) ~= nil end,
        GetNumPets = function() return #(W.pets or {}), #(W.pets or {}) end,
        GetPetInfoByIndex = function(i)
            local p = (W.pets or {})[i]
            if p then return p.guid end
        end,
        PickupPet = function(guid)
            if petBy(guid) then W.cursor = { "battlepet", guid } end
        end,
    }
    -- what a slot held, on the cursor as picking it up puts it there
    local function lifted(kind, had, name, was)
        if kind == "macro" then return { "macro", name, own = type(was) == "table" and was.own or nil } end
        if kind == "item" then return { "item", had, "link" } end
        if kind == "summonmount" then return { "mount", had, select(2, mountBy("id", had)) } end
        if kind == "summonpet" then return { "battlepet", had } end
        return had and { "spell", 7, "spell", had, had } or nil
    end
    -- what is carried goes onto the slot; what the slot held comes onto the cursor
    function PlaceAction(slot)
        local carried = W.cursor
        local what = carried and carried[1]
        if not (what == "spell" or what == "macro" or what == "item" or what == "mount" or what == "battlepet") then
            return
        end
        local kind, had = GetActionInfo(slot)
        local name = GetActionText(slot)
        W.placed = W.placed or {}
        local was = W.placed[slot]
        if what == "macro" then
            W.placed[slot] = { "macro", carried[2], own = carried.own }
        elseif what == "item" then
            W.placed[slot] = { "item", carried[2] }
        elseif what == "mount" then
            W.placed[slot] = { "summonmount", carried[2] }
        elseif what == "battlepet" then
            W.placed[slot] = { "summonpet", carried[2] }
        else
            W.placed[slot] = carried[4]
        end
        W.cursor = lifted(kind, had, name, was)
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
        W.cursor = lifted(kind, had, name, was)
        fire("ACTIONBAR_SLOT_CHANGED", slot)
    end
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
    if type(placed) == "table" and placed[1] ~= "macro" then return placed[2] end
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
    return type(placed) == "table" and placed[1] == "macro" and placed[2] or nil
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
-- A macro given a name or an icon: the bar slots that hold it show its new name, as the game's do.
function EditMacro(x, name, icon)
    assert(not W.combat, "EditMacro in a fight")
    local m = macroAt(x)
    if not m then return nil end
    if W.macros and W.macros[m.name] == m.own then
        if name and name ~= m.name then
            W.macros[m.name] = nil
            W.macros[name] = m.own
        end
        if icon then m.own[1] = icon end
    else
        if name then m.own[1] = name end
        if icon then m.own[2] = icon end
    end
    for _, held in pairs(W.placed or {}) do
        if type(held) == "table" and held[1] == "macro" and (held.own == m.own or held[2] == m.name) and name then held[2] = name end
    end
    fire("UPDATE_MACROS")
    return macroPlace(m.own)
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
    -- as the game: a deleted macro is off every bar button that held it
    for slot, held in pairs(W.placed or {}) do
        local same = type(held) == "table" and held[1] == "macro"
            and (held.own == m.own or (held.own == nil and held[2] == m.name))
        if same then
            W.placed[slot] = false
            fire("ACTIONBAR_SLOT_CHANGED", slot)
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
    -- W.target: there is one; W.far: the spells that do not reach it; W.rangeless: those that ask no
    -- range; W.hideRange: a value the client hands out in place of the answer
    IsSpellInRange = function(id, unit)
        assert(unit == "target", "TEST: range asked of " .. tostring(unit))
        if not W.target or (W.rangeless and W.rangeless[id]) then return nil end
        if W.hideRange ~= nil then return W.hideRange end
        return not (W.far and W.far[id])
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
    -- an item's range to the target; in a fight the client keeps this call from addons
    IsItemInRange = function(id, unit)
        assert(not W.combat, "TEST: an item's range asked in a fight")
        assert(unit == "target", "TEST: range asked of " .. tostring(unit))
        if not W.target then return nil end
        return not (W.farItems and W.farItems[id])
    end,
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
        -- one that cannot be used casts nothing
        if item.nouse then return nil end
        if item.sub ~= 5 then return "Use", 9000 end
        if item.drink then return "Drink", 430 end
        return "Food", 433
    end,
    -- a toy is not in the bags: the item calls take it for unusable (seen on his client, /ffdev kinds)
    IsUsableItem = function(id)
        if W.toys and W.toys[id] then return false, false end
        return true, false
    end,
    -- the game's names for its kinds of consumable; one it keeps only for old items says so
    GetItemSubClassInfo = function(class, sub)
        local names = { [0] = "Explosives and Devices", [1] = "Potions", [2] = "Elixirs", [3] = "Flasks", [4] = "Scrolls",
            [5] = "Food & Drink", [6] = "Item Enhancements (OBSOLETE)", [7] = "Bandages", [8] = "Other" }
        if class ~= 0 or not names[sub] then return nil end
        return names[sub], false
    end,
}
-- the game's controller cursor and its Options window, as far as the page leans on them
SettingsPanel = { Container = { SettingsList = {} } }
SmartNavigation = { UpdateParent = function(_, frame) W.cursorRead = frame end }
function SmartNavigation_MarkFrameIgnored(frame) frame.smartNavigationIgnored = true end
function SmartNavigation_ClearIgnoreStatus(frame) frame.smartNavigationIgnored = nil end
-- picking up: the bars' lock, the pick up key, and what lands on the cursor
-- The game's options: an addon's page in its list, and the pages under it, in the order they are listed
-- (W.subcategories); a page opened by its category's id (W.opened).
Settings = {
    GetValue = function(name) return name == "lockActionBars" and W.locked == true end,
    RegisterCanvasLayoutCategory = function(frame, name)
        return { frame = frame, name = name, GetID = function() return name end }
    end,
    RegisterAddOnCategory = function(category) W.category = category end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
        W.subcategories = W.subcategories or {}
        W.subcategories[#W.subcategories + 1] = { parent = parent, frame = frame, name = name }
    end,
    OpenToCategory = function(id) W.opened = id end,
}
-- the unit under the mouse, where a test puts one there
function UnitExists(unit)
    return unit == "player" or (unit == "mouseover" and W.mouseover ~= nil) or (unit == "target" and W.target ~= nil)
end
-- A bar slot's range to the target and whether it can be used, as the game tells its own bar buttons.
function IsActionInRange(slot)
    local kind, id = GetActionInfo(slot)
    if not W.target or kind ~= "spell" or (W.rangeless and W.rangeless[id]) then return nil end
    if W.hideRange ~= nil then return W.hideRange end
    return not (W.far and W.far[id])
end
C_ActionBar = { IsUsableAction = function(slot)
    local kind, id = GetActionInfo(slot)
    if kind ~= "spell" then return true, false end
    return not (W.short[id] or W.unusable[id]), W.short[id] or false
end }
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
function StaticPopup_Show(which, text, _, data)
    W.popup = { which = which, text = text, data = data }
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
    -- where the game writes a macro's name on a bar button, in its own lettering
    b.Name = b:CreateFontString()
    b.Name.font = "GameFontHighlightSmallOutline"
    -- its icon: the game dims it short of power or unusable, and leaves it alone out of range
    b.icon = b:CreateTexture()
    -- a hover shows the tooltip of what it holds, as the game's bar button does (ActionButton.lua:
    -- SetTooltip, which a refresh of the tooltip runs again); the mouse off it puts the tooltip away
    function b:SetTooltip()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetAction(self.action)
    end
    b.scripts.OnEnter = function(self) self:SetTooltip() end
    b.scripts.OnLeave = function() GameTooltip:Hide() end
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
    GameTooltip:Hide()
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
    -- As the game's own: the bar's buttons take their slot off the bar's page ("useparent-actionpage")
    -- and have no "action" of their own. Another addon's bars keep the one it gives them.
    if kind == "game" then
        main.attrs.actionpage = 1
        for i = 1, 12 do
            local b = W.frames["ActionButton" .. i]
            b.attrs.action, b.attrs["useparent-actionpage"] = nil, true
        end
    end
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
        strfind = string.find,
        strsub = string.sub,
        tostring = tostring,
        tonumber = tonumber,
        select = select,
        -- whom an ability is for, as the game tells a snippet
        IsSpellHelpful = function(id) return C_Spell.IsSpellHelpful(id) end,
        IsSpellHarmful = function(id) return C_Spell.IsSpellHarmful(id) end,
        IsHelpfulItem = function(id) return C_Item.IsHelpfulItem(id) end,
        IsHarmfulItem = function(id) return C_Item.IsHarmfulItem(id) end,
        -- what a slot holds, and whether the player is in a fight
        GetActionInfo = function(slot) return GetActionInfo(slot) end,
        -- Action Bar 1's page as the game works it out: a form's bar (W.bonus) over the bar's own page
        -- (W.barPage, TurnPage); no vehicle, override bar or passing shapeshift here
        HasVehicleActionBar = function() return false end,
        HasOverrideActionBar = function() return false end,
        HasTempShapeshiftActionBar = function() return false end,
        HasBonusActionBar = function() return (W.bonus or 0) > 0 end,
        GetBonusBarIndex = function() return 6 + (W.bonus or 0) end,
        GetActionBarPage = function() return W.barPage or 1 end,
        PlayerInCombat = function() return W.combat == true end,
    }
    W.env = setmetatable({}, { __index = function(t, k)
        if k == "armed" or k == "held" or k == "picked" or k == "own" or k == "lifted" then return rawget(t, k) end
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

-- W.guard (a test's to set): in a fight the client refuses addon code whatever changes a protected frame,
-- a bar button or one made from a secure template. Secure code (W.secure: a wrap's body being run) may.
for _, m in ipairs({ "SetAttribute", "SetPoint", "ClearAllPoints", "SetParent", "Show", "Hide", "SetScale", "SetWidth",
    "SetHeight" }) do
    local plain = Frame[m]
    Frame[m] = function(self, ...)
        if W and W.guard and W.combat and not W.secure then
            local protected = self.action ~= nil
                or (type(self.template) == "string" and self.template:find("Secure", 1, true) ~= nil)
            if protected then error(("blocked in a fight: %s on %s"):format(m, tostring(self.name)), 2) end
        end
        return plain(self, ...)
    end
end
-- What secure code may put on the cursor, as the client's own (PickupAny): an ability by its kind, or
-- the cursor emptied.
-- "clear" empties it first, and what is named after it is then picked up. An item is known by its number
-- or its item string, and is on the cursor by its number.
local function pickupAny(kind, value, more)
    if kind == "clear" then
        W.cursor = nil
        fire("ACTIONBAR_HIDEGRID")
        kind, value = value, more
    end
    if kind == "macro" then
        PickupMacro(value)
    elseif kind == "spell" then
        C_Spell.PickupSpell(value)
    elseif kind == "item" then
        W.cursor = { "item", tonumber(value) or tonumber(tostring(value):match("^item:(%d+)")), "link" }
    elseif kind == "toy" or kind == "mount" or kind == "battlepet" or kind == "macrotext" then
        -- the client's PickupAny knows no such kind: nothing comes onto the cursor
        return
    elseif kind then
        W.cursor = { kind, value }
    end
end
-- a wrap's body, run as secure code
local function secureRun(frame, body, signature, ...)
    local fn = assert(load("local " .. signature .. " = ...; " .. body, frame.name, "t", W.env))
    -- secure code run from secure code (RunAttribute): the outer run is still secure after
    local outer = W.secure
    W.secure = true
    local ok, a, b = pcall(fn, ...)
    W.secure = outer
    if not ok then error(a, 0) end
    return a, b
end
-- A frame's OnAttributeChanged wrap (Frame:SetAttribute): its body, run as secure code, and only for a
-- frame protected itself (made from a secure template), as the client does: its SecureHandler_Other_Execute
-- asks GetFrameHandle(frame, true), which a frame protected only through its children does not answer,
-- and then runs nothing. (A wrap on the game's own Action Bar 1 never ran on his client, 2026-11-23.)
function RunAttributeWrap(frame, wrapped, name, value)
    if not frame.protected then return end
    secureRun(frame, wrapped.before, "self, name, value, owner", frame, name, value, wrapped.header)
end
-- a frame's own snippet, run by secure code (the client's RunAttribute)
function Frame:RunAttribute(attribute)
    local body = self.attrs[attribute]
    assert(type(body) == "string", "RunAttribute of no snippet")
    return secureRun(self, body, "self", self)
end
-- The game's state drivers (SecureStateDriver.lua): a frame's "state-<id>" set to the value of the first of
-- its conditions that holds, as they are looked at again after the events that change them; a frame made
-- from the state handler template runs its "_onstate-<id>" then. Of the conditions only those a bar's page
-- goes by are known here: [bonusbar:N] (W.bonus) and [bar:N] (W.barPage); any other never holds.
function RegisterStateDriver(frame, id, conditions)
    W.drivers = W.drivers or {}
    W.drivers[#W.drivers + 1] = { frame = frame, id = id, conditions = conditions }
    ResolveDrivers()
end
function ResolveDrivers()
    local function holds(cond)
        local n = cond:match("^bonusbar:(%d)$")
        if n then return (W.bonus or 0) == tonumber(n) end
        n = cond:match("^bar:(%d)$")
        if n then return (W.barPage or 1) == tonumber(n) end
        return cond == ""
    end
    for _, driver in ipairs(W.drivers or {}) do
        local value
        for clause in driver.conditions:gmatch("[^;]+") do
            local cond, v = clause:match("^%[(.-)%](.*)$")
            if not cond then cond, v = "", clause end
            if value == nil and holds(cond) then value = v end
        end
        -- set by the game's own manager: secure, in a fight too
        if driver.frame.attrs["state-" .. driver.id] ~= value then
            local was = W.secure
            W.secure = true
            driver.frame:SetAttribute("state-" .. driver.id, value)
            W.secure = was
        end
    end
end
-- The game turning Action Bar 1 to another page (a druid's form, a stance): its ActionBarController sets
-- the bar's "actionpage", in a fight too, and then each of the bar's buttons takes its slot off it anew
-- (CalculateAction: (page - 1) * 12 + the button's number). Then the events the client sends with it.
-- A form's page is a bonus bar's (7 to 11), the bar's own pages are 1 to 6. The state drivers are looked
-- at again after the events, as the game's manager does at its next pass.
function TurnPage(page)
    W.bonus = (page >= 7 and page <= 11) and (page - 6) or 0
    W.barPage = page <= 6 and page or 1
    local bar = W.frames.MainActionBar
    local was = W.secure
    W.secure = true
    bar:SetAttribute("actionpage", page)
    W.secure = was
    for i = 1, 12 do
        local b = W.frames["ActionButton" .. i]
        if b and b.attrs.action == nil then b.action = (page - 1) * 12 + i end
    end
    fire("UPDATE_SHAPESHIFT_FORM")
    fire("UPDATE_BONUS_ACTIONBAR")
    ResolveDrivers()
end
-- A drag begun on a frame, as the client runs it: the wrap's body first, which may refuse it or put
-- something on the cursor; else the frame's own handler.
function DragOff(frame)
    local wrapped = frame.wraps and frame.wraps.OnDragStart
    if wrapped and wrapped.before then
        local kind, value = secureRun(frame, wrapped.before, "self, button, kind, value, owner", frame, "LeftButton",
            GetCursorInfo(), nil, wrapped.header)
        if kind == false then return end
        if kind and kind ~= "message" then return pickupAny(kind, value) end
    end
    if frame.scripts.OnDragStart then frame.scripts.OnDragStart(frame, "LeftButton") end
end
-- A drag let go over a frame, as the client runs it: the wrap's body before (which is told what the
-- cursor holds, and may answer "message", a pickup, or false), the frame's own handler (a bar button
-- places what is carried), then the wrap's body after.
-- (The client's Wrapped_Drag: the body is told all that GetCursorInfo gives, "self,button,kind,value,...",
-- and a drop comes with no mouse button.)
local function secureDrop(frame, body, header, ...)
    local fn = assert(load("local owner = ...\nreturn (function(self, button, kind, value, ...)\n" .. body
        .. "\nend)(select(2, ...))", frame.name, "t", W.env))
    W.secure = true
    local ok, a, b, c = pcall(fn, header, frame, nil, ...)
    W.secure = false
    if not ok then error(a, 0) end
    return a, b, c
end
function DropOn(frame)
    local wrapped, message = frame.wraps and frame.wraps.OnReceiveDrag, nil
    if wrapped and wrapped.before then
        local kind, value, more = secureDrop(frame, wrapped.before, wrapped.header, GetCursorInfo())
        if kind == false then return end
        if kind == "message" then
            message = value
        elseif kind then
            return pickupAny(kind, value, more)
        end
    end
    if frame.action then
        PlaceAction(frame.action)
    elseif frame.scripts.OnReceiveDrag then
        frame.scripts.OnReceiveDrag(frame)
    end
    if wrapped and wrapped.after and message ~= nil then
        secureRun(frame, wrapped.after, "self, message, button, owner", frame, message, "LeftButton", wrapped.header)
    end
end
local function click(frame, down, button)
    button = button or "LeftButton"
    -- What the game's bar button does with a click that reaches it: with an ability on the cursor it
    -- takes that, at the release (ActionButton.lua: a mouse press acts on its release); else it casts.
    local function bar()
        if W.cursor and (W.cursor[1] == "spell" or W.cursor[1] == "macro") then
            if not down then PlaceAction(frame.action) end
        elseif down then
            W.casts[#W.casts + 1] = "bar:" .. frame.name
        end
    end
    if not frame.wrap then
        -- a plain button of an addon's runs its own click: on the press when it listens for presses
        if frame.scripts.OnClick and not frame.attrs.type then
            if down == (frame.clicksOnPress == true) then frame.scripts.OnClick(frame, button, down) end
            return
        end
        if frame.action then return bar() end
        if down then W.casts[#W.casts + 1] = "bar:" .. frame.name end
        return
    end
    local fn = assert(load("local self, button, down, owner = ...; " .. frame.wrap, frame.name, "t", W.env))
    W.secure = true
    local ran, verdict, message = pcall(fn, frame, button, down, frame.header)
    W.secure = false
    if not ran then error(verdict, 0) end
    -- A bar button: the wrap's body before, the game's own handler unless that body answered false, and
    -- the wrap's body after when the one before gave it a message (the client's Wrapped_Click).
    if frame.action then
        if verdict ~= false then
            bar()
            if frame.wrapAfter and message ~= nil then
                secureRun(frame, frame.wrapAfter, "self, message, button, down, owner", frame, message, button, down,
                    frame.header)
            end
        end
        -- the click's own script is over; what follows a click follows it either way
        if frame.scripts.PostClick then frame.scripts.PostClick(frame, button, down) end
        return
    end
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
