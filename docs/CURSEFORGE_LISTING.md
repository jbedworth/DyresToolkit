# CurseForge listing

Copy-ready text for the CurseForge project form. Keep it aligned with README.md
and the tested client; do not advertise clients or versions that have not been
tested.

## Project fields

| Field | Value |
| --- | --- |
| Name | Dyre's Toolkit |
| Slug | dyres-toolkit (every Dyre's AddOn with frames or settings declares it as a required dependency by this slug) |
| Project ID | 1755491 |
| Class | Addons |
| Main category | Libraries. The TOC uses `## Category: Dyre's AddOns` instead, so the in-game AddOn list shows the family as one section with the toolkit as its parent. |
| Additional categories | None |
| Author shown | Dyre, set through the CurseForge account's username |
| License | MIT License (the embedded libraries keep their own terms; see README) |
| Logo | `artwork/dyres-toolkit-logo-512.png` (1024 master and SVG source in `artwork/`) |
| Relations | None: its libraries (LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0) are embedded in its package. |
| Source | https://github.com/jbedworth/DyresToolkit |
| Issues | https://github.com/jbedworth/DyresToolkit/issues |
| Donation | Ko-fi, https://ko-fi.com/dyre_janelle (the project's Donation field) |

## Summary

Threat warnings and tank tools for every player, and the shared layout mode, grid, mini-map button, and settings home for Dyre's AddOns on WoW: Forever.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
**Dyre's Toolkit** ties Dyre's AddOns together on WoW: Forever. The Dyre's AddOns you install use it, and the CurseForge app installs it with them. It also gives every player threat warnings and tank tools.

### Group warnings
- **Threat** beside enemy nameplates and above your target: a shield (tank view) or crossed swords (DPS and healer view) and your threat percent, the icon and the text both in green, yellow, or red. In the tank view, yellow comes early when another player nears the pull point, and a mob another tank holds is blue. A sound you choose plays when a mob turns red (by default Bell buzz from Dyre's Sounds 1.5.0 or later; without it, the game's raid warning).
- Auto uses the tank bar's rule: the tank view for the group's Tank or raid main tank, a Druid in Bear Form, a Paladin with Righteous Fury, or a Warrior in Defensive Stance.
- **Pet taunt on**: a message when Growl, Torment, or Suffering is on autocast in a group where you are not the tank.

### Tank tools
- Skull, Next marker, and pings in combat with no "blocked from an action" popup, on a bar and as key bindings.
- A PULL button and `/dyre pull 10`, handed to Deadly Boss Mods or BigWigs when one is loaded, else the game's countdown.
- Dyre's countdown on screen: when anyone in your group starts a pull, a big animated countdown with a draining bar, who started it, and a "PULL!" splash, in place of the game's own (it never overrides another AddOn: hidden with BigWigs, and with Deadly Boss Mods unless DBM's own pull bar is turned off).

### One layout mode
- `/dyre unlock` shows every Dyre's AddOn's frames, so you can drag them where you want. `/dyre lock` locks them all again. Each AddOn's own unlock command does the same.
- Frames always start locked when you log in, and move only out of combat.

### Snapping
- A frame you drop near another snaps beside it, also when the other frame belongs to a different Dyre's AddOn.
- **Shift-drag** moves a group of snapped frames together.
- **Ctrl** as you drop places a frame exactly where you let go, with no snapping.
- **Ctrl-drag** moves a frame even while frames are locked: grab it by a button or a box's header.

### The grid
- While frames are unlocked, a grid across the screen, with red lines through its center. Its size is a setting.
- With **Snap to the grid** on (the default), a frame near a red center line centers on it, or puts its nearer edge on it.
- Elsewhere, an edge within a quarter of the grid size of a grey line lines up with it. When both edges (left and right, or top and bottom) are that close, the one that moves the least wins, so a frame may line up at its lower-right corner rather than its upper-left: check both.
- Snapping to another Dyre's frame comes before the grid; a Shift-dragged group snaps to the grid as one block.

### Minimap button and settings
- Left-click locks or unlocks frames; right-click opens a menu with the grid switches, the settings, and each installed Dyre's AddOn.
- Options > AddOns > **Dyre's AddOns** holds these settings, with each Dyre's AddOn's page under it. `/dyre` opens it.

### Commands
- `/dyre` opens the settings; `/dyre unlock`, `/dyre lock`.
- `/dyre grid`, `/dyre snap`, `/dyre minimap` switch the grid, snapping, and the minimap button.
- `/dyre pull [seconds]`, `/dyre tank_reset`, `/dyre tank_debug`, `/dyre threat_debug`, `/dyre taunt_debug`; `/dtt` and `/tanktools` take the short tank words.
- `/dyretoolkit` works the same, in case another AddOn uses `/dyre`.

### Compatibility
For World of Warcraft: Forever 1.60.1 (tested on build 70888).

Source, issues, and license (MIT): https://github.com/jbedworth/DyresToolkit
```
