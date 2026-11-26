-- The swing timer and range box (Swing.lua). tests/run.lua loads this file
-- with its test helpers and tests/tank.lua's client harness. These mocks test
-- the rules, not the client: the timer bar's fill, the range events'
-- boundaries, and the look are in-client checks (TESTING.md).
local test, equal, contains, fixture = ...

local NAMES = {[75] = "Auto Shot", [2974] = "Wing Clip", [14267] = "Wing Clip", [2480] = "Shoot Bow",
    [7918] = "Shoot Gun", [7919] = "Shoot Crossbow", [2764] = "Throw", [5019] = "Shoot", [19434] = "Aimed Shot",
    [1310687] = "Sniper Shot"}

-- A client with the swing APIs. options: class, known (spell IDs), subclass
-- (the ranged weapon's item subclass; nil: none), missing (events the client
-- lacks), db (saved DyresToolkitCharDB), near (CheckInteractDistance index 3).
local function SwingFixture(options)
    options = options or {}
    local state = fixture({noLogin = true, class = options.class or "HUNTER", db = options.db,
        globals = options.globals})
    local env = state.env
    local missing = options.missing or {}
    env.C_EventUtils = {IsEventValid = function(event) return not missing[event] end}
    state.checks, state.checkCalls = {}, {}
    local getName = env.C_Spell.GetSpellName
    env.C_Spell.GetSpellName = function(id) return NAMES[id] or getName(id) end
    if not options.noRangeAPI then
        env.C_Spell.EnableSpellRangeCheck = function(name, enable)
            state.checks[name] = enable or nil
            state.checkCalls[#state.checkCalls + 1] = name .. "=" .. tostring(enable)
        end
    end
    -- options.casts: spell name -> cast time in milliseconds (or a secret).
    state.casts = options.casts or {}
    -- options.speed: the ranged weapon's tooltip Speed line (right text).
    if options.speed then
        env.C_TooltipInfo = {GetItemByID = function(item)
            state.tooltipReads = (state.tooltipReads or 0) + 1
            return {lines = {{leftText = "Ranged weapon " .. item}, {leftText = "Bow", rightText = options.speed}}}
        end}
    end
    if options.speedLabel then env.SPEED = options.speedLabel end
    env.C_Spell.GetSpellInfo = function(name)
        if state.casts[name] ~= nil then return {name = name, castTime = state.casts[name]} end
    end
    env.C_DurationUtil = {CreateDuration = function()
        local duration = {}
        function duration:SetTimeFromStart(start, seconds) self.start, self.seconds = start, seconds end
        return duration
    end}
    state.known = {}
    for _, id in ipairs(options.known or {}) do state.known[id] = true end
    env.IsPlayerSpell = function(id) return state.known[id] == true end
    state.subclass = options.subclass
    env.GetInventoryItemID = function(_, slot)
        if slot == 18 and state.subclass then return 1000 + state.subclass end
    end
    env.C_Item = {GetItemInfoInstant = function(item)
        return item, "Weapon", "Ranged", "INVTYPE_RANGED", 1, 2, item - 1000
    end}
    state.near = options.near
    env.CheckInteractDistance = function(unit, index)
        state.nearAsked = (state.nearAsked or 0) + 1
        equal(index, 3, "about 10 yards")
        return state.near
    end
    env.UnitIsDeadOrGhost = function() return state.dead == true end
    state.fire("ADDON_LOADED", "DyresToolkit")
    state.fire("PLAYER_LOGIN")
    state.swing = state.core.swing
    state.widget = state.swing.Widget()
    function state.range(spell, inRange, checks)
        state.fire("SPELL_RANGE_CHECK_UPDATE", spell, inRange, checks ~= false)
    end
    function state.settled()
        state.advance(state.swing.SETTLE)
        return state.swing.ShownState()
    end
    function state.header()
        return state.widget.header.text
    end
    function state.border()
        local color = state.widget.box.lastSetBackdropBorderColor
        return color and table.concat({color[1], color[2], color[3]}, ",")
    end
    return state
end

local GREEN, RED = "0.15,0.9,0.25", "0.95,0.15,0.1"

test("swing: the range rule, case by case", function()
    local RangeState = SwingFixture().swing.RangeState
    local function near() return true end
    local function far() return false end
    equal(RangeState({hostile = false, ranged = true}), nil, "no enemy target: no state")
    equal(RangeState({hostile = true, ranged = true, melee = true, near = near}), "range", "ranged wins first")
    equal(RangeState({hostile = true, ranged = false, melee = true, meleeProbe = true, near = near}), "melee")
    equal(RangeState({hostile = true, ranged = false, melee = false, meleeProbe = true, deadZone = true,
        near = near}), "deadzone")
    equal(RangeState({hostile = true, ranged = false, melee = false, meleeProbe = true, deadZone = true,
        near = far}), "far")
    equal(RangeState({hostile = true, ranged = false, deadZone = true, near = near}), "close",
        "no melee check: the dead zone and melee together")
    equal(RangeState({hostile = true, ranged = false, deadZone = true, near = near, recentMelee = true}), "melee",
        "no melee check: melee swings landing")
    equal(RangeState({hostile = true, ranged = false, deadZone = false, near = near}), "far",
        "a wand has no dead zone")
    equal(RangeState({hostile = true, melee = false, meleeProbe = true}), "far", "no ranged check: out of melee")
    equal(RangeState({hostile = true}), nil, "no answer yet")
    local asked = 0
    RangeState({hostile = true, ranged = true, deadZone = true, near = function() asked = asked + 1 end})
    equal(asked, 0, "the near check is read only when needed")
end)

test("swing: saved settings are repaired in place, with defaults", function()
    local state = SwingFixture({db = {swing = {show = "sometimes", range = "yes", hold = false, theme = "pink",
        frame = 5}}})
    local db = state.env.DyresToolkitCharDB.swing
    equal(db.show, "combat", "not a choice: In combat")
    equal(db.range, true)
    equal(db.hold, false, "a saved choice stays")
    equal(db.theme, "gold")
    equal(type(db.frame), "table")
    local saved = {show = "always"}
    equal(state.core.SanitizeSwing(saved), saved, "the same table")
    equal(SwingFixture({db = {}}).env.DyresToolkitCharDB.swing.show, "combat", "a fresh character")
end)

test("swing: a Hunter with Wing Clip gets RANGE, DEAD ZONE, MELEE, and TOO FAR from the range events", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2})
    equal(state.checks["Auto Shot"], true, "Auto Shot by name")
    equal(state.checks["Wing Clip"], true)
    equal(state.checks["Shoot Bow"], nil, "a Hunter's ranged check is Auto Shot")
    state.range(75, true)
    equal(state.swing.ShownState(), nil, "a change waits to settle")
    equal(state.settled(), "range")
    equal(state.header(), "RANGE")
    equal(state.border(), GREEN)
    state.near = true
    state.range(75, false)
    equal(state.settled(), "deadzone")
    equal(state.header(), "DEAD ZONE")
    equal(state.border(), RED)
    state.range(14267, true)
    equal(state.settled(), "melee", "Wing Clip's rank 2 ID is the same check")
    equal(state.border(), GREEN)
    state.range(2974, false)
    state.near = false
    state.range(75, false)
    equal(state.settled(), "far")
    equal(state.header(), "TOO FAR")
    state.range(75, false, false)
    state.range(2974, false, false)
    equal(state.settled(), nil, "no check active (target lost): no state")
