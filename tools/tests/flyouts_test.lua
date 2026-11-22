-- The addon alone, as anyone who installs it runs it. From the repo root:
--   lua tools/tests/run.lua tools/tests/flyouts_test.lua captured      (and: relookup)

print("model: " .. MODEL)
boot()
flushAll()
check(root() == nil or root().attrs.units == 0, "a fresh character has no flyout")

print("by hand on the game's bar: stack three spells onto ActionButton1")
for _, id in ipairs({ 501, 502, 503 }) do
    W.cursor = { "spell", 7, "spell", id, id }
    fire("ACTIONBAR_SHOWGRID")
    local tab = tabOf("ActionButton1")
    check(tab and tab:IsShown(), "tab shown on ActionButton1 while carrying " .. id)
    -- A bar close above this one must not cover the plus. While a spell is carried the game
    -- lifts its bars to the top layer: only a higher level on that same layer is over them.
    local beside = W.frames.ActionButton2
    check(beside:GetFrameStrata() == "TOOLTIP", "the game's bar buttons are on the top layer while a spell is carried")
    check(tab:GetFrameStrata() == "TOOLTIP" and tab:GetFrameLevel() > beside:GetFrameLevel() + 600,
        "the plus is on that layer too, at a level over every bar button and the frames on it")
    -- the arrow of a flyout ends 4 past the button's edge: the plus stands past its tip
    local out = math.abs(tab.point[4]) + math.abs(tab.point[5])
    if id == 501 then
        check(out == NS.Drop.BADGE_OUT, "on a button with no flyout yet the plus sits at the button's edge")
    else
        check(out == NS.Drop.BADGE_PAST and out - 18 * 0.31 > 4 + 1,
            "on a button with a flyout the plus stands clear of the flyout's arrow")
    end
    tab.scripts.OnReceiveDrag(tab)
    check(W.cursor == nil, "cursor emptied after the drop")
end
local one = opener("1")
check(one ~= nil and opener("E") == one, "each of the button's keys opens the flyout")
local menu = menuOf(one)
check(count(one) == 4 and entry(one, 1).attrs.spell == 101, "the host's spell plus three")
check(W.frames["FallensFlyoutsOpener" .. one].parent == W.frames.ActionButton1, "the arrow belongs to its button")
tap("1")
check(menu:IsShown(), "open after tapping 1, through the release")
tap("2")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "2 cast the first drop and shut it")
check(GetBindingAction("2", true) == "ACTIONBUTTON2" and GetBindingAction("ESCAPE", true) == "TOGGLEGAMEMENU",
    "2 and Escape are the game's again")
