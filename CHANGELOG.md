# Changelog

## [1.1.6] - 2026-11-23

### Added
- Mounts go in a flyout. Drag one from the Mounts tab of the Collections window, or off a bar, onto a bar button's plus, as you would a spell: its icon in the flyout summons it. A mount on a bar button can be the first of a flyout too. In combat a mount is refused with a word in red; add it out of combat.

### Fixed
- A toy added to a flyout (a hearthstone toy, say) vanished from it at once, and dropped again it was refused with "That is in the flyout already." Toys are kept in the Toy Box, never in the bags, and "Hide items I have none of" took them for items you had none of. A toy of your own now shows in its flyout like any item you have, and dragged out of a flyout it is picked up as from the Toy Box.

## [1.1.5] - 2026-11-23

### Added
- A setting, off unless turned on, under Arrange a flyout in the settings (`/ff`): Press a flyout's key again for the last one used. With a flyout open, pressing its key again casts the icon you picked from it last and shuts it, in combat too. A key that is also one of the flyout's own picks stays that pick.

### Fixed
- A flyout on Action Bar 1 follows the bar at once when a druid's form, a stance or stealth turns the bar to another page, in combat too. Each page is a bar of its own: a flyout made out of form is on its button only out of form, even where the form's page holds the same ability in that place, and one made in Bear Form only in Bear Form. Until now a flyout caught up only about a second after each shift, and in combat not until the fight was over: in between, a click on its button cast the button's ability, or opened the other page's flyout.
- In combat the plus for adding to a flyout stands where it does out of combat, past the tip of the flyout's arrow, and a drop there adds to the flyout. It stood on the arrow itself, pulled down onto the button's edge.
- Dragging an ability off a bar in combat could be refused, with an error naming Fallen's Flyouts ("tried to call the protected function 'PickupAction()'"), once the flyout icon window (a right-click on a flyout's bar button) had been open in that session. The icon window no longer touches what the game's bar buttons check at the start of a drag. While it is open, an ability dragged off a bar is picked up as by any drag.

## [1.1.4] - 2026-11-23

### Added
- Automatic flyouts of your own. On the Automatic Flyouts page of the settings, tick the kinds one flyout should hold (Food and Drink together, say) and press Create: it joins a row of yours on that page, is dragged onto a bar like the ready-made ones, and keeps itself filled the same way, each kind's best first. Besides the seven ready-made kinds the list has the game's other kinds of consumable. Right-click one of yours on that page to give it an icon and a name of its own, as you would a flyout on a bar: its macro takes them too. The x on its corner deletes it.
- A flyout can be given a name, as a macro can. Right-click the flyout's bar button: the icon window has a name box, sixteen letters as for a macro, and the name is written on the button where a macro's name stands. The window's search has a box of its own now, beside Choose an Icon.
- An ability dropped on an icon of a flyout takes that icon's place, as on a bar slot: the icon casts it from then on, on its spot and with its key, and the one it held comes onto the cursor. In combat too. A click sets it down the same way out of combat. Until now a drop on an icon did nothing.
- Flyout keys, in the settings (`/ff`): every flyout has a bar there, with its picture and name, that opens as a section of the game's Keybindings options does, to a row for each of its icons with the key that picks it. Click a key and press another to give that icon a key of its own in that flyout; right-click gives it its spot's key back.

### Changed
- The Fallen's Flyouts section of the game's Keybindings options is now only the twelve rows for the spots of every flyout. The heading and six rows it had for each of eight flyouts, used or not, are gone: they made eight look like a limit, which it is not. A key for one icon of one flyout is set in the addon's settings, under Flyout keys, or as before by hovering the icon in Quick Keybind Mode, and the section says so. A key already set on one of the old rows goes on working: it is that icon's own key now.
- The window someone sees after a first install says that a right-click on a flyout's bar button gives the flyout an icon and a name of its own.