end)

test("swing: the flicker at an edge does not change the box", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2, near = true})
    state.range(75, false)
    state.range(2974, false)
    equal(state.settled(), "deadzone")
    state.range(2974, true)
    state.advance(0.05)
    state.range(2974, false)
    state.advance(0.2)
    equal(state.swing.ShownState(), "deadzone", "back in time: unchanged")
end)

test("swing: below level 12 (no Wing Clip), TOO CLOSE, and MELEE while melee swings land", function()
    local state = SwingFixture({known = {75}, subclass = 3, near = true})
    equal(state.checks["Wing Clip"], nil)
    state.range(75, false)
    equal(state.settled(), "close")
    equal(state.header(), "TOO CLOSE")
    state.fire("PLAYER_SWING", 2.0, 0)
    equal(state.settled(), "melee")
    state.advance(2.0)
    equal(state.swing.ShownState(), "melee", "still within the swing and its grace")
    state.advance(0.6)
    equal(state.settled(), "close", "no swing for a swing time and a half second")
end)

test("swing: other classes use the ranged weapon's own shoot spell; a wand has no dead zone", function()
    local warrior = SwingFixture({class = "WARRIOR", known = {7918}, subclass = 3, near = true})
    equal(warrior.checks["Shoot Gun"], true)
    equal(warrior.checks["Auto Shot"], nil)
    warrior.range(7918, false)
    equal(warrior.settled(), "close", "a gun has a dead zone; no Warrior melee check yet")
    local mage = SwingFixture({class = "MAGE", known = {5019}, subclass = 19, near = true})
    equal(mage.checks["Shoot"], true)
    mage.range(5019, false)
    equal(mage.settled(), "far", "a wand out of range is too far")
    mage.range(5019, true)
    equal(mage.settled(), "range")
    local unarmed = SwingFixture({class = "ROGUE", known = {}, subclass = nil})
    equal(next(unarmed.checks), nil, "nothing to check")
end)

