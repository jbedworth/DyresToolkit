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

The part every Dyre's AddOn shares. One layout mode, grid, and snapping for every frame. Bars that turn into columns. One settings home and a profile for each character. For WoW: Forever and Classic Era.

## Description

Paste this with the description editor in Markdown mode. Pasted into the rich
text editor, the headings, bullets, and bold show as raw, escaped markdown.

Per-file changelogs need no manual text: each CI upload uses the version's
`CHANGELOG.md` section, through `release-notes.md`.

```markdown
I build Dyre's AddOns as a family of small AddOns, so you only install the ones you want. The catch with a family is that every AddOn wants to move, snap, and save its settings a little differently, and I didn't want you learning that six times. **Dyre's Toolkit** is the part they all share, so they all work the same way. The CurseForge app installs it for you with any Dyre's AddOn, and on its own it shows nothing in combat and plays no sounds.

### One layout mode for every frame
- Type `/dyre unlock`, or left-click the minimap button, and every Dyre's AddOn shows its frames with an outline and a label, so you always know which frame is which. Drag them where you want, then type `/dyre lock`.
- A grid shows while frames are unlocked, with red lines through the middle of the screen. Frames snap to the grid and to each other, even when they come from different Dyre's AddOns.
- **Shift-drag** moves a group of snapped frames together.
- Hold **Ctrl** as you drop a frame to place it to the pixel, with no snapping.
- **Ctrl-drag** moves a frame while frames are locked, the same way Questie's tracker does.
- A button bar can have one opacity out of combat and another in combat. It shows at 80% or more while your mouse is over it.
- A button bar can be a row or a column. This works for the Mage's Conjure and Portals bars, the Warlock's Stones bar, the Hunter's Aspect bar, and the tank bar. While frames are unlocked, click the small rotate button on the bar's outline.
- Frames always start locked when you log in. They never move in combat.

### One settings home
- Options > AddOns > Dyre's AddOns has a page for each Dyre's AddOn you have. Type `/dyre` to open it.
- Warlock Tools Forever and Mage Tools Forever show the settings of their companion AddOns on their own pages, so you set up your whole class in one place. Each feature has an on/off switch on the main page.
- When a companion AddOn is missing, its page tells you what it adds and where to get it.
- You can turn off the welcome message each AddOn writes in chat at login. Errors and problems still show.

### Profiles
- Each character has its own profile. It holds the settings, frame positions, sizes, and sounds of every Dyre's AddOn.
- Make a named profile with New, then pick it on any character. They all share one set of settings and frame positions, and a change on one reaches the others at their next login.
- Copy another character's setup, or the defaults, with one click.
- Export a profile as one line of text, and import it on another account.

### Minimap button
- Left-click locks or unlocks the frames.
- Right-click opens a menu with the grid switches, the settings, and each Dyre's AddOn you have.

### Where did the threat and tank tools go?
I moved them into their own AddOn, **Dyre's Threat and Combat Tools** (`/dct`), so players who don't tank don't get them by default. Install it to get the threat labels, the tank button bar, the pull countdown, the pet taunt warning, and the swing timer. Your settings and key bindings come with you.

### Commands
- `/dyre` opens the settings.
- `/dyre unlock` and `/dyre lock` unlock and lock every frame.
- `/dyre grid`, `/dyre snap`, and `/dyre minimap` turn the grid, snapping, and the minimap button on or off.
- `/dyretoolkit` does the same as `/dyre`, for when another AddOn already uses `/dyre`.

### Compatibility
For World of Warcraft: Forever 1.60.1, tested on build 70888, and for Classic Era.

Questions, ideas, or bugs? Tell me in the comments.

Dyre's AddOns are free. If you enjoy them, you can support them on Ko-fi: https://ko-fi.com/dyre_janelle

Source, issues, and license (MIT): https://github.com/jbedworth/DyresToolkit
```