### Fixed
- A flyout's bar button dragged to another bar slot in combat takes its flyout along at once: its arrow, its keys and a click on the button all open it there. Until now the flyout stayed on the old button until combat ended. A flyout whose button was dropped on, its ability left on the cursor, follows that ability to the button it is set down on.
- An icon dragged out of its flyout in combat leaves it at once: the icons after it move up a spot, and a flyout left with only its button's own ability is no flyout any more, as out of combat. Let go over another icon of the same flyout, it takes that icon's spot. An icon with a key of its own keeps that key wherever it goes; the others take the keys of the spots they stand on. Until now nothing in a flyout could be changed until combat ended. Out of combat it lifts and slides as before. A flyout that fills itself, and one whose icons stand around its button, keep their icons in combat.
- A flyout's icon shows when its ability is out of range of the target, as a bar button does: its key turns red, and an icon with no key shows the game's range dot. Where the bars are set up to tint a whole button out of range, the flyout's icons take that same tint. Until now a flyout showed no range at all.
- An ability can be added to a flyout in combat: drag it onto the plus, which stands on the flyout's arrow in combat. It takes the next spot, with its key, at once. Until now nothing could be added until combat ended. A flyout that fills itself, and one whose icons stand around its button, take none in combat, and a new flyout is still made out of combat.
- The plus for adding to a flyout stands on the side that flyout opens from. For a flyout turned to open another way it stood on the bar's usual side.

## [1.1.3] - 2026-11-22

### Added
- A first login with the addon shows a small window, once: one line on how a flyout is made, and the preset flyouts that keep themselves filled from your bags (Food, Drink, Potions and the rest) in a row, each ready to be dragged onto a bar from there. It is one of the game's own windows in look and can be dragged about. Okay or its x closes it for good. Anyone who already has a flyout never sees it.

### Fixed
- Holding a flyout's key to keep it open did not work when that key was also one of the flyout's own pick keys (a flyout on the 1 button, say): it shut after the first pick. Such a key can now be held like any other. While it is down it keeps the flyout open, and once let go it is its icon's key again.
- The key text of a bar button lying under an open flyout showed through the flyout's icon. A flyout is now drawn over the bar buttons' texts as well as the buttons.
- An error in another addon that listens to this one could stop flyouts being laid out and followed: a flyout then stayed on a button whose ability had been dragged off. Such an error is now reported and stops nothing.
- A flyout's icons did not say how many of an item there are. Each icon now shows it in its corner, as a bar button does: the number in the bags for anything used up or stacked, and a spell's charges or uses.
- The settings page was taller than the game's Options window, so its last check boxes hung out under it. The page now scrolls inside the window, with the game's own scroll bar, and a controller's cursor scrolls it too.

### Changed
- An open flyout's keys are always the flyout's. With Fallen's Modifier Keys, a key set as a modifier there used to be skipped, so icons began at 2: they begin at 1 again, and the modifier key is left alone only while it is being held down. This needs the Fallen's Modifier Keys release that comes out alongside this one.
- A flyout now holds up to twelve, up from six, picked with the bar's own twelve keys: 1 to 9, 0, - and =. The game's Keybindings options have a row for each of the twelve spots of every flyout. In gamepad mode a ninth to twelfth icon stand on a third ring around the button; no pad button picks that ring, so there they are picked by key or by a click.
- The settings page says, over Arrange a flyout, that none of it is needed with a mouse: a flyout is made by dragging a spell, item or macro onto a bar button, where the + appears. That section is for a controller.

### Removed
- Set Keys is gone from the settings page. A key for an icon inside a flyout is set the game's own ways: in its Keybindings options, or by hovering the icon in Quick Keybind Mode and pressing the key.

## [1.1.2] - 2026-11-21

### Fixed
- The game's mouseover casting was ignored by a flyout's icons: a heal picked from a flyout went to the target, not to the friend under the mouse as it does from a bar button. A flyout's icons now obey it as the bar's own buttons do, with its key where one is set, and the focus cast key as well.

## [1.1.1] - 2026-11-21