test("swing: changing weapons turns the old check off and the new one on", function()
    local state = SwingFixture({class = "WARRIOR", known = {7918, 2480}, subclass = 3})
    equal(state.checks["Shoot Gun"], true)
    state.subclass = 2
    state.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
    equal(state.checks["Shoot Gun"], nil, "turned off: the client keeps a check on across /reload")
    equal(state.checks["Shoot Bow"], true)
end)

test("swing: turning the range box off turns every check off and hides the state", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2})
    state.range(75, true)
    equal(state.settled(), "range")
    state.settings.DYRE_SWING_RANGE:SetValue(false)
    equal(next(state.checks), nil, "no check left on")
    equal(state.swing.CurrentState(), nil)
    state.settings.DYRE_SWING_RANGE:SetValue(true)
    equal(state.checks["Auto Shot"], true, "back on")
end)

test("swing: a swing starts its bar from the swing event; secret or odd values are skipped", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local rows = state.swing.Rows()
    state.now = 10
    state.fire("PLAYER_SWING", 2.6, 0)
    local duration = rows[0].bar.lastSetTimerDuration[1]
    equal(duration.start, 10)
    equal(duration.seconds, 2.6)
    state.fire("PLAYER_SWING", state.secret(), 0)
    equal(rows[0].bar.lastSetTimerDuration[1], duration, "a secret duration: skipped")
    state.fire("PLAYER_SWING", -1, 0)
    state.fire("PLAYER_SWING", 0 / 0, 0)
    equal(rows[0].bar.lastSetTimerDuration[1], duration, "odd values: skipped")
    state.fire("PLAYER_SWING", 2, 7)
end)

test("swing: the off-hand row shows once the off hand swings; the ranged row with a ranged weapon", function()
    local state = SwingFixture({class = "WARRIOR", known = {}, subclass = nil, db = {swing = {inUse = false}}})
    local rows = state.swing.Rows()
    equal(rows[0].frame.shown, true)
    equal(rows[1].frame.shown, false, "no off-hand swing yet")
    equal(rows[2].frame.shown, false, "no ranged weapon")
    state.fire("PLAYER_SWING", 1.8, 1)
    equal(rows[1].frame.shown, true)
    state.subclass = 2
    state.fire("PLAYER_EQUIPMENT_CHANGED", 18, false)
    equal(rows[2].frame.shown, true)
    equal(rows[1].frame.shown, false, "equipment changed: the off hand shows again once it swings")
end)