tap("1"); tap("1")
check(W.casts[#W.casts] == "spell:101" and not menu:IsShown(), "a double tap casts the host's own spell")

print("a mouse click on the bar button itself")
local function mouse(frame) click(frame, true); click(frame, false) end
local host, before = W.frames.ActionButton1, #W.casts
mouse(host)
check(menu:IsShown() and #W.casts == before, "it opens the flyout and casts nothing")
mouse(host)
check(not menu:IsShown() and #W.casts == before, "a second click shuts it")
mouse(host); tap("2")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "opened by the mouse, 2 still picks")
W.combat = true
mouse(host)
check(menu:IsShown(), "in a fight too")
mouse(entry(one, 3))
check(W.casts[#W.casts] == "spell:502" and not menu:IsShown(), "a click on an icon casts it and shuts the flyout")
W.combat = false
mouse(W.frames.ActionButton3)
check(W.casts[#W.casts] == "bar:ActionButton3" and not menu:IsShown(), "a button without a flyout casts as ever")
W.cursor = { "spell", 7, "spell", 777, 777 }
fire("ACTIONBAR_SHOWGRID")
mouse(host)
check(W.casts[#W.casts] == "action:1" and not menu:IsShown(), "with something on the cursor the click goes to the bar")
W.cursor = nil
fire("ACTIONBAR_HIDEGRID")
mouse(host)
check(menu:IsShown(), "and with the cursor empty it opens again")
mouse(host)

print("an icon of its own for the flyout")
local FIRE = "INTERFACE\\ICONS\\Spell_Fire_Fireball"
local function face()
    local units = NS.Flyouts.Units()
    return units[one].face
end
local function saved() return NS.Profiles.Data().flyouts[1].icon end
before = #W.casts
rightClick(host)
local window = W.frames.FallensFlyoutsIconPopup
check(window ~= nil and window:IsShown() and not menu:IsShown() and #W.casts == before,
    "a right-click on the bar button opens the game's icon window and casts nothing")
check(window.IconSelector.num() == 5, "it lists the game's icons")
check(NS.Icon.Search("FIRE") == 1 and window.IconSelector.get(1) == FIRE, "a search finds an icon by its file name")
check(NS.Icon.Search("spell 605") == 1 and window.IconSelector.get(1) == 605, "or by a spell's name")
check(NS.Icon.Search("605") == 1, "or by a spell's number")
check(NS.Icon.Search("no such thing") == 0, "nothing matching leaves none")
check(NS.Icon.Search("") == 5, "an empty search shows them all again")
window:OkayButton_OnClick()
check(saved() == nil and not face():IsShown() and not window:IsShown(), "Okay with nothing picked changes nothing")
rightClick(host)
window.IconSelector.picked(3, FIRE)
window:OkayButton_OnClick()
check(saved() == FIRE and face():IsShown() and face().texture == FIRE and face().parent == host,
    "a picked icon is saved and drawn on the bar button")
rightClick(host)
window.IconSelector.picked(2, 600001)
window:CancelButton_OnClick()
check(saved() == FIRE and face().texture == FIRE, "Cancel leaves the icon as it was")
rightClick(host)
window.IconSelector.picked(1, QUESTION_PATH)
window:OkayButton_OnClick()
check(saved() == nil and not face():IsShown(), "the ? icon gives the button its own icon back")
W.combat = true
rightClick(host)
check(not window:IsShown() and W.errors[#W.errors]:find("fight"), "in a fight the window stays shut")
W.combat = false
check(W.released == 4, "each showing hands the game's icon list back")

print("one of the flyout's own icons on the bar button, and a way back")
do
    -- His words (2026-11-21): a row over the first row of icons with the icons of every spell in the flyout;
    -- picking one shows that spell's tooltip on the bar as well, so its cooldown is seen without opening the
    -- flyout; and a button like "Reset to default icon".
    local record = NS.Flyouts.At("ActionButton1")
    local function ids()
        local out = {}
        for i, e in ipairs(record.entries) do out[i] = tostring(e.id) end
        return table.concat(out, " ")
    end
    local order = ids()
    rightClick(host)
    local own, reset = NS.Icon.own, NS.Icon.reset
    check(own ~= nil and own:IsShown() and own.buttons[1]:IsShown() and own.buttons[2].Icon.texture == record.entries[2].id
        and not own.buttons[#record.entries + 1]:IsShown(),
        "the window has a row of the flyout's own icons, one for each")
    check(window.IconSelector.point[5] == -(97 + 52) and window.IconSelector.height == 361 - 52,
        "the game's list starts under the row")
    check(own.buttons[1].SelectedTexture:IsShown() and not own.buttons[2].SelectedTexture:IsShown(),
        "the one the bar button holds is marked")
    check(reset ~= nil and reset.text == "Reset to default icon", "and there is a button to reset to the default icon")
    local second = record.entries[2]
    own.buttons[2].scripts.OnClick(own.buttons[2])
    check(own.buttons[2].SelectedTexture:IsShown() and not own.buttons[1].SelectedTexture:IsShown()
        and window.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == second.id,
        "one clicked in the row is the one picked")
    window:OkayButton_OnClick()
    flushAll()
    local kind, id = GetActionInfo(1)
    check(kind == "spell" and id == second.id and W.cursor == nil,
        "Okay puts that one on the bar button itself: the game then shows its icon, tooltip and cooldown there")
    check(NS.Flyouts.At("ActionButton1") == record and record.main.id == second.id and ids() == order and saved() == nil,
        "the flyout stays on its button with every icon in its place, led by the one picked")
    rightClick(host)
    check(own.buttons[2].SelectedTexture:IsShown(), "opened again, the row marks the one on the button now")
    reset.scripts.OnClick(reset)
    flushAll()
    kind, id = GetActionInfo(1)
    check(not window:IsShown() and kind == "spell" and id == 101 and record.main.id == 101 and record.first == nil and ids() == order,
        "Reset to default icon puts back the ability the button had")
    -- an icon of the game's list is reset the same way
    rightClick(host)
    window.IconSelector.picked(3, FIRE)
    window:OkayButton_OnClick()
    rightClick(host)
    reset.scripts.OnClick(reset)
    check(saved() == nil and not face():IsShown(), "and takes an icon picked from the game's list off again")
    W.combat = true
    local ok, why = NS.Flyouts.Lead(record, second)
    check(ok == false and why:find("fight") ~= nil and record.main.id == 101, "nothing is put on a bar button in a fight")
    W.combat = false
    flushAll()
end

print("an icon's frame hugs the icon, as on the game's own flyout")
do
    local Art = NS.Art
    for i = 1, 4 do
        local e = entry(one, i)
        for _, kind in ipairs({ "artNormal", "artPushed" }) do
            local art = e[kind]
            local own = C_Texture.GetAtlasInfo(art.atlas)
            -- the ring's drawn size: its share of the piece, at the size the piece is drawn
            local ringW, ringH = art.w * RING_W / own.width, art.h * RING_H / own.height
            check(ringW - Art.ICON < 2 and ringH - Art.ICON < 2 and ringW >= Art.ICON and ringH >= Art.ICON,
                ("icon %d %s: the ring is %.1f by %.1f on a %d icon, not hanging off it"):format(i, kind, ringW, ringH, Art.ICON))
        end
        check(e.artNormal.atlas == Art.NAMES.frame and e.artNormal.w == Art.FRAME, "icon " .. i .. " wears the row frame at 35")
        check(e.artHighlight.w == Art.OVER_W and e.artHighlight.h == Art.OVER_H, "icon " .. i .. " highlights at the ring's size")
        check(e.back ~= nil and e.back.atlas == Art.NAMES.back, "icon " .. i .. " has the game's dark slot under it")
        check(e.key.color ~= nil and e.key.color[1] == 0.8, "icon " .. i .. " writes its key in the gray of the game's bar keys")
    end
    check(NS.Drop.pop == nil or NS.Drop.pop.frame.atlas == Art.NAMES.frame, "the drop slot wears the same frame")
end

print("the pad buttons by place: the D-pad together, the face buttons past it")
do
    local function pads(way, n) return table.concat(NS.Flyouts.PadsFor(way, n), " ") end
    check(pads("UP", 2) == "PADDDOWN PADDUP", "two icons opening upward: down by the button, up above it")
    check(pads("UP", 3) == "PADDDOWN PADDRIGHT PADDUP" and pads("UP", 4) == "PADDDOWN PADDLEFT PADDRIGHT PADDUP",
        "three and four: left and right between down and up")
    check(pads("UP", 5) == "PADDDOWN PADDLEFT PADDRIGHT PADDUP PAD4",
        "five: the D-pad keeps the four places by the button, the fifth icon takes a face button")
    check(pads("UP", 6) == "PADDDOWN PADDLEFT PADDRIGHT PADDUP PAD4 PAD3", "six: the two past the D-pad take the face buttons")
    check(pads("DOWN", 5) == "PADDUP PADDRIGHT PADDLEFT PADDDOWN PAD4", "opening downward: up by the button, down the fourth")
    check(pads("RIGHT", 5) == "PADDLEFT PADDUP PADDDOWN PADDRIGHT PAD4" and pads("LEFT", 6) == "PADDRIGHT PADDDOWN PADDUP PADDLEFT PAD4 PAD3",
        "opening sideways: left and right at the ends of the four")
    local together = true
    for _, way in ipairs({ "UP", "DOWN", "LEFT", "RIGHT" }) do
        for n = 1, 6 do
            local list, seenFace = NS.Flyouts.PadsFor(way, n), false
            for _, button in ipairs(list) do
                local face = button == "PAD4" or button == "PAD3"
                -- a D-pad direction after a face button would have the face button between D-pad icons
                if seenFace and not face then together = false end
                seenFace = seenFace or face
            end
            together = together and #list == n
        end
    end
    check(together, "whatever the way and the count, no face button sits between two D-pad icons")
end

print("pad symbols on the icons: only while the pad is the input in use")
local function label(i) return entry(one, i).key.text end
local function symbol(i) return (label(i) or ""):find("|A", 1, true) ~= nil end
check(label(1) == "1" and label(2) == "2" and label(4) == "4", "no controller: each icon shows its key")
-- plugged in and never touched: the game's bars keep showing keys
W.pad = 1
fire("GAME_PAD_CONNECTED")
check(label(1) == "1" and label(4) == "4", "a controller plugged in but idle: still the keys, as on the game's bars")
mouse(host)
check(menu:IsShown() and label(1) == "1", "and still the keys on an open flyout")
mouse(host)
W.padInUse = true
fire("GAME_PAD_ACTIVE_CHANGED", true)
check(label(4) == "|A:Gamepad_Ltr_Up:11:11|a" and label(1):find("Gamepad_Gen_PADDDOWN", 1, true) ~= nil,
    "the controller picked up: the top icon shows D-pad up and the one by the button D-pad down, as symbols")
check(label(3):find("PADDRIGHT", 1, true) ~= nil and label(2):find("PADDLEFT", 1, true) ~= nil,
    "the icons between take right and left")
for i = 1, 6 do
    local text = label(i) or ""
    check(text == "" or #text == 1 or text:find("|A", 1, true) ~= nil, "label " .. i .. " is a symbol or a key, never words")
end
W.padInUse = false
fire("GAME_PAD_ACTIVE_CHANGED", false)
check(label(1) == "1", "back on keyboard and mouse: the keys again")
-- the game switched and no word of it came: nothing stays stuck past the next showing
W.padInUse = true
mouse(host)
check(menu:IsShown() and symbol(1), "the pad in use with no word from the game: an opening flyout shows symbols all the same")
W.padInUse = false
mouse(host); mouse(host)
check(menu:IsShown() and label(1) == "1", "and keys the same way once the keyboard is back")
mouse(host)
W.padInUse = true
W.padOff = true
fire("GAME_PAD_ACTIVE_CHANGED", true)
check(label(1) == "1", "the controller turned off in the game's settings: keys")
W.padOff = nil
-- no command with a key and a pad button both: the game's last word decides
W.base.PAD1 = nil
fire("UPDATE_BINDINGS")
fire("GAME_PAD_ACTIVE_CHANGED", true)
check(symbol(1), "no command to tell by: the game saying the pad is in use shows symbols")
fire("GAME_PAD_ACTIVE_CHANGED", false)
check(label(1) == "1", "and its saying otherwise shows keys")
W.base.PAD1 = "JUMP"
W.padInUse = false
fire("UPDATE_BINDINGS")
W.pad = nil
fire("GAME_PAD_DISCONNECTED")
check(label(1) == "1", "controller unplugged: the keys again")

print("the icons show cooldown and power as bar buttons do")
local function sweep(i) return entry(one, i).cooldown.sweep end
local function tint(i)
    local c = entry(one, i).icon.color
    return c and table.concat(c, ",")
end
mouse(host)
check(sweep(1) == nil and sweep(2) == nil and tint(2) == "1,1,1", "ready: no sweep, full color")
W.gcd = { startTime = 100, duration = 1.5, isActive = true, modRate = 1 }
fire("SPELL_UPDATE_COOLDOWN")
check(sweep(1) and sweep(1)[1] == 100 and sweep(1)[2] == 1.5 and sweep(4) and sweep(4)[2] == 1.5,
    "the global cooldown sweeps every icon")
W.gcd = nil
W.cooling[502] = { startTime = 100, duration = 30, isActive = true, modRate = 1 }
fire("SPELL_UPDATE_COOLDOWN")
check(sweep(1) == nil and sweep(3) and sweep(3)[2] == 30, "after it only the spell on cooldown keeps its sweep")
W.short[501], W.unusable[503] = true, true
fire("SPELL_UPDATE_USABLE")
check(tint(2) == "0.5,0.5,1" and tint(4) == "0.4,0.4,0.4" and tint(1) == "1,1,1",
    "short of power dims blue, unusable gray, the rest stay full")
mouse(host)
W.short[501] = nil
mouse(host)
check(tint(2) == "1,1,1" and sweep(3) and sweep(3)[2] == 30, "an opening flyout shows the state as it is then")
check(sweep(3).object == true, "the sweep is fed the client's duration object, which works in a fight too")
-- a client without that object: a number it hides is never handed to the sweep
local SECRET, object = {}, C_Spell.GetSpellCooldownDuration
issecretvalue = function(v) return v == SECRET end
C_Spell.GetSpellCooldownDuration = nil
W.cooling[501] = { startTime = SECRET, duration = SECRET, isActive = true, modRate = SECRET }
fire("SPELL_UPDATE_COOLDOWN")
check(sweep(2) == nil and NS.Flyouts.hid.cooldown == true and #W.caught == 0,
    "a hidden cooldown number is never passed on: no sweep, and no error")
C_Spell.GetSpellCooldownDuration = object
issecretvalue = nil
mouse(host)
W.cooling, W.short, W.unusable = {}, {}, {}
-- an error while drawing must not stop the flyout working
W.breakDrawing = true
mouse(host)
check(menu:IsShown() and #W.caught == 1 and GetBindingAction("2", true):find("FallensFlyoutsEntry"),
    "an error in drawing is reported, and the flyout still opens with its keys")
tap("2")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "and a pick still casts and shuts it")
W.breakDrawing, W.caught = nil, {}

print("holding the flyout's key keeps it open")
before = #W.casts
press("E")
check(menu:IsShown(), "pressed, it opens")
tap("2"); tap("2"); tap("3")
check(#W.casts == before + 3 and menu:IsShown(), "held, every pick casts and it stays open")
release("E")
check(not menu:IsShown() and GetBindingAction("2", true) == "ACTIONBUTTON2", "let go, it shuts and the keys go back")
tap("E")
check(menu:IsShown(), "a tap opens it and it stays for a pick")
tap("2")
check(not menu:IsShown(), "and after a tap a pick shuts it, as before")
press("E"); release("E"); press("E"); release("E")
check(not menu:IsShown(), "a held press with no pick, let go, leaves it open; the next press shuts it")
press("CTRL-6")
check(menu:IsShown() and GetBindingAction("CTRL-2", true):find("FallensFlyoutsEntry"),
    "a key with a modifier: the number keys work under that modifier while it is held")
tap("CTRL-2"); tap("CTRL-2")
check(W.casts[#W.casts] == "spell:501" and menu:IsShown(), "so picks land while Ctrl is still down")
release("CTRL-6")
check(not menu:IsShown() and GetBindingAction("CTRL-2", true) == "", "let go, it shuts and Ctrl with a number is free again")
press("1"); release("1")
tap("2")
check(not menu:IsShown(), "a key that is itself a pick cannot be held: a pick shuts it")
W.combat = true
press("E"); tap("2"); tap("2")
check(menu:IsShown(), "in a fight held picks keep it open too")
release("E")
check(not menu:IsShown(), "and letting go shuts it")
W.combat = false

print("the settings page")
check(SlashCmdList.FALLENSFLYOUTS ~= nil and SLASH_FALLENSFLYOUTS1 == "/ff" and SLASH_FALLENSFLYOUTS2 == "/flyouts",
    "/ff and /flyouts open it")
local page, rows = NS.ProfileUI.panel, SettingsPanel.Container.SettingsList
page:Show()
flushAll()
check(W.cursorRead == page and rows.smartNavigationIgnored == true,
    "with a controller the game's cursor is told to read the page, and its own rows under it are set aside")
page:Hide()
check(rows.smartNavigationIgnored == nil, "leaving the page gives the game's rows back")

print("flyout size")
local base = menu.scale
check(entry(one, 1).w == 30 and entry(one, 1).h == 30, "by default the icons are the game's own flyout size, 30 wide")
check(page.slider.value == 100 and page.sizeText.text == "100%", "the size slider starts at 100%")
page.slider:SetValue(150)
check(math.abs(menu.scale - base * 1.5) < 0.001 and NS.Profiles.Data().size == 1.5 and page.sizeText.text == "150%",
    "at 150% a flyout is half again as big, and the profile keeps it")
page.larger.scripts.OnClick(page.larger)
check(page.slider.value == 155, "Larger steps it up")
W.combat = true
page.slider:SetValue(100)
check(math.abs(menu.scale - base * 1.55) < 0.001 and page.slider.value == 155, "no size change in a fight")
W.combat = false
page.slider:SetValue(100)
check(math.abs(menu.scale - base) < 0.001 and NS.Profiles.Data().size == nil, "back at 100% it is the game's size again")

print("an icon's own key inside its flyout")
local mine = NS.Profiles.Data().flyouts[1]
mouse(host)
NS.Flyouts.SetKey(mine, 2, "Q")
check(menu:IsShown() and label(2) == "Q" and GetBindingAction("Q", true):find("Entry" .. one .. "_2", 1, true) ~= nil,
    "a key of its own picks an icon while the flyout is open")
check(GetBindingAction("2", true) == "ACTIONBUTTON2", "and the number it had is the bar's")
tap("Q")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "pressing it casts and shuts")
check(GetBindingAction("Q", true) == "ACTIONBUTTON2" and W.base.Q == "ACTIONBUTTON2",
    "shut, the key does what it always did: the game's own bindings are never touched")
NS.Flyouts.SetKey(mine, 3, "Q")
check(mine.entries[2].key == nil and mine.entries[3].key == "Q", "given to another icon of the same flyout, it leaves the first")
NS.Flyouts.SetKey(mine, 3, "1")
mouse(host)
check(label(3) == "1" and label(1) ~= "1" and label(1) ~= label(2) and label(2) ~= label(4),
    "an icon given another one's number: the rest move over, no key twice in a flyout")
mouse(host)
NS.Flyouts.SetKey(mine, 3, nil)
check(mine.entries[3].key == nil, "and its own key can be given back")

print("setting keys by hovering: in the game's Quick Keybind Mode")
local top = entry(one, 4)
local quick = QuickKeybindFrame
mouse(host)
-- the icon window's search box had the focus last
W.focus = nil
top.scripts.OnEnter(top)
quick.scripts.OnKeyDown(quick, "R")
check(W.focus == nil and mine.entries[4].key == nil, "out of that mode a hover only shows the tooltip, and a key sets nothing")
W.quick = true
top.scripts.OnEnter(top)
check(W.focus == nil, "in that mode no typing box takes the keyboard: the game's own window has it")
quick.scripts.OnKeyDown(quick, "LSHIFT")
check(mine.entries[4].key == nil, "a modifier alone sets nothing")
W.shiftKey = true
quick.scripts.OnKeyDown(quick, "R")
W.shiftKey = nil
check(mine.entries[4].key == "SHIFT-R" and label(4) == "s-R", "a key the game's window is given becomes the hovered icon's, with its modifier")
check(W.base["SHIFT-R"] == nil and GetBindingAction("SHIFT-R", false) == "", "and the game's own bindings stay as they were")
top.scripts.OnEnter(top)
quick.scripts.OnGamePadButtonDown(quick, "PADRSHOULDER")
check(mine.entries[4].pad == "PADRSHOULDER", "a pad button pressed there becomes its pad button")
top.scripts.OnEnter(top)
quick.scripts.OnKeyDown(quick, "BACKSPACE")
check(mine.entries[4].key == nil and mine.entries[4].pad == nil, "Backspace over the icon gives it its own back")
top.scripts.OnLeave(top)
quick.scripts.OnKeyDown(quick, "T")
check(mine.entries[4].key == nil, "off the icon a key sets nothing")
W.quick = false

print("setting keys by hovering: from Set Keys in the settings")
page.keys.scripts.OnClick(page.keys)
check(W.popup ~= nil and W.popup.which == "FALLENSFLYOUTS_KEYS" and NS.Keys.On(), "Set Keys starts the mode")
top.scripts.OnEnter(top)
check(W.focus ~= nil, "a hover on an icon waits for a key in a typing box")
W.focus.scripts.OnKeyDown(W.focus, "T")
check(mine.entries[4].key == "T", "the key pressed becomes that icon's")
top.scripts.OnEnter(top)
W.clock = W.clock + 1
W.focus.scripts.OnChar(W.focus, "g")
check(mine.entries[4].key == "G", "a client that hands the box only the character typed: that names the key")
top.scripts.OnEnter(top)
W.focus.scripts.OnKeyDown(W.focus, "DELETE")
check(mine.entries[4].key == nil, "Delete gives it its own back there too")
top.scripts.OnEnter(top)
W.focus.scripts.OnEscapePressed(W.focus)
check(W.focus == nil, "Escape lets go of the keyboard")
StaticPopup_Hide("FALLENSFLYOUTS_KEYS")
check(not NS.Keys.On(), "and Done ends the mode")
if menu:IsShown() then mouse(host) end

W.cursor = { "spell", 7, "spell", 501, 501 }
fire("ACTIONBAR_SHOWGRID")
tabOf("ActionButton1").scripts.OnReceiveDrag(tabOf("ActionButton1"))
check(count(one) == 4 and W.cursor ~= nil and W.errors[#W.errors]:find("already"), "a spell is not stacked twice")
W.cursor = nil
fire("ACTIONBAR_HIDEGRID")
W.combat = true
tap("1"); tap("ESCAPE")
check(not menu:IsShown(), "in a fight: opens, Escape shuts")
tap("1"); tap("PADDDOWN")
check(W.casts[#W.casts] == "spell:101" and not menu:IsShown(), "in a fight: D-pad down picks the icon by the button")
tap("1"); tap("PADDUP")
check(W.casts[#W.casts] == "spell:503" and not menu:IsShown(), "and D-pad up the top one")
W.cursor = { "spell", 7, "spell", 504, 504 }
tabOf("ActionButton1").scripts.OnReceiveDrag(tabOf("ActionButton1"))
check(count(one) == 4 and W.cursor ~= nil, "a drop in a fight is refused")
tap("1")
rightClick(entry(one, 4))
check(count(one) == 4 and menu:IsShown(), "a right-click in a fight takes nothing out")
tap("ESCAPE")
W.cursor, W.combat = nil, false
flushAll()

print("a second flyout beside it")
stack("ActionButton2", 601)
local two = opener("2")
check(two ~= nil and two ~= one and opener("1") == one, "ActionButton2 gets a flyout of its own")
check(count(two) == 2 and entry(two, 1).attrs.spell == 102 and entry(two, 2).attrs.spell == 601,
    "its own spell and the one dropped")
tap("2"); tap("1")
check(W.casts[#W.casts] == "spell:102" and not menuOf(two):IsShown(), "its key opens it and 1 casts its first")
tap("E")
check(menu:IsShown(), "E opens the first")
tap("Q")
check(menuOf(two):IsShown() and not menu:IsShown(), "the other button's key shuts it and opens the second")
tap("2")
check(W.casts[#W.casts] == "spell:601" and not menuOf(two):IsShown(), "and the pick comes from the open one")
check(opener("1") == one and opener("2") == two and opener("Q") == two and GetBindingAction("3", true) == "ACTIONBUTTON3",
    "shut, every key is back")
local casts = #W.casts
tap("E")
rightClick(entry(one, 4))
check(count(one) == 3 and menu:IsShown() and #W.casts == casts, "a right-click takes an entry out, casts nothing")
check(#NS.Profiles.Data().flyouts[1].entries == 3, "and it is out of the saved flyout")
check(lastChat("Spell 503 taken off the flyout") ~= nil, "chat says what was taken off")
tap("ESCAPE")
tap("Q")
rightClick(entry(two, 2))
check(not opens("2") and not opens("Q") and #NS.Profiles.Data().flyouts == 1,
    "with its one added entry out, the second flyout is gone")
check(opener("1") ~= nil and GetBindingAction("2", true) == "ACTIONBUTTON2", "and its key is the bar's again")
check(lastChat("Spell 601 taken off. Nothing else was added, so the flyout is gone") ~= nil,
    "and chat says the flyout went with it")
mouse(W.frames.ActionButton2)
check(W.casts[#W.casts] == "action:2", "and a click on that button casts its own ability again")

print("a drag moves an icon inside its flyout, as icons move on a phone's home screen")
local Move = NS.Move
local function drag(frame) frame.scripts.OnDragStart(frame) end
local function slot(i) return NS.Flyouts.Slot(i) end
-- how far along its flyout a frame was last put
local function along(frame) return math.abs(frame.point[4]) + math.abs(frame.point[5]) end
local function order()
    local out = {}
    for i = 1, count(one) do out[i] = entry(one, i).attrs.spell end
    return table.concat(out, " ")
end
-- frames pass with no mouse read: the place is aimed at by hand here
local function settle() for _ = 1, 40 do Move.Step(0.02) end end
local function show() if not menu:IsShown() then tap("E") end end
local plus = function() return tabOf("ActionButton1") end
W.locked = true
show()
check(order() == "101 501 502", "three icons to move about")
drag(entry(one, 3))
check(Move.Moving() == nil and count(one) == 3 and W.cursor == nil, "bars locked: a plain drag moves nothing")
W.shift = true
drag(entry(one, 3))
check(Move.Moving() ~= nil and entry(one, 3).alpha == 0 and count(one) == 3 and W.cursor == nil,
    "with Shift held the icon lifts out of its place; nothing is on the cursor and nothing is taken off")
Move.Aim(1)
Move.Step(0.02)
check(along(entry(one, 1)) > slot(1) and along(entry(one, 1)) < slot(2), "the others slide, a part of the way each frame")
settle()
check(along(entry(one, 1)) == slot(2) and along(entry(one, 2)) == slot(3),
    "held over the first place, the other two end one place up each: the gap is where it would land")
Move.Aim(2)
settle()
check(along(entry(one, 1)) == slot(1) and along(entry(one, 2)) == slot(3), "held over the middle, the gap is in the middle")
Move.Aim(1)
Move.Drop()
check(order() == "502 101 501" and menu:IsShown(), "let go over the first place it is first, the rest in their order, the flyout still open")
check(Move.Landing() ~= nil and entry(one, 1).alpha == 0, "the held icon is settling into the gap")
settle()
check(Move.Landing() == nil and entry(one, 1).alpha == 1 and along(entry(one, 1)) == slot(1)
    and along(entry(one, 2)) == slot(2) and along(entry(one, 3)) == slot(3), "then every icon is seen, each in its place")
tap("1")
check(W.casts[#W.casts] == "spell:502" and not menu:IsShown(), "the keys go by place: 1 casts the icon moved to the first place")

print("the mouse does the same: followed while held, landed when it lets go")
show()
local _, unitOne = NS.Flyouts.At("ActionButton1")
local long = slot(3) + NS.Art.ICON + NS.Art.PAD
local upright = unitOne.way == "UP" or unitOne.way == "DOWN"
-- left, right, top, bottom
menu.rect = upright and { 100, 100 + NS.Art.STRIP, 300 + long, 300 } or { 100, 100 + long, 300 + NS.Art.STRIP, 300 }
local function middle(place)
    local d, s = slot(place) + NS.Art.ICON / 2, menu:GetEffectiveScale()
    local x, y = (menu.rect[1] + menu.rect[2]) / 2, (menu.rect[3] + menu.rect[4]) / 2
    if unitOne.way == "UP" then y = menu.rect[4] + d end
    if unitOne.way == "DOWN" then y = menu.rect[3] - d end
    if unitOne.way == "RIGHT" then x = menu.rect[1] + d end
    if unitOne.way == "LEFT" then x = menu.rect[2] - d end
    return x * s, y * s
end
for place = 1, 3 do
    check(Move.Where(unitOne, middle(place)) == place, "the middle of place " .. place .. " is place " .. place)
end
check(Move.Where(unitOne, 5000, 5000) == nil, "a point far off the flyout is no place")
W.mouseDown = true
drag(entry(one, 1))
W.mouseX, W.mouseY = middle(3)
Move.Tick(0.02)
check(Move.Moving() ~= nil and Move.Moving().at == 3, "held over the last place, the gap goes there")
W.mouseDown = false
Move.Tick(0.02)
settle()
check(order() == "101 501 502" and Move.Moving() == nil and Move.Landing() == nil, "let go, it is last again")
local record = NS.Flyouts.At("ActionButton1")
NS.Flyouts.SetKey(record, 3, "T", false)
show()
drag(entry(one, 3))
Move.Aim(2)
Move.Drop()
settle()
check(order() == "101 502 501" and record.entries[2].key == "T" and record.entries[3].key == nil, "an icon's own key moves with it")
NS.Flyouts.SetKey(record, 2, nil, false)
show()
drag(entry(one, 2))
Move.Aim(3)
Move.Drop()
settle()
check(order() == "101 501 502", "and back")

print("dragged out of the flyout it comes off, as off a bar")
show()
drag(entry(one, 3))
W.mouseDown = true
W.mouseX, W.mouseY = 5000, 5000
Move.Tick(0.02)
check(W.cursor ~= nil and W.cursor[4] == 502 and Move.Moving() == nil, "off the flyout it is on the cursor at once")
check(count(one) == 3 and entry(one, 3).shown ~= false and menu:IsShown() and entry(one, 3).alpha == 0,
    "while the mouse is held its frame stays as it is, unseen: the game's drag lives only while that frame is shown")
W.mouseDown = false
Move.Tick(0.02)
Move.Tick(0.02)
check(count(one) == 2 and W.cursor ~= nil and W.cursor[4] == 502 and menu:IsShown() and Move.Moving() == nil,
    "the mouse let go, it is off the flyout and still on the cursor, the flyout still open")
check(entry(one, 1).alpha == 1 and entry(one, 2).alpha == 1 and along(entry(one, 2)) == slot(2), "the icons left close up, seen")
check(lastChat("Spell 502 taken off the flyout") ~= nil, "chat says what was taken off")
plus().scripts.OnReceiveDrag(plus())
check(count(one) == 3 and entry(one, 3).attrs.spell == 502 and W.cursor == nil,
    "dropped on the plus it is back in the flyout")
do
    -- His report (2026-11-22): a spell pulled out of a flyout had to be clicked onto a spot, where the game
    -- places a dragged spell on the let-go. The game, as it is taken to be: a drag lives while the frame it
    -- began on is shown, and a let-go over a bar button then places what the cursor holds; with that frame
    -- hidden under the drag, the let-go places nothing.
    local function letGoOver(origin, slot)
        W.mouseDown = false
        if origin.shown ~= false and menu:IsShown() then PlaceAction(slot) end
        origin.scripts.OnDragStop(origin)
        Move.Tick(0.02)
        Move.Tick(0.02)
        flushAll()
    end
    show()
    local origin = entry(one, 3)
    drag(origin)
    W.mouseDown = true
    W.mouseX, W.mouseY = 5000, 5000
    Move.Tick(0.02)
    letGoOver(origin, 5)
    check(W.placed[5] == 502 and W.cursor == nil and count(one) == 2,
        "let go over a bar spot, the spell lands there by the let-go alone, and is off the flyout")
    W.placed[5] = nil
    fire("ACTIONBAR_SLOT_CHANGED", 5)
    stack("ActionButton1", 502)
    -- His report after that (2026-11-22): one taken from the middle left a gap. The frame kept unseen for the
    -- drag showed the next icon once its own was off, still unseen.
    show()
    origin = entry(one, 2)
    drag(origin)
    W.mouseDown = true
    W.mouseX, W.mouseY = 5000, 5000
    Move.Tick(0.02)
    letGoOver(origin, 5)
    show()
    check(count(one) == 2 and entry(one, 2).attrs.spell == 502 and entry(one, 1).alpha == 1 and entry(one, 2).alpha == 1
        and along(entry(one, 2)) == slot(2),
        "one taken from the middle: the next closes up into its place and is seen, no gap")
    W.placed[5] = nil
    fire("ACTIONBAR_SLOT_CHANGED", 5)
    stack("ActionButton1", 501)
    NS.Flyouts.Move(NS.Flyouts.At("ActionButton1"), 3, 2)
    flushAll()
    check(order() == "101 501 502", "and the flyout is put back as it was for the checks that follow")
    -- dragged out and let go on the plus of its own button: it stays where it was
    show()
    drag(entry(one, 3))
    W.mouseDown = true
    W.mouseX, W.mouseY = 5000, 5000
    Move.Tick(0.02)
    plus().scripts.OnReceiveDrag(plus())
    W.mouseDown = false
    Move.Tick(0.02)
    Move.Tick(0.02)
    flushAll()
    check(count(one) == 3 and order() == "101 501 502" and W.cursor == nil and entry(one, 3).alpha == 1,
        "let go on its own button's plus, it stays in its flyout, seen again")
    show()
end
W.shift, W.locked = false, false
show()
drag(entry(one, 3))
check(Move.Moving() ~= nil, "bars unlocked: a plain drag is enough")
tap("ESCAPE")
check(Move.Moving() == nil and entry(one, 3).alpha == 1, "the flyout shut under a move: the icon is back, nothing moved")
W.shift = true
show()
drag(entry(one, 2))
Move.Aim(3)
Move.Step(0.02)
fire("PLAYER_REGEN_DISABLED")
check(Move.Moving() == nil and entry(one, 2).alpha == 1 and along(entry(one, 3)) == slot(3) and order() == "101 501 502",
    "a fight beginning mid-move puts every icon back where it was")
W.combat = true
show()
drag(entry(one, 3))
check(Move.Moving() == nil and count(one) == 3 and W.cursor == nil and W.errors[#W.errors]:find("fight"),
    "in a fight a drag moves nothing")
tap("ESCAPE")
W.combat, W.shift = false, false

print("a flyout saved on a button that is gone, its ability on a hidden bar of the game's")
do
    -- as after a bar addon is taken off: the flyout was saved on one of its buttons
    local saved = NS.Flyouts.At("ActionButton1")
    saved.host = "GoneBarButton36"
    W.frames.ActionButton1.shown = false
    NS.Flyouts.Moved()
    fire("PLAYER_ENTERING_WORLD")
    check(saved.host == "ActionButton1", "it goes to the game's own button that holds its ability, hidden as that is")
    check(NS.Flyouts.Lost(saved) == false, "and waits there, to show with its bar")
    W.frames.ActionButton1.shown = true
    NS.Flyouts.Moved()
    fire("PLAYER_ENTERING_WORLD")
    check(saved.host == "ActionButton1" and opener("1") == one and NS.Flyouts.At("ActionButton1") == saved,
        "its bar shown again, it is on its button as before")
end

print("the game's key menu: a heading for each flyout, a row for each of its spots")
local Binds = NS.Binds
do
    local file = assert(io.open("Bindings.xml"))
    local xml = file:read("a")
    file:close()
    local spotsListed, picksListed, fine = 0, 0, true
    for name, category in xml:gmatch('<Binding name="([%w_]+)" category="([%w_]+)">') do
        if Binds.Number(name) then
            spotsListed = spotsListed + 1
            fine = fine and _G["BINDING_NAME_" .. name] ~= nil
        elseif name:find("^" .. Binds.PICK .. "%d+$") then
            picksListed = picksListed + 1
            fine = fine and _G["BINDING_NAME_" .. name] ~= nil
        elseif name:find("^PREFACE_") then
            fine = fine and type(_G[name]) == "string"
        else
            fine = fine and name:find("^HEADER_") ~= nil
        end
        fine = fine and category == Binds.CATEGORY
    end
    check(spotsListed == Binds.SLOTS * Binds.PLACES and picksListed == Binds.PLACES and fine
        and _G[Binds.CATEGORY] == "Fallen's Flyouts",
        "Bindings.xml lists every row the code reads, each with its text, under the addon's own heading")
end
local function rebound()
    W.clock = W.clock + 10
    fire("UPDATE_BINDINGS")
    W.ticker()
end
local function head(n) return _G[Binds.Heading(n)] end
local function spotName(n, i) return _G["BINDING_NAME_" .. Binds.Command(n, i)] end
local keyed, keyedUnit = NS.Flyouts.At("ActionButton1")
local second2 = "CLICK FallensFlyoutsEntry" .. one .. "_2:Key"
check(keyed.number == 1 and head(1) == "Spell 101" and spotName(1, 1) == "1: Spell 101" and spotName(1, 2) == "2: Spell 501"
    and spotName(1, 4) == "4: (empty)" and head(2) == "Flyout 2: none yet" and spotName(2, 1) == "1: (empty)",
    "a flyout has a heading named after its ability and a row for each icon; a spot or a heading with nothing says so")
-- a key on a spot's row picks that spot while its flyout is open
W.base.F9 = Binds.Command(1, 2)
rebound()
check(opener("F9") == nil and opener("1") == one, "a key on a spot's row opens nothing: the flyout opens by its bar button's key")
tap("E")
check(menu:IsShown() and GetBindingAction("F9", true) == second2 and label(2) == "F9",
    "with the flyout open, that key picks its spot, and the icon shows it")
tap("F9")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "pressed, it casts that icon and shuts the flyout")
check(GetBindingAction("F9", true) == Binds.Command(1, 2), "shut, the key is the row's again: it does nothing")
-- the rows for the spots of every flyout
W.base.T = Binds.PICK .. "2"
W.base.PADLSHOULDER = Binds.PICK .. "2"
rebound()
tap("E")
check(GetBindingAction("F9", true) == second2 and GetBindingAction("T", true) ~= second2,
    "a key set for spot 2 of every flyout stands behind this flyout's own row")
tap("E")
W.base.F9 = nil
rebound()
tap("E")
check(GetBindingAction("T", true) == second2 and label(2) == "T",
    "with none on the flyout's own row, the key for that spot of every flyout picks it")
check(GetBindingAction("PADLSHOULDER", true) == second2, "a pad button set there picks it too")
check(GetBindingAction("2", true) == "ACTIONBUTTON2", "and 2 is the bar's own then")
tap("T")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "pressed, it casts that icon and shuts the flyout")
check(GetBindingAction("T", true) == Binds.PICK .. "2", "shut, that key too is its row's again")
NS.Flyouts.SetKey(keyed, 2, "Y", false)
tap("E")
check(GetBindingAction("Y", true) == second2 and GetBindingAction("T", true) ~= second2,
    "an icon's own key stands before any row's")
tap("E")
NS.Flyouts.SetKey(keyed, 2, nil, false)
W.base.T, W.base.PADLSHOULDER = nil, nil
rebound()
check(opener("1") == one and label(2) == "2", "taken off in the menu, every key is as before")
-- a key change right after the addon's own binding is not lost
NS.Flyouts.Apply()
W.base.F12 = "ACTIONBUTTON1"
fire("UPDATE_BINDINGS")
W.clock = W.clock + 10
W.ticker()
check(opener("F12") == one, "a key given to the bar button in the moment after the addon bound its own is taken up all the same")
W.base.F12 = nil
rebound()
-- a heading with a key under it keeps its flyout when an earlier one goes; one with none closes up
stack("ActionButton2", 601)
stack("ActionButton3", 602)
local rowTwo, rowThree = NS.Flyouts.At("ActionButton2"), NS.Flyouts.At("ActionButton3")
check(rowTwo.number == 2 and rowThree.number == 3 and head(2) == "Spell 102" and head(3) == "Spell 103"
    and spotName(3, 2) == "2: Spell 602", "later flyouts take the next headings")
W.base.F10 = Binds.Command(3, 1)
rebound()
NS.Flyouts.Remove(rowTwo, 2)
check(NS.Flyouts.At("ActionButton2") == nil and rowThree.number == 3 and head(2) == "Flyout 2: none yet" and head(3) == "Spell 103",
    "one taken away, a flyout with a key under its heading keeps the heading and the key")
W.base.F10 = nil
rebound()
check(rowThree.number == 2 and head(2) == "Spell 103" and head(3) == "Flyout 3: none yet",
    "with no key under it, it closes up: the named headings are the flyouts on the bars, with no gaps")

-- his list (2026-11-21): six named rows, four flyouts on his bars. One sat on a bar of gamepad
-- mode, one was a leftover whose ability was on no bar any more.
local padBar = CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
actionButton("GamepadMainActionBarFrameTestActionButton1", 20, padBar).id = 20
W.placed = W.placed or {}
W.placed[20] = 811
fire("ACTIONBAR_SLOT_CHANGED", 20)
flushAll()
stack("GamepadMainActionBarFrameTestActionButton1", 812)
local onPad, padUnit = NS.Flyouts.At("GamepadMainActionBarFrameTestActionButton1")
check(onPad ~= nil and onPad.number == 3 and head(3) == "Spell 811 (gamepad mode)",
    "a flyout on a bar of gamepad mode has a heading too, and the heading says where it is")
NS.KeyMenu.Hover(Binds.Command(3, 1))
check(padUnit.ring.shown and not keyedUnit.ring.shown, "a hover on one of its rows lights its own button")
NS.KeyMenu.Hover(Binds.Command(3, 2))
check(padUnit.ring.shown, "and another row of the same flyout keeps it lit")
NS.KeyMenu.Hover(nil)
-- the leftover: its ability taken off the bars, the flyout is on no button
W.placed[3] = 999
fire("ACTIONBAR_SLOT_CHANGED", 3)
flushAll()
check(NS.Flyouts.At("ActionButton3") == nil and NS.Flyouts.Lost(rowThree) and rowThree.number == nil
    and head(2) == "Spell 811 (gamepad mode)" and head(3) == "Flyout 3: none yet",
    "a flyout whose ability is on no bar has no heading in the key menu; the rest close up")
W.placed[3] = nil
fire("ACTIONBAR_SLOT_CHANGED", 3)
flushAll()
check(NS.Flyouts.At("ActionButton3") == rowThree and rowThree.number == 3 and head(3) == "Spell 103", "back on a bar, it has a heading again")
W.base.F10 = Binds.Command(3, 2)
rebound()
W.placed[3] = 999
fire("ACTIONBAR_SLOT_CHANGED", 3)
flushAll()
check(rowThree.number == 3 and head(3):find("Spell 103 (off your bars)", 1, true) ~= nil and head(3):find("|cff808080", 1, true) == 1
    and spotName(3, 2) == "2: Spell 602", "with a key under its heading the heading is kept for it, grayed and marked off the bars")
W.placed[3] = nil
fire("ACTIONBAR_SLOT_CHANGED", 3)
flushAll()
W.base.F10 = nil
rebound()
check(rowThree.number == 3 and head(3) == "Spell 103", "and back on its bar the heading reads as before")
NS.Flyouts.Remove(onPad, 2)
W.placed[20] = nil
padBar:Hide()
NS.Flyouts.Remove(rowThree, 2)
check(NS.Flyouts.At("ActionButton3") == nil and head(2) == "Flyout 2: none yet" and head(3) == "Flyout 3: none yet"
    and spotName(2, 1) == "1: (empty)", "headings with no flyout left say so again, and their rows are empty")
NS.KeyMenu.Hover(Binds.Command(1, 1))
check(keyedUnit.ring.shown and keyedUnit.glow.shown, "a hover on a flyout's row in the key menu lights its bar button")
NS.KeyMenu.Hover(Binds.PICK .. "1")
check(not keyedUnit.ring.shown and not keyedUnit.glow.shown, "a hover on a row that is no one flyout's puts the light out")
NS.KeyMenu.Hover(Binds.Command(1, 3))
NS.KeyMenu.Hover(nil)
check(not keyedUnit.ring.shown, "and so does leaving the rows")

print("our key layers addon: its hold keys are left alone, and nothing is read off the bars while one is down")
do
    local held = false
    FallensFlyouts_Layers({ Held = function() return held end, HoldKeys = function() return { "1" } end })
    check(opener("1") == nil and opener("E") == one, "a key that holds a layer is no opener key, though it is the bar button's own")
    tap("E")
    check(menu:IsShown() and label(1) == "2" and label(2) == "3" and GetBindingAction("1", true) == "ACTIONBUTTON1",
        "nor a pick key: the spots take the next free keys, and the hold key is left to its addon")
    tap("E")
    local name, how = FallensFlyouts_KeyTarget("ActionButton1", "F7")
    check(name == "FallensFlyoutsOpener" .. one and how == "LeftButton" and FallensFlyouts_KeyTarget("ActionButton4", "F7") == nil,
        "asked what a key is to be bound to, to act as a button's key: the flyout's opener; nothing for a button with none")
    local _, tapped = FallensFlyouts_KeyTarget("ActionButton1", "3")
    check(tapped == "tap", "a key that is one of that flyout's picks is to tap the opener, not hold it")
    -- while a hold is down, the keys its layer sends to a button are not taken for the button's own
    held = true
    W.base.F7 = "ACTIONBUTTON1"
    rebound()
    check(opener("F7") == nil, "while a hold is down nothing is read off the bars: a layer's key is not taken for our own")
    W.placed = W.placed or {}
    W.placed[1] = 990
    fire("ACTIONBAR_SLOT_CHANGED", 1)
    flushAll()
    W.ticker()
    check(NS.Flyouts.At("ActionButton1") == keyed, "nor is a flyout moved off a button that shows another action for that time")
    W.placed[1] = nil
    fire("ACTIONBAR_SLOT_CHANGED", 1)
    flushAll()
    W.base.F7 = nil
    held = false
    rebound()
    check(NS.Flyouts.At("ActionButton1") == keyed and opener("F7") == nil and opener("E") == one, "the hold let go, all is read again and is as it was")
    local laid = 0
    FallensFlyouts_Watch(function() laid = laid + 1 end)
    NS.Flyouts.Apply()
    check(laid == 1, "it hears of every lay, to work its own plan out again")
    -- its root says which layer is on and which keys that layer has: an opener key of ours
    -- that is such a key just now is left to it, whenever our keys are bound in a fight or out
    local theirs = CreateFrame("Frame", "TestLayersRoot", UIParent, "SecureHandlerBaseTemplate")
    FallensFlyouts_Layers({ Held = function() return held end, HoldKeys = function() return {} end,
        Root = function() return theirs end })
    check(opener("E") == one and opener("1") == one, "with no layer on, every opener key is ours")
    theirs.attrs.layer = 1
    theirs.attrs.lkey1_E = true
    tap("1")
    tap("1")
    check(opener("E") == nil and opener("1") == one, "a layer on: the opener key that is one of its keys is left to it, at the next binding")
    theirs.attrs.layer = nil
    tap("1")
    tap("1")
    check(opener("E") == one, "the layer off, the key is ours again")
    FallensFlyouts_Layers(nil)
    check(opener("1") == one, "with no such addon about, the key opens its flyout as before")
    tap("E")
    check(label(1) == "1" and label(2) == "2", "and the spots have their own keys again")
    -- The names that addon reads off our root in its own snippets. They are a promise: a change
    -- here breaks it in a fight, where nothing can be worked out afresh.
    local promised = W.frames.FallensFlyoutsRoot.attrs
    local at = one .. "_1"
    check(promised.open == one and promised.units ~= nil and promised["opener" .. one] == "FallensFlyoutsOpener" .. one
        and promised["okeys" .. one] ~= nil and promised["okey" .. at] ~= nil and promised["obtn" .. at] ~= nil
        and promised["pkeys" .. one] ~= nil and promised["pkey" .. at] ~= nil
        and promised["pentry" .. at] == "FallensFlyoutsEntry" .. at and promised.ckeys ~= nil and promised.ckey1 ~= nil,
        "the root holds what that addon reads, under the names promised to it: the open flyout, each opener with its keys and clicks, the picks, the close keys")
    tap("E")
end

print("arranging a flyout without a drag, from the settings page")
do
    local Arrange, w = NS.Arrange, page.arrange
    local function press(button) button.scripts.OnClick(button) end
    check(w ~= nil and #w.icons == 6 and w.off ~= nil, "the page has the arrange row: six icon places, Previous, Next and Take Off")
    -- the page up, as when it is being used: it follows what changes on the bars
    page:Show()
    flushAll()
    check(w.which.text == "1 of 1: Spell 101" and w.icons[3].shown and not w.icons[4].shown and not w.off:IsEnabled(),
        "it shows the flyout on the bars, an icon for each of its three")
    press(w.icons[3])
    check(Arrange.Held() == 3 and w.icons[3].scale == 1.25 and w.icons[3].ring.shown and w.off:IsEnabled()
        and w.status.text:find("Spell 502", 1, true) ~= nil, "a press picks an icon up: it grows, and the page says what comes next")
    press(w.icons[1])
    check(order() == "502 101 501" and Arrange.Held() == nil and w.icons[1].scale == 1, "a press on another place moves it there")
    press(w.icons[1])
    press(w.icons[1])
    check(order() == "502 101 501" and Arrange.Held() == nil, "a second press on the picked icon puts it down where it was")
    press(w.icons[1])
    press(w.icons[3])
    check(order() == "101 501 502", "and it goes back the same way")
    W.combat = true
    press(w.icons[1])
    press(w.icons[2])
    check(order() == "101 501 502" and W.errors[#W.errors]:find("fight"), "in a fight nothing moves")
    W.combat = false
    press(w.icons[3])
    press(w.off)
    check(count(one) == 2 and lastChat("Spell 502 taken off the flyout") ~= nil and Arrange.Held() == nil,
        "Take Off takes the picked icon off its flyout")
    stack("ActionButton1", 502)
    stack("ActionButton2", 601)
    check(order() == "101 501 502" and w.which.text == "1 of 2: Spell 101" and w.next:IsEnabled(), "with two flyouts on the bars, Next is there")
    press(w.next)
    check(w.which.text:find("^2 of 2: ") ~= nil and w.icons[2].shown and not w.icons[3].shown, "Next shows the other flyout")
    press(w.next)
    check(w.which.text == "1 of 2: Spell 101", "and round to the first again")
    NS.Flyouts.Remove(NS.Flyouts.At("ActionButton2"), 2)
    check(w.which.text == "1 of 1: Spell 101", "a flyout taken away elsewhere is gone from the page too")
    page:Hide()
end

print("an upright bar whose other buttons are empty and hidden")
do
    -- His right-hand bar (2026-11-21): the flyout on its last button opened upward along the bar
    -- once the button beside it was hidden. Each button there sits in a holder that is no bar's shape.
    local hadPlaced = W.placed
    W.placed = W.placed or {}
    local edge = {}
    for i = 1, 3 do
        local holder = CreateFrame("Frame", nil, UIParent)
        edge[i] = actionButton("EdgeBarButton" .. i, 30 + i, holder)
        edge[i].cx, edge[i].cy = 1880, 300 + i * 40
    end
    W.placed[33] = 821
    fire("ACTIONBAR_SLOT_CHANGED", 33)
    flushAll()
    edge[1]:Hide()
    edge[2]:Hide()
    stack("EdgeBarButton3", 822)
    local _, edgeUnit = NS.Flyouts.At("EdgeBarButton3")
    check(edgeUnit ~= nil and edgeUnit.way == "LEFT" and edgeUnit.runs:find("up and down", 1, true) ~= nil,
        "with the buttons beside it hidden, the bar is still read as upright: the flyout opens to the side")
    edge[2]:Show()
    NS.Flyouts.Moved()
    NS.Flyouts.Follow()
    check(edgeUnit.way == "LEFT", "and it opens the same way when one of them is shown")
    local edgeFlyout = NS.Flyouts.At("EdgeBarButton3")
    if edgeFlyout then NS.Flyouts.Remove(edgeFlyout, 2) end
    W.placed[33] = nil
    if not hadPlaced then W.placed = nil end
    for i = 1, 3 do edge[i]:GetParent():Hide() end
    fire("ACTIONBAR_SLOT_CHANGED", 33)
    flushAll()
    check(NS.Flyouts.At("EdgeBarButton3") == nil and order() == "101 501 502", "the bars are as before")
end

print("ranks of one spell in a flyout stand in rank order, whichever the button holds")
do
    local hadPlaced = W.placed
    W.placed = W.placed or {}
    W.ranks = { [9001] = { "Mend", 1 }, [9002] = { "Mend", 2 }, [9003] = { "Mend", 3 } }
    local function ids(flyout)
        local out = {}
        for i, entry in ipairs(flyout.entries) do out[i] = tostring(entry.id) end
        return table.concat(out, " ")
    end
    -- the button holds rank 2; rank 1 is dragged onto it
    W.placed[8] = 9002
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    flushAll()
    stack("ActionButton8", 9001)
    local ranked = NS.Flyouts.At("ActionButton8")
    check(ranked ~= nil and ids(ranked) == "9001 9002" and ranked.main.id == 9002,
        "rank 1 put onto rank 2: rank 1 is the first icon, and the button keeps its own")
    stack("ActionButton8", 777)
    stack("ActionButton8", 9003)
    check(ids(ranked) == "9001 9002 777 9003", "another spell among them stays where it was put")
    NS.Flyouts.Move(ranked, 4, 1)
    check(ids(ranked) == "9001 9002 9003 777", "a rank moved by hand ahead of the lower ones: they stand in order in the places they hold")
    NS.Flyouts.Move(ranked, 4, 2)
    check(ids(ranked) == "9001 777 9002 9003", "the other spell moved in among them: it stays there, the ranks in order around it")
    -- the game names no rank for one of them: the spells' own numbers decide
    W.ranks[9002][2] = nil
    NS.Flyouts.Move(ranked, 4, 1)
    check(ids(ranked) == "9001 9002 777 9003", "with a rank the game does not name, they go by the spells' own numbers")
    W.ranks[9002][2] = 2
    local box = page.arrange.ranks
    check(box ~= nil and box:GetChecked() and NS.Flyouts.Ranked(), "the settings page has a check box for it, on to begin with")
    box.checked = false
    box.scripts.OnClick(box)
    NS.Flyouts.Move(ranked, 4, 1)
    check(not NS.Flyouts.Ranked() and ids(ranked) == "9003 9001 9002 777" and NS.Profiles.Data().unranked == true,
        "turned off there, the order is the player's own, and the profile remembers")
    box.checked = true
    box.scripts.OnClick(box)
    check(NS.Flyouts.Ranked() and ids(ranked) == "9001 9002 9003 777" and NS.Profiles.Data().unranked == nil,
        "turned on again, the ranks stand in order at once")
    W.combat = true
    box.checked = false
    box.scripts.OnClick(box)
    check(NS.Flyouts.Ranked() and box:GetChecked(), "in a fight the setting does not change, and the box shows it")
    W.combat = false
    while #ranked.entries > 1 and NS.Flyouts.At("ActionButton8") do NS.Flyouts.Remove(ranked, 1) end
    W.placed[8] = nil
    W.ranks = nil
    if not hadPlaced then W.placed = nil end
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    flushAll()
    check(NS.Flyouts.At("ActionButton8") == nil and order() == "101 501 502", "the bars are as before")
end

print("flyouts that fill themselves from the bags: food, drink and the rest, each kind apart")
do
    local Auto = NS.Auto
    local hadPlaced = W.placed
    W.placed = W.placed or {}
    W.macros, W.level = {}, 10
    -- sub: the game's kind (5 food and drink, 1 potion, 2 elixir); level: how good; needs: the level to use it
    W.items = {
        [4540] = { sub = 5, level = 5 }, [4541] = { sub = 5, level = 15, needs = 5 },
        [4542] = { sub = 5, level = 25, needs = 15 }, [4543] = { sub = 5, level = 20, needs = 10 },
        [159] = { sub = 5, drink = true, level = 5 }, [1179] = { sub = 5, drink = true, level = 15, needs = 5 },
        [118] = { sub = 1, level = 5 }, [5997] = { sub = 2, level = 5 },
    }
    W.bags = { 4540, 159, 4541, 118, 4542, 777777 }
    local function ids(flyout)
        local out = {}
        for i, entry in ipairs(flyout and flyout.entries or {}) do out[i] = tostring(entry.id) end
        return table.concat(out, " ")
    end
    local function bags(list)
        W.bags = list
        fire("BAG_UPDATE_DELAYED")
        flushAll()
    end
    local picked, macroName = Auto.Pick("food")
    check(picked == true and macroName == "Food" and W.cursor ~= nil and W.cursor[1] == "macro" and W.cursor[2] == "Food",
        "picked, a macro named for the kind is on the cursor")
    check(W.macros.Food ~= nil and W.macros.Food[1] == 133952 and W.macros.Food[2] == "#fallensflyouts food",
        "it is made with the kind's own fixed icon, never an item's, and marked as the addon's")
    check(NS.Flyouts.At("ActionButton9") == nil, "nothing is on a bar until it is dropped on one")
    PlaceAction(9)
    flushAll()
    local food, foodUnit = NS.Flyouts.At("ActionButton9")
    check(food ~= nil and food.auto == "food" and ids(food) == "4541 4540",
        "dropped on a bar button, its flyout is the food in the bags this character can eat, the best first")
    check(food ~= nil and food.main.kind == "macro" and food.main.id == "Food", "the macro leads it and is no icon in it")
    local before = #W.casts
    mouse(W.frames.ActionButton9)
    check(foodUnit ~= nil and foodUnit.menu:IsShown() and #W.casts == before, "a press on the button opens it")
    mouse(entry(foodUnit.index, 1))
    check(W.casts[#W.casts] == "item:item:4541" and not foodUnit.menu:IsShown(), "a pick eats that food and shuts it")
    bags({ 4540, 159, 118, 4542 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4540", "the last of one eaten: it is gone from the flyout")
    bags({ 4540, 159, 118, 4542, 4541, 4543 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4543 4541 4540", "more food in the bags: it is in the flyout, in its place by how good it is")
    fire("PLAYER_LEVEL_UP", 15)
    flushAll()
    check(ids(NS.Flyouts.At("ActionButton9")) == "4542 4543 4541 4540", "a level gained: food that needed it joins")
    -- nothing on a bar changes in a fight
    W.combat = true
    bags({ 159, 118 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4542 4543 4541 4540", "in a fight the flyout stays as it was")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    check(NS.Flyouts.At("ActionButton9") == nil and W.placed[9][2] == "Food", "the fight over and no food left: the button is its macro alone")
    bags({ 4540, 159, 118, 1179, 5997 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4540", "food again, the flyout is back by itself")
    -- drink is a kind apart, and so are the rest
    Auto.Pick("drink")
    PlaceAction(10)
    flushAll()
    check(ids(NS.Flyouts.At("ActionButton10")) == "1179 159" and W.macros.Drink[1] == 132793,
        "the drink flyout holds the drinks and no food, under its own icon")
    check(ids({ entries = (Auto.Entries("potions")) }) == "118" and ids({ entries = (Auto.Entries("elixirs")) }) == "5997"
        and ids({ entries = (Auto.Entries("scrolls")) }) == "", "potions and elixirs are each their own kind; a kind with nothing is empty")
    -- more kinds of food than a flyout holds
    for id = 4550, 4557 do W.items[id] = { sub = 5, level = id - 4500 } end
    bags({ 4540, 4550, 4551, 4552, 4553, 4554, 4555, 4556, 4557 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4557 4556 4555 4554 4553 4552", "with more than six kinds of food, the six best are shown")
    bags({ 4540, 159, 118, 1179, 5997 })
    -- the game has no word yet on an item: it joins when the word comes
    W.items[4544] = { sub = 5, level = 30, unknown = true }
    bags({ 4540, 159, 4544 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4540", "an item the game has no word on yet is left out for now")
    W.items[4544].unknown = nil
    fire("GET_ITEM_INFO_RECEIVED", 4544)
    flushAll()
    check(ids(NS.Flyouts.At("ActionButton9")) == "4544 4540", "and joins when the word comes")
    -- it is not changed by hand
    local errorsBefore = #W.errors
    stack("ActionButton9", 777)
    food = NS.Flyouts.At("ActionButton9")
    check(ids(food) == "4544 4540" and #W.errors == errorsBefore + 1 and W.errors[#W.errors]:find("fills itself", 1, true) ~= nil,
        "something dropped on its plus is refused, with the reason")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    local removed, whyNot = NS.Flyouts.Remove(food, 1)
    check(removed == false and whyNot ~= nil and NS.Flyouts.Move(food, 2, 1) == false and ids(food) == "4544 4540",
        "its icons are not taken off or moved by hand")
    check(head(food.number) == "Food" and spotName(food.number, 1) == "1: Item 4544", "its heading in the key menu is named after the kind, its rows after what is in it")
    -- a name already taken by a macro of the player's own
    W.macros.Potions = { 1, "/cast Something" }
    local _, potionName = Auto.Pick("potions")
    check(potionName == "Potions 2" and W.macros.Potions[2] == "/cast Something" and Auto.Macro("potions") == "Potions 2",
        "a macro of the player's own with that name is left alone: ours takes the next name")
    W.cursor = nil
    W.macroFull = true
    local elixir, whyFull = Auto.Pick("elixirs")
    check(elixir == false and whyFull == Auto.TEXT.full, "with the macro list full it says so and makes nothing")
    W.macroFull = nil
    W.combat = true
    check(Auto.Pick("scrolls") == false and W.macros.Scrolls == nil, "in a fight nothing is made or picked up")
    W.combat = false
    -- the settings page, and the same from chat
    local autoPage = NS.AutoUI.panel
    NS.AutoUI.Build()
    check(#autoPage.icons == #Auto.KINDS and autoPage.icons[1].icon.texture == 133952,
        "the settings page has an icon for each kind, the kind's own")
    W.cursor = nil
    autoPage.icons[2].scripts.OnClick(autoPage.icons[2])
    check(W.cursor ~= nil and W.cursor[2] == "Drink", "a click on one picks its macro up")
    W.cursor = nil
    autoPage.icons[1].scripts.OnDragStart(autoPage.icons[1])
    check(W.cursor ~= nil and W.cursor[2] == "Food", "so does a drag")
    W.cursor = nil
    SlashCmdList.FALLENSFLYOUTS("drink")
    check(W.cursor ~= nil and W.cursor[2] == "Drink", "and /ff drink from chat")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    -- the bars as they were
    local all = NS.Flyouts.List()
    for i = #all, 1, -1 do
        if all[i].auto then table.remove(all, i) end
    end
    W.placed[9], W.placed[10] = nil, nil
    W.macros, W.items, W.bags, W.level, W.macroCount = nil, nil, nil, nil, nil
    if not hadPlaced then W.placed = nil end
    NS.Flyouts.Apply()
    for _, slot in ipairs({ 9, 10 }) do fire("ACTIONBAR_SLOT_CHANGED", slot) end
    flushAll()
    check(NS.Flyouts.At("ActionButton9") == nil and NS.Flyouts.At("ActionButton10") == nil and order() == "101 501 502",
        "the bars are as before")
end

print("flyouts leave out the items the player has none of, till there are some again")
do
    local hadPlaced = W.placed
    W.placed = W.placed or {}
    local function ids(flyout)
        local out = {}
        for i, entry in ipairs(flyout and flyout.entries or {}) do out[i] = tostring(entry.id) end
        return table.concat(out, " ")
    end
    local function bags(list)
        W.bags = list
        fire("BAG_UPDATE_DELAYED")
        flushAll()
    end
    local function stackItem(host, id)
        W.cursor = { "item", id }
        fire("ACTIONBAR_SHOWGRID")
        local tab = tabOf(host)
        tab.scripts.OnReceiveDrag(tab)
        flushAll()
    end
    W.bags = { 601, 602, 603 }
    W.placed[8] = 9101
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    flushAll()
    for _, id in ipairs({ 601, 602, 603 }) do stackItem("ActionButton8", id) end
    local own = NS.Flyouts.At("ActionButton8")
    check(own ~= nil and ids(own) == "9101 601 602 603", "a flyout of a spell and three items, made by hand")
    check(NS.Flyouts.Hiding() and NS.Flyouts.SetHiding(false) == true, "the setting is on to begin with; it can be turned off")
    bags({ 601, 603 })
    check(ids(own) == "9101 601 602 603", "with it off, an item the player has none of stays in the flyout")
    check(NS.Flyouts.SetHiding(true) == true and ids(own) == "9101 601 603" and #NS.Flyouts.Full(own) == 4,
        "with it on, the flyout leaves that one out and keeps it in mind")
    bags({ 601, 602, 603 })
    check(ids(own) == "9101 601 602 603", "the item in the bags again: it is back, in its old place")
    bags({ 603 })
    check(ids(own) == "9101 603", "two of them gone at once")
    -- changed by hand while some are left out
    NS.Flyouts.Move(own, 2, 1)
    bags({ 601, 602, 603 })
    check(ids(own) == "603 601 602 9101", "an icon moved while others were left out: those come back in the places they had")
    bags({ 602, 603 })
    stackItem("ActionButton8", 602)
    check(#NS.Flyouts.Full(own) == 4, "an item that is in it already is not added a second time, shown or not")
    NS.Flyouts.Remove(own, 1)
    bags({ 601, 602, 603 })
    check(ids(own) == "601 602 9101", "one taken off by hand is gone for good; the ones left out were not")
    -- room is counted on the whole
    for id = 604, 606 do
        W.bags[#W.bags + 1] = id
        stackItem("ActionButton8", id)
    end
    bags({ 601 })
    local errorsBefore = #W.errors
    W.bags[#W.bags + 1] = 607
    stackItem("ActionButton8", 607)
    check(#NS.Flyouts.Full(own) == 6 and ids(own) == "601 9101" and #W.errors == errorsBefore + 1,
        "full is full, though only two of the six show")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    -- none of its items, and the spell taken off: nothing to show, yet still reached from the settings
    bags({})
    check(ids(own) == "9101" and NS.Flyouts.At("ActionButton8") == own, "with none of the items it shows what is left: the spell")
    NS.Arrange.Refresh()
    local box = page.arrange.hide
    check(box ~= nil and box:GetChecked(), "the settings page has a check box for it under Arrange, ticked")
    -- what is saved is the whole
    fire("PLAYER_LOGOUT")
    check(own.all == nil and #own.entries == 6, "what is saved is the whole flyout")
    NS.Flyouts.Apply()
    check(ids(own) == "9101" and #NS.Flyouts.Full(own) == 6, "and it is laid as before from that")
    box.checked = false
    box.scripts.OnClick(box)
    check(not NS.Flyouts.Hiding() and #own.entries == 6 and own.all == nil and NS.Profiles.Data().showLacking == true,
        "unticked: everything shows, whether the player has it or not, and the profile remembers")
    W.combat = true
    box.checked = true
    box.scripts.OnClick(box)
    check(not NS.Flyouts.Hiding() and not box:GetChecked(), "in a fight the setting does not change, and the box shows it")
    W.combat = false
    NS.Flyouts.SetHiding(true)
    check(NS.Profiles.Data().showLacking == nil, "ticked again, nothing is kept in the profile: it is how flyouts are")
    -- taken apart from the front: its spell is no longer its first icon
    for _ = 1, 8 do
        local left = NS.Flyouts.At("ActionButton8")
        if left then NS.Flyouts.Remove(left, 1) end
    end
    W.placed[8], W.bags = nil, nil
    if not hadPlaced then W.placed = nil end
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    flushAll()
    check(NS.Flyouts.At("ActionButton8") == nil and order() == "101 501 502", "the bars are as before")
end

print("the key that opened a flyout, pressed again, picks its spot: under a held modifier too")
do
    -- his controller (2026-11-21): a shoulder held and D-pad down opens a flyout; the same again
    -- only shut it, where D-pad down stands for the spot by the button
    local _, unit = NS.Flyouts.At("ActionButton1")
    W.base["SHIFT-PADDDOWN"] = "ACTIONBUTTON1"
    rebound()
    local first = "CLICK FallensFlyoutsEntry" .. unit.index .. "_1:Key"
    check(opener("SHIFT-PADDDOWN") == one, "a D-pad button under a held shoulder is the flyout's key")
    local castsBefore = #W.casts
    tap("SHIFT-PADDDOWN")
    check(unit.menu:IsShown() and GetBindingAction("SHIFT-PADDDOWN", true) == first and GetBindingAction("PADDDOWN", true) == first,
        "open, that same press is the pick of the spot the D-pad's down stands for, with the shoulder held or let go")
    tap("SHIFT-PADDDOWN")
    check(W.casts[#W.casts] == "spell:101" and #W.casts == castsBefore + 1 and not unit.menu:IsShown(),
        "pressed again it casts that spot and shuts the flyout: it is not just shut")
    tap("SHIFT-PADDDOWN")
    tap("SHIFT-PADDUP")
    check(W.casts[#W.casts] == "spell:502" and not unit.menu:IsShown(), "the other D-pad buttons under the shoulder pick their spots as before")
    W.base["SHIFT-PADDDOWN"] = nil
    rebound()
    check(opener("SHIFT-PADDDOWN") == nil and opener("1") == one, "the key taken away, all is as before")
end

print("the mouse on an icon: nothing on the press, the pick on the release")
do
    local _, unit = NS.Flyouts.At("ActionButton1")
    local icon = entry(unit.index, 2)
    tap("E")
    local castsBefore = #W.casts
    click(icon, true)
    check(unit.menu:IsShown() and #W.casts == castsBefore, "a mouse press on an icon casts nothing: it may be the start of a move")
    -- his report (2026-11-21): Shift held and the icon dragged out cast it first
    W.shift = true
    icon.scripts.OnDragStart(icon)
    check(NS.Move.Moving() and #W.casts == castsBefore, "dragged from there, it is lifted and still nothing was cast")
    NS.Move.Cancel()
    W.shift = nil
    click(icon, true)
    click(icon, false)
    check(W.casts[#W.casts] == "spell:501" and #W.casts == castsBefore + 1 and not unit.menu:IsShown(),
        "pressed and let go on the icon, it casts once, on the release, and the flyout shuts")
    tap("E")
    tap("2")
    check(W.casts[#W.casts] == "spell:501" and #W.casts == castsBefore + 2, "a pick key still casts on its press")
    -- the tooltip of a spell names its rank, as the spellbook's does
    icon.scripts.OnEnter(icon)
    check(W.tip ~= nil and W.tip.id == 501 and W.tip.rank == true, "an icon's tooltip asks for the spell with its rank")
    if unit.menu:IsShown() then tap("E") end
end

print("turning a flyout: pulled by its end to open another way, or to lie along its button")
do
    local Turn = NS.Turn
    local flyout, unit = NS.Flyouts.At("ActionButton1")
    -- the bar in the open, lying flat, so that every shape has room
    local was = {}
    local function bar(y)
        for i = 1, 12 do
            local button = W.frames["ActionButton" .. i]
            was[i] = was[i] or { button.cx, button.cy }
            button.cx, button.cy = 900 + (i - 1) * 50, y
        end
        NS.Flyouts.Moved()
        NS.Flyouts.Follow()
    end
    bar(500)
    local function shape(side, run)
        for _, s in ipairs(Turn.Shapes(unit)) do
            if s.side == side and s.run == run then return s end
        end
    end
    local function pull(side, run)
        local s = shape(side, run)
        Turn.At(s.x, s.y)
    end
    check(unit.side == "UP" and unit.way == "UP" and flyout.side == nil and #Turn.Shapes(unit) == 16,
        "left alone it opens straight out the bar's way; there are sixteen shapes it could take")
    local START, CAP = NS.Art.NAMES.first, NS.Art.NAMES.last
    local function cut(piece) return table.concat(piece.cut, " ") end
    local function turned(degrees) return table.concat(NS.Art.CUT[degrees], " ") end
    check(unit.strip.first.atlas == START and unit.strip.capped == false,
        "straight out, the strip's near end is the open one, onto the button")
    check(Turn.Start(unit) == false, "a shut flyout is not turned")
    tap("E")
    check(unit.menu:IsShown() and (Turn.Grip() == nil or not Turn.Grip():IsShown()),
        "opened by its key with the mouse elsewhere, it shows nothing new: no grip")
    unit.menu.over = true
    Turn.Poll()
    local grip = Turn.Grip()
    check(grip ~= nil and grip:IsShown() and grip.point[2] == unit.menu and grip.point[3] == "TOP",
        "with the mouse on the open flyout, out of a fight, a grip shows at its far end")
    unit.menu.over = nil
    Turn.Poll()
    check(grip:IsShown(), "the mouse just off it, the grip stays a moment, to be reached")
    W.clock = W.clock + 1
    Turn.Poll()
    check(not grip:IsShown(), "the mouse gone, so is the grip")
    unit.menu.over = true
    Turn.Poll()
    W.cursor = { "spell", 7, "spell", 777, 777 }
    Turn.Poll()
    check(not grip:IsShown(), "with something on the cursor, carried to the flyout, there is no grip in the way")
    W.cursor = nil
    Turn.Poll()
    check(grip:IsShown(), "the cursor empty again, it is back")
    check(Turn.Start(unit) == true and Turn.Turning(), "the grip grabbed, a turn is under way")
    pull("RIGHT", "RIGHT")
    check(unit.side == "RIGHT" and unit.way == "RIGHT" and unit.menu.point[1] == "LEFT" and unit.menu.point[3] == "RIGHT"
        and unit.menu:IsShown(), "pulled out to the right of the button, it opens to the right at once, still open")
    check(grip.point[3] == "RIGHT" and unit.arrow.point[1] == "RIGHT", "the grip is at its new end, and the button's arrow points that way")
    pull("UP", "RIGHT")
    check(unit.side == "UP" and unit.way == "RIGHT" and unit.menu.point[1] == "BOTTOMLEFT" and unit.menu.point[3] == "TOPLEFT",
        "pulled up and across, it lies as a row over the button, running right from it")
    check(unit.arrow.point[1] == "TOP" and entry(unit.index, 2).point[1] == "LEFT",
        "the arrow says above; the icons run along the row")
    -- His report (2026-11-21): lying along its button the strip had no edge at its near end. It is closed
    -- there as at the far end: the end art, turned about.
    check(unit.strip.capped == true and unit.strip.first.atlas == CAP and unit.strip.last.atlas == CAP
        and cut(unit.strip.first) == turned(270) and cut(unit.strip.last) == turned(90),
        "lying along the button, the strip is closed at both ends: the far end's art at the near end, turned about")
    -- and it can lie centered on its button
    local function centered(side, run)
        for _, s in ipairs(Turn.Shapes(unit)) do
            if s.side == side and s.run == run and s.mid then return s end
        end
    end
    local mid, corner = centered("UP", "RIGHT"), shape("UP", "RIGHT")
    local host = W.frames.ActionButton1
    -- His report (2026-11-21): centering was hard to hit. Its mark was where the centered flyout would
    -- end; it is the middle of that side of the button now, where he looked for it.
    check(mid ~= nil and corner ~= nil and not corner.mid and centered("UP", "LEFT") == nil and mid.x == host.cx
        and mid.y > host.cy and mid.y - host.cy < corner.x - host.cx,
        "each side has one centered shape, and its mark is by the middle of that side of the button, nearer than any end")
    -- a real pull is followed only once the mouse has stayed a moment: shapes passed on the way are not laid
    Turn.At(mid.x, mid.y, true)
    check(unit.mid ~= true and unit.way == "RIGHT" and unit.menu.point[1] == "BOTTOMLEFT",
        "the mouse just arrived at a mark, nothing is laid out yet")
    W.clock = W.clock + 0.05
    Turn.At(corner.x, corner.y, true)
    W.clock = W.clock + 0.05
    Turn.At(mid.x, mid.y, true)
    check(unit.mid ~= true, "passing over another mark on the way starts the wait again")
    W.clock = W.clock + 0.1
    Turn.At(mid.x + 3, mid.y - 2, true)
    check(unit.side == "UP" and unit.way == "RIGHT" and unit.mid == true and unit.menu.point[1] == "BOTTOM"
        and unit.menu.point[3] == "TOP" and unit.strip.capped == true,
        "pulled to that end it snaps centered: a row over the button, its middle over the button's middle")
    Turn.Stop()
    check(flyout.side == "UP" and flyout.run == "RIGHT" and flyout.mid == true, "let go, centered is the flyout's own shape")
    NS.Flyouts.Apply()
    tap("E")
    check(unit.mid == true and unit.menu.point[1] == "BOTTOM", "and it is kept when laid again")
    Turn.Start(unit)
    pull("UP", "RIGHT")
    check(unit.mid == false and flyout.mid == nil and unit.menu.point[1] == "BOTTOMLEFT", "pulled back to the corner shape it is off center again")
    pull("UP", "LEFT")
    check(unit.way == "LEFT" and unit.menu.point[1] == "BOTTOMRIGHT" and unit.menu.point[3] == "TOPRIGHT", "or running left")
    pull("LEFT", "DOWN")
    check(unit.side == "LEFT" and unit.way == "DOWN" and unit.menu.point[1] == "TOPRIGHT" and unit.menu.point[3] == "TOPLEFT",
        "beside the button it lies as a column, here running down")
    check(Turn.Stop() == true and not Turn.Turning() and flyout.side == "LEFT" and flyout.run == "DOWN" and unit.menu:IsShown(),
        "let go, the shape is the flyout's own from then on, and it is open as it was")
    tap("E")
    NS.Flyouts.Moved()
    NS.Flyouts.Follow()
    NS.Flyouts.Apply()
    check(unit.side == "LEFT" and unit.way == "DOWN", "laid again later, it keeps the shape")
    tap("E")
    Turn.Start(unit)
    pull("UP", "UP")
    Turn.Stop()
    check(flyout.side == nil and flyout.run == nil and unit.side == "UP", "pulled back to where the bar would open it, it is the bar's again")
    -- a shape that would leave the screen is not taken
    tap("E")
    bar(30)
    tap("E")
    local below = shape("DOWN", "DOWN")
    Turn.Start(unit)
    Turn.At(below.x, below.y)
    check(below.fits == false and unit.side ~= "DOWN", "a shape that would run off the screen is not offered")
    Turn.Stop()
    NS.Flyouts.SetShape(flyout, nil)
    -- in a fight
    W.combat = true
    fire("PLAYER_REGEN_DISABLED")
    check(not grip:IsShown() and Turn.Start(unit) == false, "in a fight there is no grip and nothing turns")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    if unit.menu:IsShown() then tap("E") end
    -- stepped through from the settings, for those with no mouse
    bar(500)
    NS.Arrange.Refresh()
    local seen = {}
    for _ = 1, 16 do
        page.arrange.turn.scripts.OnClick(page.arrange.turn)
        seen[unit.side .. ">" .. unit.way .. (unit.mid and " centered" or "")] = true
    end
    local kinds = 0
    for _ in pairs(seen) do kinds = kinds + 1 end
    check(kinds == 16 and seen["DOWN>RIGHT centered"] and seen["LEFT>DOWN centered"] and flyout.side == nil,
        "the Turn button under Arrange steps through all sixteen, the centered ones among them, and comes round to the bar's own")
    unit.menu.over = nil
    for i = 1, 12 do W.frames["ActionButton" .. i].cx, W.frames["ActionButton" .. i].cy = was[i][1], was[i][2] end
    NS.Flyouts.SetShape(flyout, nil)
    NS.Flyouts.Moved()
    NS.Flyouts.Follow()
    check(unit.side == "UP" and unit.way == "UP" and order() == "101 501 502" and opener("1") == one, "the bars are as before")
end

print("gamepad mode, binding or moving onto a taken button: swap the old one out, or add to its flyout")
do
    local Pad = NS.PadBind
    -- the game's hint bar maker: a bar of prompts, each a button's symbol and a text
    InputPromptLegends = { CreateInputLegend = function(parent, key)
        local bar = CreateFrame("Frame", nil, parent)
        bar.made, bar.laid = {}, 0
        function bar:GetOrCreatePromptFrameUsingTemplateAndInputs(template, keys)
            local id = template .. table.concat(keys)
            if not self.made[id] then
                local prompt = CreateFrame("Frame", nil, self)
                prompt.key = keys[1]
                function prompt:SetPromptText(text) self.label = text end
                function prompt:EnablePrompt() self.on = true end
                self.made[id] = prompt
            end
            return self.made[id]
        end
        function bar:ApplyDefaultPromptPositioning() self.laid = self.laid + 1 end
        parent[key] = bar
        return bar
    end }
    -- The game's dialog, as its code runs it. It takes every pad button itself: with a trigger held
    -- the press places onto that group's button, a bare face button places nothing. An empty button
    -- takes the ability; a taken one takes it too, and the dialog then holds the old one.
    local dialog = CreateFrame("Frame", "TestPadBindDialog", UIParent)
    dialog.BindingInfoFrame = CreateFrame("Frame", nil, dialog)
    -- the box's own words: its title, its instruction, and the name and icon of the ability it holds
    local box = dialog.BindingInfoFrame
    box.TitleBox = CreateFrame("Frame", nil, box)
    box.TitleBox.TitleText = box.TitleBox:CreateFontString()
    box.BindInstructionText, box.ActionName, box.ActionIcon = box:CreateFontString(), box:CreateFontString(), box:CreateTexture()
    for _, region in ipairs({ box.TitleBox.TitleText, box.BindInstructionText, box.ActionName, box.ActionIcon }) do region.alpha = 1 end
    dialog.ActionTooltip = CreateFrame("Frame", nil, dialog)
    dialog:Hide()
    -- As the game's: while it is up the bar itself is put away, and the dialog shows copies
    -- of the bar's buttons, each of the same slot as the button it stands for.
    local console = W.frames.MainActionBar
    -- (the dialog reads a copy's slot off its ID: "storage slots as their IDs", in its own words)
    for i = 1, 9 do actionButton("GamepadActionBarEditFrameTestActionButton" .. i, i, dialog).id = i end
    dialog.scripts.OnShow = function() console:Hide() end
    dialog.scripts.OnHide = function() console:Show() end
    function dialog:StartListeningForButtons()
        self.scripts.OnGamePadButtonDown = function(me)
            if me.heldSlot then me:PlaceOrClearHeldActionCapturedInputHandler(me.heldSlot, false, me.plain) end
        end
    end
    function dialog:EnterBindingMode()
        self.plain = true
        self.BindingInfoFrame:Show()
        self:Show()
        self:StartListeningForButtons()
    end
    function dialog:ExitBindingMode()
        self.BindingInfoFrame:Hide()
        self:Hide()
    end
    -- Edit Action Bar: an ability picked up off a button is held, to be put on another
    function dialog:EnterEditMode()
        self.plain = false
        self:Show()
        self:StartListeningForButtons()
    end
    function dialog:TransitionToSelectActionToPickup() self.BindingInfoFrame:Hide() end
    -- as the game's: the ability comes off the button and is held, and the box says what is held
    function dialog:SelectActionToPickupCapturedInputHandler(slot)
        ClearCursor()
        local _, had = GetActionInfo(slot)
        if not had then return false end
        W.placed[slot] = false
        fire("ACTIONBAR_SLOT_CHANGED", slot)
        self.pickupFunc, self.pickupParams, self.pickupSlot = C_Spell.PickupSpell, { had }, slot
        self.BindingInfoFrame:Show()
        return true
    end
    function dialog:ExitEditMode() self:Hide() end
    function dialog:PlaceOrClearHeldActionCapturedInputHandler(slot, _, exitOnBind)
        local _, had = GetActionInfo(slot)
        ClearCursor()
        self.pickupFunc(table.unpack(self.pickupParams))
        PlaceAction(slot)
        ClearCursor()
        if not had then
            if exitOnBind then self:ExitBindingMode() else self:TransitionToSelectActionToPickup() end
            return true
        end
        self.pickupFunc, self.pickupParams = C_Spell.PickupSpell, { had }
        return true
    end
    -- a press is its own moment in time
    local function press(key, slot)
        W.clock = W.clock + 1
        dialog.heldSlot = slot
        dialog.scripts.OnGamePadButtonDown(dialog, key)
        dialog.heldSlot = nil
    end
    local function bind(id, slot)
        dialog.pickupFunc, dialog.pickupParams = C_Spell.PickupSpell, { id }
        dialog:EnterBindingMode()
        press("PAD4", slot)
    end
    local function up()
        local bar = Pad.Bar()
        return bar ~= nil and bar:IsVisible()
    end
    check(Pad.Install(dialog) == true, "the addon listens in on the game's dialog")
    bind(701, 5)
    check(not up() and Pad.Offer() == nil and W.placed[5] == 701, "bound onto an empty button, the ability is placed and nothing is offered")
    bind(702, 2)
    local bar, prompts = Pad.Bar()
    check(W.placed[2] == 702, "bound onto a taken button, the new ability takes the old one's place, as ever")
    check(up() and Pad.Offer() ~= nil and bar.laid > 0, "and a hint bar of the game's own make comes up over the dialog's")
    check(prompts.add.key == "PAD1" and prompts.add.label == "Add to Flyout" and prompts.add.shown
        and prompts.back.key == "PAD2" and prompts.back.label == "Swap Out" and prompts.back.shown
        and prompts.edit.key == "PAD4" and prompts.edit.shown,
        "in a bind it names both ways on: A adds to a flyout, B swaps the old one out; and the game's own Y")
    -- His words (2026-11-21): "it should show a preview of what it will look like, and update in real time",
    -- and an X option for a round background with a border.
    local view = Pad.View()
    check(view ~= nil and view:IsShown() and view.count == 2 and view.tokens[1]:IsShown() and view.tokens[2]:IsShown()
        and not view.tokens[3]:IsShown() and view.tokens[1].icon.texture == Pad.Offer().old.id
        and view.tokens[2].icon.texture == Pad.Offer().new.id and Pad.Offer().new.id == 702,
        "a picture shows the flyout as it would be: what the button held and the new one, around the button")
    check(view.around == W.frames.GamepadActionBarEditFrameTestActionButton2,
        "in place: it stands around the dialog's own copy of the button being bound")
    check(view.tokens[1].pad == "PADDUP" and view.tokens[2].pad == "PADDRIGHT" and view.tokens[1].point[5] > 0 and view.tokens[2].point[4] > 0,
        "each in its place, with the pad button that would pick it")
    check(prompts.left.shown and prompts.left.key == "PAD3" and prompts.left.label == "Hide Background" and view.plate.rim.shown,
        "the left button, free in a bind, shows or hides the round background, which the picture shows too")
    press("PAD3")
    check(NS.Flyouts.Plate() == false and prompts.left.label == "Show Background" and not view.plate.rim.shown and Pad.Offer() ~= nil,
        "X: the background is off, in the picture at once, and the offer stands")
    press("PAD3")
    check(NS.Flyouts.Plate() == true and view.plate.rim.shown, "X again: on")
    press("PAD2")
    dialog:ExitBindingMode()
    check(not up() and Pad.Offer() == nil and W.placed[2] == 702 and NS.Flyouts.At("ActionButton2") == nil,
        "B: the game shuts its dialog, the swap stands and no flyout is made")
    bind(703, 2)
    press("PADLSHOULDER")
    check(Pad.Offer() ~= nil and W.placed[2] == 703 and NS.Flyouts.Plate() == true, "a button that is not the hint's changes nothing")
    press("PAD1")
    local made = NS.Flyouts.At("ActionButton2")
    check(W.placed[2] == 702 and W.cursor == nil, "A: the old ability is back on the button and the cursor is empty")
    check(made ~= nil and #made.entries == 2 and made.main.id == 702 and made.entries[2].id == 703,
        "and the new one is in a flyout made on that button")
    check(lastChat("Spell 703 is in the flyout of Spell 702 now") ~= nil and up() and prompts.back.label == "Done",
        "chat says so, and the bar now says B is Done")
    -- His idea (2026-11-21): a quick swap of what picks from the flyout, as it is made, on a button the
    -- hint bar names.
    check(prompts.add.shown and prompts.add.label == "Use Face Buttons" and NS.Flyouts.Faces(made) == false,
        "and A, its work done, now offers the pad's other cross for picking from this flyout")
    press("PAD1")
    check(NS.Flyouts.Faces(made) == true and made.face == true and prompts.add.label == "Use D-Pad" and up(),
        "A again: this flyout picks with the face buttons, and the bar offers the D-pad back")
    check(view:IsShown() and view.tokens[1].pad == "PAD4" and view.tokens[2].pad == "PAD2" and view.tokens[1].icon.texture == 702,
        "and the picture changes with it: the flyout as it now is, each icon under its face button")
    press("PAD1")
    check(NS.Flyouts.Faces(made) == false and prompts.add.label == "Use Face Buttons", "and again: the D-pad once more")
    dialog:ExitBindingMode()
    check(not up(), "the dialog shut, the bar goes with it")

    -- his own way of trying it: the same two abilities onto the same button, over and over
    local offered = 0
    for _ = 1, 6 do
        bind(703, 2)
        if Pad.Offer() ~= nil and up() then offered = offered + 1 end
        press("PAD1")
        dialog:ExitBindingMode()
        flushAll()
    end
    made = NS.Flyouts.At("ActionButton2")
    check(offered == 6, "the same ability bound onto the same button six times running: offered every time (" .. offered .. ")")
    check(made ~= nil and #made.entries == 2 and W.placed[2] == 702, "and each time the flyout is as it was: its lead on the button, the other in it")
    for _ = 1, 3 do
        bind(703, 2)
        dialog:ExitBindingMode()
        flushAll()
        bind(702, 2)
        if Pad.Offer() == nil then offered = offered + 100 end
        press("PAD1")
        dialog:ExitBindingMode()
        flushAll()
    end
    made = NS.Flyouts.Of({ kind = "spell", id = 703 }) or NS.Flyouts.Of({ kind = "spell", id = 702 })
    check(offered == 6 and made ~= nil and #made.entries == 2, "swapped out, then the old one bound back over it: offered again, the two still one flyout")
    while NS.Flyouts.Of({ kind = "spell", id = 703 }) do NS.Flyouts.Remove(NS.Flyouts.Of({ kind = "spell", id = 703 }), 2) end
    while NS.Flyouts.Of({ kind = "spell", id = 702 }) do NS.Flyouts.Remove(NS.Flyouts.Of({ kind = "spell", id = 702 }), 2) end

    bind(704, 1)
    -- time passes: the flyout's lead is off its button for now, so the flyout has left it
    flushAll()
    press("PAD1")
    flushAll()
    check(order() == "101 501 502 704" and NS.Flyouts.At("ActionButton1") ~= nil and W.placed[1] == 101,
        "onto a button that has a flyout: the new one joins it, and the lead is on its button again")
    dialog:ExitBindingMode()
    bind(705, 3)
    local before = Pad.Offer()
    -- A with a trigger held is a bind onto that group's A button, not our hint
    press("PAD1", 2)
    check(Pad.Offer() ~= nil and Pad.Offer() ~= before and Pad.Offer().slot == 2 and W.placed[3] == 705,
        "A pressed with a trigger held binds as the game means it, and is not taken for the hint")
    dialog:ExitBindingMode()

    -- moving abilities about: what was picked up off one button is put onto a taken one
    W.placed[2] = nil
    dialog.pickupFunc, dialog.pickupParams = C_Spell.PickupSpell, { 706 }
    dialog:EnterEditMode()
    dialog.BindingInfoFrame:Show()
    press("PAD4", 3)
    check(Pad.Offer() ~= nil and Pad.Offer().moving == true and up(), "while abilities are moved about it is offered too")
    check(prompts.add.shown and prompts.left.shown and prompts.left.label == "Swap Out" and not prompts.edit.shown
        and prompts.back.shown and prompts.back.label == "Cancel",
        "there the bar reads: A adds to a flyout, X swaps the old one out, B cancels, as the game's own buttons do")
    press("PAD1")
    made = NS.Flyouts.At("ActionButton3")
    check(made ~= nil and made.entries[2].id == 706 and up() and prompts.left.label == "Done" and not prompts.back.shown,
        "A there: stacked the same way, and the bar says X is Done")
    dialog:TransitionToSelectActionToPickup()
    check(not up(), "the held one let go, the bar is gone")
    dialog:ExitEditMode()

    -- His words (2026-11-21): Edit Action Bar on one of our flyouts "just removes it from the button
    -- immediately ... and we have no option like Edit flyout": rearrange, remove, D-pad or face buttons.
    -- Then, of the first build, which edited inside the game's dialog: "i just hit the fking d pad up
    -- button expecting my selected d pad right one in the flyout to go to up. guess what it did instead?
    -- replaced my fucking d pad up bind". The dialog places the ability it holds at every D-pad press and
    -- no addon may take those presses from it. So nothing is edited while it is up.
    do
        local Edit = NS.PadEdit
        -- a flyout of its own for this, of three, on a button of its own
        W.placed[7] = 771
        fire("ACTIONBAR_SLOT_CHANGED", 7)
        flushAll()
        stack("ActionButton7", 772)
        stack("ActionButton7", 773)
        local target = NS.Flyouts.At("ActionButton7")
        local function ids()
            local out = {}
            for i, e in ipairs(target.entries) do out[i] = tostring(e.id) end
            return table.concat(out, " ")
        end
        local function bound(key) return GetBindingAction(key, true) == "CLICK FallensFlyoutsPadEdit" .. key .. ":LeftButton" end
        local function pickUp(slot)
            W.clock = W.clock + 1
            dialog:SelectActionToPickupCapturedInputHandler(slot)
        end
        dialog:EnterEditMode()
        pickUp(5)
        check(Pad.Picked() == nil and not up(), "a button with no flyout picked up: nothing is offered")
        dialog:TransitionToSelectActionToPickup()
        W.placed[5] = 701
        -- a taken spot and an empty one beside it, for what follows
        W.placed[4] = 704
        W.placed[6] = false
        fire("ACTIONBAR_SLOT_CHANGED", 5)
        flushAll()
        pickUp(7)
        check(Pad.Picked() ~= nil and up() and prompts.add.label == "Edit Flyout" and prompts.add.shown and prompts.back.label == "Cancel"
            and prompts.left.shown and not prompts.edit.shown and GetActionInfo(7) == nil,
            "a flyout's button picked up: its ability is off the button and held, and A offers Edit Flyout")
        -- His words: "why are you showing the flyout here? why not show in place".
        check(Pad.View():IsShown() and Pad.View().count == 3 and Pad.View().around == W.frames.GamepadActionBarEditFrameTestActionButton7,
            "the flyout is pictured in place: around the dialog's own copy of that button")
        check(box.BindInstructionText.alpha == 1 and (Pad.Panel() == nil or not Pad.Panel():IsShown()),
            "the box still speaks of the ability the game holds: that is what is so until A is pressed")
        press("PAD1")
        check(Pad.Armed() ~= nil and Pad.Picked() == nil and select(2, GetActionInfo(7)) == 771 and NS.Flyouts.At("ActionButton7") == target
            and ids() == "771 772 773",
            "A: the ability is back on its button at once and the flyout is whole")
        check(Edit.Editing() == nil and not bound("PADDUP") and not bound("PAD1"),
            "nothing is edited while the game's dialog is up: there the D-pad is the game's")
        check(prompts.back.shown and prompts.back.label == "Open Flyout Editor" and not prompts.add.shown and not prompts.left.shown
            and not prompts.edit.shown, "the bar names the one button to press: B opens the flyout editor")
        local words = Pad.Panel()
        check(words ~= nil and words:IsShown() and words:GetFrameStrata() == "TOOLTIP" and words.title.text == "Edit Flyout"
            and words.lines[1].text:find("to leave Edit Action Bar", 1, true) ~= nil and words.lines[2].text == "The flyout editor opens then."
            and words.lines[3].text == "The D-pad moves the icons there. Pressed here it changes nothing.",
            "the box says so in the top layer, and where the D-pad does its work: " .. tostring(words.lines[3].text))
        check(box.BindInstructionText.alpha == 0 and box.ActionName.alpha == 0 and box.TitleBox.TitleText.alpha == 0,
            "the game's words about binding the ability are out of sight meanwhile")
        -- What he did (2026-11-21): the D-pad pressed there, to move an icon. The dialog sets the ability it
        -- thinks it holds down on that spot and takes hold of what was there: "replaced my ... d pad up bind".
        -- Now each such press is undone at once, on a taken spot and on an empty one, time after time.
        local function bars() return table.concat({ tostring(W.placed[4]), tostring(W.placed[5]), tostring(W.placed[6]),
            tostring(W.placed[7]) }, " ") end
        local before = bars()
        press("PADDUP", 4)
        check(bars() == before and W.placed[4] == 704, "D-pad up pressed there, on a taken spot: the spot holds what it held: " .. bars())
        check(Pad.Armed() ~= nil and words:IsShown() and prompts.back.label == "Open Flyout Editor" and Pad.Offer() == nil
            and not dialog.ActionTooltip.shown,
            "and the box still says how to go on; nothing else is offered over it")
        press("PADDRIGHT", 5)
        press("PADDUP", 4)
        check(bars() == before, "pressed again and again, on other taken spots: every one as it was: " .. bars())
        press("PADDDOWN", 7)
        check(bars() == before and NS.Flyouts.At("ActionButton7") == target and ids() == "771 772 773",
            "pressed for the flyout's own button: its ability stays and the flyout is whole")
        press("PADDLEFT", 6)
        check(bars() == before and W.placed[6] == false, "pressed for an empty spot: the spot is empty again: " .. bars())
        check(Pad.Armed() ~= nil and prompts.back.shown and prompts.back.label == "Open Flyout Editor" and not words:IsShown()
            and box.BindInstructionText.alpha == 1,
            "the dialog, holding nothing now, is back at its first step: our bar still names the button that opens the editor")
        -- another ability picked up there: the edit asked for is off
        pickUp(5)
        check(Pad.Armed() == nil and not up(), "another ability picked up instead: no editor is waiting any more")
        dialog:TransitionToSelectActionToPickup()
        W.placed[5] = 701
        W.placed[4] = nil
        fire("ACTIONBAR_SLOT_CHANGED", 5)
        dialog:ExitEditMode()
        flushAll()
        check(Edit.Editing() == nil and not bound("PADDUP"), "the dialog left after that, nothing opens")

        -- a flyout that lies along its button as a strip has no editor of this kind: nothing is offered
        NS.Flyouts.SetAround(false)
        dialog:EnterEditMode()
        pickUp(7)
        check(Pad.Picked() == nil and not up(), "a flyout that does not stand around its button: Edit Flyout is not offered")
        dialog:TransitionToSelectActionToPickup()
        W.placed[7] = 771
        fire("ACTIONBAR_SLOT_CHANGED", 7)
        dialog:ExitEditMode()
        NS.Flyouts.SetAround(true)
        flushAll()

        -- the way meant: pick up, A, B
        dialog:EnterEditMode()
        pickUp(7)
        press("PAD1")
        dialog:ExitEditMode()
        flushAll()
        local e = Edit.Editing()
        check(e ~= nil and e.flyout == target and e.mark == 1 and not dialog:IsShown(), "the dialog left, the editor opens for that flyout")
        check(bound("PADDUP") and bound("PADDRIGHT") and bound("PADDDOWN") and bound("PADDLEFT") and bound("PAD1") and bound("PAD2")
            and bound("PAD3") and bound("PAD4") and bound("PADRSHOULDER"),
            "in it the pad's buttons are the editor's own")
        check(Pad.View():IsShown() and Pad.View().around == W.frames.ActionButton7 and Pad.View().marked == 1 and Pad.View().tokens[1].ring.shown,
            "the flyout is pictured in place around its own button, the first icon selected")
        check(prompts.add.label == "Select Next Icon" and prompts.left.label == "Take Icon Off" and prompts.edit.label == "Use Face Buttons"
            and prompts.back.label == "Done" and prompts.plate ~= nil and prompts.plate.label == "Hide Background",
            "the bar names every button: A selects, X takes off, Y swaps the pad's crosses, RB the background, B is Done")
        -- what he did: an icon selected, then D-pad for the side it should go to
        tap("PAD1")
        check(Edit.Editing().mark == 2 and Pad.View().marked == 2, "A: the next icon is selected (the one to the right)")
        tap("PADDUP")
        check(ids() == "772 771 773" and Edit.Editing().mark == 1 and Pad.View().marked == 1 and W.placed[4] == nil
            and select(2, GetActionInfo(7)) == 771,
            "D-pad up: the selected icon goes up, and the one that was up takes its place; nothing on the bars is touched: " .. ids())
        tap("PADDDOWN")
        check(ids() == "773 771 772" and Edit.Editing().mark == 3, "D-pad down: it changes places with the one below: " .. ids())
        tap("PADDLEFT")
        check(ids() == "773 771 772" and Edit.Editing().mark == 3 and NS.PadEdit.Hint():find("No icon is on that side", 1, true) ~= nil,
            "D-pad left, where no icon is: nothing moves, and the line over the bar says why")
        tap("PAD4")
        check(NS.Flyouts.Faces(target) == true and prompts.edit.label == "Use D-Pad" and Pad.View().tokens[1].pad == "PAD4",
            "Y: this flyout picks with the face buttons, the picture with it")
        tap("PAD4")
        tap("PADRSHOULDER")
        check(NS.Flyouts.Plate() == false and prompts.plate.label == "Show Background" and not Pad.View().plate.rim.shown,
            "RB: the background is off, in the picture too")
        tap("PADRSHOULDER")
        tap("PAD3")
        check(ids() == "773 771" and Edit.Editing() ~= nil and Edit.Editing().mark == 2 and Pad.View().count == 2,
            "X: the selected icon comes off, and the editing goes on: " .. ids())
        tap("PAD2")
        check(Edit.Editing() == nil and not bound("PADDUP") and not bound("PAD2") and not up() and NS.Flyouts.At("ActionButton7") == target,
            "B: done. The pad's buttons are the game's again and the flyout stays as edited")
        -- its button out of view for a while (the pad put down, another page of the bar): it ends by itself
        Edit.Open(target)
        local editor = W.frames.FallensFlyoutsPadEditor
        check(editor:IsShown() and NS.PadEdit.Hint():find("is selected", 1, true) ~= nil, "opened again, the line over the bar says what is selected")
        editor.scripts.OnUpdate(editor, 0.3)
        check(Edit.Editing() ~= nil, "its button in view, it stays up")
        W.frames.ActionButton7:Hide()
        for _ = 1, 6 do editor.scripts.OnUpdate(editor, 0.3) end
        check(Edit.Editing() == nil and not bound("PADDUP") and not editor:IsShown(),
            "its button gone from view for over a second: it ends and the pad's buttons are the game's again")
        W.frames.ActionButton7:Show()
        -- the game's dialog coming up ends it as well
        Edit.Open(target)
        dialog:EnterEditMode()
        editor.scripts.OnUpdate(editor, 0.3)
        check(Edit.Editing() == nil and not bound("PADDUP"), "the game's dialog coming up ends it")
        dialog:ExitEditMode()
        flushAll()
        -- a fight ends it too
        Edit.Open(target)
        check(Edit.Editing() ~= nil and bound("PADDUP"), "opened again")
        fire("PLAYER_REGEN_DISABLED")
        check(Edit.Editing() == nil and not bound("PADDUP"), "a fight beginning ends the editing and gives the buttons back")
        NS.Flyouts.Remove(target, 2)
        W.placed[7] = nil
        fire("ACTIONBAR_SLOT_CHANGED", 7)
        flushAll()
    end

    W.combat = true
    bind(707, 3)
    check(Pad.Offer() == nil and not up(), "in a fight nothing is offered")
    W.combat = false
    dialog:ExitBindingMode()
    -- the bars as they were for what follows
    NS.Flyouts.Remove(NS.Flyouts.At("ActionButton1"), 4)
    for _, lead in ipairs({ 705, 707, 103, 102 }) do
        local left = NS.Flyouts.Of({ kind = "spell", id = lead })
        while left and #left.entries > 1 do
            NS.Flyouts.Remove(left, 2)
            left = NS.Flyouts.Of({ kind = "spell", id = lead })
        end
    end
    W.placed = nil
    for _, slot in ipairs({ 1, 2, 3, 5 }) do fire("ACTIONBAR_SLOT_CHANGED", slot) end
    flushAll()
    check(order() == "101 501 502" and NS.Flyouts.At("ActionButton2") == nil and NS.Flyouts.At("ActionButton3") == nil
        and opener("1") == one, "the bars are as before")

    -- His recording (2026-11-21): the old ability sits on two buttons. Added at one of them, the
    -- flyout has to be on that one: it is the button he presses next.
    local function onCopies()
        for _, flyout in ipairs(NS.Flyouts.List()) do
            if flyout.host:find("^GamepadActionBarEditFrame") then return true end
        end
        return false
    end
    W.placed = { [6] = 801, [7] = 801 }
    for _, slot in ipairs({ 6, 7 }) do fire("ACTIONBAR_SLOT_CHANGED", slot) end
    flushAll()
    bind(802, 6)
    -- time passes while the dialog is up, as it does for a hand
    flushAll()
    press("PAD1")
    flushAll()
    check(not onCopies(), "while the dialog is up no flyout goes onto the dialog's copies of the bar")
    dialog:ExitBindingMode()
    flushAll()
    local onFirst = NS.Flyouts.At("ActionButton6")
    check(onFirst ~= nil and #onFirst.entries == 2, "an ability on two buttons, one added at the first: its flyout is on the first")
    bind(803, 7)
    flushAll()
    press("PAD1")
    flushAll()
    check(not onCopies(), "nor the second time")
    dialog:ExitBindingMode()
    flushAll()
    local onSecond, secondUnit = NS.Flyouts.At("ActionButton7")
    check(onSecond ~= nil and onSecond == onFirst and #onSecond.entries == 3 and NS.Flyouts.At("ActionButton6") == nil,
        "another added at the second button: the flyout is on that button, where it was added")
    local castCount = #W.casts
    mouse(W.frames.ActionButton7)
    check(secondUnit ~= nil and secondUnit.menu:IsShown() and #W.casts == castCount,
        "and a press on that button opens the flyout, casting nothing")
    if secondUnit and secondUnit.menu:IsShown() then mouse(W.frames.ActionButton7) end
    -- a bar of another make, in view all the while with the same ability on it, does not draw it away
    local sideBar = CreateFrame("Frame", "AaSideBar", UIParent)
    actionButton("AaSideButton1", 9, sideBar)
    W.placed[9] = 801
    fire("ACTIONBAR_SLOT_CHANGED", 9)
    flushAll()
    bind(803, 7)
    flushAll()
    press("PAD1")
    flushAll()
    dialog:ExitBindingMode()
    flushAll()
    check(NS.Flyouts.At("ActionButton7") == onFirst and NS.Flyouts.At("AaSideButton1") == nil,
        "with the ability on another bar in view too, the flyout still stays where it was added")
    sideBar:Hide()
    local kept = NS.Flyouts.Of({ kind = "spell", id = 801 })
    while kept and #kept.entries > 1 do
        NS.Flyouts.Remove(kept, 2)
        kept = NS.Flyouts.Of({ kind = "spell", id = 801 })
    end
    W.placed = nil
    for _, slot in ipairs({ 6, 7, 9 }) do fire("ACTIONBAR_SLOT_CHANGED", slot) end
    flushAll()
    check(order() == "101 501 502" and NS.Flyouts.Of({ kind = "spell", id = 801 }) == nil and opener("1") == one,
        "the bars are as before once more")
end

print("the button gets another key")
one = opener("1")
W.base.G = "ACTIONBUTTON1"
W.clock = W.clock + 10
fire("UPDATE_BINDINGS")
W.ticker()
check(opener("G") == one, "a key bound to the button later opens the flyout too")
W.base.G = nil
W.clock = W.clock + 10
fire("UPDATE_BINDINGS")
W.ticker()
check(opener("G") == nil and opener("1") == one, "and a key taken off it no longer does")

NS.Profiles.Reset()
check(not opens("1") and GetBindingAction("1", true) == "ACTIONBUTTON1", "Reset on the profile gives every key back")

print("two characters on one account")
stack("ActionButton1", 501)
check(opens("1"), "the first character stacks a flyout on ActionButton1")
login("Player-1-0000000B")
check(not opens("1") and not opens("2") and not opens("3"), "another character logs in without it")
stack("ActionButton2", 601)
check(opens("2"), "and stacks its own on ActionButton2")
login("Player-1-0000000A")
check(opens("1") and not opens("2") and second("1") == 501, "the first still has its own, and only its own")
login("Player-1-0000000B")
check(opens("2") and not opens("1") and second("2") == 601, "and so does the second")

print("profiles: this character, this class, everyone")
login("Player-1-0000000A")
check(pick("Tester A - Realm (this character)") and reads() == "Tester A - Realm (this character)",
    "a character starts on its own profile, first in the list")
stack("ActionButton3", 602)
check(opens("1") and opens("3") and opener("1") ~= opener("3"), "it has two flyouts now")
check(pick("MAGE (this class)") and opens("1") and opens("3") and reads() == "MAGE (this class)",
    "the class profile, first picked, starts with the flyouts in use")
login("Player-1-0000000B")
check(opens("2") and not opens("1") and not opens("3"), "another of the class is still on its own")
check(pick("MAGE (this class)") and opens("1") and opens("3") and not opens("2"),
    "on the class profile it shows the class's flyouts")
login("Player-1-0000000D", "MAGE", "swap")
pick("MAGE (this class)")
check(second("2") == 501 and second("3") == 602 and not opens("1"),
    "on other bars each shared flyout sits on the button that holds its ability")
login("Player-1-0000000E", "MAGE", "shift")
pick("MAGE (this class)")
check(not opens("1") and not opens("2") and not opens("3"), "and waits unseen where no button holds it")
login("Player-1-0000000B")
check(second("1") == 501 and NS.Profiles.Active() == "MAGE", "a character comes back on the profile it picked")
check(pick("Tester B - Realm (this character)") and opens("2") and not opens("1"), "and its own profile is as it left it")
login("Player-1-0000000F", "DRUID")
check(not opens("1") and not opens("2"), "a character of another class starts with nothing")
NS.ProfileUI.Build()
NS.ProfileUI.Refresh()
check(reads() == "Tester F - Realm (this character)" and NS.ProfileUI.panel.dropdown.rows[2].label == "DRUID (this class)",
    "and is offered its own class, with the others' profiles further down")
W.combat = true
check(not pick("Default (every character)") or NS.Profiles.Active() == "Tester F - Realm", "no profile change in a fight")
W.combat = false
check(pick("Default (every character)") and NS.Profiles.Active() == "Default", "everyone's profile can be picked out of one")
check(NS.ProfileUI.panel.delete:IsEnabled() and not NS.ProfileUI.panel.rename:IsEnabled(),
    "it can be deleted, not renamed")
pick("Tester F - Realm (this character)")
check(not NS.ProfileUI.panel.delete:IsEnabled(), "a character's own profile cannot be deleted")

print("the addon alone, with the dev folder off")
char.guid, char.class, char.name, char.swap, char.shift = "Player-1-0000000G", "MAGE", "Tester G", false, nil
boot()
flushAll()
check(SlashCmdList.FALLENSFLYOUTSDEV == nil and SlashCmdList.FALLENSFLYOUTS ~= nil, "only the addon is loaded")
stack("ActionButton1", 501)
stack("ActionButton1", 502)
stack("ActionButton2", 601)
local lead, beside = opener("1"), opener("2")
check(lead ~= nil and beside ~= nil and lead ~= beside and count(lead) == 3 and count(beside) == 2,
    "drops stack into flyouts, one per button")
tap("1"); tap("3")
check(W.casts[#W.casts] == "spell:502" and not menuOf(lead):IsShown(), "the button's key opens, a number casts and shuts")
W.combat = true
tap("2"); tap("PADDUP")
check(W.casts[#W.casts] == "spell:601" and not menuOf(beside):IsShown(), "in a fight, by pad, the same")
W.combat = false
boot()
flushAll()
lead, beside = opener("1"), opener("2")
check(lead ~= nil and beside ~= nil and count(lead) == 3 and second("2") == 601,
    "after a reload both are back from the saved profile")
tap("E")
rightClick(entry(lead, 3))
rightClick(entry(lead, 2))
check(not opens("1") and not opens("E") and opens("2") and #NS.Profiles.Data().flyouts == 1,
    "right-clicks take a flyout apart")
print("a login in a fight, before the bars are placed")
check(way("2") == "UP", "on the placed bar the flyout grows up")
unplaced = true
boot()
W.combat = true
W.frames.MainActionBar.w, W.frames.MainActionBar.h = 500, 40
flushAll()
check(opens("2") and way("2") == "UP", "it is laid the way it was last time, though the bar was not placed yet")
W.combat = false
fire("PLAYER_REGEN_ENABLED")
flushAll()
check(way("2") == "UP", "and it is right after the fight too")
FallensFlyoutsDB.chars[char.guid].laid = nil
boot()
check(way("2") == "RIGHT", "with nothing remembered and the bar unplaced, it reads the bar as it stands")
W.frames.MainActionBar.w, W.frames.MainActionBar.h = 500, 40
fire("PLAYER_REGEN_DISABLED")
W.combat = true
flushAll()
check(way("2") == "UP", "and is laid again as the fight lock starts, for where the bar is by then")
W.combat = false
fire("PLAYER_REGEN_ENABLED")
flushAll()
unplaced = false

print("bars that send their keys through a helper child")
barWorld = function() return "helper" end
login("Player-1-0000000H")
stack("SideBarButton15", 501)
check(opener("F3") ~= nil, "the key is found through the helper child and opens the flyout")
tap("F3"); tap("2")
check(W.casts[#W.casts] == "spell:501" and not opens("2"), "and a pick casts and shuts it")

print("bars of their own buttons, upright at the screen's right edge")
barWorld = function() return "own" end
login("Player-1-0000000I")
stack("OwnBarButton3", 501)
check(opener("3") ~= nil and way("3") == "LEFT", "the key is found, and the flyout grows left, away from the edge")
barWorld = function() return "game" end

print("a frame with a GetName of its own does not break the search for bar buttons")
do
    -- His error (2026-11-21): a spellbook entry's own GetName, which gives a spell's name, failed on an
    -- entry with no spell while every frame was asked its name.
    local odd = CreateFrame("Frame", nil, UIParent)
    odd.GetName = function() error("a spellbook entry with no spell") end
    local also = CreateFrame("CheckButton", nil, UIParent)
    also.GetName = function() error("a check button with a GetName of its own") end
    local ok, found = pcall(NS.Bars.All, true)
    check(ok and type(found) == "table" and #found > 0, "every frame is asked by the frame calls themselves: " .. tostring(found))
end

print("in gamepad mode a flyout opens around its button, as the pad's buttons lie")
do
    login("Player-1-0000000M")
    local F2, Art2 = NS.Flyouts, NS.Art
    local padBar = W.frames.GamepadMainActionBarFrame or CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
    local NAME = "GamepadMainActionBarFrameTestActionButton7"
    actionButton(NAME, 27, padBar).id = 27
    W.placed = W.placed or {}
    W.placed[27] = 811
    fire("ACTIONBAR_SLOT_CHANGED", 27)
    flushAll()
    for id = 812, 815 do stack(NAME, id) end
    local flyout, unit = F2.At(NAME)
    local function at(i)
        local p = entry(unit.index, i).point
        return p[1] == "CENTER" and p[2] == unit.menu and math.floor(p[4] + 0.5) .. "," .. math.floor(p[5] + 0.5) or "not centered"
    end
    local function pads()
        local out = {}
        for i, pick in ipairs(F2.Picks(flyout)) do out[i] = pick.pad end
        return table.concat(out, " ")
    end
    local r = Art2.BUTTON / 2 + 6 + Art2.ICON / 2
    local step = Art2.ICON + 6
    local function spot(x, y) return math.floor(x + 0.5) .. "," .. math.floor(y + 0.5) end
    -- His idea (2026-11-21): four on a flyout for gamepad: D-pad up above the icon, down below, right to
    -- the right, and so on.
    check(flyout ~= nil and #flyout.entries == 5 and unit.radial == true, "a flyout on a bar of gamepad mode opens around its button")
    check(at(1) == spot(0, r) and at(2) == spot(r, 0) and at(3) == spot(0, -r) and at(4) == spot(-r, 0),
        "the first four stand above, right of, below and left of the button: " .. table.concat({ at(1), at(2), at(3), at(4) }, " | "))
    check(at(5) == spot(0, r + step), "a fifth stands a step further out, above: " .. at(5))
    check(pads() == "PADDUP PADDRIGHT PADDDOWN PADDLEFT PAD4",
        "each is picked by the D-pad button of its side, the fifth by the face button of its side: " .. pads())
    check(unit.strip.first.shown == false and unit.strip.last.shown == false and unit.menu.point[1] == "CENTER",
        "there is no strip: the icons stand by themselves, around the button's middle")
    -- His words (2026-11-21): "an up arrow confusingly makes one think possible that they need to hit dpad up".
    local corner = unit.dots.pieces[1].dot.point
    check(unit.dots.shown == true and not unit.arrow:IsShown() and #unit.dots.pieces == 4 and unit.dots.pieces[1].dot.shown
        and corner[2] == unit.host and corner[3] == "TOPRIGHT",
        "its button is marked by four dots at its corner, as the pad's buttons lie, and wears no arrow")
    check(unit.plate.rim.shown and unit.hub.shown and unit.hub.icon.texture == 811,
        "open, a round plate with a rim lies behind the icons, the button's own icon at its middle")
    -- His words (2026-11-21): the symbol's "resize is delayed" when a group of gamepad mode is picked and
    -- grows. It was sized again only at the next laying out, up to a second on.
    local dot = unit.dots.pieces[2].dot
    local was, wasX = dot.w, dot.point[4]
    unit.host.w = (unit.host.w or 100) * 2
    unit.host.scripts.OnSizeChanged(unit.host)
    check(dot.w == was * 2 and dot.point[4] == wasX * 2 and unit.grown == 2,
        "its button grown to twice its size, the dots are twice as large and as far in at once, with no laying out between")
    unit.host.w = unit.host.w / 2
    unit.host.scripts.OnSizeChanged(unit.host)
    check(dot.w == was and unit.grown == 1, "and back with it")
    tap(unit.keys[1] or "1")
    unit.menu.over = true
    NS.Turn.Poll()
    check((NS.Turn.Grip() == nil or not NS.Turn.Grip():IsShown()) and NS.Turn.Start(unit) == false and NS.Move.Start(entry(unit.index, 2)) == false,
        "it has no end to pull and no line to slide along: no grip, and no icon is lifted")
    unit.menu.over = nil
    -- the face buttons first, for every flyout of the profile
    check(F2.SetFaces(true) == true and pads() == "PAD4 PAD2 PAD1 PAD3 PADDUP",
        "with the face buttons picked in the settings they come first, each on its side, and the D-pad takes the fifth: " .. pads())
    -- one flyout's own word, as the quick swap in the bind dialog gives it
    F2.SetFace(flyout, false)
    check(pads() == "PADDUP PADDRIGHT PADDDOWN PADDLEFT PAD4" and F2.Faces() == true, "a flyout's own choice stands over the profile's")
    F2.SetFace(flyout, nil)
    F2.SetFaces(false)
    -- a strip again where the player wants one
    check(F2.SetAround(false) == true and unit.radial == false and unit.strip.first.shown ~= false
        and entry(unit.index, 2).point[1] ~= "CENTER",
        "with that turned off in the settings it opens as a strip, as on any bar")
    check(unit.arrow:IsShown() and unit.dots.shown == false and not unit.plate.rim.shown and not unit.hub.shown,
        "a strip has the bar's arrow again, and neither dots nor plate")
    F2.SetFaces(true)
    check(pads() == table.concat({ "PAD1", "PAD3", "PAD2", "PAD4", "PADDUP" }, " "),
        "a strip picked with the face buttons takes the one on the same side as each D-pad button was: " .. pads())
    F2.SetFaces(false)
    F2.SetAround(true)
    F2.SetShape(flyout, "RIGHT")
    _, unit = F2.At(NAME)
    check(unit.radial == false and unit.side == "RIGHT", "and a flyout given a shape of its own keeps that shape in gamepad mode too")
    F2.SetShape(flyout, nil)
    -- on any other bar nothing changes
    stack("ActionButton1", 501)
    local _, plain = F2.At("ActionButton1")
    check(plain ~= nil and plain.radial == false, "a flyout on any other bar is a strip as ever")
    local page = NS.Options and NS.Options.Page and NS.Options.Page()
    if page and page.arrange and page.arrange.around then
        check(page.arrange.around:GetChecked() == true and page.arrange.faces:GetChecked() == false, "the settings show both choices")
    end
end

print("the flyout is in its bar's layer, and its arrow never stays pressed")
do
    login("Player-1-0000000L")
    stack("ActionButton1", 501)
    local _, unit = NS.Flyouts.At("ActionButton1")
    local host = W.frames.ActionButton1
    local top = 0
    for i = 1, 12 do top = math.max(top, W.frames["ActionButton" .. i]:GetFrameLevel()) end
    -- His report (2026-11-21): flyouts showed through windows that were over the bars. They sat in the
    -- layer of the game's own flyout, over most windows.
    check(unit.menu:GetFrameStrata() == host:GetFrameStrata() and unit.menu:GetFrameStrata() == "MEDIUM"
        and unit.menu:GetFrameLevel() > top,
        "the flyout is in its bar's own layer, just over the bar's buttons: a window over the bars is over it too")
    tap("1")
    unit.menu.over = true
    NS.Turn.Poll()
    local grip = NS.Turn.Grip()
    check(grip ~= nil and grip:IsShown() and grip:GetFrameStrata() == "MEDIUM" and grip:GetFrameLevel() > unit.menu:GetFrameLevel(),
        "its grip is in that layer too, just over the flyout")
    unit.menu.over = nil
    -- the game lifts its bars for a spell on the cursor: the flyout goes up with them, and comes down after
    W.cursor = { "spell", 7, "spell", 777, 777 }
    fire("ACTIONBAR_SHOWGRID")
    flushAll()
    check(host:GetFrameStrata() == "TOOLTIP" and unit.menu:GetFrameStrata() == "TOOLTIP",
        "the bars lifted for a spell on the cursor, the flyout is lifted with them")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    flushAll()
    check(unit.menu:GetFrameStrata() == "MEDIUM", "and let down again with them")
    if unit.menu:IsShown() then tap("1") end
    -- His report (2026-11-21): the arrow sometimes stayed dimmed. Its pressed look waited for a mouse-up
    -- that is not always handed to it.
    local opener = unit.opener
    W.mouseDown = true
    opener.scripts.OnMouseDown(opener)
    check(unit.art == "arrowDown", "pressed with the mouse, the arrow looks pressed")
    W.mouseDown = false
    flushAll()
    check(unit.art == "arrow", "the mouse let go with no word of it to the arrow, it is its plain self again all the same")
    opener.over = true
    W.mouseDown = true
    opener.scripts.OnMouseDown(opener)
    W.mouseDown = false
    opener.over = nil
    opener.scripts.OnLeave(opener)
    check(unit.art == "arrow", "and the mouse gone off it after a let-go leaves it plain, not pressed")
    flushAll()
end

print("macros of one name are told apart by their text")
do
    login("Player-1-0000000J")
    -- his own macros (2026-11-21): every one named with a single space, two of them with one icon
    W.macros, W.shared = {}, {}
    CreateMacro(" ", 134400, "/cast Lesser Heal(Rank 3)")
    CreateMacro(" ", 135913, "#showtooltip greater heal(rank 2)")
    CreateMacro(" ", 135913, "#showtooltip greater heal(rank 1)")
    CreateMacro("Solo", 136243, "/cast Something")
    local RANK2, RANK1 = "#showtooltip greater heal(rank 2)", "#showtooltip greater heal(rank 1)"
    -- a macro onto a bar slot, and onto the plus of a button, as a drag puts it
    local function put(place, slot)
        PickupMacro(place)
        PlaceAction(slot)
        ClearCursor()
        flushAll()
    end
    local function drop(place, host)
        PickupMacro(place)
        local tab = tabOf(host)
        tab.scripts.OnReceiveDrag(tab)
        ClearCursor()
        flushAll()
    end
    local function runs(unit, i) return entry(unit.index, i).attrs.macro end

    put(2, 8)
    local kind, place, sub = GetActionInfo(8)
    check(kind == "macro" and place == 2 and sub == "" and GetActionText(8) == " ",
        "the game names a macro on a slot by its place in the list, as seen on his client")
    drop(3, "ActionButton8")
    local flyout, unit = NS.Flyouts.At("ActionButton8")
    check(flyout ~= nil and #flyout.entries == 2 and flyout.entries[1].text == RANK2 and flyout.entries[2].text == RANK1,
        "a macro dropped on one of the same name goes into its flyout: each is known by its text")
    check(unit ~= nil and entry(unit.index, 1).attrs.type == "macro" and runs(unit, 1) == 2 and runs(unit, 2) == 3,
        "each icon runs its own macro, by its place in the list while others share its name")
    check(entry(unit.index, 1).icon.texture == 135913 and NS.Flyouts.Icon(flyout.entries[2]) == 135913,
        "and wears its own macro's icon")
    check(NS.Flyouts.Name(flyout.entries[1]) == "greater heal(rank 2)" and NS.Flyouts.Name(flyout.entries[2]) == "greater heal(rank 1)",
        "a macro with a blank name is named by what its text asks for")
    local said = #W.errors
    drop(3, "ActionButton8")
    flyout = NS.Flyouts.At("ActionButton8")
    check(#flyout.entries == 2 and #W.errors == said + 1 and W.errors[#W.errors] == "That is in the flyout already.",
        "the same macro a second time is refused as before")
    drop(1, "ActionButton8")
    flyout, unit = NS.Flyouts.At("ActionButton8")
    check(#flyout.entries == 3 and runs(unit, 3) == 1, "a third of that name with a text of its own goes in too")

    -- the flyout goes with its lead, not with any macro of that name
    put(3, 9)
    W.placed[8] = false
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    put(2, 7)
    for _ = 1, 3 do flushAll() end
    check(NS.Flyouts.At("ActionButton7") == flyout and NS.Flyouts.At("ActionButton9") == nil,
        "moved to another button, the flyout follows the macro that leads it, not the other one of its name")

    -- the macro's text is changed in the macro window
    W.shared[1][3] = RANK2 .. "\n/cast Greater Heal(Rank 2)"
    fire("UPDATE_MACROS")
    flushAll()
    flyout, unit = NS.Flyouts.At("ActionButton7")
    check(flyout ~= nil and flyout.main.text == W.shared[1][3] and flyout.entries[1].text == W.shared[1][3] and runs(unit, 1) == 2,
        "its text changed, the flyout still knows it and stays on its button")

    -- a macro above them is deleted and the places shift
    DeleteMacro(1)
    flushAll()
    flyout, unit = NS.Flyouts.At("ActionButton7")
    check(flyout ~= nil and #flyout.entries == 3 and runs(unit, 1) == 1 and runs(unit, 2) == 2,
        "a macro above them deleted, each icon still runs its own macro at its new place")
    check(NS.Macros.Find(flyout.entries[3]) == false, "and the icon of the deleted macro stands for none")

    -- a name of its own is kept as what the button runs: it stays right whatever shifts
    drop(3, "ActionButton7")
    flyout, unit = NS.Flyouts.At("ActionButton7")
    check(#flyout.entries == 4 and flyout.entries[4].id == "Solo" and runs(unit, 4) == "Solo",
        "a macro with a name of its own is run by its name")
    -- an older save knows a macro by its name alone
    local old = { kind = "macro", id = "Solo" }
    check(NS.Macros.Find(old) == 3 and NS.Macros.Same(old, flyout.entries[4]),
        "a macro saved by an older version, with no text, is still found by its name")

    W.macros, W.shared, W.macroCount = nil, nil, nil
    W.placed[7], W.placed[8], W.placed[9] = nil, nil, nil
end

print("macros that stand for ranks of one spell are kept in rank order, as the spells are")
do
    login("Player-1-0000000K")
    W.macros, W.shared = {}, {}
    W.ranks = W.ranks or {}
    W.ranks[2101], W.ranks[2102], W.ranks[2103] = { "Greater Heal", 1 }, { "Greater Heal", 2 }, { "Greater Heal", 3 }
    CreateMacro(" ", 135913, "/cast Greater Heal(Rank 3)")
    CreateMacro(" ", 135913, "/cast Greater Heal(Rank 1)")
    CreateMacro(" ", 135913, "/cast Greater Heal(Rank 2)")
    W.macroSpell = { ["/cast Greater Heal(Rank 3)"] = 2103, ["/cast Greater Heal(Rank 1)"] = 2101,
        ["/cast Greater Heal(Rank 2)"] = 2102 }
    local function drop(place, host)
        PickupMacro(place)
        local tab = tabOf(host)
        tab.scripts.OnReceiveDrag(tab)
        ClearCursor()
        flushAll()
    end
    PickupMacro(1)
    PlaceAction(8)
    ClearCursor()
    flushAll()
    drop(2, "ActionButton8")
    drop(3, "ActionButton8")
    local flyout, unit = NS.Flyouts.At("ActionButton8")
    local texts = {}
    for i, e in ipairs(flyout.entries) do texts[i] = e.text:match("Rank %d") end
    check(table.concat(texts, ", ") == "Rank 1, Rank 2, Rank 3",
        "the button holds the Rank 3 macro, and the flyout runs Rank 1, Rank 2, Rank 3: " .. table.concat(texts, ", "))
    check(entry(unit.index, 1).attrs.macro == 2 and entry(unit.index, 3).attrs.macro == 1 and flyout.main.text:find("Rank 3", 1, true),
        "each icon runs its own macro, and the button's own still leads the flyout")
    W.macros, W.shared, W.macroCount, W.macroSpell = nil, nil, nil, nil
    W.placed[8] = nil
end

-- what ships names nobody else's addon and nothing of the dev folder
for _, file in ipairs(tocFiles()) do
    local text = io.open(file):read("a")
    check(not (text:find("FallensFlyoutsDev")),
        file .. " names nothing of the dev folder")
end

print(fails == 0 and "FLYOUTS TEST: PASS" or ("FLYOUTS TEST: FAIL (" .. fails .. ")"))
os.exit(fails == 0 and 0 or 1)
