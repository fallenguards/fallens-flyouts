# Changelog

## [1.1.0] - 2026-11-21

### Added
- Automatic flyouts, on a page of their own in the settings (`/ff`): Food, Drink, Potions, Elixirs, Flasks, Scrolls and Bandages. Drag one onto an action bar and it fills itself with what is in your bags, the best first, and keeps up as your bags change: the last of something used up, it is gone; more of it or something new in your bags, it is back. Each sits on your bar as a macro with an icon of its own. Nothing on a bar changes in a fight, so a flyout catches up when the fight ends. `/ff food`, `/ff drink` and so on put one on your cursor from chat.
- Ranks of one spell in the same flyout are kept in rank order, Rank 1 first, whichever of them the button holds. Other icons stay where you put them. A check box under Arrange a flyout in the settings (`/ff`) turns this off.
- Turn a flyout: out of combat an open flyout has a grip at its far end. Drag the grip to where the flyout should end and it snaps there as you go: straight out from any side of its button, or lying along a side as a row or a column. Let go and it stays; drag it back and it opens the bar's own way again. With no mouse, the Turn button under Arrange a flyout in the settings steps through the same shapes.
- Make an automatic flyout of your own: build a flyout by hand as ever, then tick Only show what I have for it under Arrange a flyout in the settings (`/ff`). It leaves out the items you have none of and takes them back when you have some again.

### Changed
- In the game's Keybindings options, the flyouts on the bars of gamepad mode have a heading and rows of their own, apart from the flyouts on your action bars.
- A flyout whose ability is on no bar any more is no longer listed there, and the listed flyouts close up with no gaps between them. A row with a key set on it always keeps its flyout.

### Fixed
- A flyout on an upright bar opened along the bar, not to the side, while the buttons beside its own were empty and hidden.

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
