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
do
    local own = select(2, GetActionInfo(1))
    mouse(host)
    check(select(2, GetActionInfo(1)) == 777 and not menu:IsShown(),
        "with something on the cursor the click goes to the bar, which takes it")
    -- and back as it was: what the button held came onto the cursor
    PlaceAction(1)
    check(select(2, GetActionInfo(1)) == own, "the button holds its own again")
end
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

print("the icons show range as bar buttons do")
do
    local RED, KEY, FULL = "1,0.1,0.1", "0.8,0.8,0.8", "1,1,1"
    local function keyColor(i)
        local c = entry(one, i).key.color
        return c and table.concat(c, ",")
    end
    local function gray(i) return entry(one, i).icon.gray == true end
    -- frames drawn with no event: a third of a second of them
    local function drawn()
        C_Timer.After(0, function() end)
        flushAll()
    end
    -- a client whose bars tint a usable button out of range, icon and all, as some are set up to
    local function barsTint(r, g, b, grayed)
        for slot = 1, 3 do
            local button = W.frames["ActionButton" .. slot]
            local far = IsActionInRange(slot) == false and C_ActionBar.IsUsableAction(slot)
            if far and r then
                button.icon:SetVertexColor(r, g, b)
                button.icon:SetDesaturated(grayed)
            else
                button.icon:SetVertexColor(1, 1, 1)
                button.icon:SetDesaturated(false)
            end
        end
    end
    local caught = #W.caught
    mouse(host)
    check(menu:IsShown() and keyColor(2) == KEY and tint(2) == FULL and label(2) == "2",
        "no target: every key in its gray, every icon in full color")
    -- a target the first drop does not reach
    W.target, W.far = true, { [501] = true }
    fire("PLAYER_TARGET_CHANGED")
    check(keyColor(2) == RED and keyColor(1) == KEY and keyColor(3) == KEY and label(2) == "2",
        "out of range of the target that icon's key goes red, as a bar button's does; the others stay")
    check(tint(2) == FULL and not gray(2) and NS.Flyouts.FarTint() == nil,
        "its icon is left as it is while no bar button has shown what the bars do out of range")
    -- the player walks: no event tells of it, the open flyout asks by itself
    W.far = { [502] = true }
    drawn()
    check(keyColor(2) == KEY and keyColor(3) == RED, "moved, with no event: the keys follow within a moment")
    -- the game's own bars: a button out of range keeps its icon, and so do the flyout's
    W.far = { [101] = true, [501] = true }
    barsTint()
    drawn()
    check(NS.Flyouts.FarTint() == false and keyColor(1) == RED and keyColor(2) == RED and tint(1) == FULL and tint(2) == FULL,
        "bars that leave an icon alone out of range: the flyout's icons are left alone too, the keys red")
    -- bars set up to tint the whole icon: the flyout's icons take that very tint
    barsTint(1, 0.3, 0.1, true)
    drawn()
    check(tint(1) == "1,0.3,0.1" and tint(2) == "1,0.3,0.1" and gray(1) and gray(2),
        "bars that tint the whole icon out of range: the flyout's icons out of range take the same tint: "
        .. tostring(tint(2)))
    check(tint(3) == FULL and not gray(3) and keyColor(3) == KEY, "an icon in range keeps its color")
    -- the game's own dimming stays on top: an icon that cannot be used shows that, not the range
    W.unusable[501] = true
    fire("SPELL_UPDATE_USABLE")
    check(tint(2) == "0.4,0.4,0.4" and not gray(2) and keyColor(2) == RED,
        "an icon that cannot be used keeps the game's gray, with its key red")
    W.unusable[501] = nil
    fire("SPELL_UPDATE_USABLE")
    check(tint(2) == "1,0.3,0.1" and gray(2), "usable again and still out of range: the tint again")
    -- a bar button between two looks, gray from the game's own dimming, teaches nothing
    W.frames.ActionButton1.icon:SetVertexColor(0.4, 0.4, 0.4)
    W.frames.ActionButton1.icon:SetDesaturated(false)
    drawn()
    check(tint(2) == "1,0.3,0.1", "a bar button caught in the game's own gray is not taken for the bars' range tint")
    barsTint(1, 0.3, 0.1, true)
    -- the flyout's own button in range, another icon not: the tint the bars showed is kept
    W.far = { [501] = true }
    barsTint(1, 0.3, 0.1, true)
    drawn()
    check(tint(1) == FULL and not gray(1) and keyColor(1) == KEY and tint(2) == "1,0.3,0.1",
        "back in range an icon is in full color with its key gray, the one still out of range tinted")
    -- an ability that asks no range
    W.rangeless = { [501] = true }
    drawn()
    check(tint(2) == FULL and not gray(2) and keyColor(2) == KEY, "an ability that asks no range shows none")
    W.rangeless = nil
    -- an icon with no key: the game's dot stands for its range, gray in range and red out of it
    local key = entry(one, 2).key
    key:SetText("")
    drawn()
    check(key.text == RANGE_INDICATOR and keyColor(2) == RED, "an icon with no key shows the game's range dot, red out of range")
    W.far = {}
    drawn()
    check(key.text == RANGE_INDICATOR and keyColor(2) == KEY, "in range the dot is gray")
    W.target = nil
    fire("PLAYER_TARGET_CHANGED")
    check(key.text == "", "and with no target there is no dot")
    key:SetText("2")
    -- the bars' tint taken away (the bars' look changed): seen plain a few times, the flyout drops it
    W.target, W.far = true, { [101] = true, [501] = true }
    barsTint()
    fire("PLAYER_TARGET_CHANGED")
    check(tint(2) == "1,0.3,0.1", "one plain look at a bar button does not drop the tint")
    drawn()
    drawn()
    check(tint(1) == FULL and tint(2) == FULL and not gray(2) and keyColor(2) == RED,
        "bars seen plain out of range again and again: the flyout's icons are plain again, the keys red")
    barsTint(1, 0.3, 0.1, true)
    drawn()
    check(tint(2) == "1,0.3,0.1", "and tinted again when the bars are")
    -- a value the client hides is never compared: no red, no error
    local SECRET = {}
    issecretvalue = function(v) return v == SECRET end
    W.hideRange = SECRET
    drawn()
    check(#W.caught == caught and NS.Flyouts.hid.range == true and keyColor(2) == KEY and tint(2) == FULL,
        "a range the client hides is never read: the icon shows none, and nothing breaks")
    W.hideRange, issecretvalue = nil, nil
    NS.Flyouts.hid.range = false
    -- in a fight the same
    W.combat = true
    drawn()
    check(keyColor(2) == RED and tint(2) == "1,0.3,0.1" and #W.caught == caught, "in a fight the range shows the same")
    W.combat = false
    -- shut and opened: right at once
    mouse(host)
    W.far = { [502] = true }
    barsTint(1, 0.3, 0.1, true)
    mouse(host)
    check(keyColor(2) == KEY and tint(2) == FULL and not gray(2) and keyColor(3) == RED and tint(3) == "1,0.3,0.1",
        "an opening flyout shows the range as it is then")
    mouse(host)
    check(not menu:IsShown() and #W.caught == caught, "none of it raised an error")
    W.target, W.far = nil, nil
    barsTint()
end
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
check(not menu:IsShown(), "opened by a tap of a key that is itself a pick, a pick shuts it, as after any tap")
-- His words (2026-11-22): "holding a key to keep a flyout open so can spam button is not working. it still
-- just closes the flyout after the first press of in-flyout key press". The key that opened it was one of
-- the flyout's own pick keys (1 opens this one and 1 is its first icon's key), and such a key was a tap.
before = #W.casts
press("1")
check(menu:IsShown() and GetBindingAction("1", true) == "CLICK FallensFlyoutsOpener" .. one .. ":own1"
    and GetBindingAction("2", true):find("FallensFlyoutsEntry") ~= nil,
    "held, a key that is one of the flyout's own picks stays the opener's while it is down; the other picks are bound")
tap("2"); tap("3"); tap("2")
check(#W.casts == before + 3 and menu:IsShown(), "so every pick casts and the flyout stays open while that key is held")
release("1")
check(not menu:IsShown() and GetBindingAction("2", true) == "ACTIONBUTTON2", "let go, it shuts and the keys go back")
-- held and let go with nothing picked: it stays open, and the key is its own icon's from then on
press("1"); release("1")
check(menu:IsShown() and GetBindingAction("1", true) == "CLICK FallensFlyoutsEntry" .. one .. "_1:Key",
    "let go with nothing picked, it stays open and that key is its icon's key again")
before = #W.casts
tap("1")
check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:101" and not menu:IsShown(),
    "pressed again it casts its own icon and shuts the flyout: " .. tostring(W.casts[#W.casts]))
-- in a fight too, where nothing can be bound from outside
W.combat = true
press("1"); tap("2"); tap("2")
check(menu:IsShown(), "in a fight a held key of that kind keeps it open through its picks too")
release("1")
check(not menu:IsShown(), "and letting go shuts it")
W.combat = false
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

print("the settings page scrolls: nothing it holds is drawn outside the game's window")
do
    -- His snip and words (2026-11-22): the page's last check boxes hung out under the game's window. "need
    -- to fix spilling outside of settings window immediately. put a scroll in."
    local scroll, content = page.scroll, page.content
    check(scroll ~= nil and scroll.otype == "ScrollFrame" and scroll.parent == page and scroll.scrollChild == content
        and content.parent == scroll, "the page holds a scroll frame, and what scrolls in it")
    local point, to, toPoint, x, y = scroll:GetPoint()
    check(point == "BOTTOMRIGHT" and to == page and toPoint == "BOTTOMRIGHT" and x < 0 and y == 0,
        "the scroll frame ends at the page's own bottom, with room at the right for the bar")
    check(page.bar ~= nil and page.bar.template == "MinimalScrollBar" and scroll.bar == page.bar
        and page.bar.hideIfUnscrollable == true, "with the game's own scroll bar, there only when there is somewhere to scroll to")
    -- every button, check box, slider and list of the page is inside what scrolls: the game cuts those off
    -- at the scroll frame's edge
    local inside, outside = 0, {}
    for _, f in ipairs(W.all) do
        local up, through = f.parent, false
        while up and up ~= page do
            if up == content then through = true end
            up = up.parent
        end
        if up == page and f ~= scroll and f ~= page.bar then
            if through or f.parent == content then
                inside = inside + 1
            elseif f ~= content then
                outside[#outside + 1] = tostring(f.otype) .. " " .. tostring(f.text or f.label or "")
            end
        end
    end
    check(inside >= 12 and #outside == 0, ("all %d of the page's controls are inside it; outside: %s"):format(inside,
        table.concat(outside, ", ")))
    -- it scrolls as far as its lowest line, the foot of the list of flyout keys
    local last = page.arrange.foot
    content.rect, last.rect = { 0, 500, 1000, 999 }, { 0, 20, 300, 280 }
    scroll.h = 500
    NS.ProfileUI.Fit()
    check(content.h == 1000 - 280 + 16 and scroll:GetVerticalScrollRange() == content.h - 500,
        ("what scrolls is as tall as the page's content, down to its lowest line: %s"):format(tostring(content.h)))
    content.rect, last.rect = nil, nil
end

print("keys inside a flyout are set the game's own ways: the page has no Set Keys")
do
    -- His words (2026-11-22): "keys insdie a flyout should NOT be here since we have the default ways to
    -- keybind things."
    local found = {}
    for _, f in ipairs(W.all) do
        local text = tostring(f.text or "") .. " " .. tostring(f.label or "")
        if text:find("Set Keys", 1, true) or text:find("Keys inside a flyout", 1, true) then found[#found + 1] = text end
    end
    check(page.keys == nil and #found == 0, "no Set Keys button and no heading for it: " .. table.concat(found, ", "))
    check(NS.Keys.Start == nil and StaticPopupDialogs.FALLENSFLYOUTS_KEYS == nil, "and no key setting window of the addon's own")
end

print("flyout size, on the game's own stepper slider")
do
    -- His words (2026-11-24): "bro what is this \"smaller, larger\" lmao. just throwing away ui principles? why
    -- not just follow the api's scroll anyway?" with a snip of the game's own stepper slider, and "i feel like
    -- we should have a button for \"match base icon size\" (which does what you would think) and maybe a box
    -- nearby to toggle whether the flyout background is shown at all, and an opacity for the flyout
    -- background."
    local base = menu.scale
    local slider = page.slider
    check(slider.template == "MinimalSliderWithSteppersTemplate" and page.smaller == nil and page.larger == nil,
        "the size is the game's slider with a stepper at each end, and no Smaller or Larger button")
    check(entry(one, 1).w == 30 and entry(one, 1).h == 30, "by default the icons are the game's own flyout size, 30 wide")
    check(slider:GetValue() == 100 and slider.RightText.text == "100%", "the size slider starts at 100%, said at its right")
    slider:SetValue(150)
    check(math.abs(menu.scale - base * 1.5) < 0.001 and NS.Profiles.Data().size == 1.5 and slider.RightText.text == "150%",
        "at 150% a flyout is half again as big, and the profile keeps it")
    slider.Forward.scripts.OnClick(slider.Forward)
    check(slider:GetValue() == 155 and NS.Profiles.Data().size == 1.55, "its right stepper steps it up")
    slider.Back.scripts.OnClick(slider.Back)
    check(slider:GetValue() == 150, "and its left stepper down")
    W.combat = true
    slider:SetValue(100)
    check(math.abs(menu.scale - base * 1.5) < 0.001 and slider:GetValue() == 150, "no size change in a fight")
    W.combat = false
    slider:SetValue(100)
    check(math.abs(menu.scale - base) < 0.001 and NS.Profiles.Data().size == nil, "back at 100% it is the game's size again")
    -- the bar's own icon size: an icon of the flyout as large as the bar button's
    page.match.scripts.OnClick(page.match)
    check(math.abs(entry(one, 1).w * menu.scale - host:GetWidth() * host:GetEffectiveScale() / UIParent:GetEffectiveScale())
        < 0.01 and slider:GetValue() == 150,
        ("Match Base Icon Size: its icons as large as the bar button's (%s against %s)"):format(
            tostring(entry(one, 1).w * menu.scale), tostring(host:GetWidth())))
    slider:SetValue(100)
    -- the background: shown or not, and how opaque
    local unit = select(2, NS.Flyouts.At(host:GetName()))
    local strip = unit.strip
    local function seen() return strip.first.shown and strip.last.shown end
    check(page.back:GetChecked() and seen() and page.opacity:GetValue() == 100 and strip.first:GetAlpha() == 1,
        "the background is shown and whole to begin with")
    page.opacity:SetValue(40)
    check(math.abs(strip.first:GetAlpha() - 0.4) < 0.001 and math.abs(strip.last:GetAlpha() - 0.4) < 0.001
        and NS.Profiles.Data().backAlpha == 0.4 and page.opacity.RightText.text == "40%",
        "at 40% the background is that opaque, and the profile keeps it")
    page.back.checked = false
    page.back.scripts.OnClick(page.back)
    check(not seen() and NS.Profiles.Data().noBack == true and not page.opacity:IsSliderEnabled(),
        "unticked, no background is drawn, and its opacity is grayed out")
    W.combat = true
    page.back.checked = true
    page.back.scripts.OnClick(page.back)
    check(not seen() and not page.back:GetChecked(), "in a fight it does not change, and the box shows it")
    W.combat = false
    page.back.checked = true
    page.back.scripts.OnClick(page.back)
    page.opacity:SetValue(100)
    check(seen() and NS.Profiles.Data().noBack == nil and NS.Profiles.Data().backAlpha == nil and page.opacity:IsSliderEnabled(),
        "ticked again and back at 100%, nothing is kept in the profile: it is how flyouts are")
end

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
local castsBefore = #W.casts
rightClick(entry(one, 4))
check(count(one) == 4 and #W.casts == castsBefore + 1 and not menu:IsShown(),
    "in a fight a right-click casts the icon, as on a bar, and takes nothing out")
if menu:IsShown() then tap("ESCAPE") end
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
-- A player's word (2026-11-24): "There are macros that will do one thing if you left click and another thing
-- if you right click. With your addon, right clicking removes the macro of the menu", with a macro of
-- "/use [button:1] 16; [button:2] 17". His answer: "I'll switch the default to just not have right click
-- remove since can just shift drag to remove like usual anyway."
rightClick(entry(one, 2))
check(count(one) == 4 and #W.casts == casts + 1 and W.castButtons[#W.casts] == "RightButton" and not menu:IsShown(),
    "a right-click casts the icon as on a bar, with the right button (a macro's [button:2] runs), and takes nothing out")
casts = #W.casts
tap("E")
-- dragged off the flyout and let go, as off a bar
local units = NS.Flyouts.Units()
NS.Flyouts.CarryOff(units[one], 4)
W.cursor = nil
check(count(one) == 3 and #W.casts == casts, "an icon dragged off the flyout and let go is out of it, and nothing is cast")
check(#NS.Profiles.Data().flyouts[1].entries == 3, "and it is out of the saved flyout")
check(lastChat("taken off") == nil, "and chat says nothing of it: it was plain to see")
if menu:IsShown() then tap("ESCAPE") end
NS.Flyouts.CarryOff(units[two], 2)
W.cursor = nil
check(not opens("2") and not opens("Q") and #NS.Profiles.Data().flyouts == 1,
    "with its one added entry out, the second flyout is gone")
check(opener("1") ~= nil and GetBindingAction("2", true) == "ACTIONBUTTON2", "and its key is the bar's again")
check(lastChat("taken off") == nil and lastChat("flyout is gone") == nil, "and chat says nothing of that either")
mouse(W.frames.ActionButton2)
check(W.casts[#W.casts] == "bar:ActionButton2", "and a click on that button casts its own ability again")

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

print("carried onto the plus of a flyout's button, the flyout opens with a gap where it goes")
do
    -- His words (2026-11-24): "is there a reason when adding spells to an existing flyout we don't show the
    -- full preview so we can decide what order to put it in right away??", and of how a drop chooses between
    -- putting it in and taking an icon's place, over the middle of an icon replacing it and anywhere else
    -- putting it in: "obviously yes the way you said it.."
    if menu:IsShown() then tap("ESCAPE") end
    local Art = NS.Art
    -- a point that many places along the flyout (0.5: the first icon's middle)
    local function point(r)
        local d, s = r * (Art.ICON + Art.NEXT) + Art.FIRST - Art.NEXT / 2, menu:GetEffectiveScale()
        local x, y = (menu.rect[1] + menu.rect[2]) / 2, (menu.rect[3] + menu.rect[4]) / 2
        if unitOne.way == "UP" then y = menu.rect[4] + d end
        if unitOne.way == "DOWN" then y = menu.rect[3] - d end
        if unitOne.way == "RIGHT" then x = menu.rect[1] + d end
        if unitOne.way == "LEFT" then x = menu.rect[2] - d end
        return x * s, y * s
    end
    local function carry(id)
        W.cursor = { "spell", 7, "spell", id, id }
        fire("CURSOR_CHANGED")
        flushAll()
    end
    local function onPlus()
        local tab = plus()
        local x, y = tab:GetCenter()
        local s = tab:GetEffectiveScale()
        W.mouseX, W.mouseY = x * s, y * s
        tab.over = true
        tab.scripts.OnEnter(tab)
        return Move.Preview(), tab
    end
    local function tick() for _ = 1, 40 do Move.Tick(0.02) end end
    carry(503)
    local p, tab = onPlus()
    check(p ~= nil and menu:IsShown() and p.gap == 4 and p.ghost.shown ~= false and p.ghost.icon.texture == 503
        and p.catcher:IsShown(), "pointed at the plus, the flyout opens, what is carried faintly in a gap at its end")
    tick()
    check(p.gap == 4 and p.target == nil, "while the cursor stays on the plus the gap stays at the end")
    -- His words (2026-11-24): "when i try to replace, it just bounces out of my way". On the way to the
    -- first icon's middle the cursor crosses its edge: nothing moves, and its middle takes the drop.
    tab.over, p.catcher.over = false, true
    W.mouseX, W.mouseY = point(0.05)
    Move.Tick(0.02)
    check(p.gap == 4 and along(entry(one, 1)) == slot(1), "passing an icon's edge moves nothing")
    W.mouseX, W.mouseY = point(0.3)
    Move.Tick(0.02)
    check(p.target == 1 and entry(one, 1).lit and p.gap == 4 and along(entry(one, 1)) == slot(1),
        "most of an icon takes the drop as a replacement at once, and it stays where it is")
    -- resting between two icons: they part there after a moment
    W.mouseX, W.mouseY = point(1.02)
    Move.Tick(0.1)
    Move.Tick(0.2)
    check(p.gap == 4 and p.between == 2, "between the first icon and the second, nothing moves for a moment")
    Move.Tick(0.1)
    check(p.gap == 2 and p.between == nil, "after a rest of 0.35 s there, Android's first wait, the gap goes there")
    -- off the plus, along the flyout
    tab.over, p.catcher.over = false, true
    W.mouseX, W.mouseY = point(1.02)
    tick()
    check(p.gap == 2 and p.target == nil and along(entry(one, 1)) == slot(1) and along(entry(one, 2)) == slot(3)
        and along(entry(one, 3)) == slot(4), "between the first icon and the second, the gap goes there and the icons part")
    W.mouseX, W.mouseY = point(2.5)
    tick()
    check(p.target == 2 and entry(one, 2).lit and not entry(one, 1).lit and p.ghost.shown == false,
        "over the middle of an icon, that icon lights up instead: a drop there takes its place")
    W.mouseX, W.mouseY = point(1.5)
    tick()
    check(p.gap == 2 and p.target == nil and not entry(one, 2).lit, "back over the gap, it goes in there again")
    p.catcher.scripts.OnReceiveDrag(p.catcher)
    flushAll()
    check(order() == "101 503 501 502" and W.cursor == nil and Move.Preview() == nil and menu:IsShown(),
        "let go, it goes in where the gap was, and the flyout stays open to show it")
    tap("ESCAPE")
    -- over the middle of an icon: it takes that icon's place, and the one it took the place of is carried
    carry(504)
    p, tab = onPlus()
    tab.over, p.catcher.over = false, true
    W.mouseX, W.mouseY = point(2.5)
    tick()
    check(p.target == 3, "over the third icon's middle")
    p.catcher.scripts.OnReceiveDrag(p.catcher)
    flushAll()
    check(order() == "101 503 504 502" and W.cursor ~= nil and W.cursor[4] == 501,
        "let go, it takes that icon's place, and the icon it took the place of is on the cursor")
    if menu:IsShown() then tap("ESCAPE") end
    -- let go on the plus at once: at the end, as ever
    carry(505)
    p, tab = onPlus()
    tab.scripts.OnReceiveDrag(tab)
    flushAll()
    check(order() == "101 503 504 502 505" and W.cursor == nil, "let go on the plus itself, it goes in at the end, as ever")
    if menu:IsShown() then tap("ESCAPE") end
    -- the cursor away from the plus and the flyout: it shuts as it was
    carry(506)
    p, tab = onPlus()
    tab.over = false
    p.catcher.over = false
    tick()
    check(Move.Preview() == nil and not menu:IsShown() and along(entry(one, 2)) == slot(2) and not p.catcher:IsShown(),
        "the cursor away from the plus and the flyout, it shuts, every icon in its own place")
    W.cursor = nil
    fire("CURSOR_CHANGED")
    flushAll()
    -- as it was, for what follows: 101 501 502
    local record = NS.Flyouts.At("ActionButton1")
    for i = #record.entries, 1, -1 do
        local id = record.entries[i].id
        if id ~= 101 and id ~= 502 then NS.Flyouts.Remove(record, i) end
    end
    NS.Flyouts.Stack(W.frames.ActionButton1, { kind = "spell", id = 501 })
    NS.Flyouts.Move(record, 3, 2)
    check(order() == "101 501 502", "the flyout as it was: " .. order())
end

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
check(lastChat("taken off") == nil, "with no word of it in chat")
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

print("the game's key menu: a row for each of the twelve spots of every flyout, and none of any one flyout")
local Binds = NS.Binds
do
    -- His words (2026-11-22), of the eight headings with six rows each that stood here: "why have empty flyouts
    -- here? that makes no sense. can in principle make infinite num flyouts, right? this makes it seem like 8
    -- is max." And of what stands here now: "ok do that and then a sentence at bottom or top that says \"For
    -- flyout-specific keybindings rather than this general set, see the addon settings menu.\"??? where we
    -- allow ppl to set specifics? or what". A key for one icon is set by a hover in the game's Quick Keybind
    -- Mode, on the same page of the game's options: the sentence names that.
    local file = assert(io.open("Bindings.xml"))
    local xml = file:read("a")
    file:close()
    local listed, hidden, picks, texts, gaps, fine = 0, 0, 0, {}, 0, true
    for row in xml:gmatch("<Binding [^>]+>") do
        local name = row:match('name="([%w_]+)"')
        if row:find('hidden="true"', 1, true) then
            hidden = hidden + 1
            fine = fine and name:find("^" .. Binds.SPOT .. "%d+S%d+$") ~= nil and not row:find("category=", 1, true)
        else
            listed = listed + 1
            fine = fine and row:match('category="([%w_]+)"') == Binds.CATEGORY
            if name:find("^" .. Binds.PICK .. "%d+$") then
                picks = picks + 1
                fine = fine and _G["BINDING_NAME_" .. name] == "Spot " .. name:match("%d+$") .. " of every flyout"
            elseif name:find("^PREFACE_") then
                texts[#texts + 1] = _G[name]
                -- one line of the key menu is 580 wide: about 88 letters of its font
                fine = fine and type(_G[name]) == "string" and #_G[name] <= 88
            else
                gaps = gaps + 1
                fine = fine and name:find("^HEADER_") ~= nil
            end
        end
    end
    check(picks == 12 and Binds.PICKS == 12 and #texts == 4 and gaps == 1 and listed == 17 and fine
        and _G[Binds.CATEGORY] == "Fallen's Flyouts",
        "Bindings.xml lists twelve rows, one for each spot of every flyout, each with its text, under the addon's own heading")
    check(hidden == Binds.SLOTS * Binds.PLACES and hidden == 48,
        "the rows of before, a heading's six for each of eight flyouts, are no row of the menu any more: hidden, kept for their keys")
    local ours, old = 0, 0
    for i = 1, GetNumBindings() do
        local command = GetBinding(i)
        if command:find("^" .. Binds.PICK .. "%d+$") then ours = ours + 1 end
        if command:find("^" .. Binds.SPOT .. "%d+S%d+$") then old = old + 1 end
    end
    check(ours == 12 and old == 0, ("what the game lists of ours: %d rows of every flyout, %d of any one flyout"):format(ours, old))
    check(texts[1] == "Keys for the icons inside your flyouts, the same for every flyout."
        and texts[2]:find("1 to 9, 0, - and =", 1, true) ~= nil,
        "over the rows it says what they are, and what the keys are with none set: " .. tostring(texts[2]))
    check(texts[3] == "All flyout keys, these and the keys of one flyout, are in the addon's settings: /ff."
        and texts[4] == "Or use Quick Keybind Mode above: open the flyout, hover an icon, press the key.",
        "under them it says where the keys of one flyout are set: the addon's settings first, as he worded it: "
        .. tostring(texts[3]) .. " " .. tostring(texts[4]))
    check(NS.KeyMenu == nil and NS.Flyouts.Point == nil and Binds.Head == nil and Binds.Number == nil,
        "nothing is left of the headings: no names for them, and no hover that lit a flyout's button from its rows")
end
local function rebound()
    W.clock = W.clock + 10
    fire("UPDATE_BINDINGS")
    W.ticker()
end
local keyed = NS.Flyouts.At("ActionButton1")
local second2 = "CLICK FallensFlyoutsEntry" .. one .. "_2:Key"
-- a key on a row of every flyout picks that spot while a flyout is open
W.base.T = Binds.PICK .. "2"
W.base.PADLSHOULDER = Binds.PICK .. "2"
rebound()
check(opener("T") == nil and opener("1") == one, "a key on a row opens nothing: the flyout opens by its bar button's key")
tap("E")
check(menu:IsShown() and GetBindingAction("T", true) == second2 and label(2) == "T",
    "with a flyout open, the key set for spot 2 of every flyout picks its second icon, and the icon shows it")
check(GetBindingAction("PADLSHOULDER", true) == second2, "a pad button set there picks it too")
check(GetBindingAction("2", true) == "ACTIONBUTTON2", "and 2 is the bar's own then")
tap("T")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "pressed, it casts that icon and shuts the flyout")
check(GetBindingAction("T", true) == Binds.PICK .. "2", "shut, the key is its row's again: it does nothing")
NS.Flyouts.SetKey(keyed, 2, "Y", false)
tap("E")
check(GetBindingAction("Y", true) == second2 and GetBindingAction("T", true) ~= second2,
    "an icon's own key stands before the row's")
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
-- A key set on one of the old rows, by someone on a version before 1.1.4: the flyout was saved with its
-- heading's number, and the game's bindings still hold the key on that row's command.
keyed.number = 1
W.base.F9 = Binds.Command(1, 2)
W.base.PADRSHOULDER = Binds.Command(1, 3)
NS.Flyouts.SetKey(keyed, 1, "U", false)
W.base.F10 = Binds.Command(1, 1)
rebound()
NS.Flyouts.Apply()
check(keyed.entries[2].key == "F9" and keyed.entries[3].pad == "PADRSHOULDER" and keyed.number == nil,
    "a key and a pad button set on rows of before are their icons' own now, and the heading's number is gone from the flyout")
check(keyed.entries[1].key == "U", "an icon that has a key of its own keeps it")
check(W.base.F9 == Binds.Command(1, 2) and GetBindingAction("F9", false) == Binds.Command(1, 2),
    "nothing of the game's bindings is rewritten: the old row still holds its key there")
tap("E")
check(menu:IsShown() and GetBindingAction("F9", true) == second2 and label(2) == "F9", "open, that key picks its icon as it did")
tap("F9")
check(W.casts[#W.casts] == "spell:501" and not menu:IsShown(), "and casts it")
-- a character of the same account on a later login: the row still holds its key, the icon has one of its own
keyed.number = 1
NS.Flyouts.SetKey(keyed, 2, "G", false)
NS.Flyouts.Apply()
check(keyed.entries[2].key == "G" and keyed.number == nil, "an icon's own key, set since, is not overwritten by the old row's")
NS.Flyouts.SetKey(keyed, 1, nil, false)
NS.Flyouts.SetKey(keyed, 2, nil, false)
NS.Flyouts.SetKey(keyed, 3, nil, true)
W.base.F9, W.base.F10, W.base.PADRSHOULDER = nil, nil, nil
rebound()
check(opener("1") == one and label(1) == "1" and label(2) == "2", "the keys given back, all is as before")

print("our key layers addon: its hold keys open nothing, an open flyout's keys are the flyout's, nothing is read off the bars while one is down")
do
    local held = false
    FallensFlyouts_Layers({ Held = function() return held end, HoldKeys = function() return { "1" } end })
    check(opener("1") == nil and opener("E") == one, "a key that holds a layer is no opener key, though it is the bar button's own")
    -- His words (2026-11-22), his flyouts having begun at 2 once key 1 held a layer: "why are all the
    -- flyouts starting at 2 now instead of 1????" and "we should always respect our in-flyout keys. if
    -- someone opened the flyout, they want THOSE keys to take precedence."
    tap("E")
    check(menu:IsShown() and label(1) == "1" and label(2) == "2"
        and GetBindingAction("1", true) == "CLICK FallensFlyoutsEntry" .. one .. "_1:Key",
        "open, the flyout's keys are the flyout's: its first icon is on 1 though 1 holds a layer")
    local castsBefore = #W.casts
    tap("1")
    check(#W.casts == castsBefore + 1 and W.casts[#W.casts] == "spell:101" and not menu:IsShown(),
        "pressed, 1 casts the first icon and shuts the flyout: " .. tostring(W.casts[#W.casts]))
    check(GetBindingAction("1", true) == "ACTIONBUTTON1" and opener("1") == nil,
        "shut, the key is whoever's it was, and it still opens nothing of ours")
    tap("E")
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
    -- A modifier key that is held DOWN as the flyout opens is its addon's until it is let go: its
    -- release has to end the layer there. (Its root says so: hdown_<KEY>.) Up, it is the flyout's.
    FallensFlyouts_Layers({ Held = function() return held end, HoldKeys = function() return { "1" } end,
        Root = function() return theirs end })
    rebound()
    local first, second = "CLICK FallensFlyoutsEntry" .. one .. "_1:Key", "CLICK FallensFlyoutsEntry" .. one .. "_2:Key"
    theirs.attrs.hdown_1 = true
    tap("E")
    check(menu:IsShown() and GetBindingAction("1", true) == "ACTIONBUTTON1" and GetBindingAction("2", true) == second
        and label(1) == "1", "opened with that key held down: it is left to its addon, the rest are the flyout's, the icons count from 1 all the same")
    tap("E")
    theirs.attrs.hdown_1 = nil
    tap("E")
    check(menu:IsShown() and GetBindingAction("1", true) == first, "opened with it up, as when its layer is tapped on: the key is the flyout's")
    tap("E")
    -- a layer on, none of whose keys is this flyout's opener key
    theirs.attrs.lkey1_E = nil
    theirs.attrs.layer = 1
    tap("E")
    check(menu:IsShown() and GetBindingAction("1", true) == first, "a layer on with its key up does not keep the key from the flyout")
    tap("E")
    theirs.attrs.layer = nil
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

print("the settings: General on the addon's page, a Controller page of its own for what only a controller needs")
do
    -- His words (2026-11-24): "this is a very confusing section. if we have a section only relevant to
    -- console players, then 1: it should be cleanly separated (aka like another tab in the dropdown like
    -- automatic flyouts are) and 2, it should be clearly labelled as such... i have no idea what i'm
    -- looking at there, and why things like keep a spell ranks in order button etc are under arrange a
    -- flyout."
    local main = page.arrange
    check(main.ranks ~= nil and main.hide ~= nil and main.twice ~= nil and main.icons == nil and main.around == nil
        and main.plate == nil and main.faces == nil,
        "the addon's page has the three settings for every flyout, and nothing of a controller's")
    local over = select(2, main.ranks:GetPoint())
    check(over ~= nil and over.text == "General", "they stand under a heading of their own, General: "
        .. tostring(over and over.text))
    local pad = NS.ControllerUI.panel
    local listed, auto
    for i, sub in ipairs(W.subcategories or {}) do
        if sub.frame == pad then listed = i end
        if sub.frame == NS.AutoUI.panel then auto = i end
    end
    local sub = listed and W.subcategories[listed]
    check(sub ~= nil and sub.name == "Controller" and sub.parent == W.category and auto ~= nil and listed > auto,
        "the Controller page is a page of its own under the addon's, named Controller, listed after Automatic Flyouts")
    NS.ControllerUI.Build()
    local w = pad.arrange
    check(w ~= nil and w.around ~= nil and w.faces ~= nil and w.plate ~= nil and w.ranks == nil and w.hide == nil,
        "it holds the three settings of gamepad mode, and none of the rest")
    local Arrange = NS.Arrange
    local function press(button) button.scripts.OnClick(button) end
    check(w ~= nil and #w.icons == 12 and w.off ~= nil, "and the arrange row: twelve icon places, Previous, Next and Take Off")
    -- His words (2026-11-22): "ok leave it if needed for controllers. but put reminder there that you can
    -- simply drag spells onto each other where the \"+\" appears to create the flyouts so ppl dont think
    -- they HAVE to go through that ... for non controller users"
    local live = w.live and w.live.text or ""
    check(live:find("Only for playing with a controller", 1, true) == 1 and live:find("none of this page is needed", 1, true) ~= nil
        and live:find("onto a bar button, where the + appears", 1, true) ~= nil,
        "its first words: only for a controller; with a mouse a flyout is made by a drag onto the +")
    -- the page up, as when it is being used: it follows what changes on the bars
    pad:Show()
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
    check(count(one) == 2 and lastChat("taken off") == nil and Arrange.Held() == nil,
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
    press(w.icon)
    check(NS.Icon.Target() == NS.Flyouts.At("ActionButton1") and NS.Icon.Target() ~= nil,
        "Icon and Name opens the icon and name window for the flyout shown, as a right-click on its button does")
    W.frames.FallensFlyoutsIconPopup:Hide()
    pad:Hide()
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
    do
        -- an item's range: asked outside a fight, never in one (the client keeps that call from addons there)
        local function keyColor(i)
            local c = entry(foodUnit.index, i).key.color
            return c and table.concat(c, ",")
        end
        local caught = #W.caught
        W.target, W.farItems = true, { [4541] = true }
        fire("PLAYER_TARGET_CHANGED")
        check(keyColor(1) == "1,0.1,0.1" and keyColor(2) == "0.8,0.8,0.8", "an item out of range of the target has its key red too")
        W.combat = true
        fire("PLAYER_TARGET_CHANGED")
        C_Timer.After(0, function() end)
        flushAll()
        check(#W.caught == caught and keyColor(1) == "0.8,0.8,0.8", "in a fight an item's range is not asked: no error, no red")
        W.combat = false
        W.target, W.farItems = nil, nil
        fire("PLAYER_TARGET_CHANGED")
        check(keyColor(1) == "0.8,0.8,0.8" and #W.caught == caught, "no target: its key is gray again")
    end
    do
        -- a flyout that fills itself takes nothing by hand, in a fight as out of one
        local held = #food.entries
        C_Spell.PickupSpell(501)
        DropOn(entry(foodUnit.index, 1))
        check(#food.entries == held and W.cursor ~= nil and W.errors[#W.errors] == "That flyout fills itself from your bags.",
            "a drop on an icon of a flyout that fills itself is refused in red")
        W.cursor = nil
        W.combat = true
        C_Spell.PickupSpell(501)
        DropOn(foodUnit.opener)
        check(#food.entries == held and W.cursor ~= nil and W.errors[#W.errors] == "That flyout fills itself from your bags.",
            "in a fight a drop on the arrow of a flyout that fills itself is refused in red")
        W.combat = false
        W.cursor = nil
        fire("ACTIONBAR_HIDEGRID")
    end
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
    for id = 4550, 4563 do W.items[id] = { sub = 5, level = id - 4500 } end
    bags({ 4540, 4550, 4551, 4552, 4553, 4554, 4555, 4556, 4557, 4558, 4559, 4560, 4561, 4562, 4563 })
    check(ids(NS.Flyouts.At("ActionButton9")) == "4563 4562 4561 4560 4559 4558 4557 4556 4555 4554 4553 4552",
        "with more than twelve kinds of food, the twelve best are shown")
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
    for id = 604, 612 do
        W.bags[#W.bags + 1] = id
        stackItem("ActionButton8", id)
    end
    bags({ 601 })
    local errorsBefore = #W.errors
    W.bags[#W.bags + 1] = 613
    stackItem("ActionButton8", 613)
    check(#NS.Flyouts.Full(own) == 12 and ids(own) == "601 9101" and #W.errors == errorsBefore + 1,
        "full is full, though only two of the twelve show")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    -- none of its items, and the spell taken off: nothing to show, yet still reached from the settings
    bags({})
    check(ids(own) == "9101" and NS.Flyouts.At("ActionButton8") == own, "with none of the items it shows what is left: the spell")
    NS.Arrange.Refresh()
    local box = page.arrange.hide
    check(box ~= nil and box:GetChecked(), "the settings page has a check box for it under General, ticked")
    -- what is saved is the whole
    fire("PLAYER_LOGOUT")
    check(own.all == nil and #own.entries == 12, "what is saved is the whole flyout")
    NS.Flyouts.Apply()
    check(ids(own) == "9101" and #NS.Flyouts.Full(own) == 12, "and it is laid as before from that")
    box.checked = false
    box.scripts.OnClick(box)
    check(not NS.Flyouts.Hiding() and #own.entries == 12 and own.all == nil and NS.Profiles.Data().showLacking == true,
        "unticked: everything shows, whether the player has it or not, and the profile remembers")
    W.combat = true
    box.checked = true
    box.scripts.OnClick(box)
    check(not NS.Flyouts.Hiding() and not box:GetChecked(), "in a fight the setting does not change, and the box shows it")
    W.combat = false
    NS.Flyouts.SetHiding(true)
    check(NS.Profiles.Data().showLacking == nil, "ticked again, nothing is kept in the profile: it is how flyouts are")
    -- taken apart from the front: its spell is no longer its first icon
    for _ = 1, 14 do
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
        NS.ControllerUI.panel.arrange.turn.scripts.OnClick(NS.ControllerUI.panel.arrange.turn)
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
    -- Edit Action Bar's first box, and the game's own hint bars: one under each box, up with its box
    dialog.EditActionBarsInfoFrame = CreateFrame("Frame", nil, dialog)
    dialog.EditActionBarsInfoFrame:Hide()
    dialog.bindingModeFooter = { inputLegend = CreateFrame("Frame", nil, box) }
    dialog.editModeFooter = { inputLegend = CreateFrame("Frame", nil, dialog.EditActionBarsInfoFrame) }
    local theirBar, theirFirstBar = dialog.bindingModeFooter.inputLegend, dialog.editModeFooter.inputLegend
    function dialog:ShowEditModeFrameAndBindings()
        self.EditActionBarsInfoFrame:Show()
        self.BindingInfoFrame:Hide()
    end
    function dialog:ShowBindingModeFrameAndBindings()
        self.EditActionBarsInfoFrame:Hide()
        self.BindingInfoFrame:Show()
    end
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
        self:TransitionToSelectActionToPickup()
        self:Show()
        self:StartListeningForButtons()
    end
    function dialog:TransitionToSelectActionToPickup()
        self.editHolding = nil
        self:ShowEditModeFrameAndBindings()
    end
    function dialog:UndoEdit()
        if self:PlaceOrClearHeldActionCapturedInputHandler(self.pickupSlot, false) then self:TransitionToSelectActionToPickup() end
    end
    -- as the game's: the ability comes off the button and is held, and the box says what is held
    function dialog:SelectActionToPickupCapturedInputHandler(slot)
        ClearCursor()
        local _, had = GetActionInfo(slot)
        if not had then return false end
        W.placed[slot] = false
        fire("ACTIONBAR_SLOT_CHANGED", slot)
        self.pickupFunc, self.pickupParams, self.pickupSlot = C_Spell.PickupSpell, { had }, slot
        self.editHolding = true
        return true
    end
    -- as the game's capture: the box of the held ability comes up only after the pick up has returned
    function dialog:CapturePickup(slot)
        if self:SelectActionToPickupCapturedInputHandler(slot) then self:ShowBindingModeFrameAndBindings() end
    end
    function dialog:ExitEditMode()
        self.editHolding = nil
        self:Hide()
    end
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
    -- A press is its own moment in time. It is given out as the game gives a pad press out: first to the
    -- topmost frame that takes the pad's buttons, and on to the next only when that one passes it on.
    -- `W.noCatch`: a client that gives a frame of ours nothing while its dialog is up.
    local function press(key, slot)
        W.clock = W.clock + 1
        local catcher = W.frames.FallensFlyoutsPadCatcher
        if catcher and catcher:IsVisible() and not W.noCatch and catcher.scripts.OnGamePadButtonDown(catcher, key) ~= true then
            return
        end
        dialog.heldSlot = slot
        dialog.scripts.OnGamePadButtonDown(dialog, key)
        dialog.heldSlot = nil
        -- the dialog's own Cancel while it holds an ability picked up in Edit Action Bar: put back, first step
        if key == "PAD2" and dialog.editHolding and dialog:IsShown() then dialog:UndoEdit() end
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
    check(lastChat("is in the flyout of") == nil and up() and prompts.back.label == "Done",
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
            dialog:CapturePickup(slot)
        end
        dialog:EnterEditMode()
        -- His words (2026-11-21): "why is the symbols that indicate flyout going away when i go to edit action
        -- bar??? we just force user to memorize which is the flyouts?" The dialog shows copies of the bar's
        -- buttons, and a copy had none of our marks.
        local marks = Pad.Marks()
        local onSeven, onFive
        for _, mark in ipairs(marks and marks.pool or {}) do
            if mark.on == W.frames.GamepadActionBarEditFrameTestActionButton7 then onSeven = mark end
            if mark.on == W.frames.GamepadActionBarEditFrameTestActionButton5 then onFive = mark end
        end
        check(marks ~= nil and marks:IsVisible() and onSeven ~= nil and onSeven:IsVisible() and onSeven.dots.shown == true
            and onSeven.dots.pieces[1].dot.shown and onSeven.dots.pieces[1].dot.point[2] == W.frames.GamepadActionBarEditFrameTestActionButton7,
            "in Edit Action Bar the dialog's copy of a button that has a flyout wears the flyout's dots, at its corner")
        check(onFive == nil, "a copy of a button with no flyout wears none")
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
        -- His words (2026-11-21), of the build that edited only after the dialog: "why am i being sent
        -- through TWO identical instructions before getting to flyout editing? ... first i have to hit A
        -- ... then it tells me i have to hit B ... then it tells me to hit B a-fucking-gain ... and THEN it
        -- finally goes to what it should have fking done with the first A". And: "why the hell does it
        -- un-dim everything and open the spellbook back up?!!? we're still editing!!" So: A, and the editor
        -- is up there and then, inside Edit Action Bar, a frame of ours keeping the pad from the dialog.
        local copy7 = W.frames.GamepadActionBarEditFrameTestActionButton7
        local function dial() return table.concat(NS.Flyouts.Spots(target.entries), " ") end
        local function slots() return table.concat({ tostring(W.placed[4]), tostring(W.placed[5]), tostring(W.placed[6]),
            tostring(W.placed[7]) }, " ") end
        press("PAD1")
        local catcher = W.frames.FallensFlyoutsPadCatcher
        local inside = Edit.Editing()
        check(inside ~= nil and inside.inside == dialog and dialog:IsShown() and select(2, GetActionInfo(7)) == 771
            and NS.Flyouts.At("ActionButton7") == target and ids() == "771 772 773",
            "A: the flyout editor is up at once, inside Edit Action Bar, with no other button to press first; the ability is back on its button")
        check(catcher ~= nil and catcher:IsVisible() and catcher:GetFrameStrata() == "TOOLTIP",
            "a frame of ours over the dialog is up to take the pad's presses")
        local says = Pad.Panel()
        check(says ~= nil and says:IsShown() and says.title.text == "Edit Flyout" and says.lines[1].text == NS.Flyouts.Name(target.entries[1]) .. " is selected."
            and says.lines[2].text == "The D-pad moves it to that side of the button."
            and says.lines[3].text == "Press the same side again for the next ring out." and box.BindInstructionText.alpha == 0,
            "the game's box says what is selected and what the D-pad does: " .. tostring(says.lines[1].text))
        check(prompts.add.label == "Select Next Icon" and prompts.left.label == "Take Icon Off" and prompts.edit.label == "Use Face Buttons"
            and prompts.back.label == "Done" and prompts.plate ~= nil and prompts.plate.label == "Hide Background"
            and theirBar:GetAlpha() == 0 and bar.point[2] == theirBar,
            "one hint bar, ours, where the game's stands, names every button")
        check(Pad.View():IsShown() and Pad.View().around == copy7 and Pad.View().marked == 1,
            "the flyout is pictured around the dialog's copy of its button, the first icon selected")
        -- what he did then: the D-pad, to move the selected icon
        local held = slots()
        press("PAD1")
        check(Edit.Editing().mark == 2 and Pad.View().marked == 2 and says.lines[1].text == NS.Flyouts.Name(target.entries[2]) .. " is selected.",
            "A: the next icon is selected, and the box names it")
        press("PADDUP", 4)
        check(dial() == "2 1 3" and slots() == held and W.placed[4] == 704 and Pad.View().tokens[2].pad == "PADDUP",
            "D-pad up: the selected icon goes up. The dialog is never given the press: every bar spot holds what it held: " .. slots())
        press("PADDLEFT", 6)
        check(dial() == "2 4 3" and slots() == held and W.placed[6] == false, "D-pad left: to the empty left side; the empty bar spot stays empty")
        press("PADLTRIGGER", 5)
        press("PADRTRIGGER", 5)
        check(slots() == held and Edit.Editing() ~= nil, "a trigger is kept from the dialog as well, and does nothing")
        -- B: done, and the same press is the dialog's own Cancel: one press, back at Edit Action Bar's first step
        press("PAD2")
        check(Edit.Editing() == nil and not catcher:IsVisible() and Pad.Armed() == nil and not up(),
            "B: done, at one press: the editor and the frame that kept the pad are gone")
        check(dialog:IsShown() and dialog.EditActionBarsInfoFrame:IsShown() and not box:IsShown() and theirBar:GetAlpha() == 1
            and theirFirstBar:GetAlpha() == 1 and box.BindInstructionText.alpha == 1,
            "the dialog is back at its first step, still up and dimmed, with its own words and hint bar")
        check(slots() == held and select(2, GetActionInfo(7)) == 771 and NS.Flyouts.At("ActionButton7") == target and dial() == "2 4 3",
            "nothing is held, every bar spot holds what it held, and the flyout is as edited: " .. dial())
        dialog:ExitEditMode()
        flushAll()
        check(Edit.Editing() == nil and not bound("PADDUP"), "the dialog left after that: nothing else opens")
        -- RB in the dialog: the icon and name window, once the dialog is left (it keeps the pad while it is up)
        dialog:EnterEditMode()
        pickUp(7)
        press("PAD1")
        check(Edit.Editing() ~= nil and Edit.Editing().inside == dialog, "the editor up in the dialog again")
        press("PADRSHOULDER", 7)
        check(Edit.Editing() == nil and Pad.Armed() ~= nil and Pad.Armed().icon == true and NS.Icon.Target() == nil
            and prompts.back.label == "Icon and Name",
            "RB in the dialog: the editor closes, and the icon and name window waits for the dialog to be left")
        dialog:ExitEditMode()
        flushAll()
        check(NS.Icon.Target() == target and Edit.Editing() == nil,
            "the dialog left, the icon and name window opens for that flyout, and not the editor")
        W.frames.FallensFlyoutsIconPopup:Hide()
        -- as it was, for what follows
        for _, e in ipairs(target.entries) do e.spot = nil end
        NS.Flyouts.Apply()

        -- A client that gives a frame of ours no pad press while its dialog is up. That shows at the first
        -- press: the dialog is given it. What it set down is undone, the box says how to go on, and from
        -- then on the editor opens after the dialog.
        W.noCatch = true
        dialog:EnterEditMode()
        pickUp(7)
        press("PAD1")
        check(Edit.Editing() ~= nil and Edit.Editing().inside == dialog and not Pad.CannotCatch(), "there too the editor comes up in the dialog at A")
        press("PADDUP", 4)
        check(slots() == held and W.placed[4] == 704 and dial() == "1 2 3", "D-pad up went to the dialog there: undone at once, every bar spot as it was")
        check(Pad.CannotCatch() and Edit.Editing() == nil and Pad.Armed() ~= nil and says:IsShown()
            and says.lines[1].text:find("to leave Edit Action Bar", 1, true) ~= nil and prompts.back.label == "Open Flyout Editor"
            and not prompts.add.shown,
            "and the box now says to leave Edit Action Bar for the editor: " .. tostring(says.lines[1].text))
        dialog:ExitEditMode()
        flushAll()
        check(Edit.Editing() ~= nil and Edit.Editing().inside == nil and bound("PADDUP"), "left, the editor opens after the dialog, the pad's buttons bound to it")
        tap("PAD2")
        check(Edit.Editing() == nil and not bound("PADDUP"), "and B ends that one")

        -- on such a client, from then on: A puts the ability back and the box says how to go on
        dialog:EnterEditMode()
        pickUp(7)
        press("PAD1")
        check(Pad.Armed() ~= nil and Pad.Picked() == nil and select(2, GetActionInfo(7)) == 771 and NS.Flyouts.At("ActionButton7") == target
            and ids() == "771 772 773",
            "A: the ability is back on its button at once and the flyout is whole")
        check(Edit.Editing() == nil and not bound("PADDUP") and not bound("PAD1"),
            "where the pad cannot be kept from the dialog, nothing is edited while it is up")
        check(prompts.back.shown and prompts.back.label == "Open Flyout Editor" and not prompts.add.shown and not prompts.left.shown
            and not prompts.edit.shown, "the bar names the one button to press: B opens the flyout editor")
        -- His snip (2026-11-21): "after hitting edit flyout, there's stacked hint bars". Ours, of one button,
        -- is shorter than the game's own under it, whose end showed beside ours.
        check(theirBar:GetAlpha() == 0 and Pad.Veiled() == theirBar and bar.point[2] == theirBar,
            "the game's own hint bar under ours is out of sight: one bar, not two")
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
        check(theirFirstBar:IsVisible() and theirFirstBar:GetAlpha() == 0 and bar.point[2] == theirFirstBar and theirBar:GetAlpha() == 1,
            "there our bar stands on the hint bar of that first step, which is out of sight in its turn; the other is as it was")
        -- another ability picked up there: the edit asked for is off
        pickUp(5)
        check(Pad.Armed() == nil and not up(), "another ability picked up instead: no editor is waiting any more")
        check(theirBar:GetAlpha() == 1 and theirFirstBar:GetAlpha() == 1 and Pad.Veiled() == nil,
            "our bar gone, the game's own hint bars are in sight again")
        dialog:TransitionToSelectActionToPickup()
        W.placed[5] = 701
        W.placed[4] = nil
        fire("ACTIONBAR_SLOT_CHANGED", 5)
        dialog:ExitEditMode()
        flushAll()
        check(Edit.Editing() == nil and not bound("PADDUP"), "the dialog left after that, nothing opens")

        -- an ability picked up and set down on an empty button: the flyout stays, and nothing is said
        local function alive()
            for _, own in ipairs(NS.Flyouts.List()) do
                if own == target then return true end
            end
            return false
        end
        local lines = #W.chat
        dialog:EnterEditMode()
        pickUp(7)
        press("PADDLEFT", 6)
        dialog:ExitEditMode()
        for _ = 1, 3 do flushAll() end
        check(#W.chat == lines and W.placed[6] == 771 and alive(), "the ability moved to an empty button: its flyout stays, and nothing is said")
        W.placed[6] = false
        W.placed[7] = 771
        fire("ACTIONBAR_SLOT_CHANGED", 6)
        fire("ACTIONBAR_SLOT_CHANGED", 7)
        for _ = 1, 3 do flushAll() end

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
            and bound("PAD3") and bound("PAD4") and bound("PADLSHOULDER") and bound("PADRSHOULDER"),
            "in it the pad's buttons are the editor's own")
        check(Pad.View():IsShown() and Pad.View().around == W.frames.ActionButton7 and Pad.View().marked == 1 and Pad.View().tokens[1].ring.shown,
            "the flyout is pictured in place around its own button, the first icon selected")
        check(prompts.add.label == "Select Next Icon" and prompts.left.label == "Take Icon Off" and prompts.edit.label == "Use Face Buttons"
            and prompts.back.label == "Done" and prompts.plate ~= nil and prompts.plate.label == "Hide Background"
            and prompts.plate.key == "PADLSHOULDER" and prompts.icon ~= nil and prompts.icon.label == "Icon and Name"
            and prompts.icon.key == "PADRSHOULDER",
            "the bar names every button: A selects, X takes off, Y swaps the pad's crosses, LB the background, RB the "
                .. "icon and name, B is Done")
        -- what he did: an icon selected, then D-pad for the side it should go to
        local function spots() return table.concat(NS.Flyouts.Spots(target.entries), " ") end
        local tokens = Pad.View().tokens
        tap("PAD1")
        check(Edit.Editing().mark == 2 and Pad.View().marked == 2, "A: the next icon round the dial is selected (the one to the right)")
        tap("PADDUP")
        check(spots() == "2 1 3" and ids() == "771 772 773" and Edit.Editing().mark == 2 and tokens[2].spot == 1 and tokens[2].pad == "PADDUP"
            and tokens[1].pad == "PADDRIGHT" and tokens[2].ring.shown and W.placed[4] == nil and select(2, GetActionInfo(7)) == 771,
            "D-pad up: the selected icon stands up now, and the one that was up took its side; nothing on the bars is touched: " .. spots())
        -- His words (2026-11-21), of the first editor, which only let two icons change places: "why would
        -- we not let users move an icon anywhere they want on the dial? why would they HAVE to swap with
        -- an existing one?"
        tap("PADDLEFT")
        check(spots() == "2 4 3" and tokens[2].spot == 4 and tokens[2].pad == "PADDLEFT" and Edit.Editing().mark == 2,
            "D-pad left, where no icon is: it goes there, and the side it left stays empty: " .. spots())
        local r = NS.Art.BUTTON / 2 + NS.Flyouts.RING_GAP + NS.Art.ICON / 2
        check(tokens[2].point[4] == -r and tokens[2].point[5] == 0 and tokens[1].point[4] == r and tokens[3].point[5] == -r,
            "the picture shows it so: one left of the button, one right, one below, none above")
        check(NS.PadEdit.Hint():find("is selected. The D-pad moves it to that side of the button.", 1, true) ~= nil
            and NS.PadEdit.Hint():find("Press the same side again for the next ring out.", 1, true) ~= nil,
            "the line over the bar says what the D-pad does, with no word of what cannot be done: " .. NS.PadEdit.Hint())
        tap("PADDLEFT")
        check(spots() == "2 8 3" and tokens[2].pad == "PAD3" and tokens[2].point[4] < -r,
            "the same side again: to the outer ring of that side, where the face button of that side picks it: " .. spots())
        tap("PADDLEFT")
        check(spots() == "2 12 3" and tokens[2].pad == nil and tokens[2].key.text == "" and tokens[2].point[4] < -r - NS.Art.ICON,
            "again: the third ring of that side, further out still, which no pad button picks: " .. spots())
        tap("PADDLEFT")
        check(spots() == "2 4 3" and tokens[2].pad == "PADDLEFT", "and once more: back on the first ring")
        tap("PADDDOWN")
        check(spots() == "2 3 4" and Edit.Editing().mark == 2, "D-pad down, where an icon is: the two change places: " .. spots())
        -- the bottom button goes round the dial as it lies, not as the icons were added
        tap("PAD1")
        check(Edit.Editing().mark == 3, "A: on to the next spot round the dial, the icon on the left")
        tap("PAD1")
        check(Edit.Editing().mark == 1, "A again, past the last: the first one round, the icon on the right")
        tap("PAD4")
        check(NS.Flyouts.Faces(target) == true and prompts.edit.label == "Use D-Pad" and tokens[1].pad == "PAD2",
            "Y: this flyout picks with the face buttons, the picture with it")
        tap("PAD4")
        tap("PADLSHOULDER")
        check(NS.Flyouts.Plate() == false and prompts.plate.label == "Show Background" and not Pad.View().plate.rim.shown,
            "LB: the background is off, in the picture too")
        tap("PADLSHOULDER")
        tap("PAD1")
        tap("PAD3")
        check(ids() == "771 773" and spots() == "2 4" and Edit.Editing() ~= nil and Edit.Editing().mark == 2 and Pad.View().count == 2,
            "X: the selected icon, the middle one, comes off; the others stay where they stand and the editing goes on: " .. spots())
        tap("PAD2")
        check(Edit.Editing() == nil and not bound("PADDUP") and not bound("PAD2") and not up() and NS.Flyouts.At("ActionButton7") == target,
            "B: done. The pad's buttons are the game's again and the flyout stays as edited")
        -- RB: the icon and name window for the flyout being edited, as a right-click on its bar button opens it
        Edit.Open(target)
        check(Edit.Editing() ~= nil, "the editor up again")
        tap("PADRSHOULDER")
        check(Edit.Editing() == nil and not bound("PADDUP") and NS.Icon.Target() == target,
            "RB: the editor closes, its buttons the game's again, and the icon and name window is open for that flyout")
        W.frames.FallensFlyoutsIconPopup:Hide()
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
        -- His words (2026-11-21): "backing out of the flyout editing just completely deleted the flyout
        -- entirely" (his log: the button picked up, then X, the game's own Unbind, then out); and
        -- (2026-11-22): "if someone explicitly destroys a flyout by dragging off/erasing, it shouldnt auto
        -- pop back onto that spell next time". Unbind does away with the button and its flyout for good,
        -- and the hint bar says so before it is pressed.
        dialog:EnterEditMode()
        pickUp(7)
        check(prompts.left.shown and prompts.left.label == "Unbind and Remove Flyout",
            "a flyout's button picked up: the left button is named for what it does there: " .. tostring(prompts.left.label))
        lines = #W.chat
        dialog:TransitionToSelectActionToPickup()
        check(not alive() and NS.Flyouts.At("ActionButton7") == nil and #W.chat == lines,
            "the game's Unbind on a flyout's button: the flyout is removed, with no chat line about it")
        dialog:ExitEditMode()
        for _ = 1, 3 do flushAll() end
        W.cursor = { "spell", 7, "spell", 771, 771 }
        PlaceAction(7)
        for _ = 1, 4 do flushAll() end
        check(select(2, GetActionInfo(7)) == 771 and NS.Flyouts.At("ActionButton7") == nil and not alive(),
            "the same ability bound there again: a plain button, no flyout comes back with it")
        W.placed[7] = nil
        fire("ACTIONBAR_SLOT_CHANGED", 7)
        flushAll()
        W.noCatch = nil
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
local leadUnit = NS.Flyouts.Units()[lead]
NS.Flyouts.CarryOff(leadUnit, 3)
NS.Flyouts.CarryOff(leadUnit, 2)
W.cursor = nil
check(not opens("1") and not opens("E") and opens("2") and #NS.Profiles.Data().flyouts == 1,
    "icons dragged off one by one take a flyout apart")
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

print("flyouts of the player's own: several kinds ticked make one that holds them all")
do
    -- His words (2026-11-22): "how do we allow users to make custom auto-populated flyouts like our shipped
    -- ones? ... put all said categories into a dropdown, and people can select one or more to combine too? so
    -- for ex could put food and drink into one."
    login("Player-1-0000000S")
    local Auto, Page, F9 = NS.Auto, NS.AutoUI, NS.Flyouts
    W.placed = W.placed or {}
    W.macros, W.level = {}, 10
    -- sub 8 is the game's "Other"; nouse: filed there by the game, with nothing to use
    W.items = {
        [4540] = { sub = 5, level = 5 }, [4541] = { sub = 5, level = 15, needs = 5 },
        [4542] = { sub = 5, level = 25, needs = 15 },
        [159] = { sub = 5, drink = true, level = 5 }, [1179] = { sub = 5, drink = true, level = 15, needs = 5 },
        [118] = { sub = 1, level = 5 }, [5997] = { sub = 2, level = 5 },
        [9001] = { sub = 8, level = 7 }, [9002] = { sub = 8, level = 9, nouse = true },
    }
    local function ids(entries)
        local out = {}
        for i, held in ipairs(entries or {}) do out[i] = tostring(held.id) end
        return table.concat(out, " ")
    end
    local function bags(list)
        W.bags = list
        fire("BAG_UPDATE_DELAYED")
        flushAll()
    end
    bags({ 4540, 159, 4541, 118, 4542, 1179, 5997, 9001, 9002 })
    local names = {}
    for i, part in ipairs(Auto.Parts()) do names[i] = part.name end
    check(table.concat(names, "|") == "Food|Drink|Potions|Elixirs|Flasks|Scrolls|Bandages|Explosives and Devices|Other",
        "the kinds to tick: the ready-made ones, then the game's other kinds of consumable under the game's names, none of "
            .. "them twice and none the game keeps only for old items: " .. table.concat(names, "|"))

    -- the page: a list of boxes to tick, Create, and a row of the player's own
    local page = Page.panel
    Page.Build()
    local function row(label)
        for _, r in ipairs(page.drop.rows) do
            if r.label == label then return r end
        end
    end
    check(#page.drop.rows == #Auto.Parts() and row("Food").box == true and page.drop.Text.text == "Kinds",
        "the page's list has every kind, each with a box to tick")
    check(not page.create:IsEnabled() and page.ticked.text == "Nothing is ticked yet." and #Auto.Mixes() == 0 and #page.own == 0,
        "with nothing ticked there is nothing to create")
    local errorsBefore = #W.errors
    check(Page.Create() == nil and #Auto.Mixes() == 0 and W.errors[#W.errors] == Auto.TEXT.none and #W.errors == errorsBefore + 1,
        "Create with nothing ticked makes nothing and says why in the red text")
    row("Drink").pick()
    row("Food").pick()
    check(page.ticked.text == "In this order: Drink, Food" and page.create:IsEnabled() and row("Drink").on() and not row("Potions").on(),
        "ticked, the page says which and in what order, and Create is lit")
    row("Drink").pick()
    row("Drink").pick()
    check(page.ticked.text == "In this order: Food, Drink", "a tick taken off and put back goes to the end")
    page.create.scripts.OnClick(page.create)
    local kind = Auto.Mixes()[1]
    check(kind ~= nil and kind.id == "mix1" and kind.name == "Food/Drink" and kind.icon == 133952 and kind.own == true,
        "Create: a kind of the player's own, named for its two kinds, under the first kind's icon")
    local saved = FallensFlyoutsDB.mixes.list[1]
    check(saved ~= nil and saved.id == "mix1" and table.concat(saved.parts, " ") == "food drink", "kept with the saved data of the whole account")
    check(#page.own == 1 and page.own[1]:IsShown() and page.own[1].label.text == "Food/Drink" and page.own[1].icon.texture == 133952
        and page.ticked.text == "Nothing is ticked yet." and not page.create:IsEnabled() and page.drop.Text.text == "Kinds",
        "it is in the row under the list, and the ticks are off again")
    check(ids((Auto.Entries("mix1"))) == "4541 4540 1179 159", "it holds the food this character can eat, the best first, then the drinks: "
        .. ids((Auto.Entries("mix1"))))
    Page.Tick("food")
    Page.Tick("drink")
    check(Page.Create() == kind and #Auto.Mixes() == 1, "the same kinds ticked again give the one there is, not a second")

    -- from the page onto a bar
    W.cursor = nil
    page.own[1].scripts.OnClick(page.own[1], "LeftButton")
    local macro = W.macros["Food/Drink"]
    check(W.cursor ~= nil and W.cursor[2] == "Food/Drink" and macro ~= nil and macro[1] == 133952 and macro[2] == "#fallensflyouts mix1",
        "a click on it picks its macro up: named as the kind, under its icon, marked as the addon's")
    PlaceAction(9)
    flushAll()
    local flyout, unit = F9.At("ActionButton9")
    check(flyout ~= nil and flyout.auto == "mix1" and ids(flyout.entries) == "4541 4540 1179 159", "dropped on a bar button, its flyout is there")
    local before = #W.casts
    mouse(W.frames.ActionButton9)
    check(unit ~= nil and unit.menu:IsShown() and #W.casts == before, "a press on the button opens it")
    mouse(entry(unit.index, 3))
    check(W.casts[#W.casts] == "item:item:1179" and not unit.menu:IsShown(), "a pick of its third icon drinks the best drink and shuts it")
    bags({ 4540, 159 })
    check(ids(F9.At("ActionButton9").entries) == "4540 159", "it keeps up with the bags as the ready-made ones do")
    -- more than a flyout holds: no kind is crowded out by one before it
    for id = 4550, 4563 do W.items[id] = { sub = 5, level = id - 4500 } end
    bags({ 4540, 4550, 4551, 4552, 4553, 4554, 4555, 4556, 4557, 4558, 4559, 4560, 4561, 4562, 4563, 159, 1179 })
    check(ids(F9.At("ActionButton9").entries) == "4563 4562 4561 4560 4559 4558 4557 4556 4555 4554 1179 159",
        "fifteen kinds of food and two drinks: both drinks are in, with the ten best foods: " .. ids(F9.At("ActionButton9").entries))
    bags({ 4540, 159, 118, 5997, 9001, 9002 })

    -- a kind of the game's own naming, alone: what can be used of it, under the icon of its best
    Page.Tick("sub8")
    local other = Page.Create()
    check(other ~= nil and other.id == "mix2" and other.name == "Other" and ids((Auto.Entries("mix2"))) == "9001",
        "a kind the game names: only what can be used of it goes in")
    check(other ~= nil and other.icon == 9001 and FallensFlyoutsDB.mixes.list[2].icon == 9001 and page.own[2].icon.texture == 9001,
        "with no icon of its own it takes the icon of the best the bags hold of it")
    local three = Auto.Mix({ "potions", "elixirs", "food", "potions" })
    check(three ~= nil and three.name == "Potions +2" and ids((Auto.Entries(three.id))) == "118 5997 4540",
        "three kinds: named for the first and how many more, each kind in the order ticked, none twice")
    local long, longer, alone = Auto.Mix({ "bandages", "scrolls" }), Auto.Mix({ "sub0", "bandages" }), Auto.Mix({ "sub0" })
    check(long.name == "Bandages/Scrolls" and longer.name == "Explosives an +1" and alone.name == "Explosives and D",
        ("a name never passes the sixteen letters a macro's takes: %s | %s | %s"):format(long.name, longer.name, alone.name))
    Auto.Mix({ "potions" })
    local eighth, whyMost = Auto.Mix({ "flasks" })
    Page.Refresh()
    local shown = 0
    for _, button in ipairs(page.own) do shown = shown + (button:IsShown() and 1 or 0) end
    check(#Auto.Mixes() == Auto.MIX_MOST and eighth == nil and whyMost == Auto.TEXT.most and shown == Auto.MIX_MOST,
        "seven of them and no more: the next is refused, with the reason")
    -- His snip (2026-11-23): "text overlapping when i make multipel custom auto flyouts". Where a name stands:
    -- under its icon's middle, as wide as its letters.
    local function span(button)
        local x = button.point[4] + NS.Art.ICON / 2
        local half = (button.label:GetStringWidth() or 0) / 2
        return x - half, x + half, button.point[5]
    end
    local apart, xs = true, true
    for n = 2, #page.own do
        local _, rightBefore, yBefore = span(page.own[n - 1])
        local left, _, y = span(page.own[n])
        if y == yBefore and left < rightBefore + 4 then apart = false end
        if not (page.own[n].remove and page.own[n].remove.template == "UIPanelCloseButtonNoScripts"
            and page.own[n].remove.point[2] == page.own[n] and page.own[n].remove.point[3] == "TOPRIGHT") then xs = false end
    end
    check(apart, "on the row no name runs into the next, however long it is")
    check(xs, "each of them has the game's small close button on its top right corner")
    -- a page too narrow for them all: they go on in a row under it, and the words under the row move down
    page.content.w = 400
    Page.Refresh()
    local lines = {}
    for _, button in ipairs(page.own) do lines[button.point[5]] = true end
    local count = 0
    for _ in pairs(lines) do count = count + 1 end
    local lowest = 0
    for y in pairs(lines) do lowest = math.min(lowest, y) end
    check(count >= 2 and page.note.points[1][5] < lowest - NS.Art.ICON - 16, "a page too narrow for them: they go on in another row, "
        .. "and the words under them stand under the last: " .. count .. " rows")
    page.content.w = nil
    Page.Refresh()
    -- a macro of a kind whose number only begins the same is not this kind's
    macro[2] = "#fallensflyouts mix10"
    check(Auto.Macro("mix1") == nil, "the macro of mix10 is not taken for the macro of mix1")
    macro[2] = "#fallensflyouts mix1"
    check(Auto.Macro("mix1") == "Food/Drink", "its own is")
    -- nothing of it in a fight
    W.combat = true
    local made, whyFight = Auto.Mix({ "flasks", "scrolls" })
    check(made == nil and whyFight == Auto.TEXT.fight and Auto.Unmix("mix1") == false and Auto.Kind("mix1") ~= nil,
        "in a fight none is made and none deleted")
    W.combat = false

    -- deleted from the page: asked first; then its macro, its flyout and the kind are gone
    W.popup = nil
    page.icons[1].scripts.OnClick(page.icons[1], "RightButton")
    check(W.popup == nil and W.cursor == nil and Auto.Unmix("food") == false and Auto.Kind("food") ~= nil,
        "a ready-made kind is not deleted: the right button does nothing on it")
    -- His words (2026-11-23): "should have \"x\" appears in top right of each to clear them instead of right
    -- click. right click should be for setting icon like usual"
    page.own[1].scripts.OnClick(page.own[1], "RightButton")
    local window = NS.Icon.popup
    check(W.popup == nil and window ~= nil and window:IsShown() and window.BorderBox.IconSelectorEditBox.text == "Food/Drink"
        and window.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture() == 133952 and not NS.Icon.own:IsShown(),
        "the right button on one of the player's own opens the icon window, with its name and its icon, and deletes nothing")
    window.BorderBox.IconSelectorEditBox:SetText("Snacks")
    window.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(4242)
    window:OkayButton_OnClick()
    flushAll()
    local mine = Auto.Kind("mix1")
    check(mine.name == "Snacks" and mine.icon == 4242 and FallensFlyoutsDB.mixes.list[1].name == "Snacks"
        and FallensFlyoutsDB.mixes.list[1].icon == 4242 and page.own[1].label.text == "Snacks" and page.own[1].icon.texture == 4242,
        "Okay: the name and the icon are the kind's, kept with it, and the row shows them")
    check(W.macros["Snacks"] ~= nil and W.macros["Food/Drink"] == nil and W.macros["Snacks"][1] == 4242 and Auto.Macro("mix1") == "Snacks",
        "its macro is renamed and given the icon, so the bars show them")
    check(F9.At("ActionButton9") ~= nil and F9.At("ActionButton9").auto == "mix1" and F9.At("ActionButton9").main.id == "Snacks"
        and GetActionText(9) == "Snacks", "its flyout on the bar follows the macro's new name")
    page.own[1].scripts.OnClick(page.own[1], "RightButton")
    window.BorderBox.IconSelectorEditBox:SetText("")
    window:OkayButton_OnClick()
    flushAll()
    check(Auto.Kind("mix1").name == "Food/Drink" and Auto.Macro("mix1") == "Food/Drink" and F9.At("ActionButton9") ~= nil,
        "an empty name gives back the name of its kinds, its macro's too")
    page.own[1].scripts.OnClick(page.own[1], "RightButton")
    NS.Icon.reset.scripts.OnClick(NS.Icon.reset)
    flushAll()
    check(Auto.Kind("mix1").icon == 133952 and FallensFlyoutsDB.mixes.list[1].icon == nil and W.macros["Food/Drink"][1] == 133952,
        "Reset gives back its own icon")
    page.own[1].remove.scripts.OnClick(page.own[1].remove)
    check(W.popup ~= nil and W.popup.which == "FALLENSFLYOUTS_CONFIRM" and W.popup.text:find("Food/Drink", 1, true) ~= nil
        and Auto.Kind("mix1") ~= nil, "its x asks first")
    StaticPopupDialogs.FALLENSFLYOUTS_CONFIRM.OnAccept(nil, W.popup.data)
    flushAll()
    local left = 0
    for _, own in ipairs(F9.List()) do left = left + (own.auto == "mix1" and 1 or 0) end
    check(Auto.Kind("mix1") == nil and W.macros["Food/Drink"] == nil and FallensFlyoutsDB.mixes.list[1].id == "mix2",
        "Yes: the kind is gone, its macro with it, and it is out of the saved data")
    check(F9.At("ActionButton9") == nil and left == 0 and GetActionInfo(9) == nil,
        "its flyout is gone from the bar, and the button is empty as the game leaves it")
    shown = 0
    for _, button in ipairs(page.own) do shown = shown + (button:IsShown() and 1 or 0) end
    check(shown == Auto.MIX_MOST - 1 and page.own[1].label.text == "Other" and page.own[1].kind.id == "mix2",
        "the row closes up")
    local again = Auto.Mix({ "food", "drink" })
    check(again ~= nil and again.id ~= "mix1" and again.name == "Food/Drink", "made again it is a new one, never the old one's number: "
        .. tostring(again and again.id))

    -- the page scrolls inside the game's window, down to its last line
    local scroll, content = page.scroll, page.content
    check(scroll ~= nil and content ~= nil and scroll.parent == page and scroll.scrollChild == content
        and page.drop.parent == content and page.create.parent == content and page.icons[1].parent == content
        and page.own[1].parent == content, "everything on the page is inside a scroll frame that fills it")
    content.rect, page.note.rect = { 0, 500, 1000, 999 }, { 0, 20, 300, 280 }
    scroll.h = 500
    Page.Fit()
    check(content.h == 1000 - 280 + 16 and scroll:GetVerticalScrollRange() == content.h - 500,
        "and it scrolls as far as its last line: " .. tostring(content.h))
    content.rect, page.note.rect = nil, nil

    -- the next login: they are read from the saved data
    local keptMacros = W.macros
    login("Player-1-0000000S")
    W.macros = keptMacros
    local Next = NS.Auto
    check(Next ~= Auto and #Next.Mixes() == Auto.MIX_MOST and Next.Kind("mix2") ~= nil and Next.Kind("mix2").name == "Other"
        and Next.Kind("mix2").icon == 9001 and Next.Kind("mix1") == nil,
        "at the next login the player's own are there again, as they were")
    NS.AutoUI.Build()
    check(#NS.AutoUI.panel.own == Auto.MIX_MOST and NS.AutoUI.panel.own[1].label.text == "Other", "and in the page's row")
    -- the saved data and the bars as they were
    FallensFlyoutsDB.mixes = nil
    local all = NS.Flyouts.List()
    for i = #all, 1, -1 do
        if all[i].auto then table.remove(all, i) end
    end
    W.macros, W.items, W.bags, W.level, W.macroCount, W.popup = nil, nil, nil, nil, nil, nil
    NS.Flyouts.Apply()
    flushAll()
    check(#NS.Auto.Mixes() == 0, "none left behind for what follows")
end

print("a flyout's bar button dragged to another slot in a fight takes its flyout along")
do
    -- His words (2026-11-22): "we need to fix not being able to move flyouts in a fight. it's extremely annoying."
    login("Player-1-0000000T")
    local F10 = NS.Flyouts
    W.placed = W.placed or {}
    -- button 5 is empty and has keys of its own; button 1 gets a flyout
    W.placed[5] = false
    fire("ACTIONBAR_SLOT_CHANGED", 5)
    W.base["5"], W.base["SHIFT-F"] = "ACTIONBUTTON5", "ACTIONBUTTON5"
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    rebound()
    flushAll()
    local flyout, unit = F10.At("ActionButton1")
    local f = unit.index
    local one, two, five, six = W.frames.ActionButton1, W.frames.ActionButton2, W.frames.ActionButton5, W.frames.ActionButton6
    local r = root()
    check(opener("1") == f and opener("E") == f and not opens("5") and F10.DropWrapped("ActionButton5")
        and F10.DropWrapped("ActionButton1") and r.attrs["slot-ActionButton5"] == 5 and r.attrs["bkeys-ActionButton5"] == 2,
        "before a fight the secure code is told every bar button's slot and keys, and is run at a drop on any of them")
    -- "ok the flyout can move in combat, but it's no longer a flyout in its new spot, until combat ends..."
    -- (2026-11-22): a click on the new button cast its ability, since only a flyout's own button had its
    -- click made ready, and none can be in a fight. Every bar button's is now, ahead of any fight.
    check(five.wrap ~= nil and F10.Wrapped("ActionButton5") and six.wrap ~= nil and F10.Wrapped("ActionButton6"),
        "before a fight every bar button's click is made ready to open a flyout, whether it has one or not")
    local three = W.frames.ActionButton3
    local casts = #W.casts
    mouse(three)
    check(#W.casts == casts + 1 and W.casts[#W.casts] == "bar:ActionButton3" and r.attrs["host-ActionButton3"] == nil,
        "a button with no flyout still casts at a click, as ever")
    -- out of a fight the drop code leaves everything to the addon's own code, as it always was
    -- (onto button 6: button 5 has had no flyout when the fight below begins)
    PickupAction(1)
    for _ = 1, 4 do flushAll() end
    DropOn(six)
    for _ = 1, 4 do flushAll() end
    check(F10.At("ActionButton6") == flyout and not opens("1"), "out of a fight a drag is followed as it always was")
    PickupAction(6)
    for _ = 1, 4 do flushAll() end
    DropOn(one)
    for _ = 1, 4 do flushAll() end
    flyout, unit = F10.At("ActionButton1")
    f = unit and unit.index
    check(flyout ~= nil and opener("1") == f and not opens("5"), "and back")

    -- in a fight: nothing of the addon's own code may touch a bar button or a frame hung on one
    -- (the fight's first event comes while addon code still may: the lock falls after it)
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    PickupAction(1)
    flushAll()
    DropOn(five)
    flushAll()
    check(r.attrs["host-ActionButton5"] == f and r.attrs["host-ActionButton1"] == nil and r.attrs["hostof" .. f] == "ActionButton5",
        "in a fight, its button dragged onto another: the secure code has the flyout on that button at the drop")
    check(unit.menu.point ~= nil and unit.menu.point[2] == five and unit.opener.parent == five and unit.opener.point[2] == five
        and unit.opener.shown, "the flyout and its grip hang on the new button")
    check(opener("5") == f and opener("SHIFT-F") == f and not opens("1") and not opens("E")
        and GetBindingAction("1", true) == "ACTIONBUTTON1", "the new button's keys open it, and the old button's keys are the old button's again")
    check(flyout.host == "ActionButton5" and unit.host == five and unit.arrow.point ~= nil and unit.arrow.point[2] == five,
        "where it sits is saved, and its arrow is drawn on the new button")
    local quiet = #W.casts
    mouse(five)
    check(unit.menu:IsShown() and #W.casts == quiet, "a click on the new button opens the flyout there, in the fight, and casts nothing")
    mouse(five)
    check(not unit.menu:IsShown() and #W.casts == quiet, "a second click shuts it")
    mouse(one)
    check(not unit.menu:IsShown(), "a click on the old button opens nothing: it is a plain button again")
    tap("5")
    check(unit.menu:IsShown(), "the new button's key opens it, in the fight")
    local before = #W.casts
    tap("1")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:" .. tostring(entry(f, 1).attrs.spell) and not unit.menu:IsShown(),
        "and its first key picks its first icon, which casts and shuts it: " .. tostring(W.casts[#W.casts]))
    press("SHIFT-F")
    check(unit.menu:IsShown() and GetBindingAction("SHIFT-1", true) == "CLICK FallensFlyoutsEntry" .. f .. "_1:Key",
        "opened by a key with a modifier and held: the picks are under that modifier too, as on any button")
    release("SHIFT-F")
    if unit.menu:IsShown() then tap("5") end
    check(not unit.menu:IsShown(), "shut again")
    -- a second one of its ability dropped elsewhere, the first still on its button: the flyout stays
    local lead = select(2, GetActionInfo(5))
    C_Spell.PickupSpell(lead)
    DropOn(six)
    flushAll()
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    check(r.attrs["host-ActionButton5"] == f and r.attrs["host-ActionButton6"] == nil and opener("5") == f,
        "a second one of its ability set down elsewhere leaves the flyout on the button that still has the first")
    -- the fight over: laid there as on any button
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    local after, afterUnit = F10.At("ActionButton5")
    check(after == flyout and afterUnit ~= nil and F10.Wrapped("ActionButton5") and opener("5") == afterUnit.index and not opens("1"),
        "the fight over: it is laid on the new button as on any, and that button's own click opens it")
    mouse(five)
    check(afterUnit ~= nil and afterUnit.menu:IsShown(), "a click on the button opens it")
    mouse(five)

    -- dropped on the button of another flyout, in a fight: that one waits for the fight's end
    W.placed[6] = nil
    fire("ACTIONBAR_SLOT_CHANGED", 6)
    stack("ActionButton2", 601)
    for _ = 1, 4 do flushAll() end
    local other, otherUnit = F10.At("ActionButton2")
    flyout, unit = F10.At("ActionButton5")
    f = unit.index
    local g = otherUnit.index
    check(other ~= nil and other ~= flyout and opener("2") == g and opener("5") == f, "two flyouts, each on its button")
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    PickupAction(5)
    flushAll()
    DropOn(two)
    flushAll()
    check(r.attrs["host-ActionButton2"] == f and r.attrs["hostof" .. f] == "ActionButton2" and opener("2") == f and opener("Q") == f
        and not opens("5"), "dropped on another flyout's button in a fight: the button is the dropped one's now, keys and all")
    check(r.attrs["hostof" .. g] == nil and r.attrs["okeys" .. g] == 0 and not otherUnit.opener.shown and r.attrs.adrift == true,
        "the flyout that button had waits, with no key and no grip, for its ability to be set down")
    -- While it has no button, the flyout of a button is still looked up, by the plus marks for one, each
    -- time the cursor's load changes (his client, 2026-11-23: "attempt to index field 'host' (a nil value)").
    local okAt, found = pcall(F10.At, "ActionButton9")
    check(okAt and found == nil, "asked for a button's flyout while one flyout has no button: answered, not broken: " .. tostring(found))
    check(pcall(function()
        fire("CURSOR_CHANGED")
        fire("ACTIONBAR_HIDEGRID")
        fire("ACTIONBAR_SHOWGRID")
    end), "and the cursor's events pass with no error")
    -- what the swap left on the cursor is set down by a click, the only way the game leaves: a click on a
    -- button that is not taking it changes nothing, and the click that sets it down hangs its flyout there
    local held = W.cursor and W.cursor[4]
    W.cursor = nil
    mouse(W.frames.ActionButton3)
    check(r.attrs["host-ActionButton3"] == nil and r.attrs["hostof" .. g] == nil, "a click that only casts another button leaves it waiting")
    W.cursor = { "spell", 7, "spell", held, held }
    mouse(five)
    flushAll()
    check(W.cursor == nil and select(2, GetActionInfo(5)) == held, "the click set its ability down on the button")
    check(r.attrs["hostof" .. g] == "ActionButton5" and r.attrs["host-ActionButton5"] == g and opener("5") == g
        and otherUnit.opener.shown and otherUnit.opener.parent == five and other.host == "ActionButton5",
        "set down by a click in the fight, its flyout hangs on that button at once, keys and all")
    mouse(five)
    check(otherUnit.menu:IsShown(), "and a click there opens it, in the fight")
    mouse(five)
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 6 do flushAll() end
    local onTwo, onFive = F10.At("ActionButton2"), F10.At("ActionButton5")
    check(onTwo == flyout and onFive == other and opens("2") and opens("5") and opener("2") ~= opener("5")
        and r.attrs.adrift == nil, "the fight over: each flyout is on the button its ability is on")
    W.guard = nil
    -- the bars as they were
    local all = F10.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    W.placed[1], W.placed[2], W.placed[5], W.placed[6] = nil, nil, nil, nil
    W.base["5"], W.base["SHIFT-F"] = nil, nil
    F10.Apply()
    for _, slot in ipairs({ 1, 2, 5, 6 }) do fire("ACTIONBAR_SLOT_CHANGED", slot) end
    rebound()
    flushAll()
    check(not opens("1") and not opens("2") and not opens("5"), "none left behind for what follows")
end

print("an icon dragged in a fight: off its flyout at once, back in where it is let go")
do
    -- His words (2026-11-22): "we need to fix not being able to move flyouts in a fight. it's extremely annoying."
    -- Asked which move, he named the bar button dragged to another slot and the icon moved inside its flyout.
    -- And (2026-11-23): "if i drag an ability out of a flyout mid combat, it does let me do so now thankfully,
    -- but it doesn't actually disappear from the flyout itself. even worse, it NEVER does unless i repeat it
    -- out of combat. ... i want it in real time anyway".
    login("Player-1-0000000U")
    local F11, Art11 = NS.Flyouts, NS.Art
    for id = 501, 504 do stack("ActionButton1", id) end
    local flyout, unit = F11.At("ActionButton1")
    local f = unit.index
    local r = root()
    local function ids()
        local out = {}
        for i, held in ipairs(flyout.entries) do out[i] = tostring(held.id) end
        return table.concat(out, " ")
    end
    local function stands(frame) return table.concat({ tostring(frame.point[1]), tostring(frame.point[4]), tostring(frame.point[5]) }, ",") end
    local function long() return math.max(unit.menu.w, unit.menu.h) end
    -- the icon a key picks while the flyout is open, or "" for a key that picks none
    local function ours(key)
        local action = GetBindingAction(key, true)
        return action:match("^CLICK (FallensFlyoutsEntry[%d_]+):") or ""
    end
    check(ids() == "101 501 502 503 504" and r.attrs["at" .. f .. "_2"] == "FallensFlyoutsEntry" .. f .. "_2"
        and entry(f, 2).attrs.ffspot == 2 and entry(f, 2).wraps ~= nil and entry(f, 2).wraps.OnDragStart ~= nil
        and entry(f, 2).wraps.OnReceiveDrag ~= nil, "each icon's spot is told to the secure code, which is run at an icon's drag and at a drop on one")
    -- an icon with a key of its own, which it keeps wherever it goes
    flyout.entries[3].key = "G"
    F11.Apply()
    flushAll()
    W.cvars = W.cvars or {}
    local second, third, fourth, fifth = entry(f, 2), entry(f, 3), entry(f, 4), entry(f, 5)
    local spots = {}
    for i = 1, 5 do spots[i] = stands(entry(f, i)) end
    local full = long()
    tap("1")
    check(unit.menu:IsShown() and ours("G") == third.name and ours("3") == "", "the flyout is open; the icon with its own key is picked by it alone")
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    local warned, caught = #W.errors, #W.caught
    -- dragged out: off the flyout at once
    DragOff(second)
    flushAll()
    check(W.cursor ~= nil and W.cursor[1] == "spell" and W.cursor[4] == 501 and #W.errors == warned,
        "in a fight an icon's drag puts its ability on the cursor, with no word of refusal")
    check(ids() == "101 502 503 504" and not second:IsShown() and r.attrs["count" .. f] == 4
        and r.attrs["holds" .. f] == ";spell:101;spell:502;spell:503;spell:504;",
        "and takes it off its flyout at once, in what is saved and in what the secure code knows: " .. ids())
    check(stands(third) == spots[2] and stands(fourth) == spots[3] and stands(fifth) == spots[4] and long() == full - Art11.ICON - Art11.NEXT,
        "on the screen the icons after it move up a spot, and the strip is one icon shorter")
    check(unit.menu:IsShown(), "the flyout stays open")
    -- as out of a fight: an icon with a key of its own is picked by that key alone, the others by their spot's
    check(ours("G") == third.name and ours("2") == "" and ours("3") == fourth.name and ours("4") == fifth.name and ours("5") == "",
        "the keys follow: the icon with its own key keeps it, the others take the keys of the spots they stand on now, "
        .. "and the emptied spot's key is free again: " .. table.concat({ ours("G"), ours("2"), ours("3"), ours("4"), ours("5") }, " "))
    check(third.key.text == "G" and fourth.key.text == "3" and fifth.key.text == "4", "and each icon shows its key: "
        .. table.concat({ tostring(third.key.text), tostring(fourth.key.text), tostring(fifth.key.text) }, " "))
    -- let go over an icon of the flyout: back in, on that icon's spot
    DropOn(fourth)
    flushAll()
    check(W.cursor == nil and ids() == "101 502 501 503 504" and second:IsShown() and r.attrs["count" .. f] == 5,
        "let go over an icon of its flyout, it goes back in on that icon's spot, and those after move down: " .. ids())
    check(stands(second) == spots[3] and stands(fourth) == spots[4] and stands(fifth) == spots[5] and long() == full,
        "on the screen too, and the strip is as long as before")
    check(unit.entries[3] == second and second.entryIndex == 3 and unit.entries[4] == fourth, "the addon reads each icon with what it casts")
    local before = #W.casts
    tap("3")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:501", "the third spot's key casts it there: " .. tostring(W.casts[#W.casts]))
    tap("1")
    tap("5")
    check(W.casts[#W.casts] == "spell:504", "and the fifth spot's key the last icon again: " .. tostring(W.casts[#W.casts]))
    -- dragged out and let go over a bar button: the game puts it there; the flyout is without it
    tap("1")
    DragOff(fifth)
    W.placed = W.placed or {}
    DropOn(W.frames.ActionButton7)
    flushAll()
    check(ids() == "101 502 501 503" and GetActionInfo(7) == "spell" and select(2, GetActionInfo(7)) == 504 and not fifth:IsShown(),
        "let go over a bar button, the game puts the ability there and the flyout is without it: " .. ids())
    -- dragged out and dropped on the flyout's arrow: in again at the end, with its own key
    DragOff(third)
    flushAll()
    check(ids() == "101 501 503" and ours("G") == "", "an icon with a key of its own taken off: its key goes with it")
    DropOn(unit.opener)
    flushAll()
    check(ids() == "101 501 503 502" and flyout.entries[4].key == "G" and third:IsShown() and W.cursor == nil,
        "dropped on the flyout's arrow it is in again, at the end, with its own key: " .. ids())
    if not unit.menu:IsShown() then tap("1") end
    before = #W.casts
    tap("G")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:502", "and that key picks it: " .. tostring(W.casts[#W.casts]))
    -- dragged out and let go of on nothing
    tap("1")
    DragOff(fourth)
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    flushAll()
    check(ids() == "101 501 502" and r.attrs["count" .. f] == 3, "let go of on nothing, it stays off: " .. ids())
    DropOn(entry(f, 1))
    check(ids() == "101 501 502", "a drop on an icon with nothing lifted and nothing carried changes nothing")
    -- with the bars locked, only with the game's key for picking an ability up
    r.attrs.barslocked = true
    W.modified = W.modified or {}
    DragOff(entry(f, 1))
    check(W.cursor == nil and ids() == "101 501 502", "bars locked and no pickup key held: the icon is not lifted")
    r.attrs.barslocked = nil
    check(#W.caught == caught, "none of it raised an error")
    -- the fight over: laid afresh, each icon by its name again
    if unit.menu:IsShown() then tap("1") end
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    local after, afterUnit = F11.At("ActionButton1")
    local names, order = true, {}
    for i = 1, 3 do
        local frame = afterUnit.entries[i]
        names = names and frame == entry(afterUnit.index, i) and frame.entryIndex == i and stands(frame) == spots[i]
        order[i] = tostring(frame.attrs.spell)
    end
    check(after == flyout and names and table.concat(order, " ") == "101 501 502" and not entry(afterUnit.index, 4):IsShown(),
        "the fight over: laid afresh as saved, each icon in its made place again: " .. table.concat(order, " "))
    tap("1")
    before = #W.casts
    tap("G")
    check(W.casts[#W.casts] == "spell:502" and #W.casts == before + 1, "the keys are as ever, an icon's own too")
    if unit.menu:IsShown() then tap("1") end
    check(r.attrs["still" .. afterUnit.index] == nil, "a flyout made by hand is not held still")
    -- a flyout left with only its button's own ability is no flyout any more, as out of a fight
    stack("ActionButton2", 601)
    local small, smallUnit = F11.At("ActionButton2")
    local g = smallUnit and smallUnit.index
    check(small ~= nil and #small.entries == 2 and opens("Q"), "a flyout of two: its button's own ability and one more")
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    tap("Q")
    check(smallUnit.menu:IsShown(), "it is open")
    DragOff(entry(g, 2))
    flushAll()
    check(W.cursor ~= nil and W.cursor[4] == 601 and not smallUnit.menu:IsShown() and not smallUnit.opener:IsShown()
        and r.attrs["hostof" .. g] == nil and r.attrs["host-ActionButton2"] == nil and not opens("Q"),
        "its other icon dragged out in a fight: shut, its arrow gone, its button's keys the button's own again")
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    before = #W.casts
    mouse(W.frames.ActionButton2)
    check(W.casts[#W.casts] == "bar:ActionButton2" and #W.casts == before + 1, "a click on the button casts its ability")
    check(#W.caught == caught, "and nothing raised an error")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    check(F11.At("ActionButton2") == nil and not opens("Q") and #F11.List() == 1, "the fight over, the flyout left with one is removed")
    W.guard = nil
    local all = F11.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    W.placed[7] = nil
    F11.Apply()
    fire("ACTIONBAR_SLOT_CHANGED", 7)
    flushAll()
    check(not opens("1"), "none left behind for what follows")
end

print("an ability added to a flyout in a fight")
do
    -- His words (2026-11-23): "flyout swaps in combat work. but i cant add to a flyout in combat still."
    login("Player-1-0000000W")
    local F12, Art12 = NS.Flyouts, NS.Art
    W.macros = { Mend = { 135, "/cast Mend" } }
    fire("UPDATE_MACROS")
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    flushAll()
    local flyout, unit = F12.At("ActionButton1")
    local f, r = unit.index, root()
    local grip = unit.opener
    local function ids()
        local out = {}
        for i, held in ipairs(flyout.entries) do out[i] = tostring(held.id) end
        return table.concat(out, " ")
    end
    local function long() return math.max(unit.menu.w, unit.menu.h) end
    local function carry(id)
        C_Spell.PickupSpell(id)
        fire("CURSOR_CHANGED")
    end
    local function empty()
        W.cursor = nil
        fire("CURSOR_CHANGED")
    end
    check(ids() == "101 501 502" and r.attrs["room" .. f] == F12.MAX - 3
        and r.attrs["holds" .. f] == ";spell:101;spell:501;spell:502;" and grip.wraps ~= nil and grip.wraps.OnReceiveDrag ~= nil,
        "before a fight the secure code is told what the flyout holds and how many more it takes, and is run at a drop on its arrow")
    check(r.attrs["xkey" .. f .. "_4"] == "4" and r.attrs["xkey" .. f .. "_5"] == "5" and r.attrs["xpad" .. f .. "_4"] ~= nil,
        "and the key and pad button each place gets: " .. tostring(r.attrs["xkey" .. f .. "_4"]))
    -- out of a fight the plus takes the drop itself, and the arrow none
    carry(503)
    local tab = NS.Drop.Tab("ActionButton1")
    check(tab ~= nil and tab:IsShown() and tab.mouse == true, "out of a fight the plus takes the drop itself")
    DropOn(grip)
    check(ids() == "101 501 502" and W.cursor ~= nil, "a drop on the arrow out of a fight adds nothing")
    empty()
    local wide = long()
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    carry(503)
    tab = NS.Drop.Tab("ActionButton1")
    -- His snips (2026-11-23): "'+' still getting compressed lower in combat". It stands where it does out of
    -- a fight, past the arrow's tip, and the arrow takes a drop that far out: the plus's middle and more.
    local _, plusUnit = NS.Flyouts.At("ActionButton1")
    local plusSide = NS.Art.SIDES[plusUnit.side]
    check(tab:IsShown() and tab.mouse == false and tab.point[2] == W.frames.ActionButton1
        and tab.point[4] == plusSide.x * NS.Drop.BADGE_PAST and tab.point[5] == plusSide.y * NS.Drop.BADGE_PAST
        and grip.hit ~= nil and grip.hit[3] == -NS.Flyouts.GRIP_REACH and NS.Flyouts.GripReach() >= NS.Drop.BADGE_PAST + 4,
        "in a fight the plus stands where it does out of one, past the arrow's tip, inside where the arrow takes a "
        .. "drop, and lets the drop through to it")
    local other = NS.Drop.Tab("ActionButton2")
    check(other == nil or not other:IsShown(), "and on no button without a flyout")
    local warned, caught = #W.errors, #W.caught
    DropOn(grip)
    flushAll()
    local fourth = entry(f, 4)
    check(W.cursor == nil and ids() == "101 501 502 503", "dropped on the arrow in a fight: it is in the flyout and off the cursor: " .. ids())
    check(fourth:IsShown() and fourth.attrs.type == "spell" and fourth.attrs.spell == 503
        and fourth.icon.texture == F12.Icon({ kind = "spell", id = 503 }) and fourth.entry == flyout.entries[4],
        "its icon stands on the next spot, with its picture, and casts it")
    check(long() == wide + Art12.ICON + Art12.NEXT, "the strip is one icon longer")
    check(fourth.key.text == "4" and r.attrs["count" .. f] == 4 and r.attrs["room" .. f] == F12.MAX - 4, "its key is written on it")
    check(not tab:IsShown(), "the plus is gone with the cursor's load")
    check(#W.errors == warned and #W.caught == caught, "with no word of refusal and no error")
    tap("1")
    local before = #W.casts
    tap("4")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:503", "its key casts it: " .. tostring(W.casts[#W.casts]))
    -- the same again is refused
    carry(503)
    DropOn(grip)
    check(ids() == "101 501 502 503" and W.cursor ~= nil and W.errors[#W.errors] == "That is in the flyout already.",
        "one the flyout holds already is refused in red and stays on the cursor")
    -- with the flyout open
    carry(504)
    tap("1")
    check(unit.menu:IsShown(), "the flyout is open")
    DropOn(grip)
    flushAll()
    check(W.cursor == nil and ids() == "101 501 502 503 504" and entry(f, 5):IsShown() and entry(f, 5).attrs.spell == 504,
        "dropped on the arrow of the open flyout: added at the end: " .. ids())
    check(unit.menu:IsShown(), "the flyout stays open")
    before = #W.casts
    tap("5")
    check(W.casts[#W.casts] == "spell:504" and #W.casts == before + 1, "and its key casts it at once")
    -- an item from the bags, a macro from the macro window
    W.cursor = { "item", 4540, "link" }
    fire("CURSOR_CHANGED")
    DropOn(grip)
    flushAll()
    check(W.cursor == nil and entry(f, 6).attrs.type == "item" and entry(f, 6).attrs.item == "item:4540"
        and flyout.entries[6].kind == "item" and flyout.entries[6].id == 4540, "an item is added the same way")
    PickupMacro("Mend")
    DropOn(grip)
    flushAll()
    check(W.cursor == nil and entry(f, 7).attrs.type == "macro" and flyout.entries[7] ~= nil and flyout.entries[7].kind == "macro"
        and flyout.entries[7].id == "Mend", "and a macro, known by its name once it is in")
    PickupMacro("Mend")
    DropOn(grip)
    check(#flyout.entries == 7 and W.errors[#W.errors] == "That is in the flyout already.", "a macro it holds already is refused")
    empty()
    -- An icon lifted and let go of on nothing is off the flyout, and the next drop is no move: a spell from
    -- elsewhere dropped on an icon takes that icon's place, as on a bar slot, and hands back what was there.
    tap("1")
    DragOff(entry(f, 2))
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    carry(505)
    DropOn(entry(f, 3))
    flushAll()
    check(ids() == "101 505 503 504 4540 Mend" and W.cursor ~= nil and W.cursor[4] == 502,
        "an icon lifted and let go of on nothing is off the flyout; then a spell dropped on an icon takes that icon's "
        .. "place, and what was there is on the cursor: " .. ids())
    DropOn(grip)
    flushAll()
    check(ids() == "101 505 503 504 4540 Mend 502" and W.cursor == nil,
        "what came off is added again by a drop on the arrow: " .. ids())
    -- an added icon moves like any other: dragged onto another icon of its flyout, it takes that one's spot
    DragOff(entry(f, 4))
    DropOn(entry(f, 2))
    flushAll()
    check(ids() == "101 505 504 4540 Mend 503 502" and W.cursor == nil, "an added icon is moved in the fight like any other: " .. ids())
    -- to the twelfth, and no further
    for id = 506, 510 do
        carry(id)
        DropOn(grip)
        flushAll()
    end
    check(#flyout.entries == F12.MAX and r.attrs["room" .. f] == 0 and entry(f, 12):IsShown(), "filled to twelve in the fight")
    carry(511)
    check(not NS.Drop.Tab("ActionButton1"):IsShown(), "a full flyout shows no plus")
    DropOn(grip)
    check(#flyout.entries == F12.MAX and W.cursor ~= nil and W.errors[#W.errors] == "That flyout is full.",
        "one more is refused: the flyout is full")
    empty()
    if not unit.menu:IsShown() then tap("1") end
    before = #W.casts
    tap("=")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:510", "the twelfth has its key too: " .. tostring(W.casts[#W.casts]))
    check(#W.caught == caught, "none of it raised an error")
    -- the fight over: laid afresh, all of it saved
    if unit.menu:IsShown() then tap("1") end
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    local after, afterUnit = F12.At("ActionButton1")
    check(after == flyout and ids() == "101 505 504 4540 Mend 503 502 506 507 508 509 510",
        "the fight over: the flyout holds all that was added, in its order: " .. ids())
    local laid = true
    for i = 1, F12.MAX do
        local frame = afterUnit.entries[i]
        laid = laid and frame == entry(afterUnit.index, i) and frame:IsShown() and frame.entry == after.entries[i]
    end
    check(laid and r.attrs["room" .. afterUnit.index] == 0, "laid afresh, each icon in its made place")
    tap("1")
    before = #W.casts
    tap("2")
    check(W.casts[#W.casts] == "spell:505" and #W.casts == before + 1, "and the keys go by the spots as ever")
    carry(511)
    check(NS.Drop.Tab("ActionButton2") ~= nil and NS.Drop.Tab("ActionButton2"):IsShown() and NS.Drop.Tab("ActionButton2").mouse == true,
        "out of the fight the plus is on every button again and takes the drop itself")
    empty()
    W.guard = nil
    W.macros = nil
    fire("UPDATE_MACROS")
    local all = F12.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    F12.Apply()
    flushAll()
    check(not opens("1"), "none left behind for what follows")
end

print("the keys of each flyout, on the settings page: a banner for each, as in the game's key menu")
do
    -- His words (2026-11-23): "we seem to have completely removed the ability for people to rebind flyouts
    -- individually without using the quick keybind mode....???? why does our settings menu not allow for
    -- this?...." And of the plain list first built for it: "really don't like the way you made that. why
    -- not just keybindings window style of like banners and we just have a banner per flyout... and have the
    -- icon of the flyout on the banner row to help identify it too.. and expand/collapse the banners to show
    -- the binds for it, in normal ui keybindings ui.. just in our settings window".
    login("Player-1-0000000K")
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    stack("ActionButton2", 601)
    for _ = 1, 3 do flushAll() end
    NS.ProfileUI.Build()
    NS.ProfileUI.Refresh()
    local keysPage = NS.ProfileUI.panel
    local w, K, F14, Arrange = keysPage.arrange, NS.Keys, NS.Flyouts, NS.Arrange
    local flyout, second = F14.At("ActionButton1"), F14.At("ActionButton2")
    local function banners()
        local n = 0
        for _, banner in ipairs(w.banners) do
            if banner:IsShown() then n = n + 1 end
        end
        return n
    end
    local function rows(banner)
        local n = 0
        for _, row in pairs(banner.rows) do
            if row:IsShown() then n = n + 1 end
        end
        return n
    end
    local one, two = w.banners[1], w.banners[2]
    -- what a banner or a row stands under: its first anchor (its second holds it to the page's right edge)
    local function under(frame) return frame.points[1][2] end
    check(banners() == 2 and one.flyout == flyout and two.flyout == second, "the page has a banner for each flyout on the bars")
    check(one.left.atlas == "Options_ListExpand_Left" and one.middle.atlas == "_Options_ListExpand_Middle"
        and one.right.atlas == "Options_ListExpand_Right" and one.h == 30,
        "a banner wears the art of the game's own key menu sections, at their height, shut to begin with")
    check(one.icon.texture == F14.Icon(flyout.main) and one.text.text == F14.Name(flyout.main)
        and two.icon.texture == F14.Icon(second.main), "each banner shows its flyout's picture and name")
    check(rows(one) == 0 and rows(two) == 0 and under(two) == one and w.foot.point[2] == two,
        "shut, a banner shows no rows: the next stands right under it, and what follows the list under the last")
    -- a flyout given a picture and a name of its own shows those
    flyout.icon, flyout.name = 4242, "Heals"
    Arrange.Refresh()
    check(one.icon.texture == 4242 and one.text.text == "Heals", "a flyout with a picture and a name of its own shows those")
    flyout.icon, flyout.name = nil, nil
    -- a press on a banner opens it: a row for each icon, with its key on the game's own key button
    one.scripts.OnClick(one)
    local function row(i) return one.rows[i] end
    local function text(i) return row(i).key.text end
    local function press(i, button) row(i).key.scripts.OnClick(row(i).key, button or "LeftButton") end
    check(Arrange.KeysOpen(flyout) and one.right.atlas == "Options_ListExpand_Right_Expanded" and rows(one) == 3,
        "a press on a banner opens it, with the game's own opened look: a row for each of the flyout's icons")
    check(row(2).icon.texture == F14.Icon(flyout.entries[2]) and row(2).label.text == F14.Name(flyout.entries[2])
        and row(2).key.template == "KeyBindingFrameBindingButtonTemplate" and row(2).h == 25 and row(2).key.w == 160
        and text(1) == "1" and text(2) == "2" and text(3) == "3",
        "a row shows the icon's picture and name and its key, on the game's own key button at the game's sizes")
    check(under(row(1)) == one and under(row(2)) == row(1) and under(two) == row(3) and w.foot.point[2] == two,
        "the rows stand under their banner, and the next banner under the last of them")
    W.focus = nil
    local caught = #W.caught
    press(2)
    local box = W.focus
    check(box ~= nil and K.Waiting() ~= nil and K.Waiting().flyout == flyout and K.Waiting().i == 2 and text(2) == "Press a key"
        and row(2).key.waiting == true, "a click on a key waits for the next key pressed: a typing box holds the keyboard, and the key says so")
    check(w.keysNote.text == NS.Arrange.TEXT.keysNote and under(one) == w.every and w.keysWait.h == 14
        and w.keysWait.text == "Press a key for " .. F14.Name(flyout.entries[2]) .. ". Escape leaves it as it is.",
        "the words over the list stay as they are while it waits; the line under them says what key is waited for, "
        .. "on a line as high as it always is, so nothing on the page moves: " .. tostring(w.keysWait.text))
    box.scripts.OnKeyDown(box, "LSHIFT")
    check(K.Waiting() ~= nil and flyout.entries[2].key == nil, "a modifier alone sets nothing, and the wait goes on")
    W.shiftKey = true
    box.scripts.OnKeyDown(box, "R")
    W.shiftKey = nil
    check(w.keysWait.text == "" and w.keysWait.h == 14 and under(one) == w.every,
        "the key set, that line is empty again and keeps its height")
    check(flyout.entries[2].key == "SHIFT-R" and K.Waiting() == nil and W.focus ~= box and text(2) == "s-R"
        and row(2).key.waiting == false,
        "the key pressed, with its modifier, is that icon's own in this flyout; the page shows it and the keyboard is let go: "
        .. tostring(text(2)))
    check(row(2).key.tip:find("own key in this flyout", 1, true) ~= nil and row(1).key.tip:find("the same in every flyout", 1, true) ~= nil,
        "a key's tip says whether it is the icon's own or its spot's")
    check(W.base["SHIFT-R"] == nil and GetBindingAction("SHIFT-R", false) == "", "the game's own bindings stay as they were")
    tap("1")
    local before = #W.casts
    tap("SHIFT-R")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:501", "with the flyout open that key picks the icon: "
        .. tostring(W.casts[#W.casts]))
    press(2, "RightButton")
    check(flyout.entries[2].key == nil and text(2) == "2", "a right-click on the key gives the icon its spot's key back")
    press(3)
    box = W.focus
    box.scripts.OnEscapePressed(box)
    check(K.Waiting() == nil and flyout.entries[3].key == nil and text(3) == "3", "Escape leaves the key as it was")
    press(3)
    press(3)
    check(K.Waiting() == nil and text(3) == "3", "a second click on the waiting key stops the wait")
    press(3)
    press(1)
    check(K.Waiting() ~= nil and K.Waiting().i == 1 and text(3) == "3" and text(1) == "Press a key",
        "a click on another key waits for that one instead")
    box = W.focus
    box.scripts.OnKeyDown(box, "F")
    check(flyout.entries[1].key == "F" and text(1) == "F", "and the key pressed is its key")
    press(1)
    box = W.focus
    box.scripts.OnKeyDown(box, "BACKSPACE")
    check(flyout.entries[1].key == nil and text(1) == "1", "Backspace while waiting gives the icon its spot's key back")
    -- a click anywhere else ends a wait, so that no key pressed later is taken for it
    press(3)
    row(3).key.over = true
    fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    check(K.Waiting() ~= nil, "a press of the mouse on the waiting key itself does not end the wait")
    row(3).key.over = nil
    fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    box = W.focus
    check(K.Waiting() == nil and box == nil and flyout.entries[3].key == nil and text(3) == "3",
        "a click anywhere else ends it: the keyboard is let go and nothing is set")
    -- the page put away, and a fight, end a wait; in a fight nothing is set
    press(3)
    keysPage.content.scripts.OnHide(keysPage.content)
    check(K.Waiting() == nil, "the page put away ends the wait")
    press(3)
    fire("PLAYER_REGEN_DISABLED")
    check(K.Waiting() == nil, "so does a fight")
    W.combat = true
    press(3)
    check(K.Waiting() == nil and W.errors[#W.errors] == "Flyouts change only out of a fight.", "in a fight a click on a key is refused in red")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    -- the other banner opens by itself, with its own rows; a press shuts one again
    two.scripts.OnClick(two)
    check(rows(two) == 2 and rows(one) == 3 and two.rows[2].key.text == "2" and w.foot.point[2] == two.rows[2],
        "the other flyout's banner opens beside it, with its own icons and keys")
    two.rows[2].key.scripts.OnClick(two.rows[2].key, "LeftButton")
    box = W.focus
    box.scripts.OnKeyDown(box, "T")
    check(second.entries[2].key == "T" and flyout.entries[2].key == nil, "a key set there is that flyout's icon's, and no other's")
    one.scripts.OnClick(one)
    check(not Arrange.KeysOpen(flyout) and rows(one) == 0 and one.right.atlas == "Options_ListExpand_Right" and under(two) == one,
        "a press on an open banner shuts it, and what is under it moves up")
    check(#W.caught == caught, "none of it raised an error")
    local all = F14.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    F14.Apply()
    flushAll()
    Arrange.Refresh()
    check(not opens("1") and banners() == 0 and w.foot.point[2] == w.every and w.keysNote.text == "No flyout is on the bars.",
        "none left behind for what follows, and with no flyout the page says so; every flyout's spots stay")
end

print("the plus stands on the side its button's flyout opens from")
do
    login("Player-1-0000000Z")
    stack("ActionButton1", 501)
    flushAll()
    local flyout = NS.Flyouts.At("ActionButton1")
    local function carry()
        C_Spell.PickupSpell(502)
        fire("CURSOR_CHANGED")
    end
    local function empty()
        W.cursor = nil
        fire("CURSOR_CHANGED")
    end
    carry()
    local mine, other = NS.Drop.Tab("ActionButton1"), NS.Drop.Tab("ActionButton2")
    check(mine ~= nil and other ~= nil and mine.way == "UP" and other.way == "UP" and mine.point[3] == "TOP",
        "on a bar at the foot of the screen the plus is over each button, where a flyout opens by itself")
    empty()
    NS.Flyouts.SetShape(flyout, "DOWN")
    flushAll()
    carry()
    check(mine.way == "DOWN" and mine.point[3] == "BOTTOM" and other.way == "UP" and other.point[3] == "TOP",
        "a flyout turned to open downward has its plus under its button, and the other buttons keep theirs over them")
    empty()
    NS.Flyouts.SetShape(flyout, "UP")
    flushAll()
    carry()
    check(mine.way == "UP" and mine.point[3] == "TOP", "turned to open upward again, its plus is over its button again")
    empty()
    local all = NS.Flyouts.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    NS.Flyouts.Apply()
    flushAll()
    check(not opens("1"), "none left behind for what follows")
end

print("an ability dropped on an icon takes its place, as on a bar slot")
do
    -- His words (2026-11-23): "flyouts not allowing me to drop and replace spells like how we can on normal
    -- action bar slots."
    login("Player-1-0000000X")
    local F13 = NS.Flyouts
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    flushAll()
    local flyout, unit = F13.At("ActionButton1")
    local f, r = unit.index, root()
    local function ids()
        local out = {}
        for i, held in ipairs(flyout.entries) do out[i] = tostring(held.id) end
        return table.concat(out, " ")
    end
    local function carry(id)
        C_Spell.PickupSpell(id)
        fire("CURSOR_CHANGED")
    end
    local function empty()
        W.cursor = nil
        fire("CURSOR_CHANGED")
    end
    local function carries(id) return W.cursor ~= nil and W.cursor[1] == "spell" and W.cursor[4] == id end
    -- a key set for one icon belongs to its place, as a key belongs to a bar slot
    flyout.entries[2].key = "G"
    F13.Apply()
    flushAll()
    tap("1")
    check(unit.menu:IsShown() and ids() == "101 501 502", "a flyout of three, open")
    local warned, caught = #W.errors, #W.caught
    carry(503)
    DropOn(entry(f, 2))
    flushAll()
    check(ids() == "101 503 502" and carries(501),
        "dropped on an icon: it takes the icon's place, and what the icon held is on the cursor: " .. ids())
    check(entry(f, 2).attrs.spell == 503 and entry(f, 2).icon.texture == F13.Icon({ kind = "spell", id = 503 })
        and r.attrs["count" .. f] == 3, "the icon casts it and shows its picture, and the flyout holds as many as before")
    check(flyout.entries[2].key == "G", "the key set for that icon stays with its place")
    check(unit.menu:IsShown(), "the flyout stays open")
    check(#W.errors == warned and #W.caught == caught, "with no word of refusal and no error")
    DropOn(entry(f, 3))
    flushAll()
    check(ids() == "101 503 501" and carries(502), "what came off, dropped on another icon: the same again: " .. ids())
    empty()
    carry(501)
    DropOn(entry(f, 2))
    check(ids() == "101 503 501" and carries(501) and W.errors[#W.errors] == "That is in the flyout already.",
        "one the flyout holds on another icon is refused in red and stays on the cursor")
    DropOn(entry(f, 3))
    check(W.cursor == nil and ids() == "101 503 501", "dropped on the icon that holds it: let go of, and nothing changes")
    -- set down by a click, as a bar slot takes one
    carry(504)
    local before = #W.casts
    mouse(entry(f, 3))
    flushAll()
    check(#W.casts == before and ids() == "101 503 504" and carries(501),
        "set down by a click on an icon: nothing is cast, it takes the place, and the old one is on the cursor: " .. ids())
    empty()
    flushAll()
    if not unit.menu:IsShown() then tap("1") end
    before = #W.casts
    mouse(entry(f, 3))
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:504", "with nothing carried a click on the icon casts as ever")
    -- in a fight the same, by the secure code
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    tap("1")
    carry(505)
    DropOn(entry(f, 2))
    flushAll()
    check(ids() == "101 505 504" and carries(503), "in a fight the same: in its place, the old one on the cursor: " .. ids())
    check(entry(f, 2).attrs.spell == 505 and entry(f, 2).attrs.ffmark == "spell:505"
        and entry(f, 2).icon.texture == F13.Icon({ kind = "spell", id = 505 })
        and r.attrs["holds" .. f] == ";spell:101;spell:504;spell:505;" and r.attrs["count" .. f] == 3,
        "the icon casts it and shows it, and the secure code knows what the flyout holds now: " .. tostring(r.attrs["holds" .. f]))
    check(flyout.entries[2].key == "G" and unit.menu:IsShown(), "its place keeps its key, and the flyout stays open")
    before = #W.casts
    tap("G")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:505", "that key casts the new one: " .. tostring(W.casts[#W.casts]))
    DropOn(unit.opener)
    flushAll()
    check(ids() == "101 505 504 503" and W.cursor == nil, "what came off, dropped on the flyout's arrow, is added again: " .. ids())
    carry(504)
    DropOn(entry(f, 2))
    check(ids() == "101 505 504 503" and carries(504) and W.errors[#W.errors] == "That is in the flyout already.",
        "in a fight too, one the flyout holds already is refused and stays on the cursor")
    empty()
    if not unit.menu:IsShown() then tap("1") end
    DragOff(entry(f, 4))
    DropOn(entry(f, 2))
    flushAll()
    check(ids() == "101 503 505 504" and W.cursor == nil, "an icon of the flyout dragged onto another is still moved, not swapped: " .. ids())
    check(#W.caught == caught, "none of it raised an error")
    if unit.menu:IsShown() then tap("1") end
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    local after, afterUnit = F13.At("ActionButton1")
    local order = {}
    for i = 1, 4 do order[i] = tostring(afterUnit.entries[i].attrs.spell) end
    check(after == flyout and table.concat(order, " ") == "101 503 505 504" and r.attrs["holds" .. afterUnit.index] == ";spell:101;spell:503;spell:505;spell:504;",
        "the fight over: laid afresh as saved: " .. table.concat(order, " "))
    W.guard = nil
    local all = F13.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    F13.Apply()
    flushAll()
    check(not opens("1"), "none left behind for what follows")
end

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
    NS.ControllerUI.Build()
    NS.Arrange.Refresh()
    local padArrange = NS.ControllerUI.panel.arrange
    check(padArrange.around:GetChecked() == true and padArrange.faces:GetChecked() == false,
        "the Controller page shows both choices")
    -- His words (2026-11-21): "why would we not let users move an icon anywhere they want on the dial? why
    -- would they HAVE to swap with an existing one?" An icon stands on the spot it is put on, taken or
    -- empty, and the flyout itself, open in play, shows it there and picks it by the pad button of that side.
    do
        NS.Flyouts.Shut()
        W.placed[28] = 821
        actionButton("GamepadMainActionBarFrameTestActionButton8", 28, padBar).id = 28
        fire("ACTIONBAR_SLOT_CHANGED", 28)
        flushAll()
        local NAME2 = "GamepadMainActionBarFrameTestActionButton8"
        stack(NAME2, 822)
        local two, twoUnit = F2.At(NAME2)
        local function where(i)
            local p = entry(twoUnit.index, i).point
            return p[1] == "CENTER" and p[2] == twoUnit.menu and math.floor(p[4] + 0.5) .. "," .. math.floor(p[5] + 0.5) or "not centered"
        end
        local function picks()
            local out = {}
            for i, pick in ipairs(F2.Picks(two)) do out[i] = pick.pad end
            return table.concat(out, " ")
        end
        check(two ~= nil and #two.entries == 2 and where(1) == spot(0, r) and where(2) == spot(r, 0) and picks() == "PADDUP PADDRIGHT",
            "a flyout of two stands up and right, as ever")
        -- the second one to the left, where nothing is
        check(F2.Place(two, 2, 4) == true and where(2) == spot(-r, 0) and where(1) == spot(0, r) and picks() == "PADDUP PADDLEFT",
            "put on the left, an empty side: it stands left of the button and D-pad left picks it: " .. where(2) .. " | " .. picks())
        check(F2.Show(twoUnit.index) == true and entry(twoUnit.index, 2):IsVisible() and where(2) == spot(-r, 0),
            "opened in play, it is there, in view")
        local casts = #W.casts
        tap("PADDLEFT")
        check(#W.casts == casts + 1 and W.casts[#W.casts] == "spell:822", "D-pad left casts it: " .. tostring(W.casts[#W.casts]))
        NS.Flyouts.Shut()
        -- below: both rings of one side, and the plate reaches the outer one only when one stands there
        local near = twoUnit.plate.radius
        check(F2.Place(two, 2, 7) == true and where(2) == spot(0, -(r + step)) and picks() == "PADDUP PAD1"
            and twoUnit.plate.radius == near + step,
            "put on the outer ring below: it stands a step further out, the bottom face button picks it, and the plate reaches it")
        check(F2.Place(two, 2, 3) == true and twoUnit.plate.radius == near, "back on the first ring, the plate is as small as before")
        -- a third ring, for a flyout of more than eight: a step further out again, with no pad button of its own
        check(F2.Place(two, 2, 11) == true and where(2) == spot(0, -(r + 2 * step)) and F2.Picks(two)[2].pad == nil
            and F2.Picks(two)[1].pad == "PADDUP" and twoUnit.plate.radius == near + 2 * step
            and twoUnit.menu.w >= 2 * (r + 2 * step + NS.Art.ICON / 2),
            "put on the third ring below: two steps out, the plate and the flyout's frame reach it, and no pad button is made up for it")
        check(F2.Place(two, 2, 3) == true and twoUnit.plate.radius == near, "and back on the first ring again")
        -- onto a taken spot: the two change places
        check(F2.Place(two, 2, 1) == true and where(2) == spot(0, r) and where(1) == spot(0, -r) and picks() == "PADDDOWN PADDUP",
            "put on a taken side, the two change places: " .. picks())
        -- a third one added takes the first free spot; one taken off leaves the others where they stand
        stack(NAME2, 823)
        two, twoUnit = F2.At(NAME2)
        check(#two.entries == 3 and where(3) == spot(r, 0) and picks() == "PADDDOWN PADDUP PADDRIGHT",
            "one more added takes the first free side: " .. picks())
        F2.Remove(two, 2)
        two, twoUnit = F2.At(NAME2)
        check(#two.entries == 2 and where(1) == spot(0, -r) and where(2) == spot(r, 0) and picks() == "PADDDOWN PADDRIGHT",
            "one taken off, the others stay where they stand: " .. picks())
        check(F2.Place(two, 1, 13) == false and F2.Place(two, 1, 0) == false and F2.Place(two, 5, 1) == false,
            "there are twelve spots and no more; a spot that is none, or an icon that is none, moves nothing")
        W.combat = true
        check(F2.Place(two, 1, 2) == false and where(1) == spot(0, -r), "in a fight nothing is moved")
        W.combat = false
        -- kept with the flyout: laid out anew from what is saved, each icon stands where it was put
        check(two.entries[1].spot == 3 and two.entries[2].spot == 2, "each icon's spot is kept with the flyout")
        F2.Remove(two, 2)
        W.placed[28] = nil
        fire("ACTIONBAR_SLOT_CHANGED", 28)
        flushAll()
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
    -- His snip and words (2026-11-22): the key text of a bar button lying under an open flyout stood on
    -- top of the flyout's icon. "keybinds from abilities under a flyout show through the flyout." The game
    -- keeps a button's key and count texts on a frame of the button's own, 500 levels up.
    local texts = CreateFrame("Frame", nil, W.frames.ActionButton2)
    texts:SetFrameLevel(500)
    NS.Flyouts.Apply()
    check(unit.menu:GetFrameStrata() == host:GetFrameStrata() and unit.menu:GetFrameLevel() > 500,
        "and it is over what the bar's buttons hold, their key texts too: no key shows through an icon lying over a button: level "
        .. tostring(unit.menu:GetFrameLevel()))
    -- a frame a button holds in a higher layer of its own does not lift the flyout
    local glow = CreateFrame("Frame", nil, W.frames.ActionButton3)
    glow:SetFrameStrata("HIGH")
    glow:SetFrameLevel(4000)
    NS.Flyouts.Apply()
    check(unit.menu:GetFrameLevel() > 500 and unit.menu:GetFrameLevel() < 4000, "a frame a button keeps in another layer is not counted")
    texts.parent, glow.parent = nil, nil
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

print("a button done away with by hand takes its flyout with it; moved, the flyout goes along")
do
    -- His words (2026-11-22): "if i destroy a button that had a flyout, then put a new button in its place,
    -- there is still a flyout there. why? it only happens if i do it with the same base spell. i get saving
    -- it when dragging to another spot. but if someone explicitly destroys a flyout by dragging off/erasing,
    -- it shouldnt auto pop back onto that spell next time its dragged from spellbook. very annoying"
    login("Player-1-0000000N")
    local F3 = NS.Flyouts
    W.placed = W.placed or {}
    W.placed[9], W.placed[10], W.placed[11] = 901, false, false
    fire("ACTIONBAR_SLOT_CHANGED", 9)
    flushAll()
    stack("ActionButton9", 902)
    stack("ActionButton9", 903)
    local flyout = F3.At("ActionButton9")
    local function alive()
        for _, own in ipairs(F3.List()) do
            if own == flyout then return true end
        end
        return false
    end
    local function settle() for _ = 1, 4 do flushAll() end end
    local function fromBook(id, slot)
        W.cursor = { "spell", 7, "spell", id, id }
        PlaceAction(slot)
        settle()
    end
    check(flyout ~= nil and #flyout.entries == 3, "a flyout of three on a button")

    -- dragged to another spot: that is kept
    PickupAction(9)
    settle()
    check(alive() and F3.At("ActionButton9") == nil, "its ability lifted off the button and still held: the flyout is off the button, and still there")
    PlaceAction(11)
    settle()
    check(alive() and F3.At("ActionButton11") == flyout and #flyout.entries == 3, "set down on another button: the flyout is on that one, whole")
    -- another ability dropped onto its button: the flyout's own comes onto the cursor, and is set down elsewhere
    W.cursor = { "spell", 7, "spell", 960, 960 }
    PlaceAction(11)
    settle()
    check(alive() and select(4, GetCursorInfo()) == 901, "another ability dropped on its button, its own now held: still there")
    PlaceAction(9)
    settle()
    check(alive() and F3.At("ActionButton9") == flyout, "its own set down on a free button: the flyout is on that one")

    -- dragged off the bar and let go of: the button is done away with, and the flyout with it
    local lines = #W.chat
    PickupAction(9)
    settle()
    ClearCursor()
    settle()
    check(not alive() and F3.At("ActionButton9") == nil, "dragged off the bar and let go of: the flyout is removed")
    -- His words (2026-11-22), of the line this used to print: "what the fuck is the point of these
    -- messages? every time you make an addon i tell you to remove extranneous chat messages"
    check(#W.chat == lines, "and nothing is said in chat: it was plain to see")
    fromBook(901, 9)
    check(select(2, GetActionInfo(9)) == 901 and F3.At("ActionButton9") == nil and #F3.List() == 0,
        "the same spell dragged from the spellbook onto that spot again: a plain button, no flyout comes back")

    -- the same ability on two buttons: one done away with, the flyout stays with the other
    stack("ActionButton9", 902)
    flyout = F3.At("ActionButton9")
    fromBook(901, 10)
    PickupAction(9)
    settle()
    ClearCursor()
    settle()
    check(alive() and F3.At("ActionButton10") == flyout, "the same ability on two buttons, one of them done away with: the flyout is on the other")

    -- an ability that leaves the bars with no hand in it (a talent change, a bar the game refills): kept
    W.placed[10] = false
    fire("ACTIONBAR_SLOT_CHANGED", 10)
    settle()
    check(alive() and F3.At("ActionButton10") == nil and F3.Lost(flyout), "an ability that leaves the bars by no hand keeps its flyout waiting")
    W.placed[10] = 901
    fire("ACTIONBAR_SLOT_CHANGED", 10)
    settle()
    check(F3.At("ActionButton10") == flyout, "and has it again when it is back")
    -- a waiting flyout's ability taken from the spellbook and let go of again: it was lifted off no button
    W.placed[10] = false
    fire("ACTIONBAR_SLOT_CHANGED", 10)
    settle()
    W.cursor = { "spell", 7, "spell", 901, 901 }
    fire("ACTIONBAR_SLOT_CHANGED", 11)
    settle()
    ClearCursor()
    settle()
    check(alive() and F3.Lost(flyout), "a waiting flyout's ability taken from the spellbook and let go of again: the flyout still waits")
    W.placed[10] = 901
    fire("ACTIONBAR_SLOT_CHANGED", 10)
    settle()

    -- let go of as a fight begins: settled when the fight is over
    PickupAction(10)
    settle()
    W.combat = true
    fire("PLAYER_REGEN_DISABLED")
    ClearCursor()
    settle()
    check(alive(), "let go of in a fight: nothing is removed in the fight")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    settle()
    check(not alive(), "the fight over, the flyout is removed")
    W.placed[9], W.placed[10], W.placed[11] = nil, nil, nil
end

print("the game's Mouseover Cast and focus cast are obeyed by a flyout's icons, as by the bar's own buttons")
do
    -- His words (2026-11-21): "flyouts not respecting mouseover." His settings: Mouseover Cast on with no
    -- key to hold, focus cast on Shift. A bar button then casts a heal on the friend under the mouse; an
    -- icon picked in a flyout cast it on the target.
    login("Player-1-0000000O")
    local F4 = NS.Flyouts
    W.helpful, W.harmful = { [951] = true }, { [952] = true }
    flushAll()
    stack("ActionButton1", 951)
    stack("ActionButton1", 952)
    local flyout, unit = F4.At("ActionButton1")
    check(flyout ~= nil and #flyout.entries == 3 and flyout.entries[1].id == 101,
        "a flyout of an ability for anyone, a heal and a harmful spell")
    -- an icon picked by its key, the flyout opened by its button's key first
    local function pick(i)
        tap("1")
        local before = #W.casts
        tap(tostring(i))
        return #W.casts > before and W.casts[#W.casts] or "nothing"
    end
    check(pick(2) == "spell:951", "nobody under the mouse: the heal is cast as ever: " .. tostring(W.casts[#W.casts]))
    W.mouseover = "friend"
    check(pick(2) == "spell:951@mouseover", "a friend under the mouse: the heal picked from the flyout goes to them: " .. tostring(W.casts[#W.casts]))
    check(pick(3) == "spell:952", "the harmful spell does not: it is cast as ever: " .. tostring(W.casts[#W.casts]))
    check(pick(1) == "spell:101@mouseover", "an ability that is for anyone goes to them too: " .. tostring(W.casts[#W.casts]))
    W.mouseover = "foe"
    check(pick(3) == "spell:952@mouseover" and pick(2) == "spell:951", "a foe under the mouse: the harmful spell goes to it, the heal does not")
    -- in a fight, where nothing can be set from outside: the icon is told at the click
    W.mouseover = "friend"
    W.combat = true
    fire("PLAYER_REGEN_DISABLED")
    check(pick(2) == "spell:951@mouseover", "in a fight too: " .. tostring(W.casts[#W.casts]))
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    -- clicked with the mouse, the mouse is on the icon: nobody is under it
    W.mouseover = nil
    tap("1")
    local icon = entry(unit.index, 2)
    local casts = #W.casts
    click(icon, true)
    click(icon, false)
    check(#W.casts == casts + 1 and W.casts[#W.casts] == "spell:951", "an icon clicked with the mouse is cast as ever: " .. tostring(W.casts[#W.casts]))
    -- the setting off
    W.mouseover = "friend"
    W.cvars = { enableMouseoverCast = "0" }
    fire("CVAR_UPDATE", "enableMouseoverCast", "0")
    check(pick(2) == "spell:951", "Mouseover Cast turned off in the game's options: cast as ever, at once")
    W.cvars = nil
    fire("CVAR_UPDATE", "enableMouseoverCast", "1")
    -- a key set for it: only while that key is held
    W.modKeys = { MOUSEOVERCAST = "ALT" }
    fire("UPDATE_BINDINGS")
    flushAll()
    check(pick(2) == "spell:951", "a key set for Mouseover Cast and not held: cast as ever")
    W.modHeld = { MOUSEOVERCAST = true }
    check(pick(2) == "spell:951@mouseover", "that key held: to the friend under the mouse")
    W.modKeys, W.modHeld = nil, nil
    fire("UPDATE_BINDINGS")
    flushAll()
    -- the focus cast key, as on a bar button
    W.mouseover = nil
    W.modHeld = { FOCUSCAST = true }
    check(pick(2) == "spell:951@focus", "the focus cast key held: the heal goes to the focus: " .. tostring(W.casts[#W.casts]))
    W.modHeld = nil
    -- a macro says for itself whom it is for
    W.mouseover = "friend"
    check(entry(unit.index, 1):GetAttribute("fhelp") == true and entry(unit.index, 2):GetAttribute("fharm") == nil
        and entry(unit.index, 3):GetAttribute("fhelp") == nil and entry(unit.index, 3):GetAttribute("fharm") == true,
        "each icon knows what its ability is for")
    W.mouseover, W.helpful, W.harmful = nil, nil, nil
    NS.Flyouts.Shut()
end

print("a flyout holds twelve, picked with the bar's own twelve keys: 1 to 9, 0, - and =")
do
    -- His words (2026-11-22): "we cant put more than 6 on a flyout currently, or at least the keybindings
    -- dont go beyond that. but it should be lim of 12 and use the 0-= keys too, bc many ppl that play wow
    -- have mmo mouse."
    login("Player-1-0000000T")
    local F6 = NS.Flyouts
    for id = 2001, 2011 do stack("ActionButton1", id) end
    local flyout, unit = F6.At("ActionButton1")
    check(F6.MAX == 12 and flyout ~= nil and #flyout.entries == 12, "eleven dropped onto a button's ability make a flyout of twelve")
    local errorsBefore = #W.errors
    stack("ActionButton1", 2012)
    check(#flyout.entries == 12 and #W.errors == errorsBefore + 1 and W.errors[#W.errors] == "That flyout is full.",
        "a thirteenth is refused: " .. tostring(W.errors[#W.errors]))
    W.cursor = nil
    fire("ACTIONBAR_HIDEGRID")
    flushAll()
    F6.Show(unit.index)
    local keys = {}
    for i = 1, 12 do keys[i] = entry(unit.index, i).key.text end
    check(table.concat(keys, " ") == "1 2 3 4 5 6 7 8 9 0 - =", "each icon shows its key, the bar's twelve in their order: " .. table.concat(keys, " "))
    check(entry(unit.index, 12):IsVisible() and entry(unit.index, 13) == nil, "all twelve are in view, and there is no thirteenth")
    F6.Shut()
    for i, key in ipairs({ "7", "8", "9", "0", "-", "=" }) do
        tap("1")
        local before = #W.casts
        tap(key)
        check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:" .. (2000 + i + 5),
            "opened by its button's key, " .. key .. " casts icon " .. (i + 6) .. ": " .. tostring(W.casts[#W.casts]))
    end
    -- the game's key menu: a row for each of the twelve spots of every flyout
    local named = true
    for i = 1, 12 do named = named and _G["BINDING_NAME_" .. NS.Binds.PICK .. i] == "Spot " .. i .. " of every flyout" end
    check(NS.Binds.PICKS == 12 and named and _G.PREFACE_FALLENSFLYOUTS_HELP2:find("1 to 9, 0, - and =", 1, true) ~= nil,
        "the key menu has a row for each of the twelve spots, and says what their keys are with none set")
    -- a key set on the twelfth of those rows picks the twelfth icon
    W.base["F12"] = NS.Binds.PICK .. "12"
    rebound()
    tap("1")
    local before = #W.casts
    tap("F12")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:2011", "a key set on the twelfth row picks the twelfth icon: " .. tostring(W.casts[#W.casts]))
    W.base["F12"] = nil
    rebound()
    -- on a controller a strip's first six have pad buttons, as ever; the rest are picked by their keys
    local pads = F6.PadsFor("UP", 12)
    check(pads[1] ~= nil and pads[6] ~= nil and pads[7] == nil and pads[12] == nil, "a strip's first six keep their pad buttons; the rest have none of their own")
    F6.Shut()
    for _ = 1, 12 do
        local left = F6.At("ActionButton1")
        if left then F6.Remove(left, #left.entries) end
    end
end

print("a flyout can be given a name, written on its bar button as a macro's name is")
do
    -- His words (2026-11-22, with a snip of the icon window): "we need ability to put a name to the icon too,
    -- just like we can with macros."
    login("Player-1-0000000R")
    local F8, Icon = NS.Flyouts, NS.Icon
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    local flyout, unit = F8.At("ActionButton1")
    local host = W.frames.ActionButton1
    -- as the game has it for a macro on the button: its name written at the button's foot
    host.Name.text = ""
    Icon.Open(flyout)
    local window = Icon.popup
    local box, search = window.BorderBox.IconSelectorEditBox, Icon.search
    -- His error (2026-11-23), dragging a flyout's bar button in a fight after this window had been open:
    -- "[ADDON_ACTION_BLOCKED] AddOn 'FallensFlyouts' tried to call the protected function 'PickupAction()'".
    check(W.iconWindowsShown == nil and window.BorderBox.SelectedIconArea.SelectedIconButton.selector == window,
        "the window does what the game's template does when shown, but never counts itself among the game's icon "
        .. "windows, a count every bar button reads at a drag")
    check(window:IsShown() and window.BorderBox.EditBoxHeaderText.text == "Name on the button (optional)" and box.maxLetters == 16
        and box.text == "", "the icon window's own name box is the flyout's name: sixteen letters, as for a macro, empty to begin with")
    check(search ~= nil and search ~= box and search.template == "SearchBoxTemplate" and search.maxLetters == 40
        and search.Instructions.text == "Search spells, items, macros"
        and search.point[1] == "RIGHT" and search.point[2] == window.BorderBox.IconTypeDropdown,
        "the search has a box of its own, the game's search box, between the words over the list and the list of kinds")
    search:SetText("FIRE")
    search.scripts.OnTextChanged(search)
    check(window.IconSelector.num() == 1, "typed into, the search narrows the icons as before")
    -- Okay is lit with no name: a flyout needs none
    window.BorderBox.OkayButton.off = true
    box.scripts.OnTextChanged(box)
    check(window.BorderBox.OkayButton:IsEnabled(), "an empty name leaves Okay lit: a flyout needs no name")
    box:SetText("Heals")
    window:OkayButton_OnClick()
    local label = unit.label
    check(flyout.name == "Heals" and NS.Profiles.Data().flyouts[1].name == "Heals", "Okay: the name is the flyout's, kept with it")
    check(label.shown and label.text == "Heals" and label.parent == host and label.font == "GameFontHighlightSmallOutline",
        "and it is written on the bar button, in the game's lettering for a macro's name")
    check(host.Name.alpha == 0, "what the game writes there itself gives way to it")
    check(flyout.icon == nil and not unit.face:IsShown(), "and nothing else of the flyout is changed by naming it")
    -- opened again: the name is in the box, to be typed over
    Icon.Open(flyout)
    check(box.text == "Heals" and search.text == "", "opened again, the box holds the name and the search is empty")
    box:SetText('  "Big" Heals  ')
    window:OkayButton_OnClick()
    check(flyout.name == "Big Heals" and label.text == "Big Heals", "a name is taken without quote marks or the room around it, as a macro's is: " .. tostring(flyout.name))
    -- it goes with the flyout to another button, and the old button reads as the game has it
    W.placed = W.placed or {}
    local hadFive = W.placed[5]
    W.placed[5] = false
    fire("ACTIONBAR_SLOT_CHANGED", 5)
    flushAll()
    PickupAction(1)
    for _ = 1, 4 do flushAll() end
    PlaceAction(5)
    for _ = 1, 4 do flushAll() end
    local moved, there = F8.At("ActionButton5")
    check(moved == flyout and there ~= nil and there.label.shown and there.label.text == "Big Heals"
        and there.label.parent == W.frames.ActionButton5 and W.frames.ActionButton5.Name.alpha == 0,
        "moved to another button, the flyout takes its name along")
    check(host.Name.alpha == 1, "and the button it left reads as the game has it again")
    PickupAction(5)
    for _ = 1, 4 do flushAll() end
    PlaceAction(1)
    for _ = 1, 4 do flushAll() end
    flyout, unit = F8.At("ActionButton1")
    check(flyout ~= nil and unit.label.text == "Big Heals" and W.frames.ActionButton5.Name.alpha == 1, "and back again")
    -- the name emptied: gone, and the game's own text is seen again
    Icon.Open(flyout)
    box:SetText("")
    window:OkayButton_OnClick()
    check(flyout.name == nil and not unit.label.shown and host.Name.alpha == 1,
        "the box emptied and Okay: the flyout has no name, and the button reads as the game has it")
    -- in a fight nothing is named
    W.combat = true
    local ok, why = F8.SetName(flyout, "No")
    check(ok == false and why ~= nil and flyout.name == nil, "in a fight a name is refused, with the reason")
    W.combat = false
    -- a flyout done away with leaves nothing written on its button
    F8.SetName(flyout, "Gone soon")
    check(unit.label.shown and host.Name.alpha == 0, "named again")
    for _ = 1, 3 do
        local left = F8.At("ActionButton1")
        if left then F8.Remove(left, #left.entries) end
    end
    check(F8.At("ActionButton1") == nil and not unit.label.shown and host.Name.alpha == 1,
        "the flyout taken apart: its name is off the button, and the game's own text is seen there again")
    W.placed[5] = hadFive
end

print("an icon says how many there are of its item, as a bar button does")
do
    -- His words (2026-11-22): "for items with quantities, their quantities aren't showing up in our flyouts.
    -- big problem for the consumables etc"
    login("Player-1-0000000Q")
    local hadPlaced = W.placed
    W.placed = W.placed or {}
    W.placed[8] = 9301
    fire("ACTIONBAR_SLOT_CHANGED", 8)
    flushAll()
    -- a potion that stacks, a stone that is neither used up nor stacked, arrows by the hundred, a spell with uses
    W.items = { [118] = { sub = 1, level = 5 } }
    W.bags = { 118, 6948, 2512 }
    W.counts, W.stacks, W.uses = { [118] = 17, [6948] = 1, [2512] = 1200 }, { [118] = 20, [2512] = 200 }, { [9302] = 3 }
    local function stackItem(host, id)
        W.cursor = { "item", id }
        fire("ACTIONBAR_SHOWGRID")
        local tab = tabOf(host)
        tab.scripts.OnReceiveDrag(tab)
        flushAll()
    end
    for _, id in ipairs({ 118, 6948, 2512 }) do stackItem("ActionButton8", id) end
    stack("ActionButton8", 9302)
    local flyout, unit = NS.Flyouts.At("ActionButton8")
    check(flyout ~= nil and #flyout.entries == 5, "a flyout of a spell, three items and a spell with uses")
    NS.Flyouts.Show(unit.index)
    local function says(i) return entry(unit.index, i).count and entry(unit.index, i).count.text end
    check(says(2) == "17", "the potion's icon says how many are in the bags: " .. tostring(says(2)))
    check(says(3) == "", "an item that is neither used up nor stacked says nothing: [" .. tostring(says(3)) .. "]")
    check(says(4) == "*", "more than three digits hold: a star, as on the game's buttons: " .. tostring(says(4)))
    check(says(1) == "" and says(5) == "3", "a plain spell says nothing, one with uses says how many: " .. tostring(says(5)))
    local point = entry(unit.index, 2).count:GetPoint()
    check(point == "BOTTOMRIGHT", "it stands in the icon's bottom right corner, where a bar button has it")
    -- one drunk: the number follows while the flyout is open
    W.counts[118] = 16
    fire("BAG_UPDATE_DELAYED")
    flushAll()
    check(says(2) == "16", "one used: the open flyout says so at once: " .. tostring(says(2)))
    -- the last one used, and items I have none of left in: a naught, as on a bar button
    NS.Flyouts.SetHiding(false)
    W.counts[118] = 0
    fire("BAG_UPDATE_DELAYED")
    flushAll()
    flyout, unit = NS.Flyouts.At("ActionButton8")
    NS.Flyouts.Show(unit.index)
    check(says(2) == "0", "none left, and shown grayed: it says 0: " .. tostring(says(2)))
    NS.Flyouts.SetHiding(true)
    -- a number the client hides is handed on unread, and a refusal does not stop the flyout
    local was = C_Spell.GetSpellDisplayCount
    C_Spell.GetSpellDisplayCount = function() error("refused") end
    W.counts[118] = 5
    fire("BAG_UPDATE_DELAYED")
    flushAll()
    flyout, unit = NS.Flyouts.At("ActionButton8")
    NS.Flyouts.Show(unit.index)
    check(unit.menu:IsShown() and says(2) == "5", "a count the client refuses for a spell leaves the flyout open and the rest right")
    C_Spell.GetSpellDisplayCount = was
    NS.Flyouts.Shut()
    W.items, W.bags, W.counts, W.stacks, W.uses = nil, nil, nil, nil, nil
    W.placed[8] = nil
    W.placed = hadPlaced
end

print("a first install: once, a window of the game's own kind says how a flyout is made and offers the preset flyouts")
do
    -- His words (2026-11-22): "so we have no new player popup at all?", "a brief popup for new users telling
    -- them super concisely how to make flyouts, but also for telling them about the auto flyouts and having
    -- them in a row that they can immediately drag to their bars"; and of the first one built, on the
    -- game's confirmation box: "why are you using classic styling instead of forever... for the popup",
    -- "\"These fill themselves\". the \"These\" seems like it's referring to the statement above. it should
    -- say \"You can also use these preset flyouts that automatically update with these items from your
    -- bags.\" or something along those lines", "also why cant the window be dragged".
    local savedDB = FallensFlyoutsDB
    local hadPlaced = W.placed
    FallensFlyoutsDB = nil
    login("Player-1-0000000W")
    local Welcome = NS.Welcome
    W.placed = {}
    W.macros, W.level, W.items, W.bags = {}, 10, { [4540] = { sub = 5, level = 5 } }, { 4540 }
    local up = Welcome.Frame()
    check(up ~= nil and up:IsShown() and FallensFlyoutsDB.welcome == "owed" and W.popup == nil,
        "with no saved data at all, the window comes up after the login; it is no confirmation box of the game's")
    check(up.template == "DefaultPanelFlatTemplate" and up.title.text == "Fallen's Flyouts" and up.close ~= nil
        and up.close.template == "UIPanelCloseButtonDefaultAnchors" and up.okay.template == "UIPanelButtonTemplate",
        "it is made of the game's own flat panel, the one its Loot Rolls window is made of, with that panel's title, x and button")
    check(up.make.text == "To make a flyout, drag a spell, item or macro onto a bar button and drop it on the +.",
        "it says in a line how a flyout is made: " .. tostring(up.make.text))
    -- His words (2026-11-23): "why does our initial user popout not mention the right click to change flyout
    -- icon? ppl literally won't even know."
    check(up.icon.text == "Right-click a flyout's bar button to give it an icon and a name of its own."
        and up.icon.point[2] == up.make and up.auto.point[2] == up.icon,
        "under it, a line on the right-click that gives a flyout an icon and a name: " .. tostring(up.icon.text))
    check(up.auto.text:find("You can also use these preset flyouts.", 1, true) == 1
        and up.auto.text:find("keeps itself filled with that kind of item from your bags", 1, true) ~= nil
        and up.auto.text:find("These fill themselves", 1, true) == nil,
        "and then, in words that cannot be read as part of that line, what the preset flyouts are: " .. tostring(up.auto.text))
    local names = {}
    for i, icon in ipairs(up.icons) do names[i] = icon.kind.name end
    check(table.concat(names, " ") == "Food Drink Potions Elixirs Flasks Scrolls Bandages" and up.icons[1].parent == up
        and up.more.text == "More in the settings: /ff", "under them the preset flyouts, in a row: " .. table.concat(names, " "))
    -- it can be dragged, and stays where it is put
    check(up.movable == true and up.clamped == true and up.scripts.OnDragStart ~= nil and up.scripts.OnDragStop ~= nil,
        "the window may be moved, and is kept on the screen")
    up.scripts.OnDragStart(up)
    check(up.moving == true, "a drag on it moves it")
    up.scripts.OnDragStop(up)
    check(up.moving == nil and up.moved == true, "and the mouse let go, it stays there")
    local where = up.point
    Welcome.Show()
    check(up.point == where, "shown again while it is up, it is not put back where it first stood")
    -- as high as its words run to
    check(up.h == 34 + up.make:GetStringHeight() + 12 + up.icon:GetStringHeight() + 12 + up.auto:GetStringHeight() + 12
        + NS.Art.ICON + 16 + 12 + 22 + 14,
        "it is as high as its words and its row need: " .. tostring(up.h))
    -- dragged out of it onto a bar: the flyout is there, and the window is still up for the next one
    local food = up.icons[1]
    food.scripts.OnDragStart(food)
    check(W.cursor ~= nil and W.cursor[1] == "macro" and W.cursor[2] == "Food" and up:IsShown(), "one dragged from it is on the cursor, the window still up")
    PlaceAction(9)
    flushAll()
    local made = NS.Flyouts.At("ActionButton9")
    check(made ~= nil and made.auto == "food" and #made.entries == 1 and up:IsShown(),
        "dropped on a bar button, its flyout is there, filled from the bags")
    local drink = up.icons[2]
    drink.scripts.OnClick(drink)
    check(W.cursor ~= nil and W.cursor[2] == "Drink", "a click picks one up as well")
    W.cursor = nil
    -- not closed by the player: owed still, at the next login too
    Welcome.Hide()
    check(FallensFlyoutsDB.welcome == "owed" and not up:IsShown(), "taken down by anything but the player, it is still owed")
    login("Player-1-0000000W")
    up = NS.Welcome.Frame()
    check(up ~= nil and up:IsShown(), "and comes up again at the next login")
    -- Okay: for good, on every character
    up.okay.scripts.OnClick(up.okay)
    check(FallensFlyoutsDB.welcome == "done" and not up:IsShown(), "closed with Okay, it is done with")
    login("Player-1-0000000W")
    check(NS.Welcome.Frame() == nil, "the next login has no window")
    login("Player-1-0000000X")
    check(NS.Welcome.Frame() == nil, "nor has another character's")
    -- its x closes it for good as well
    FallensFlyoutsDB = nil
    login("Player-1-0000000W")
    up = NS.Welcome.Frame()
    up.close.scripts.OnClick(up.close)
    check(FallensFlyoutsDB.welcome == "done" and not up:IsShown(), "so does its x")
    -- a login in a fight: it waits for the fight's end
    FallensFlyoutsDB = nil
    char.guid, char.class, char.name = "Player-1-0000000W", "MAGE", "Tester W"
    boot()
    W.combat = true
    flushAll()
    check(NS.Welcome.Frame() == nil and FallensFlyoutsDB.welcome == "owed", "at a login in a fight it waits")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    up = NS.Welcome.Frame()
    check(up ~= nil and up:IsShown(), "and comes up when the fight is over")
    -- in the game's gamepad mode nothing is dragged: the line names the game's own way
    local padBar = W.frames.GamepadMainActionBarFrame or CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
    padBar.shown = true
    NS.Welcome.Show()
    check(up.make.text == "To make a flyout, bind an ability onto a button that already holds one and choose Add to Flyout.",
        "in gamepad mode the line names Add to Flyout, not a drag: " .. tostring(up.make.text))
    padBar.shown = false
    NS.Welcome.Show()
    check(up.make.text:find("drop it on the +", 1, true) ~= nil, "out of that mode it names the drag")
    up.okay.scripts.OnClick(up.okay)
    -- saved data from before this version, with a flyout in it: nobody new, never shown
    FallensFlyoutsDB = { profiles = { ["Tester W - Realm"] = { flyouts = { { host = "ActionButton1",
        main = { kind = "spell", id = 101 }, entries = { { kind = "spell", id = 101 }, { kind = "spell", id = 501 } } } } } } }
    login("Player-1-0000000W")
    check(NS.Welcome.Frame() == nil and FallensFlyoutsDB.welcome == "done", "saved data that holds a flyout is no new install: no window, ever")
    -- saved data with no flyout in it: shown once
    FallensFlyoutsDB = { profiles = { ["Tester W - Realm"] = { flyouts = {} } } }
    login("Player-1-0000000W")
    up = NS.Welcome.Frame()
    check(up ~= nil and up:IsShown(), "saved data with no flyout in it: shown, once")
    up.okay.scripts.OnClick(up.okay)
    W.macros, W.level, W.items, W.bags = nil, nil, nil, nil
    W.placed = hadPlaced
    FallensFlyoutsDB = savedDB
    login("Player-1-0000000A")
end

print("a listener that breaks at every lay stops nothing: flyouts are still made, followed and removed")
do
    -- His words (2026-11-22): "i just dragged flyouts off my bars and their flyouts are still there just with
    -- empty icon????", "its not just automatic flyouts. its ALL flyouts", and later: "that should never have
    -- happened in the first place." His error log for that session: a listener of another addon (the dev
    -- one) threw at every lay, inside the addon's own laying out, so the addon never became ready and no
    -- change on the bars was followed.
    local savedDB = FallensFlyoutsDB
    local hadPlaced = W.placed
    FallensFlyoutsDB = nil
    local told = 0
    BEFORE_LOGIN = function()
        NS.Flyouts.Watch(function()
            told = told + 1
            error("the listener broke")
        end)
        FallensFlyouts_Watch(function() error("so did another addon's") end)
        NS.Profiles.OnChange(function() error("and one that listens for the profile") end)
    end
    login("Player-1-0000000V")
    BEFORE_LOGIN = nil
    local F7 = NS.Flyouts
    local function settle() for _ = 1, 4 do flushAll() end end
    check(told > 0 and #W.caught > 0 and W.caught[1]:find("the listener broke", 1, true) ~= nil,
        ("the listeners were told at the login, broke, and were reported: %d errors"):format(#W.caught))
    local hello = NS.Welcome.Frame()
    check(hello ~= nil and hello:IsShown(), "every part of the addon came up all the same: the last one's window is there")
    hello.okay.scripts.OnClick(hello.okay)
    W.placed = {}
    W.placed[1], W.placed[9] = 101, 9401
    fire("ACTIONBAR_SLOT_CHANGED", 9)
    settle()
    stack("ActionButton1", 9403)
    stack("ActionButton9", 9402)
    local flyout, unit = F7.At("ActionButton9")
    check(flyout ~= nil and #flyout.entries == 2 and unit ~= nil and opens("1"), "flyouts are made and laid on their buttons")
    local before = #W.casts
    tap("1")
    tap("2")
    check(#W.casts == before + 1 and W.casts[#W.casts] == "spell:9403", "one opens by its button's key and casts: " .. tostring(W.casts[#W.casts]))
    -- what he did: the button's ability dragged off the bar and let go of
    PickupAction(9)
    settle()
    ClearCursor()
    settle()
    check(F7.At("ActionButton9") == nil and #F7.List() == 1,
        "a button's ability dragged off the bar and let go of: its flyout is gone from the button, removed")
    PickupAction(1)
    settle()
    ClearCursor()
    settle()
    check(F7.At("ActionButton1") == nil and #F7.List() == 0 and not opens("1") and select(2, F7.Units()) == 0,
        "and so is the other: no flyout is left on an empty button")
    -- a change of profile is followed too, with its own listener broken
    W.placed[1] = 101
    fire("ACTIONBAR_SLOT_CHANGED", 1)
    settle()
    stack("ActionButton1", 9403)
    check(F7.At("ActionButton1") ~= nil, "a flyout made again")
    NS.Profiles.New("Another", false)
    settle()
    check(F7.At("ActionButton1") == nil and NS.Profiles.Active() == "Another", "on a new, empty profile it is off the bars")
    NS.Profiles.Use("Tester V - Realm")
    settle()
    check(F7.At("ActionButton1") ~= nil, "and back on the first, it is on its button again")
    W.placed = hadPlaced
    FallensFlyoutsDB = savedDB
    login("Player-1-0000000A")
end

print("a druid's form turns Action Bar 1 to another page: its flyouts follow at once, in a fight too")
do
    -- His words (2026-11-23): "ours is not working on druid forms... i make the flyout then click it and it
    -- takes me out of form (casting the first ability immediately) instead of opening the flyout, and then i
    -- go back into form and it's not even a flyout at all anymore"; "the flyouts on the same bar out of form
    -- have a delay on showing the flyout symbol, and in fact even acting as a flyout"; "cant be having delays
    -- like that". Seen on his druid (/ffdev forms): each shift left a button of the bar wrong for 0.4 to 0.9 s.
    -- Every check here is made the moment the game has turned the bar, with no time let pass.
    login("Player-1-0000000P")
    local F11 = NS.Flyouts
    local r = root()
    local errors = #W.caught
    W.placed = W.placed or {}
    -- Bear Form's page, as on his druid: the bar's buttons stand for slots 97 to 108, button 1 holds Maul
    -- there and button 2 Growl
    W.placed[97], W.placed[98] = 6807, 6795
    local one, two = W.frames.ActionButton1, W.frames.ActionButton2
    -- out of form a flyout on button 2, as his Wrath one
    stack("ActionButton2", 501)
    rebound()
    flushAll()
    local caster, cu = F11.At("ActionButton2")
    check(caster ~= nil and caster.main.id == 102 and opener("Q") == cu.index and cu.opener:IsShown(),
        "out of form: a flyout on button 2, its keys open it and its arrow shows")

    -- into the form, out of a fight
    TurnPage(9)
    local casts = #W.casts
    mouse(two)
    check(r.attrs["host-ActionButton2"] == nil and #W.casts == casts + 1 and W.casts[#W.casts] == "bar:ActionButton2"
        and not cu.menu:IsShown(), "into the form: at once a click on button 2 casts Growl, what it holds there; its "
        .. "flyout does not open")
    check(not opens("Q") and not opens("2") and not cu.opener:IsShown() and F11.At("ActionButton2") == nil,
        "at once its keys are the bar's own again, and no arrow shows")
    flushAll()
    check(F11.Of(caster.main) == caster and F11.Sleeps(caster), "the flyout of the other page is kept, asleep")

    -- a flyout made in the form, on button 1 (Maul)
    stack("ActionButton1", 502)
    rebound()
    flushAll()
    local bear, bu = F11.At("ActionButton1")
    check(bear ~= nil and bear ~= caster and bear.main.id == 6807 and opener("1") == bu.index and bu.opener:IsShown()
        and F11.Sleeps(caster), "in the form a flyout made on button 1 is led by Maul, its own; the other is untouched")
    casts = #W.casts
    mouse(one)
    check(bu.menu:IsShown() and #W.casts == casts, "a click on button 1 opens it and casts nothing")
    mouse(one)

    -- out of the form: each the moment the bar is turned back
    TurnPage(1)
    casts = #W.casts
    mouse(one)
    check(r.attrs["host-ActionButton1"] == nil and not bu.opener:IsShown() and not opens("1") and #W.casts == casts + 1
        and not bu.menu:IsShown(), "out of the form: at once button 1 is a plain button again, its key and a click "
        .. "the bar's")
    check(r.attrs["host-ActionButton2"] == cu.index and opener("Q") == cu.index and opener("2") == cu.index
        and cu.opener:IsShown() and F11.At("ActionButton2") == caster, "and at once the flyout of button 2 is back: "
        .. "its arrow, and its keys open it")
    casts = #W.casts
    mouse(two)
    check(cu.menu:IsShown() and #W.casts == casts, "a click on button 2 opens it and casts nothing")
    mouse(two)

    -- back into the form: the flyout made there is still one
    TurnPage(9)
    check(F11.At("ActionButton1") == bear and opener("1") == bu.index and bu.opener:IsShown() and not opens("Q"),
        "back in the form, at once: the flyout made there is on button 1 again, a flyout still")
    TurnPage(1)
    flushAll()

    -- in a fight: the same, by the secure code alone
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    TurnPage(9)
    casts = #W.casts
    local keyOpens = opener("1") == bu.index
    mouse(one)
    check(r.attrs["host-ActionButton1"] == bu.index and bu.opener:IsShown() and keyOpens
        and bu.menu:IsShown() and #W.casts == casts, "in a fight, into the form: at once a click on button 1 opens "
        .. "the form's flyout, its key too")
    mouse(one)
    casts = #W.casts
    mouse(two)
    check(r.attrs["host-ActionButton2"] == nil and not cu.opener:IsShown() and not opens("Q") and #W.casts == casts + 1,
        "and button 2 casts what it holds in the form")
    TurnPage(1)
    casts = #W.casts
    mouse(two)
    check(r.attrs["host-ActionButton2"] == cu.index and opener("Q") == cu.index and cu.menu:IsShown()
        and #W.casts == casts, "in a fight, out of the form: at once button 2 opens its flyout again")
    mouse(two)
    check(r.attrs["host-ActionButton1"] == nil and not bu.opener:IsShown() and not opens("1"),
        "and button 1 is a plain button")
    TurnPage(9)
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 6 do flushAll() end
    W.guard = nil
    check(F11.At("ActionButton1") == bear and F11.Sleeps(caster) and opener("1") == F11.UnitOf(bear).index
        and not opens("Q") and #F11.List() == 2, "the fight over, in the form: all as the secure code left it, "
        .. "both flyouts kept")

    -- the addon's own pass, as the seconds go by, changes nothing
    for _ = 1, 3 do rebound() end
    flushAll()
    check(F11.At("ActionButton1") == bear and F11.At("ActionButton2") == nil and F11.Sleeps(caster),
        "the once-a-second pass leaves them as they are")

    -- The ability of the flyout asleep, carried from the spellbook and let go of: that flyout stays (its
    -- ability is on its page still). A flyout taken off by a drag that ends nowhere is for one whose
    -- ability left the bars.
    C_Spell.PickupSpell(102)
    fire("ACTIONBAR_SHOWGRID")
    fire("ACTIONBAR_SLOT_CHANGED", 99)
    ClearCursor()
    fire("ACTIONBAR_HIDEGRID")
    fire("CURSOR_CHANGED")
    for _ = 1, 4 do flushAll() end
    TurnPage(1)
    check(F11.At("ActionButton2") == caster and #F11.List() == 2, "its ability carried and let go of in the form, "
        .. "the flyout of the other page is still there when the bar turns back")
    check(#W.caught == errors, "no error on the way: " .. tostring(W.caught[#W.caught]))

    -- His words (2026-11-23): "bear form vs no form is supposed to be completely separate bar. yet if i make
    -- flyout on no stance bar, and have the same ability in that slot in bear form, it auto makes the bear
    -- form version of it a flyout too. why. only happens if it's same base spell in same slot." Button 3
    -- holds the same spell out of form and in the form.
    W.placed[99] = 103
    stack("ActionButton3", 503)
    rebound()
    flushAll()
    local three = W.frames.ActionButton3
    local own3 = F11.At("ActionButton3")
    check(own3 ~= nil and own3.main.id == 103 and own3.slot == 3, "out of form: a flyout on button 3, kept to its slot")
    TurnPage(9)
    casts = #W.casts
    mouse(three)
    check(r.attrs["host-ActionButton3"] == nil and #W.casts == casts + 1 and not opens("3")
        and not F11.UnitOf(own3), "in the form button 3 holds the same spell in the same place and is no flyout: "
        .. "the form's bar is a bar of its own")
    stack("ActionButton3", 504)
    rebound()
    flushAll()
    local bear3 = F11.At("ActionButton3")
    check(bear3 ~= nil and bear3 ~= own3 and bear3.main.id == 103 and bear3.slot == 99 and #bear3.entries == 2
        and bear3.entries[2].id == 504 and #own3.entries == 2 and own3.entries[2].id == 503,
        "a flyout made there is the form's own, led by the same spell, with its own icons; the other keeps its own")
    TurnPage(1)
    check(F11.At("ActionButton3") == own3 and opens("3"), "out of form button 3 has its own flyout again")
    TurnPage(9)
    check(F11.At("ActionButton3") == bear3 and opens("3"), "and in the form the form's")
    -- one saved with no slot, from before: the first page that holds its spell, the bar out of form
    own3.slot = nil
    F11.Apply()
    flushAll()
    check(F11.At("ActionButton3") == bear3 and own3.slot == 3 and F11.Sleeps(own3),
        "a flyout saved before flyouts were kept to a page goes to the bar out of form")
    TurnPage(1)
    flushAll()

    -- the bars as they were
    local all = F11.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    W.placed[97], W.placed[98], W.placed[99] = nil, nil, nil
    F11.Apply()
    rebound()
    flushAll()
    check(not opens("1") and not opens("Q") and r.attrs["page-1"] == nil and r.attrs["page-2"] == nil
        and r.attrs["page-97"] == nil, "none left behind for what follows")
end

print("with the setting on, a flyout's key pressed again casts the icon picked last from it")
do
    -- A player's ask (2026-11-23): "double tapping a flyout keybind hits the last used spell from it".
    login("Player-1-0000000D")
    local F14 = NS.Flyouts
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    rebound()
    flushAll()
    local flyout, unit = F14.At("ActionButton1")
    check(F14.Twice() == false, "off unless turned on")
    tap("E")
    check(unit.menu:IsShown(), "the button's key opens its flyout")
    tap("3")
    local casts = #W.casts
    tap("E")
    tap("E")
    check(#W.casts == casts and not unit.menu:IsShown(), "off: pressed again, the key only shuts it")
    -- ticked in the settings: asked first, what it costs said in red, and off till yes is said to it.
    -- His words (2026-11-24): "with the double click to cast last setting, i just realized that goes against
    -- the flow of the key toggling the flyout in the first place. so i think we need a popup warning in red
    -- text, and tooltip for it in red text, that lets the user know they will no longer be able to close the
    -- flyout with the same key immediately after opening it, and that they'll have to use esc or whatever
    -- instead."
    NS.ProfileUI.Build()
    NS.Arrange.Refresh()
    local box = NS.ProfileUI.panel.arrange.twice
    local red = "|cffff2020Its key no longer shuts an open flyout: Escape (B on a controller) or a click on its bar button does.|r"
    box.checked = true
    box.scripts.OnClick(box)
    check(not F14.Twice() and not box:GetChecked() and W.popup ~= nil and W.popup.which == "FALLENSFLYOUTS_TWICE"
        and W.popup.text:find(red, 1, true) ~= nil and W.popup.text:find("1 then 1 casts the first icon.", 1, true) ~= nil,
        "ticked, it asks first, saying what it does (a key that is also an icon key stays that icon's) and the cost in "
            .. "red, and stays off meanwhile: " .. tostring(W.popup and W.popup.text))
    StaticPopupDialogs.FALLENSFLYOUTS_TWICE.OnCancel()
    W.popup = nil
    check(not F14.Twice() and not box:GetChecked(), "Cancel leaves it off")
    box.checked = true
    box.scripts.OnClick(box)
    acceptPopup()
    check(F14.Twice() and box:GetChecked(), "Turn On turns it on")
    box.checked = false
    box.scripts.OnClick(box)
    check(not F14.Twice() and not box:GetChecked() and W.popup == nil, "unticked, it is off at once, with no question")
    W.tipLines = nil
    box.scripts.OnEnter(box)
    local warn = W.tipLines and W.tipLines[#W.tipLines]
    check(warn ~= nil and warn[1]:find("no longer shuts an open flyout", 1, true) ~= nil and warn[2] == 1 and warn[3] < 0.2
        and warn[4] < 0.2 and W.tipLines[1][1]:find("1 then 1 casts the first icon.", 1, true) ~= nil,
        "its tooltip says the same: what it does, and in red what it costs")
    W.combat = true
    box.checked = true
    box.scripts.OnClick(box)
    check(not F14.Twice() and W.popup == nil and W.errors[#W.errors] == "Flyouts change only out of a fight.",
        "in a fight it is not turned on, and nothing asks")
    W.combat = false
    F14.SetTwice(true)
    flushAll()
    tap("E")
    casts = #W.casts
    tap("E")
    check(#W.casts == casts + 1 and W.casts[#W.casts] == "spell:502" and not unit.menu:IsShown(),
        "on: pressed again, the key casts the icon picked last (the third, 502) and shuts it: " .. tostring(W.casts[#W.casts]))
    -- what still shuts it, as its warning says: Escape, and a click on its bar button
    tap("E")
    casts = #W.casts
    tap("ESCAPE")
    check(not unit.menu:IsShown() and #W.casts == casts, "on: Escape shuts it, casting nothing")
    tap("E")
    mouse(unit.opener)
    check(not unit.menu:IsShown() and #W.casts == casts, "on: a click on its bar button shuts it, casting nothing")
    -- the key that is one of its picks as well stays that pick
    tap("1")
    tap("1")
    check(W.casts[#W.casts] == "spell:101" and not unit.menu:IsShown(), "a key that is one of its picks stays that pick")
    -- held down, the key keeps it open for picks, as ever
    press("E")
    tap("2")
    release("E")
    check(W.casts[#W.casts] == "spell:501" and not unit.menu:IsShown(), "held, the key keeps it open for a pick, and it "
        .. "shuts when the key is let go")
    -- kept through a laying out, and in a fight
    F14.Apply()
    flushAll()
    tap("E")
    tap("E")
    check(W.casts[#W.casts] == "spell:501" and flyout.last ~= nil and flyout.last.id == 501,
        "the one picked last is kept through a laying out: " .. tostring(W.casts[#W.casts]))
    W.guard = true
    fire("PLAYER_REGEN_DISABLED")
    W.combat = true
    flushAll()
    tap("E")
    tap("3")
    tap("E")
    casts = #W.casts
    tap("E")
    check(#W.casts == casts + 1 and W.casts[#W.casts] == "spell:502", "in a fight too: " .. tostring(W.casts[#W.casts]))
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    for _ = 1, 4 do flushAll() end
    W.guard = nil
    tap("E")
    tap("E")
    check(W.casts[#W.casts] == "spell:502", "after the fight it still casts what was picked in the fight")
    fire("PLAYER_LOGOUT")
    check(flyout.last ~= nil and flyout.last.id == 502, "and that is saved with the flyout at logout")
    F14.SetTwice(false)
    local all = F14.List()
    for i = #all, 1, -1 do table.remove(all, i) end
    F14.Apply()
    rebound()
    flushAll()
end

print("toys, mounts and battle pets go in a flyout and work there as on a bar: each case reported")
do
    -- A player's report (2026-11-23): "I keep getting the red error message at the top of my screen that
    -- says "That is in the flyout already." when attempting to add different hearthstones to one flyout. A
    -- similar issue when trying to add a campfire toy to a 'professions' one, it vanishes from the cursor and
    -- says the same thing. The mounts have no + symbol popping up at all when one is selected. I've tried
    -- moving them all to the bar first then moving them around, different combinations of mounts and
    -- hearthstones, to no avail." Each case played as /ffdev toys plays it on his account. Then his words
    -- (2026-11-23), with a snip of a toy's tooltip on a bar and in a flyout: "toys seem to be showing their
    -- like.... bag version of tooltip/action instead of their real version?", and "we should support
    -- literally any item that can go on an action bar": the two buttons he marked held battle pets.
    login("Player-1-0000000M")
    local F16 = NS.Flyouts
    W.placed = W.placed or {}
    W.bags = { 6948 }
    W.toys = { [280740] = true, [289439] = true }
    W.mounts = { { id = 3111, spell = 23229, name = "Cerulean Prideclaw", icon = 4000 } }
    local PET = "BattlePet-0-00000007348A"
    W.pets = { { guid = PET, name = "Whelpling", icon = 5000 } }
    W.placed[9], W.placed[10] = 9301, 9302
    fire("ACTIONBAR_SLOT_CHANGED", 9)
    fire("ACTIONBAR_SLOT_CHANGED", 10)
    flushAll()
    -- what the open flyout shows, icon by icon
    local function shows(host)
        local _, unit = F16.At(host)
        local out = {}
        if unit then
            F16.Show(unit.index)
            for _, frame in ipairs(unit.entries) do
                if frame:IsVisible() and frame.entry then
                    out[#out + 1] = frame.entry.kind .. ":" .. tostring(frame.entry.id)
                end
            end
            F16.Shut()
        end
        return table.concat(out, " ")
    end
    -- what is carried, dropped on a button's plus as the player drops it; false where no plus stands for it
    local function drop(host)
        fire("CURSOR_CHANGED")
        flushAll()
        local tab = tabOf(host)
        if not (tab and tab:IsVisible()) then return false end
        tab.scripts.OnReceiveDrag(tab)
        flushAll()
        return true
    end
    local errors = #W.errors
    -- 1. the hearthstones: two toys into one flyout
    C_ToyBox.PickupToyBoxItem(280740)
    check(drop("ActionButton9") and W.cursor == nil, "a toy from the Toy Box: the plus stands for it and takes it")
    check(shows("ActionButton9") == "spell:9301 item:280740", "the toy shows in the open flyout, the bags holding none "
        .. "of it: " .. shows("ActionButton9"))
    C_ToyBox.PickupToyBoxItem(289439)
    drop("ActionButton9")
    check(shows("ActionButton9") == "spell:9301 item:280740 item:289439" and #W.errors == errors,
        "a second toy: both show, and no word in red: " .. shows("ActionButton9"))
    -- 2. the campfire toy and the professions flyout: a toy into a flyout that holds an item
    C_Item.PickupItem(6948)
    drop("ActionButton10")
    C_ToyBox.PickupToyBoxItem(280740)
    drop("ActionButton10")
    check(shows("ActionButton10") == "spell:9302 item:6948 item:280740" and #W.errors == errors and W.cursor == nil,
        "a toy into a flyout that holds an item: it leaves the cursor and shows: " .. shows("ActionButton10"))
    C_ToyBox.PickupToyBoxItem(280740)
    drop("ActionButton10")
    check(W.errors[#W.errors] == "That is in the flyout already."
        and shows("ActionButton10") == "spell:9302 item:6948 item:280740",
        "dropped again, a toy the flyout shows is refused as one it holds")
    W.cursor = nil
    errors = #W.errors
    -- 3. on the bar first: a toy set on an empty button, another picked off a bar onto its plus
    C_ToyBox.PickupToyBoxItem(280740)
    PlaceAction(11)
    C_ToyBox.PickupToyBoxItem(289439)
    PlaceAction(12)
    PickupAction(12)
    check(W.cursor and W.cursor[1] == "item" and W.cursor[2] == 289439, "a toy picked off a bar is carried as an item")
    drop("ActionButton11")
    check(shows("ActionButton11") == "item:280740 item:289439" and #W.errors == errors,
        "dropped on the plus of a toy's bar button: a flyout of the two, both shown: " .. shows("ActionButton11"))
    -- 4. mounts: from the mount journal, onto a plus
    C_MountJournal.Pickup(1)
    check(drop("ActionButton9") and W.cursor == nil, "a mount from the mount journal: the plus stands for it and takes it")
    check(shows("ActionButton9") == "spell:9301 item:280740 item:289439 mount:3111" and #W.errors == errors,
        "it shows in the flyout: " .. shows("ActionButton9"))
    -- a mount picked off a bar, onto a plus
    C_MountJournal.Pickup(1)
    PlaceAction(7)
    PickupAction(7)
    check(W.cursor and W.cursor[1] == "mount" and W.cursor[2] == 3111, "a mount picked off a bar is carried as a mount")
    drop("ActionButton10")
    check(shows("ActionButton10") == "spell:9302 item:6948 item:280740 mount:3111" and #W.errors == errors,
        "and goes in as from the journal: " .. shows("ActionButton10"))
    -- a mount on a bar button leads a flyout
    C_MountJournal.Pickup(1)
    PlaceAction(12)
    C_ToyBox.PickupToyBoxItem(289439)
    drop("ActionButton12")
    check(shows("ActionButton12") == "mount:3111 item:289439" and #W.errors == errors,
        "a mount on a bar button: a toy dropped on its plus makes a flyout led by the mount: " .. shows("ActionButton12"))
    -- dragged out of a flyout, each is carried as the Toy Box and the journal carry it, and goes back in
    local _, unit9 = F16.At("ActionButton9")
    F16.CarryOff(unit9, 4)
    check(W.cursor and W.cursor[1] == "mount" and W.cursor[2] == 3111, "a mount dragged out of a flyout is on the cursor")
    drop("ActionButton9")
    _, unit9 = F16.At("ActionButton9")
    F16.CarryOff(unit9, 2)
    check(W.cursor and W.cursor[1] == "item" and W.cursor[2] == 280740, "so is a toy, though the bags hold none of it")
    drop("ActionButton9")
    check(shows("ActionButton9") == "spell:9301 item:289439 mount:3111 item:280740" and #W.errors == errors,
        "each goes back in, at the end: " .. shows("ActionButton9"))
    -- the journal's random favorite summons no one mount: no flyout takes it
    W.cursor = { "mount", 268435455, 0 }
    drop("ActionButton9")
    check(W.errors[#W.errors] == "Only spells, items, toys, mounts and macros go in a flyout.",
        "the random favorite is refused, in red: " .. tostring(W.errors[#W.errors]))
    W.cursor = nil
    -- in combat the secure code cannot look up a mount's spell: refused in red, left on the cursor
    W.combat = true
    fire("PLAYER_REGEN_DISABLED")
    flushAll()
    C_MountJournal.Pickup(1)
    _, unit9 = F16.At("ActionButton9")
    DropOn(unit9.opener)
    check(W.errors[#W.errors] == "Mounts and pets go in a flyout out of combat." and W.cursor ~= nil,
        "in combat a mount dropped on the arrow is refused in red and stays on the cursor")
    W.cursor = nil
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
    -- a toy not the player's own is an item they have none of, left out as before
    W.toys[289439] = nil
    F16.Apply()
    flushAll()
    check(shows("ActionButton9") == "spell:9301 mount:3111 item:280740",
        "a toy that is not the player's own is left out, as an item they have none of: " .. shows("ActionButton9"))
    -- each icon as the game's own button for it: its tooltip, its use, and gray only where it cannot be used
    W.toys[289439] = true
    F16.Apply()
    flushAll()
    local function icon(host, kind, id)
        local _, unit = F16.At(host)
        for _, frame in ipairs(unit and unit.entries or {}) do
            if frame.entry and frame.entry.kind == kind and frame.entry.id == id then return frame end
        end
    end
    local toy = icon("ActionButton9", "item", 280740)
    W.tip = nil
    toy.scripts.OnEnter(toy)
    check(W.tip and W.tip.toy == 280740, "a toy's tooltip is the toy's, as on a bar, not the item's that teaches it")
    check(toy:GetAttribute("type") == "toy" and toy:GetAttribute("toy") == 280740 and toy:GetAttribute("item") == nil,
        "a click uses it as the Toy Box does")
    check(toy.icon.color == nil or toy.icon.color[1] == 1, "in color: the item calls say a toy is unusable, the toy's do not")
    W.toyUnusable = { [280740] = true }
    F16.Apply()
    flushAll()
    toy = icon("ActionButton9", "item", 280740)
    check(toy.icon.color ~= nil and toy.icon.color[1] < 1, "gray where the Toy Box says it cannot be used")
    W.toyUnusable = nil
    F16.Apply()
    flushAll()
    local horse = icon("ActionButton9", "mount", 3111)
    W.tip = nil
    horse.scripts.OnEnter(horse)
    check(W.tip and W.tip.mount == 23229, "a mount's tooltip is the mount's")
    check(horse:GetAttribute("type") == "macro" and horse:GetAttribute("macrotext") == "/cast Cerulean Prideclaw",
        "a click summons it, as /cast does: " .. tostring(horse:GetAttribute("macrotext")))
    W.mounts[1].usable = false
    F16.Apply()
    flushAll()
    horse = icon("ActionButton9", "mount", 3111)
    check(horse.icon.color ~= nil and horse.icon.color[1] < 1, "gray where the journal says it cannot be summoned")
    W.mounts[1].usable = nil
    F16.Apply()
    flushAll()
    -- 5. battle pets, as on the two buttons he marked: from the Pet Journal, off a bar, and leading a flyout
    errors = #W.errors
    C_PetJournal.PickupPet(PET)
    check(drop("ActionButton10") and W.cursor == nil, "a battle pet from the Pet Journal: the plus stands for it and takes it")
    check(shows("ActionButton10") == "spell:9302 item:6948 item:280740 mount:3111 battlepet:" .. PET,
        "it shows in the flyout: " .. shows("ActionButton10"))
    local pet = icon("ActionButton10", "battlepet", PET)
    W.tip = nil
    pet.scripts.OnEnter(pet)
    check(W.tip and W.tip.pet == PET and pet:GetAttribute("macrotext") == "/summonpet " .. PET,
        "its tooltip is the pet's, and a click summons it as /summonpet does")
    C_PetJournal.PickupPet(PET)
    PlaceAction(8)
    check(GetActionInfo(8) == "summonpet", "a pet set on a bar is kept there as the game keeps it")
    C_ToyBox.PickupToyBoxItem(280740)
    drop("ActionButton8")
    check(shows("ActionButton8") == "battlepet:" .. PET .. " item:280740" and #W.errors == errors,
        "a pet on a bar button leads a flyout: " .. shows("ActionButton8"))
    local _, unit8 = F16.At("ActionButton8")
    F16.CarryOff(unit8, 2)
    PickupAction(8)
    check(W.cursor and W.cursor[1] == "battlepet" and W.cursor[2] == PET, "a pet picked off a bar is carried as a pet")
    drop("ActionButton11")
    check(shows("ActionButton11") == "item:280740 item:289439 battlepet:" .. PET, "and goes in as from the journal: "
        .. shows("ActionButton11"))
    -- in combat: a toy lifted out comes onto the cursor as the item the game picks up from the Toy Box, and
    -- dropped on the arrow goes back in as a toy; a mount stays where it is
    W.combat = true
    fire("PLAYER_REGEN_DISABLED")
    flushAll()
    _, unit9 = F16.At("ActionButton9")
    toy = icon("ActionButton9", "item", 280740)
    DragOff(toy)
    check(W.cursor and W.cursor[1] == "item" and W.cursor[2] == 280740, "in combat a toy dragged out is on the cursor")
    DropOn(unit9.opener)
    local back
    for _, frame in ipairs(unit9.entries) do
        if frame:IsShown() and frame:GetAttribute("ffmark") == "item:280740" then back = frame end
    end
    check(back and back:GetAttribute("type") == "toy" and W.cursor == nil,
        "dropped on the arrow it goes back in, used as a toy")
    horse = icon("ActionButton9", "mount", 3111)
    DragOff(horse)
    check(W.cursor == nil and horse:IsShown(), "a mount stays in its flyout in combat")
    W.combat = false
    fire("PLAYER_REGEN_ENABLED")
    flushAll()
end

print("a hint at the foot of a flyout's bar button tooltip, and one box for every hint, for the whole account")
do
    -- His words (2026-11-24): "for flyouts, can we have a message at bottom of the tooltip in gray like \"Right
    -- click to change icon/name. Turn hint off in settings.\" and then obv add ability to hide in settings?",
    -- "maybe right click to change tooltip/name. since icon doesnt really represent fact that it does/can
    -- reprsent cd too", "what is the gamepad equivalent of right click to change/select icon etc? we need to
    -- allow them to too.", and "i feel like we should switch show/hide background to lb and have rb be the one
    -- to open this to be more consistent with mouse, esp for ppl that frequently swap btwn mouse keyboard and
    -- controller".
    login("Player-1-0000000K")
    local F17 = NS.Flyouts
    stack("ActionButton1", 501)
    flushAll()
    local button = W.frames.ActionButton1
    local function tip(frame, slot)
        W.tipLines = nil
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetAction(slot)
        return W.tipLines or {}
    end
    local function has(lines, text)
        for _, line in ipairs(lines) do
            if line[1] == text then return line end
        end
    end
    local lines = tip(button, 1)
    local hint = has(lines, NS.Icon.HINT.mouse)
    check(hint ~= nil and hint[2] == 0.6 and hint[3] == 0.6 and hint[4] == 0.6 and has(lines, "Hints can be turned off in /ff.") ~= nil,
        "a flyout's bar button tooltip ends with the hint in gray, and how to turn hints off")
    check(hint ~= nil and hint[1]:find("Right-click to change what this button shows (its icon, tooltip and cooldown)", 1, true) == 1,
        "it says what a right-click changes: what the button shows, its tooltip and cooldown too, and its name")
    check(has(tip(W.frames.ActionButton2, 2), NS.Icon.HINT.mouse) == nil, "a bar button with no flyout has no hint")
    W.combat = true
    check(has(tip(button, 1), NS.Icon.HINT.mouse) == nil, "in a fight there is none: the window opens out of one only")
    W.combat = false
    -- an icon of the flyout has its own hint, drawn by the addon itself
    local function iconSays()
        local _, unit = F17.At("ActionButton1")
        F17.Show(unit.index)
        W.tipLines = nil
        local icon = unit.entries[2]
        icon.scripts.OnEnter(icon)
        local said = {}
        for _, line in ipairs(W.tipLines or {}) do said[#said + 1] = tostring(line[1]) end
        F17.Shut()
        return table.concat(said, " | ")
    end
    check(iconSays():find("to move it", 1, true) ~= nil, "an icon of the flyout ends with its own hint: " .. iconSays())
    -- the box under General
    NS.ProfileUI.Build()
    NS.Arrange.Refresh()
    local box = NS.ProfileUI.panel.arrange.hints
    check(box ~= nil and box:GetChecked(), "Show hints in tooltips is under General, ticked")
    box.checked = false
    box.scripts.OnClick(box)
    check(not NS.Profiles.Hints() and has(tip(button, 1), NS.Icon.HINT.mouse) == nil,
        "unticked, the bar button's tooltip has no hint")
    check(not iconSays():find("to move it", 1, true), "nor does an icon of the flyout")
    -- for the whole account: another character finds them off too
    login("Player-1-0000000L")
    check(not NS.Profiles.Hints(), "another character finds them off too: they are the account's, not a profile's")
    NS.Profiles.SetHints(true)
end

print("an update: once for the account, a line in chat with the addon's icon and name, and what changed")
do
    -- His words (2026-11-24): "please make sure when updates go out, the first time someone logs in with an
    -- update (not the first time user ofc since they already get intro popup and whatnot) they get like
    -- \"Thanks for updating to v#.#.#. [Here]'s what changed.\"", and "remember to always use the addon icon
    -- in chat messages like usual. and the name."
    -- each login loads the addon afresh: its parts are read from NS after each one
    local version = NS.Welcome.Version()
    check(version:match("^%d+%.%d+%.%d+$") ~= nil, "the version in use is the toc's: " .. version)
    local function thanks()
        local n, last = 0, nil
        for _, line in ipairs(W.chat) do
            if line:find("Thanks for updating", 1, true) then n, last = n + 1, line end
        end
        return n, last
    end
    -- what CHANGELOG.md says, read here as the window's words are written (tools/changes.py)
    local function changelog()
        local entries, entry, part = {}, nil, nil
        for line in io.lines("CHANGELOG.md") do
            line = line:gsub("\r$", "")
            local v, d = line:match("^## %[([^%]]+)%] %- (%S+)")
            if v then
                entry = { version = v, date = d, parts = {} }
                entries[#entries + 1] = entry
                part = nil
            elseif line:match("^### ") and entry then
                part = { name = line:match("^### (.+)$"), items = {} }
                entry.parts[#entry.parts + 1] = part
            elseif line:match("^%- ") and part then
                part.items[#part.items + 1] = (line:match("^%- (.+)$"):gsub("`", ""))
            end
        end
        return entries
    end
    local same = true
    local log, kept = changelog(), NS.Welcome.CHANGES or {}
    if #log ~= #kept then same = false end
    for i, entry in ipairs(log) do
        local k = kept[i]
        if not (k and k.version == entry.version and k.date == entry.date and #k.parts == #entry.parts) then
            same = false
        else
            for j, part in ipairs(entry.parts) do
                local kp = k.parts[j]
                if not (kp and kp.name == part.name and #kp.items == #part.items) then
                    same = false
                else
                    for n, item in ipairs(part.items) do
                        if kp.items[n] ~= item then same = false end
                    end
                end
            end
        end
    end
    check(same and #kept > 0, ("what the window says of each version is CHANGELOG.md's, word for word (%d versions): "
        .. "else python3 tools/changes.py"):format(#kept))

    -- someone who has had the addon a while (its first window seen) logs in with this version, after 1.1.4
    FallensFlyoutsDB.welcome = NS.Welcome.DONE
    FallensFlyoutsDB.seenVersion = "1.1.4"
    login("Player-1-0000000U")
    local n, line = thanks()
    check(n == 1 and line:find("|TInterface\\AddOns\\FallensFlyouts\\media\\icon:16:16|t Thanks for updating "
        .. "Fallen's Flyouts to v" .. version .. ".", 1, true) == 1,
        "the line in chat: the addon's icon, then thanks for updating Fallen's Flyouts to this version: " .. tostring(line))
    check(line:find("|Haddon:FallensFlyouts:changes:1.1.4|h|cff71d5ff[Here]|r|h's what changed.", 1, true) ~= nil,
        "and [Here]'s what changed, [Here] a link that knows the version seen last")
    check(FallensFlyoutsDB.seenVersion == version, "the version is seen now")
    login("Player-1-0000000V")
    check(thanks() == 0, "the next login, on any character, says nothing: once for the account")
    -- the link clicked: the window, with what changed after 1.1.4 up to this version
    EventRegistry:TriggerEvent("SetItemRef", "addon:FallensFlyouts:changes:1.1.4", "[Here]", "LeftButton")
    local Welcome = NS.Welcome
    local news = Welcome.News()
    local text = news and news.text and news.text.text or ""
    local wanted = Welcome.Since("1.1.4")
    local all = #wanted > 0
    for _, entry in ipairs(wanted) do
        if not text:find("v" .. entry.version, 1, true) or not text:find(entry.parts[1].items[1], 1, true) then all = false end
    end
    check(news ~= nil and news:IsShown() and all and not text:find("v1.1.4", 1, true),
        ("the link opens a window of what changed after 1.1.4 up to this version (%d versions)"):format(#wanted))
    for _, entry in ipairs(Welcome.CHANGES) do
        if Welcome.Newer(entry.version, version) then
            check(not text:find("v" .. entry.version .. "|", 1, true), "and nothing of a version still to come: " .. entry.version)
        end
    end
    news.okay.scripts.OnClick(news.okay)
    check(not news:IsShown(), "Okay closes it")
    -- someone who had it before there was such a line: the version in use's changes
    FallensFlyoutsDB.seenVersion = nil
    login("Player-1-0000000U")
    n, line = thanks()
    check(n == 1 and line:find("|Haddon:FallensFlyouts:changes:|h", 1, true) ~= nil and FallensFlyoutsDB.seenVersion == version,
        "one who had the addon before this line was there is thanked too")
    check(#NS.Welcome.Since(nil) == 1 and NS.Welcome.Since(nil)[1].version == version, "and shown this version's changes")
    -- someone new: their welcome, and no thanks
    local saved = FallensFlyoutsDB
    FallensFlyoutsDB = nil
    login("Player-1-0000000N")
    check(thanks() == 0 and FallensFlyoutsDB.welcome == NS.Welcome.OWED and FallensFlyoutsDB.seenVersion == version,
        "someone new gets the welcome and no thanks, and this version is seen")
    FallensFlyoutsDB = saved
    login("Player-1-0000000U")
end

print("the Feedback page: a filled-in issue link, What's New, and the status report (/ff status)")
do
    -- His words (2026-11-24): "we need an extensive debug status that ppl can send to us, like the \"/fcui
    -- status\"", "autofilled things from bug report in game are bis. make sure we add a \"Feedback\" tab to the
    -- fallens flyout settings dropdowns", and "keep in mind these all need to be accessible via controller, at
    -- least in gamepad mode to start."
    local FB = NS.FeedbackUI
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    flushAll()
    local at = {}
    for i, sub in ipairs(W.subcategories or {}) do at[sub.frame] = i end
    check(at[FB.panel] ~= nil and at[NS.ControllerUI.panel] ~= nil and at[NS.AutoUI.panel] ~= nil
        and at[FB.panel] > at[NS.ControllerUI.panel] and at[NS.ControllerUI.panel] > at[NS.AutoUI.panel]
        and FB.panel.name == "Feedback", "a page of its own named Feedback, listed after Automatic Flyouts and Controller")
    FB.panel:Show()
    FB.panel.scripts.OnShow(FB.panel)
    flushAll()
    local page = FB.panel
    check(page.bug.template == "UIPanelButtonTemplate" and page.idea.template == "UIPanelButtonTemplate"
        and page.news.template == "UIPanelButtonTemplate" and page.select.template == "UIPanelButtonTemplate",
        "every part of it is a button of the game's own, which a controller's cursor reaches")
    local status = page.status:GetText() or ""
    local version = NS.Welcome.Version()
    check(status:find("Fallen's Flyouts " .. version, 1, true) == 1 and status:find("Client: ", 1, true) ~= nil
        and status:find("Input: ", 1, true) ~= nil and status:find("Settings changed: ", 1, true) ~= nil
        and status:find("Other addons on (", 1, true) ~= nil,
        "the status report: the version, the client, the input, the settings changed, the other addons")
    check(status:find("    ActionButton1: led by spell 101; 3 icons (spell 3)", 1, true) ~= nil,
        "and a line for each flyout: its button, what leads it, what it holds: " .. status)
    local me = tostring(GetUnitName("player"))
    check(not status:find(me, 1, true) and not status:find(NS.Profiles.Active(), 1, true)
        and not status:find("Player-", 1, true), "with nothing of who the player is: no name, no profile's name, no id")
    fire("ADDON_ACTION_BLOCKED", "FallensFlyouts", "PickupAction()")
    fire("ADDON_ACTION_BLOCKED", "SomeoneElse", "CastSpellByName()")
    FB.Refresh()
    status = page.status:GetText()
    check(status:find("blocked PickupAction()", 1, true) ~= nil and not status:find("CastSpellByName", 1, true),
        "what the game kept this addon from doing this session, and nothing of another's")
    page.bug.scripts.OnClick(page.bug)
    local url = page.link:GetText() or ""
    check(page.link:IsShown() and page.copy:IsShown() and url:find(
        "https://github.com/fallenguards/fallens-flyouts/issues/new?template=bug_report.yml&details=", 1, true) == 1,
        "Report a Bug: a link to a new bug report, in a box ready to copy: " .. url:sub(1, 120))
    local details = url:match("&details=(.*)$"):gsub("+", " "):gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    check(details:find("Fallen's Flyouts " .. version, 1, true) == 1 and details:find("Flyouts: ", 1, true) ~= nil
        and not details:find("    ActionButton1:", 1, true) and not details:find(me, 1, true),
        "its Details from the addon box filled with the short status, no line per flyout, nothing of who")
    page.idea.scripts.OnClick(page.idea)
    check(page.link:GetText():find("?template=feature_request.yml&details=", 1, true) ~= nil, "Suggest an Idea: the idea form")
    page.news.scripts.OnClick(page.news)
    check(NS.Welcome.News() ~= nil and NS.Welcome.News():IsShown(), "What's New opens what changed in this version")
    NS.Welcome.News():Hide()
    page.select.scripts.OnClick(page.select)
    check(page.status:HasFocus() and page.status.highlighted == true, "Select All picks the whole report, to copy")
    -- /ff status opens the page
    W.opened = nil
    SlashCmdList.FALLENSFLYOUTS("status")
    check(W.opened ~= nil and W.opened == FB.category:GetID(), "/ff status opens the Feedback page")
    W.combat = true
    W.opened = nil
    SlashCmdList.FALLENSFLYOUTS("status")
    check(W.opened == nil and W.errors[#W.errors] == "The options open out of a fight.", "not in a fight, saying so")
    W.combat = false
    page:Hide()
end

print("the keys of every flyout's spots, in the addon's settings above each flyout's own")
do
    -- His words (2026-11-24): "we need to provide ability to change the default flyout keybinds in our
    -- settings menu next to the specific flyout ones too (above them) so ppl can access everything in one
    -- place."
    login("Player-1-0000000E")
    local F15 = NS.Flyouts
    stack("ActionButton1", 501)
    stack("ActionButton1", 502)
    rebound()
    flushAll()
    NS.ProfileUI.Build()
    NS.Arrange.Refresh()
    local w = NS.ProfileUI.panel.arrange
    local every = w.every
    check(every ~= nil and every:IsShown() and every.text.text == "Every flyout" and every.points[1][2] == w.keysWait
        and w.banners[1].points[1][2] == every, "an Every flyout bar stands first, above each flyout's own")
    every.scripts.OnClick(every)
    check(NS.Arrange.KeysOpen("every"), "a press opens it")
    local row = every.rows[1]
    check(row ~= nil and row:IsShown() and row.label.text == "Spot 1" and row.key.text == "1"
        and every.rows[12] and every.rows[12].label.text == "Spot 12" and every.rows[12].key.text == "=",
        "twelve rows, one for each spot, each with its key: the usual 1 to =, with none set")
    -- a new key for spot 1
    row.key.scripts.OnClick(row.key, "LeftButton")
    check(NS.Keys.Waiting() ~= nil and NS.Keys.Waiting().spot and row.key.text == "Press a key"
        and w.keysWait.text == "Press a key for spot 1 of every flyout. Escape leaves it as it is.",
        "a click waits for the next key pressed, and the line under the words says so")
    local box = W.focus
    W.base.T = nil
    box.scripts.OnKeyDown(box, "T")
    check(GetBindingAction("T") == "FALLENSFLYOUTS_PICK1" and W.saves ~= nil and NS.Keys.Waiting() == nil
        and every.rows[1].key.text == "T", "T pressed: spot 1 of every flyout is T now, kept as the game keeps its keys")
    -- the open flyout's keys are read again at the addon's next pass, as after the game's own key menu
    rebound()
    tap("1")
    tap("T")
    check(W.casts[#W.casts] == "spell:101", "an open flyout's first icon is picked with T: " .. tostring(W.casts[#W.casts]))
    -- a key that did something else: taken from it, said in red
    W.base.Y = "TOGGLEWORLDMAP"
    BINDING_NAME_TOGGLEWORLDMAP = "World Map"
    every.rows[2].key.scripts.OnClick(every.rows[2].key, "LeftButton")
    box = W.focus
    box.scripts.OnKeyDown(box, "Y")
    check(GetBindingAction("Y") == "FALLENSFLYOUTS_PICK2" and W.errors[#W.errors] == "Y did World Map: it picks spot 2 of every flyout now.",
        "a key that did something else is taken from it, as the game's key menu does, and said in red: "
            .. tostring(W.errors[#W.errors]))
    -- right-click: the usual key back
    every.rows[1].key.scripts.OnClick(every.rows[1].key, "RightButton")
    check((GetBindingAction("T") or "") == "" and GetBindingKey("FALLENSFLYOUTS_PICK1") == nil and every.rows[1].key.text == "1",
        "right-click: spot 1 has its usual key again, and T does nothing in the game's keys")
    every.rows[2].key.scripts.OnClick(every.rows[2].key, "RightButton")
    W.base.Y = "TOGGLEWORLDMAP"
    -- in a fight nothing changes
    W.combat = true
    every.rows[3].key.scripts.OnClick(every.rows[3].key, "LeftButton")
    check(NS.Keys.Waiting() == nil and W.errors[#W.errors] == F15.TEXT.fight, "in a fight it waits for no key")
    W.combat = false
    -- the game's key menu sends people here
    check(PREFACE_FALLENSFLYOUTS_ONE == "All flyout keys, these and the keys of one flyout, are in the addon's settings: /ff.",
        "the game's key menu says every flyout key is in the addon's settings, in words a player knows")
    every.scripts.OnClick(every)
end

-- what ships names nobody else's addon and nothing of the dev folder
for _, file in ipairs(tocFiles()) do
    local text = io.open(file):read("a")
    check(not (text:find("FallensFlyoutsDev")),
        file .. " names nothing of the dev folder")
    -- Chat is not for telling what the player has just done and can see. No file that ships writes
    -- to it; a line for someone new or about an update is added here by name when one is wanted.
    if file:find("Welcome%.lua$") then
        -- the one line it writes: the thanks for an update (W.Announce)
        local said
        text, said = text:gsub("DEFAULT_CHAT_FRAME:AddMessage%(SAY%.thanks:format%(", "", 1)
        text = text:gsub("%-%- luacheck: read globals DEFAULT_CHAT_FRAME", "", 1)
        check(said == 1, file .. " writes one line to chat, the thanks for an update")
    end
    check(not text:find("DEFAULT_CHAT_FRAME", 1, true) and not text:find("ChatFrame", 1, true) and not text:find("ns.Say(", 1, true)
        and not text:find("[^%w_.]print%("), file .. " writes nothing to chat")
end

print(fails == 0 and "FLYOUTS TEST: PASS" or ("FLYOUTS TEST: FAIL (" .. fails .. ")"))
os.exit(fails == 0 and 0 or 1)
