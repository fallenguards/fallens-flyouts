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
    "short of power dims blue, unusable grey, the rest stay full")
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
W.mouseDown = false
check(count(one) == 2 and W.cursor ~= nil and W.cursor[4] == 502 and menu:IsShown() and Move.Moving() == nil,
    "off the flyout and onto the cursor, the flyout still open")
check(entry(one, 1).alpha == 1 and entry(one, 2).alpha == 1 and along(entry(one, 2)) == slot(2), "the icons left close up, seen")
check(lastChat("Spell 502 taken off the flyout") ~= nil, "chat says what was taken off")
plus().scripts.OnReceiveDrag(plus())
check(count(one) == 3 and entry(one, 3).attrs.spell == 502 and W.cursor == nil,
    "dropped on the plus it is back in the flyout")
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

print("the game's key menu: a row for each flyout, and for each place of an open one")
local Binds = NS.Binds
do
    local file = assert(io.open("Bindings.xml"))
    local xml = file:read("a")
    file:close()
    local opensListed, picksListed, fine = 0, 0, true
    for name, category in xml:gmatch('<Binding name="([%w_]+)" category="([%w_]+)">') do
        if name:find("^" .. Binds.OPEN .. "%d+$") then
            opensListed = opensListed + 1
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
    check(opensListed == Binds.SLOTS and picksListed == Binds.PLACES and fine and _G[Binds.CATEGORY] == "Fallen's Flyouts",
        "Bindings.xml lists every row the code reads, each with its text, under the addon's own heading")
end
local function rebound()
    W.clock = W.clock + 10
    fire("UPDATE_BINDINGS")
    W.ticker()
end
local function rowName(n) return _G["BINDING_NAME_" .. Binds.OPEN .. n] end
local keyed, keyedUnit = NS.Flyouts.At("ActionButton1")
local second2 = "CLICK FallensFlyoutsEntry" .. one .. "_2:LeftButton"
check(keyed.number == 1 and rowName(1) == "Flyout 1: Spell 101" and rowName(2) == "Flyout 2",
    "a flyout has a row of its own, named after its ability; a row with no flyout has its number alone")
W.base.F9 = Binds.OPEN .. "1"
rebound()
check(opener("F9") == one and opener("1") == one, "a key set on its row opens the flyout, as its bar button's key still does")
tap("F9")
check(menu:IsShown(), "pressed, the flyout is open")
tap("F9")
check(not menu:IsShown(), "pressed again, it is shut")
W.base.T = Binds.PICK .. "2"
W.base.PADLSHOULDER = Binds.PICK .. "2"
rebound()
tap("F9")
check(GetBindingAction("T", true) == second2 and label(2) == "T",
    "a key set for place 2 picks the second icon of an open flyout, and the icon shows it")
check(GetBindingAction("PADLSHOULDER", true) == second2, "a pad button set for the place picks it too")
check(GetBindingAction("2", true) == "ACTIONBUTTON2", "and 2 is the bar's own then")
tap("T")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "pressed, it casts that icon and shuts the flyout")
check(GetBindingAction("T", true) == Binds.PICK .. "2", "shut, the key is the row's again: it does nothing")
NS.Flyouts.SetKey(keyed, 2, "Y", false)
tap("F9")
check(GetBindingAction("Y", true) == second2 and GetBindingAction("T", true) ~= second2,
    "an icon's own key stands before the key of its place")
tap("F9")
NS.Flyouts.SetKey(keyed, 2, nil, false)
W.base.T, W.base.PADLSHOULDER, W.base.F9 = nil, nil, nil
rebound()
check(opener("F9") == nil and opener("1") == one and label(2) == "2", "taken off in the menu, every key is as before")
-- a number is kept: a flyout keeps its row when an earlier one goes
stack("ActionButton2", 601)
stack("ActionButton3", 602)
local rowTwo, rowThree = NS.Flyouts.At("ActionButton2"), NS.Flyouts.At("ActionButton3")
check(rowTwo.number == 2 and rowThree.number == 3 and rowName(2):find("^Flyout 2: ") ~= nil and rowName(3):find("^Flyout 3: ") ~= nil,
    "later flyouts take the next rows")
NS.Flyouts.Remove(rowTwo, 2)
check(NS.Flyouts.At("ActionButton2") == nil and rowThree.number == 3 and rowName(2) == "Flyout 2" and rowName(3) ~= "Flyout 3",
    "one taken away, the flyout after it keeps its row and its keys")
NS.Flyouts.Remove(rowThree, 2)
check(NS.Flyouts.At("ActionButton3") == nil and rowName(3) == "Flyout 3", "and a row with no flyout left has its number alone again")
NS.KeyMenu.Hover(Binds.OPEN .. "1")
check(keyedUnit.ring.shown and keyedUnit.glow.shown, "a hover on a flyout's row in the key menu lights its bar button")
NS.KeyMenu.Hover(Binds.PICK .. "1")
check(not keyedUnit.ring.shown and not keyedUnit.glow.shown, "a hover on another row puts the light out")
NS.KeyMenu.Hover(Binds.OPEN .. "1")
NS.KeyMenu.Hover(nil)
check(not keyedUnit.ring.shown, "and so does leaving the rows")

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

-- what ships names nobody else's addon and nothing of the dev folder
for _, file in ipairs(tocFiles()) do
    local text = io.open(file):read("a")
    check(not (text:find("FallensFlyoutsDev")),
        file .. " names nothing of the dev folder")
end

print(fails == 0 and "FLYOUTS TEST: PASS" or ("FLYOUTS TEST: FAIL (" .. fails .. ")"))
os.exit(fails == 0 and 0 or 1)