test("swing: a Hunter's last half second of Auto Shot is the red hold-still zone", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local row = state.swing.Rows()[2]
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(row.hold.shown, true)
    equal(row.hold.lastSetWidth[1], row.width / 4, "0.5 s of 2.0 s")
    equal(row.label.text, "Ranged")
    state.advance(1.5)
    equal(row.label.text, "HOLD STILL")
    state.fire("PLAYER_STARTED_MOVING")
    equal(row.label.text, "STOP", "moving in the zone")
    state.fire("PLAYER_STOPPED_MOVING")
    equal(row.label.text, "HOLD STILL")
    state.advance(0.5)
    equal(row.label.text, "Ranged", "the shot is out")
    state.settings.DYRE_SWING_HOLD:SetValue(false)
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(row.hold.shown, false, "turned off")
    state.advance(1.6)
    equal(row.label.text, "Ranged")
end)

test("swing: clip zones for Aimed Shot and Sniper Shot, from their live cast times, before the red zone", function()
    local state = SwingFixture({known = {75, 19434, 1310687}, subclass = 2,
        casts = {["Aimed Shot"] = 2000, ["Sniper Shot"] = 1500, ["Auto Shot"] = 0}})
    local row = state.swing.Rows()[2]
    state.fire("PLAYER_SWING", 3.0, 2)
    local hold = row.width * 0.5 / 3.0
    local aimed, sniper = row.clips[1], row.clips[2]
    equal(aimed.shown, true)
    equal(aimed.lastSetWidth[1], row.width * 2 / 3, "Aimed Shot: 2 s of the 3 s swing")
    equal(aimed.points[1][4], -hold, "ends where the red zone starts")
    equal(sniper.shown, true)
    equal(sniper.lastSetWidth[1], row.width * 1.5 / 3)
    state.casts["Aimed Shot"] = 2600
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(aimed.lastSetWidth[1], row.width * 1.5 / 2.0, "a cast longer than the free part: all of it")
    state.settings.DYRE_SWING_CLIP:SetValue(false)
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(aimed.shown, false, "turned off")
    equal(sniper.shown, false)
end)

local function near(actual, expected, context)
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-9 then
        error((context and context .. ": " or "") .. "expected about " .. tostring(expected) .. ", got "
            .. tostring(actual), 2)
    end
end

test("swing: Auto Shot's cast scales with ranged haste: 0.5 x swing / the weapon's base speed", function()
    local state = SwingFixture({known = {75, 19434}, subclass = 2, speed = "Speed 3.00",
        casts = {["Aimed Shot"] = 2000}})
    local row = state.swing.Rows()[2]
    near(state.swing.HoldTime(2.4), 0.4, "a 3.00 bow swinging in 2.4 s: 0.4 s")
    state.fire("PLAYER_SWING", 2.4, 2)
    near(row.hold.lastSetWidth[1], row.width * 0.4 / 2.4)
    near(row.clips[1].lastSetWidth[1], row.width * 2 / 2.4, "Aimed Shot ends where the scaled red zone starts")
    state.advance(1.9)
    equal(row.label.text, "Ranged")
    state.advance(0.1)
    equal(row.label.text, "HOLD STILL", "at 2.0 s of 2.4")
    state.fire("PLAYER_SWING", 2.4, 2)
    equal(state.tooltipReads, 1, "the base speed is read once per weapon")
    near(SwingFixture({known = {75}, subclass = 2}).swing.HoldTime(2.4), 0.5, "no tooltip: 0.5 s")
    local french = SwingFixture({known = {75}, subclass = 2, speed = "Vitesse 2,80", speedLabel = "Vitesse"})
    near(french.swing.HoldTime(2.8), 0.5, "the game's own label and a decimal comma")
    near(french.swing.HoldTime(1.4), 0.25, "and scaled")
    near(SwingFixture({known = {75}, subclass = 2, speed = "Speed 3.00"}).swing.HoldTime(0.3), 0.05,
        "short swing: scaled")
end)

