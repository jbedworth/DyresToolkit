# Dyre's Toolkit

The shared toolkit for Dyre's AddOns on World of Warcraft: Forever. It does
nothing on its own; the Dyre's AddOns you install use it. The CurseForge app
installs it with them.

## What it gives you

- **One layout mode.** `/dyre unlock` shows every Dyre's AddOn's frames, so
  you can drag them where you want; `/dyre lock` locks them all again. Each
  AddOn's own unlock command does the same.
- **Snapping.** A frame you drop near another snaps beside it, also when the
  other frame belongs to a different Dyre's AddOn. Shift-drag moves a group of
  snapped frames together.
- **A grid** while frames are unlocked, with red lines through the center of
  the screen. Its size is a setting. Turn on **Snap to the grid**: a dropped
  frame near a red center line centers on it, or puts its nearer edge on it.
  Elsewhere, an edge within a quarter of the grid size (8 at 32) of a grey
  line lines up with it. When both edges (left and right, or top and bottom)
  are that close, the one that moves the least wins, so the frame may line
  up at its lower-right corner rather than its upper-left: check both.
  Snapping to another Dyre's frame comes before the grid; a Shift-dragged
  group snaps to the grid as one block. Hold **Ctrl** as you drop a frame to
  place it exactly, with no snapping.
- **Move without unlocking.** Hold **Ctrl** and drag a frame by a button or
  a box's header to move it while frames are locked, as with Questie's
  tracker. It goes exactly where you drop it. Frames move only out of combat.
- **A minimap button.** Left-click locks or unlocks frames. Right-click opens a
  menu: lock or unlock, the grid switches, the settings, and each installed
  Dyre's AddOn's settings. `/dyre minimap` hides or shows the button.
- **One settings home.** Options → AddOns → **Dyre's AddOns** holds these
  settings, with each Dyre's AddOn's page under it. `/dyre` opens it.

Frames always start locked when you log in. Frames move only out of combat.

## Commands

| Command | What it does |
| --- | --- |
| `/dyre` | Opens the settings (out of combat) |
| `/dyre unlock`, `/dyre lock` | Unlocks or locks every Dyre's AddOn's frames |
| `/dyre grid` | Shows or hides the grid while unlocked |
| `/dyre snap` | Turns snapping to the grid on or off |
| `/dyre minimap` | Shows or hides the minimap button |

`/dyretoolkit` works the same, in case another AddOn uses `/dyre`.

## Compatibility

For the Forever beta client 1.60.1, build 70450, Interface 16001.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT; see LICENSE. The embedded libraries keep their own terms: LibStub (public
domain), CallbackHandler-1.0 and LibDBIcon-1.0 (Ace3 BSD-style, see
`Libs/Ace3-LICENSE.txt`), and LibDataBroker-1.1 (its author asks AddOns to
embed it).
