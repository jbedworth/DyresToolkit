# Dyre's Toolkit

The shared toolkit for Dyre's AddOns on World of Warcraft: Forever and Classic
Era. The Dyre's AddOns you install use it, and the CurseForge app installs it
with them. On its own it shows nothing in combat and plays no sounds.

## Threat, tank tools, and the swing timer

These moved to their own AddOn in 2.16.0: **Dyre's Threat and Combat
Tools** (`/dct`). Install it from CurseForge to keep the threat labels and
sounds, the pull bars, the tank button bar, the pull countdown, the pet taunt
warning, and the swing timer. Your settings and key bindings come with you.
The toolkit's settings page has a link to it.

The key bindings for its buttons stay in this AddOn's `Bindings.xml`, under
their own section, "Dyre's AddOns", in Key Bindings, so saved keys keep
working. Without that AddOn, they do nothing.

The settings are per character. The Profile section at the end of the page
holds this character's profile: the settings, frame places, sizes, and sounds
of every Dyre's AddOn that has joined it. Copy another character's profile,
or the defaults, or export and import it as one line of text. A copy or
import applies at once. Press New to make a named profile from the
settings you use now, then pick it in "Profile in use" on each character that
should share it: a change on any of them reaches the others at their next
login. "This character's own" goes back to that character's own settings. The layout settings at the top (lock, grid, snap,
minimap) are yours on every character and are not in a profile.

## What it gives you

- **One layout mode.** `/dyre unlock` shows every Dyre's AddOn's frames, so
  you can drag them where you want; `/dyre lock` locks them all again. Each
  AddOn's own unlock command does the same.
- **Snapping.** A frame you drop near another snaps beside it, also when the
  other frame belongs to a different Dyre's AddOn. Shift-drag moves a group of
  snapped frames together.
- **A grid** while frames are unlocked, with red lines through the center of
  the screen. Its size is a setting. With **Snap to the grid** (on by default), a dropped
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
- **Welcome messages at login** (on by default): turn it off to hide the
  name-and-version line each Dyre's AddOn says in chat at login. Errors and
  problems always show. An AddOn follows this switch from its own update
  that supports it.
- **Bars that flip.** A Dyre's button bar can be a row or a column: its
  **Layout** setting, or the small rotate button on its outline while frames
  are unlocked.
- **Proc cues** (the engine for Dyre's Buff Reminders' proc arcs): while a
  proc's buff is up, an arc shows on each side of your character and drains
  with the time left, and a sound plays as it appears, also in combat. Dyre's
  Buff Reminders chooses the procs for each class and has their art, switches,
  sound, and arc size on its own page. An AddOn that
  brings no art gets a plain crescent in the proc's color. Sounds come from
  Dyre's Sounds.
  A stacking proc (Fingers of Frost) shows the right arc only while it has
  all its stacks, so you see when one is used, and its sound plays again
  when a stack is added.

Frames always start locked when you log in. Frames move only out of combat.

## Commands

| Command | What it does |
| --- | --- |
| `/dyre` | Opens the settings (out of combat) |
| `/dyre unlock`, `/dyre lock` | Unlocks or locks every Dyre's AddOn's frames |
| `/dyre grid` | Shows or hides the grid while unlocked |
| `/dyre snap` | Turns snapping to the grid on or off |
| `/dyre minimap` | Shows or hides the minimap button |
| `/dyre debug` | Until you reload: says in chat when another AddOn's hook into the toolkit fails, and lists those so far |
| `/dyre pull`, `/dyre tank_reset`, `/dyre debug_threat`, and the other old tank words | Say that these moved to Dyre's Threat and Combat Tools (`/dct`) |

`/dyretoolkit` works the same, in case another AddOn uses `/dyre`.

## For nameplate and unit frame authors

Dyre's AddOns that predict DoT damage draw a block and a **DIES** badge on
mob health bars. If your AddOn draws its own bars, or the badge covers
something of yours, `DyresToolkit.HealthBars` lets you say where your bar
is, where the badge goes, and when to draw nothing. You can also read the
prediction to show it your own way. See
[docs/HEALTHBARS_API.md](docs/HEALTHBARS_API.md).

## Compatibility

For the Forever beta client 1.60.1, build 70888, Interface 16001, and
Classic Era (Interface 11509).

## Credits

DoT damage prediction on WoW: Forever follows the method of Does It Die, by
Joe Greive: casts, tooltips, and the timing of hits, with the damage meter
for tick sizes. The code is Dyre's own.

## Support

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

## License

MIT; see LICENSE. The embedded libraries keep their own terms: LibStub (public
domain), CallbackHandler-1.0 and LibDBIcon-1.0 (Ace3 BSD-style, see
`Libs/Ace3-LICENSE.txt`), and LibDataBroker-1.1 (its author asks AddOns to
embed it).