test("swing: a melee swing restarts the ranged bar, grey until the next shot", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local row = state.swing.Rows()[2]
    state.fire("PLAYER_SWING", 2.0, 2)
    local gold = row.bar.lastSetStatusBarColor[1]
    state.advance(1.0)
    state.fire("PLAYER_SWING", 3.0, 0)
    local restart = row.bar.lastSetTimerDuration[1]
    equal(restart.start, 1.0, "from the melee swing")
    equal(restart.seconds, 2.0, "with the last ranged length")
    equal(row.bar.lastSetStatusBarColor[1], 0.55, "grey")
    state.advance(1.4)
    equal(row.label.text, "Ranged", "the old hold-still time is cancelled")
    state.advance(0.1)
    equal(row.label.text, "HOLD STILL", "1.5 s after the restart")
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(row.bar.lastSetStatusBarColor[1], gold, "the next shot: the theme's color again")
    local melee = SwingFixture({class = "WARRIOR", known = {}, subclass = nil})
    melee.fire("PLAYER_SWING", 2.0, 0)
    equal(melee.swing.Rows()[2].bar.lastSetTimerDuration, nil, "no ranged swing yet: nothing to restart")
end)

test("swing: no clip zone for a shot not known, instant, or with a secret cast time", function()
    local state = SwingFixture({known = {75, 19434}, subclass = 2, casts = {["Aimed Shot"] = 0}})
    local row = state.swing.Rows()[2]
    state.fire("PLAYER_SWING", 3.0, 2)
    equal(row.clips[1].shown, false, "instant")
    equal(row.clips[2].shown, false, "Sniper Shot not known")
    state.casts["Aimed Shot"] = state.secret()
    state.fire("PLAYER_SWING", 3.0, 2)
    equal(row.clips[1].shown, false, "secret: skipped")
    local level18 = SwingFixture({known = {75}, subclass = 2, casts = {}})
    level18.fire("PLAYER_SWING", 3.0, 2)
    equal(level18.swing.Rows()[2].clips[1].shown, false, "below level 20: no Aimed Shot")
end)

test("swing: no hold-still zone without Auto Shot (a wand's Shoot)", function()
    local state = SwingFixture({class = "MAGE", known = {5019}, subclass = 19})
    local row = state.swing.Rows()[2]
    state.fire("PLAYER_SWING", 1.5, 2)
    equal(row.hold.shown, false)
    state.advance(1.2)
    equal(row.label.text, "Ranged")
end)

test("swing: Show is In combat by default, Always, or Off; unlocked shows it to move, unless Off", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local widget = state.widget
    equal(widget.shown, false, "In combat: hidden out of combat")
    state.enterCombat()
    equal(widget.shown, true, "shown when combat starts")
    state.leaveCombat()
    equal(widget.shown, false)
    state.settings.DYRE_SWING_SHOW:SetValue("always")
    equal(widget.shown, true)
    state.settings.DYRE_SWING_SHOW:SetValue("off")
    equal(widget.shown, false)
    equal(next(state.checks), nil, "Off: no range check either")
    state.toolkit.Unlock()
    equal(widget.shown, false, "Off: never shown, also while unlocked")
    state.settings.DYRE_SWING_SHOW:SetValue("combat")
    equal(widget.shown, true, "unlocked: shown to move")
    equal(state.header(), "RANGE", "a sample state while unlocked")
    state.toolkit.Lock()
    equal(widget.shown, false)
end)

