# Testing

## Method

1. **Pinned source review.** Client behavior is read from Blizzard's UI source
   at Gethe/wow-ui-source `943764493e6b16d63ded3ab304150d1f05e58b57`.
2. **Automated mock tests.** `tests/run.lua` exercises the interface, saved
   settings repair, locking, dragging and snapping (neighbors, Shift groups,
   the grid), the settings home, commands, and the minimap button against a
   small mock of the client. The Python tests cover the release helpers.
3. **In-client checks.** The checklist below covers what mocks cannot.

## Source findings

- Settings sub-pages draw recursively (Blizzard_CategoryList.lua,
  CreateSection), so Dyre's AddOns → an AddOn → its own pages displays.
- The AddOn list nests a child whose `## Group` equals a parent's folder name;
  a child whose parent is missing shows at the top level (AddonList.lua).
- Forever loads no AddOn compartment (Blizzard_Minimap.toc: mainline only), so
  the minimap button is LibDBIcon's. MenuUtil loads for every game type.

## In-client checklist

- [ ] The AddOn list shows a "Dyre's AddOns" section with Dyre's Toolkit, and
      every installed Dyre's AddOn nested under it.
- [ ] Options → AddOns → Dyre's AddOns shows the toolkit's settings, with each
      Dyre's AddOn's page under it (MTF's and WTF's own pages one level
      deeper).
- [ ] The minimap button shows; left-click unlocks every Dyre's AddOn's frames
      with one chat line; right-click opens the menu; each AddOn entry opens
      its page.
- [ ] While unlocked, the grid shows; a frame from one AddOn snaps beside a
      frame from another; Shift-drag moves a snapped group.
- [ ] "Snap to the grid": near a red center line a dropped frame centers on
      it, or puts an edge on it; elsewhere an edge within a quarter of the grid size of a grey line
      lines up with it, and farther away the frame stays put; near another Dyre's frame it snaps to the frame instead; a
      Shift-dragged group lines up as one block. Changing "Grid size" redraws
      the grid.
- [ ] Ctrl held as you drop: the frame stays exactly there, also beside
      another frame or near a grid line; Shift+Ctrl moves a group unsnapped.
- [ ] After /reload, frames start locked and stay where they were dropped.
- [ ] In combat, /dyre opens nothing and says so; a drag ends after combat.