### Added
- In gamepad mode a flyout opens around its button, each icon on the side its pad button is: the first above the button on D-pad up, then right, down and left. A fifth and sixth stand a step further out and take the face buttons of their sides. A check box under Arrange a flyout in the settings (`/ff`) turns this off, and a flyout given a shape of its own keeps it.
- The face buttons can pick before the D-pad: a check box under Arrange a flyout sets it for every flyout, and in gamepad mode, right after Add to Flyout, the same button swaps it for the flyout just made (the hint bar names it: Use Face Buttons, Use D-Pad).
- A button whose flyout opens around it is marked by four small dots at its corner, laid out like the pad's buttons, in place of the arrow: an arrow there looked like a D-pad direction to press.
- A flyout that opens around its button has a round background with a rim behind it, so an open flyout is seen at a glance. A check box under Arrange a flyout turns it off; in gamepad mode the hint bar does too (Hide Background, Show Background).
- In gamepad mode, binding an ability onto a taken button shows the flyout in place, around that button: its icons and the pad button that picks each. It changes at once when the face buttons, the D-pad or the background are swapped there.
- Edit Flyout, in gamepad mode: in Edit Action Bar, pick up a button that has a flyout and the hint bar offers Edit Flyout. The ability goes back on its button and the flyout editor is up at once, there in Edit Action Bar, around that button. In it the D-pad puts the selected icon on that side of the button, whether an icon is there or not (one that is there changes places with it), and the same side again puts it on the outer ring. Each icon stays where it is put. The hint bar names the rest: select the next icon, take it off, pick with the face buttons or the D-pad, show or hide the background, done.
- In gamepad mode, the buttons shown in Bind to Action Bar and Edit Action Bar wear the flyout mark too, so the buttons that have flyouts can be told there.
- The icon window (right-click a flyout's button) has a row of the flyout's own icons over the game's list. Pick one and it goes onto the bar button itself, so its icon, tooltip and cooldown are there to see without opening the flyout. What was on the button stays in the flyout.
- Reset to default icon, in the same window: the button gets back the ability it had, and any icon picked for it is taken off.
- A flyout lying along a side of its button can be centered on the button. Drag its grip to the middle of that side of the button and it snaps there; the Turn button under Arrange a flyout in the settings steps through the centered shapes too.

### Changed
- A flyout now goes with its button when the button is thrown away. Drag the button off the bar and let go, or unbind it in gamepad mode, and its flyout is removed: it no longer comes back when the same spell is put on a bar again. Moving the button to another spot keeps its flyout, as before.
- Turning a flyout by its grip is steadier: a shape takes over only when the mouse is clearly nearer to it and has stayed there a moment, so the flyout no longer jumps through every shape passed on the way.
- Macros that cast ranks of one spell are kept in rank order in a flyout, Rank 1 first, as the spells themselves are.

### Fixed
- Macros that share a name were taken for one and the same macro. This is common: many players name their macros with a single space to keep the name off the button. A second such macro dropped on the first was refused with "That is in the flyout already.", and a flyout could show or run the wrong one. Macros are now told apart by their text as well as their name.
- A macro's icon in a flyout now shows the tooltip its bar button would: the spell or the item the macro stands for. It used to show only the macro's name.
- A macro with a blank name is listed in the game's Keybindings options by what it casts.
- An error from the spellbook while the addon looked for bar buttons ("attempt to index a nil value" in the game's spellbook code).
- Flyouts showed through windows that were over the action bars. A flyout is now in the same layer as its bar, so such a window covers it too.
- The arrow on a flyout's button could stay dimmed after a click.
- In gamepad mode the mark on a flyout's button was sized late when its group grew or shrank. It keeps the button's size at every moment now.
- A flyout lying along a side of its button had no edge at its near end. It is closed at both ends now.
- A spell dragged out of a flyout had to be clicked onto a bar spot. Letting go over the spot now places it, as with a spell dragged from anywhere else.

## [1.1.0] - 2026-11-21

### Added
- Automatic flyouts, on a page of their own in the settings (`/ff`): Food, Drink, Potions, Elixirs, Flasks, Scrolls and Bandages. Drag one onto an action bar and it fills itself with what is in your bags, the best first, and keeps up as your bags change: the last of something used up, it is gone; more of it or something new in your bags, it is back. Each sits on your bar as a macro with an icon of its own. Nothing on a bar changes in a fight, so a flyout catches up when the fight ends. `/ff food`, `/ff drink` and so on put one on your cursor from chat.
- A flyout can be turned: out of combat, with the mouse on an open flyout, a grip appears at its far end. Drag the grip to where the flyout should end and it snaps there as you go: straight out from any side of its button, or lying along a side as a row or a column. Let go and it stays; drag it back and it opens the bar's own way again. With no mouse, the Turn button under Arrange a flyout in the settings steps through the same shapes.
- Ranks of one spell in the same flyout are kept in rank order, Rank 1 first, whichever of them the button holds. Other icons stay where you put them. A check box under Arrange a flyout in the settings (`/ff`) turns this off.

### Changed
- Flyouts you make by hand now leave out the items you have none of, and take them back, each in its old place, when you have some again. Untick Hide items I have none of under Arrange a flyout in the settings to keep them in place, grayed, as before.
- The Fallen's Flyouts section of the game's Keybindings options is laid out by flyout: each flyout on your bars, up to eight of them, has a heading, with a row for each of its spots. A key set on a row picks that spot while its flyout is open. Under them are rows for the spots of every flyout alike. A flyout on a bar of gamepad mode says so in its heading, and a flyout whose ability is on no bar keeps a heading only while a key is set under it.
- The rows there that set an extra key to open a flyout are gone: a flyout opens with its bar button's own key.

### Fixed
- A flyout on an upright bar opened along the bar, not to the side, while the buttons beside its own were empty and hidden.
- A key given to a flyout's bar button in the moment after the addon had bound its own keys was not taken up until keys changed again.
- Shift-dragging an icon out of a flyout cast it first. A mouse click on an icon now casts when the button is let go, as on the game's own flyouts; the keys still cast on the press.
- A spell's tooltip in a flyout now shows its rank.
- On a controller, the button that opened a flyout while a shoulder was held only shut it when pressed again. It now picks the spot it stands for, as a plain key does.

## [1.0.0] - 2026-11-21

### Added
- Your own flyouts on any action bar button: pick up a spell, an item or a macro and drop it on the plus that appears on a button. Up to six on each button, and as many flyouts as you like.
- Open a flyout with the button's key or a click, then press 1 to 6 to cast. It works in combat.
- Hold the button's key to keep the flyout open and press as many as you like; it closes when you let go.
- Controller support: pick with the D-pad and face buttons, shown with your controller's own symbols.
- The game's own flyout look and size, with cooldowns and out-of-mana dimming on every icon. A size setting makes them bigger or smaller.
- Your own key for any icon in a flyout: use Set Keys in the settings or the game's Quick Keybind Mode, hover the icon and press a key. A flyout's keys only count while it is open, so your normal keybinds are never changed.
- A section of its own in the game's Keybindings options: a key for each flyout, and the keys that pick each icon of an open one. Hover a flyout's row there and its bar button lights up.
- A flyout follows its ability when you move it to another button.
- Shift-drag an icon to move it inside its flyout: it lifts, the others slide out of its way, and it lands where you let go. Drag it out of the flyout to take it off.
- In gamepad mode, binding or moving an ability onto a button that already has one still replaces it, and the game's hint bar then names both ways on: Add to Flyout, which keeps the old ability on the button and stacks the new one into its flyout, or Swap Out.
- No mouse drag needed: the settings (`/ff`) have an Arrange section where you pick an icon and then the place it goes, made for a controller's cursor.
- Right-click an icon to take it off a flyout. Right-click the button to pick an icon for the flyout.
- Profiles for a character, a class or everyone, in the settings (`/ff`).