test("swing: while locked, a Ctrl-drag on the top strip moves the frame; a plain drag does not", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    state.settings.DYRE_SWING_SHOW:SetValue("always")
    local widget, handle = state.widget, state.widget.handle
    equal(handle.mouse, true, "the strip takes the mouse while locked")
    equal(widget.mouse, false, "the rest stays click-through while locked")
    handle.scripts.OnDragStart()
    equal(widget.moving, nil, "no Ctrl: no move while locked")
    state.ctrl = true
    handle.scripts.OnDragStart()
    equal(widget.moving, true, "Ctrl-drag moves it")
    handle.scripts.OnDragStop()
    equal(widget.moving, false)
end)

test("swing: the theme sets the bars and the box; the state's color wins on the box", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local rows = state.swing.Rows()
    equal(rows[0].bar.lastSetStatusBarTexture[1], "Interface\\TargetingFrame\\UI-StatusBar")
    state.settings.DYRE_SWING_THEME:SetValue("tactical")
    equal(rows[0].bar.lastSetStatusBarTexture[1], "Interface\\Buttons\\WHITE8X8")
    equal(state.border(), "0.55,0.05,0.05", "no state: the theme's edge")
    state.range(75, true)
    state.settled()
    equal(state.border(), GREEN)
    state.settings.DYRE_SWING_THEME:SetValue("nope")
    equal(state.env.DyresToolkitCharDB.swing.theme, "tactical", "not a theme: unchanged")
end)

test("swing: Classic Era (no PLAYER_SWING) keeps the range box and no bars", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2, missing = {PLAYER_SWING = true}})
    equal(state.swing.barsAvailable, false)
    equal(state.swing.rangeAvailable, true)
    for swingType = 0, 2 do
        equal(state.swing.Rows()[swingType].frame.shown, false, "row " .. swingType)
    end
    state.range(75, true)
    equal(state.settled(), "range")
end)

test("swing: a client with neither API makes no frame and says nothing", function()
    local state = SwingFixture({missing = {PLAYER_SWING = true, SPELL_RANGE_CHECK_UPDATE = true}})
    equal(state.widget, nil)
    equal(state.find("swing"), nil)
end)

test("swing: settings rows, sliders, and the debug and reset commands", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2})
    equal(state.settings.DYRE_SWING_SHOW.default, "combat")
    equal(state.settings.DYRE_SWING_SHOW.name, "Show")
    equal(state.settings.DYRE_SWING_RANGE.default, true)
    equal(state.settings.DYRE_SWING_HOLD.default, true)
    equal(state.settings.DYRE_SWING_THEME.default, "gold")
    equal(state.settings.DYRE_SWING_SHOW.labels.off, "Off (never show)")
    equal(type(state.sliders.DYRE_DYRESTOOLKIT_SWING_WIDTH), "table", "a width slider")
    equal(type(state.sliders.DYRE_DYRESTOOLKIT_SWING_SCALE), "table")
    equal(state.sliders.DYRE_DYRESTOOLKIT_SWING_OPACITY, nil, "opacity is the swing timer's own, in and out of combat")
    equal(type(state.sliders.DYRE_SWING_OPACITY_COMBAT), "table")
    equal(type(state.sliders.DYRE_SWING_OPACITY_IDLE), "table")
    equal(state.settings.DYRE_SWING_IN_USE.default, true)
    state.env.SlashCmdList.DYRESTOOLKIT("debug_swing")
    contains(state.find("swing bars=true"), "class=HUNTER")
    contains(state.find("swing check Auto Shot"), "(ranged)")
    contains(state.find("swing check Wing Clip"), "(melee)")
    state.env.SlashCmdList.DYRESTOOLKIT("swing_reset")
    contains(state.find("default place"), "swing timer")
end)

local function Shown(state)
    return table.concat(state.swing.ShownRows(), ",")
end

