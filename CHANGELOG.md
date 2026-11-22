# Changelog

## [1.1.1] - 2026-11-21

### Added
- In gamepad mode a flyout opens around its button, each icon on the side its pad button is: the first above the button on D-pad up, then right, down and left. A fifth and sixth stand a step further out and take the face buttons of their sides. A check box under Arrange a flyout in the settings (`/ff`) turns this off, and a flyout given a shape of its own keeps it.
- The face buttons can pick before the D-pad: a check box under Arrange a flyout sets it for every flyout, and in gamepad mode, right after Add to Flyout, the same button swaps it for the flyout just made (the hint bar names it: Use Face Buttons, Use D-Pad).
- A button whose flyout opens around it is marked by four small dots at its corner, laid out like the pad's buttons, in place of the arrow: an arrow there looked like a D-pad direction to press.
- A flyout that opens around its button has a round background with a rim behind it, so an open flyout is seen at a glance. A check box under Arrange a flyout turns it off; in gamepad mode the hint bar does too (Hide Background, Show Background).
- In gamepad mode, binding an ability onto a taken button shows the flyout in place, around that button: its icons and the pad button that picks each. It changes at once when the face buttons, the D-pad or the background are swapped there.
- Edit Flyout, in gamepad mode: in Edit Action Bar, pick up a button that has a flyout and the hint bar offers Edit Flyout. The ability goes back on its button, and once Edit Action Bar is left the flyout editor opens around that button. In it the D-pad moves the selected icon to that side of the button (it changes places with the icon there), and the hint bar names the rest: select the next icon, take it off, pick with the face buttons or the D-pad, show or hide the background, done.
- The icon window (right-click a flyout's button) has a row of the flyout's own icons over the game's list. Pick one and it goes onto the bar button itself, so its icon, tooltip and cooldown are there to see without opening the flyout. What was on the button stays in the flyout.
- Reset to default icon, in the same window: the button gets back the ability it had, and any icon picked for it is taken off.
- A flyout lying along a side of its button can be centered on the button. Drag its grip to the middle of that side of the button and it snaps there; the Turn button under Arrange a flyout in the settings steps through the centered shapes too.

### Changed
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
