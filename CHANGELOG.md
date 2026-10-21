# Changelog

Player-facing changes for each Dyre's Toolkit release, newest first. The
release builder copies the section for the TOC version into the GitHub release
notes and the CurseForge changelog, and fails if that section is missing.

## 2.0.0

### Features
- Every Dyre's AddOn that moves to the toolkit's widgets places, drags, snaps, and resizes its frames exactly the same way: the gold outline and hint while frames are unlocked, magnetic snapping, the grid, Shift-drag for a group, and Ctrl for an exact place.
- Their size and opacity settings look and work the same everywhere, each slider with a gold mark at its default, and a "Reset size" button.

### Fixes
- Frames that change size or scale keep their place on screen. Before, making a frame bigger through a size setting could move it right and up, away from where you put it.
- A frame you lock no longer takes your mouse clicks where it sits, unless it is a bar of buttons you click.

### Other changes
- Dyre's AddOns will need Dyre's Toolkit from their next releases on; the CurseForge app installs it with them.
- For AddOn authors: contract 2 adds `CreateWidget`, `AddWidgetSettings`, `ResetWidgets`, and `Widgets`, plus `ResizeFromCenter`. Contract 1 still works.

## 1.0.0

The first full release for WoW: Forever, no longer marked beta: it was play tested on the Forever beta client 1.60.1, build 70450. CurseForge now offers it as a release, so the app updates it and installs what it needs for every player.

- The CurseForge app now installs Dyre's Toolkit with the Dyre's AddOns that need it.

## 0.1.1-beta

First beta on CurseForge, for WoW: Forever. The AddOn is the same as 0.1.0-beta, which reached GitHub only.

- One layout mode for every Dyre's AddOn: `/dyre unlock` shows every frame to drag, `/dyre lock` locks them all.
- Frames snap to each other, also across AddOns; Shift-drag moves a snapped group.
- A grid while unlocked, with its size a setting, and "Snap to the grid": near a red center line a frame centers on it or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line lines up with it (when both edges are that close, the one that moves the least wins). Snapping to another Dyre's frame comes first; a Shift-dragged group snaps as one block. Hold Ctrl as you drop to place a frame exactly, with no snapping.
- A minimap button: left-click locks or unlocks frames, right-click opens a menu with the grid switches, the settings, and each installed Dyre's AddOn.
- One "Dyre's AddOns" settings home in Options > AddOns, with each Dyre's AddOn's page under it. `/dyre` opens it.

## 0.1.0-beta

First beta for WoW: Forever.

- One layout mode for every Dyre's AddOn: `/dyre unlock` shows every frame to drag, `/dyre lock` locks them all.
- Frames snap to each other, also across AddOns; Shift-drag moves a snapped group.
- A grid while unlocked, with its size a setting, and "Snap to the grid": near a red center line a frame centers on it or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line lines up with it (when both edges are that close, the one that moves the least wins). Snapping to another Dyre's frame comes first; a Shift-dragged group snaps as one block. Hold Ctrl as you drop to place a frame exactly, with no snapping.
- A minimap button: left-click locks or unlocks frames, right-click opens a menu with the grid switches, the settings, and each installed Dyre's AddOn.
- One "Dyre's AddOns" settings home in Options > AddOns, with each Dyre's AddOn's page under it. `/dyre` opens it.