test("swing: ranged on top for a Hunter, Mage, Warlock, or Priest; main hand first for the others", function()
    for class, order in pairs({HUNTER = "2,0,1", MAGE = "2,0,1", WARLOCK = "2,0,1", PRIEST = "2,0,1",
            WARRIOR = "0,1,2", ROGUE = "0,1,2", PALADIN = "0,1,2", DRUID = "0,1,2", SHAMAN = "0,1,2"}) do
        local state = SwingFixture({class = class, known = {}, subclass = 2, db = {swing = {inUse = false}}})
        equal(table.concat(state.swing.RowOrder(), ","), order, class)
        state.fire("PLAYER_SWING", 1.5, 1)
        equal(Shown(state), order, class .. ": every row, in order")
    end
end)

test("swing: only bars in use; a Hunter shooting sees the ranged bar, and in melee the main hand joins", function()
    local state = SwingFixture({known = {75, 2974}, subclass = 2})
    local widget = state.widget
    equal(Shown(state), "2", "nothing in use: the ranged bar stays for a Hunter with a bow")
    local small = widget.height
    state.fire("PLAYER_SWING", 2.0, 2)
    equal(Shown(state), "2")
    state.fire("PLAYER_SWING", 3.0, 0)
    equal(Shown(state), "2,0", "a melee swing: the main hand joins, under the ranged bar")
    equal(widget.height > small, true, "the frame grew")
    state.advance(2.0 + state.swing.LINGER)
    equal(Shown(state), "2,0", "the melee swing is still in use")
    state.advance(1.1)
    equal(Shown(state), "2", "the melee swing ended: the main hand hides")
    equal(widget.height, small, "the frame shrank back")
    state.range(2974, true)
    state.settled()
    equal(Shown(state), "2,0", "in melee range: the main hand shows")
    state.range(2974, false)
    state.near = false
    state.range(75, false)
    state.settled()
    state.advance(10)
    equal(Shown(state), "2")
end)

test("swing: only bars in use; a Warrior keeps the main hand, the others join while in use", function()
    local state = SwingFixture({class = "WARRIOR", known = {7918}, subclass = 3})
    equal(Shown(state), "0", "the main hand stays")
    state.fire("PLAYER_SWING", 2.5, 2)
    equal(Shown(state), "0,2", "shooting: the ranged bar joins the main hand")
    state.advance(2.5 + state.swing.LINGER + 0.1)
    equal(Shown(state), "0")
    state.fire("PLAYER_SWING", 2.0, 0)
    state.fire("PLAYER_SWING", 1.8, 1)
    equal(Shown(state), "0,1", "dual wielding: both hands")
    state.toolkit.Unlock()
    equal(Shown(state), "0,1,2", "unlocked: every row, to place it")
end)

test("swing: opacity in combat and out of combat; full while unlocked", function()
    local state = SwingFixture({known = {75}, subclass = 2, db = {swing = {show = "always", combatOpacity = 90,
        idleOpacity = 42}}})
    equal(state.env.DyresToolkitCharDB.swing.idleOpacity, 40, "on steps of 5")
    equal(state.widget.alpha, 0.4, "out of combat")
    state.enterCombat()
    equal(state.widget.alpha, 0.9, "in combat")
    state.leaveCombat()
    state.settings.DYRE_SWING_OPACITY_IDLE:SetValue(70)
    equal(state.widget.alpha, 0.7, "at once")
    state.toolkit.Unlock()
    equal(state.widget.alpha, 1, "unlocked: solid")
    equal(state.core.swing.SanitizeOpacity(500), 100)
    equal(state.core.swing.SanitizeOpacity("x"), 100)
    equal(state.core.swing.SanitizeOpacity(3), 10)
end)

test("swing: a profile applied reads the swing settings again", function()
    local state = SwingFixture({known = {75}, subclass = 2})
    local db = state.env.DyresToolkitCharDB
    db.swing.show = "always"
    state.ns.ApplyProfile()
    equal(state.widget.shown, true)
end)
