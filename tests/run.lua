-- Lua 5.1 mock suite for Dyre's Toolkit. Run from the repository root:
--   lua5.1 tests/run.lua
-- Mocks cannot prove dragging, the settings panel, or the minimap button in
-- the client; TESTING.md lists the in-client checks.

if _VERSION ~= "Lua 5.1" then
    io.stderr:write("This suite requires Lua 5.1; found " .. tostring(_VERSION) .. "\n")
    os.exit(1)
end

local ADDON = "DyresToolkit"
local RUNTIME = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Minimap.lua", "Auras.lua", "Units.lua",
    "HealthBars.lua", "Spells.lua", "Macros.lua", "Announce.lua", "ClassData.lua", "Owners.lua",
    "Control.lua", "DotTracker.lua", "PlateDots.lua", "DotPredict.lua"}
local tests = {}

local function test(name, body)
    tests[#tests + 1] = {name = name, body = body}
end

local function equal(actual, expected, context)
    if actual ~= expected then
        error((context and context .. ": " or "") .. "expected " .. tostring(expected) .. ", got "
            .. tostring(actual), 2)
    end
end

local function contains(text, fragment, context)
    if type(text) ~= "string" or not text:find(fragment, 1, true) then
        error((context and context .. ": " or "") .. "expected " .. tostring(text) .. " to contain " .. fragment, 2)
    end
end

-- A frame with a center, a size, and a scale, as Box and MoveTo read them.
local function newFrame(state, x, y, width, height)
    local frame = {x = x, y = y, width = width or 40, height = height or 40, scale = 1, shown = true,
        events = {}, scripts = {}, moving = false}
    function frame:GetCenter() return self.x, self.y end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetEffectiveScale() return self.scale end
    function frame:SetScale(scale) self.scale = scale end
    function frame:IsShown() return self.shown end
    function frame:SetShown(shown) self.shown = shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:ClearAllPoints() self.anchor = nil end
    function frame:SetPoint(point, relative, relativePoint, px, py)
        self.anchor = {point, relative, relativePoint, px, py}
        if relative == state.UIParent and point == "CENTER" and relativePoint == "BOTTOMLEFT" then
            self.x, self.y = px * self.scale, py * self.scale
        end
    end
    function frame:SetAllPoints() end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:SetFrameStrata() end
    function frame:EnableMouse(enabled) self.mouse = enabled end
    function frame:GetScale() return self.scale end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:GetNumPoints() return self.anchor and 1 or 0 end
    function frame:SetMovable() end
    function frame:SetClampedToScreen() end
    function frame:RegisterForDrag() end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:IsProtected() return self.protected == true end
    function frame:SetBackdrop() end
    function frame:SetBackdropBorderColor() end
    function frame:CreateFontString()
        local text = {}
        function text:SetPoint() end
        function text:SetText(value) self.text = value end
        return text
    end
    function frame:CreateTexture()
        local texture = {}
        function texture:SetColorTexture() end
        function texture:SetWidth() end
        function texture:SetHeight() end
        function texture:SetPoint() end
        function texture:Hide() end
        state.textures = state.textures + 1
        return texture
    end
    state.frames[#state.frames + 1] = frame
    return frame
end

local function fixture(options)
    options = options or {}
    local state = {messages = {}, frames = {}, textures = 0, combat = false, shift = false, opened = nil}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) state.messages[#state.messages + 1] = message end}
    env.InCombatLockdown = function() return state.combat end
    env.IsShiftKeyDown = function() return state.shift end
    env.IsControlKeyDown = function() return state.ctrl end
    state.UIParent = newFrame(state, 960, 540, 1920, 1080)
    env.UIParent = state.UIParent
    env.CreateFrame = function() return newFrame(state, 0, 0) end
    if not options.noSettings then
        local function category(name)
            local object = {name = name, subcategories = {}, initializers = {}}
            function object:GetID() return "id:" .. self.name end
            return object
        end
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number"},
            RegisterVerticalLayoutCategory = function(name)
                state.homes = (state.homes or 0) + 1
                local object = category(name)
                return object, {category = object}
            end,
            RegisterVerticalLayoutSubcategory = function(parent, name)
                local object = category(name)
                parent.subcategories[#parent.subcategories + 1] = object
                return object, {category = object}
            end,
            RegisterAddOnCategory = function(object) state.registered = object end,
            RegisterProxySetting = function(object, variable, kind, name, default, get, set)
                local setting = {variable = variable, name = name, get = get, set = set}
                state.settings = state.settings or {}
                state.settings[variable] = setting
                return setting
            end,
            CreateCheckbox = function(object, setting) object.initializers[#object.initializers + 1] = setting end,
            CreateSlider = function(object, setting) object.initializers[#object.initializers + 1] = setting end,
            CreateSliderOptions = function() return {} end,
            OpenToCategory = function(id) state.opened = id end,
        }
    end
    -- LibDataBroker and LibDBIcon, as the minimap button uses them.
    if not options.noLibraries then
        local broker = {NewDataObject = function(_, name, data) state.launcher = data; return data end}
        local dbicon = {
            Register = function(_, name, data, db) state.icon = {name = name, data = data, db = db} end,
            Show = function() state.iconShown = true end,
            Hide = function() state.iconShown = false end,
        }
        env.LibStub = function(name)
            if name == "LibDataBroker-1.1" then return broker end
            if name == "LibDBIcon-1.0" then return dbicon end
        end
    end
    env.MenuUtil = {CreateContextMenu = function(owner, generator) state.menuOwner = owner; state.menu = generator end}
    -- Most tests drop frames without the grid; a fresh install snaps (tested apart).
    env.DyresToolkitDB = options.saved or (not options.fresh and {snapToGrid = false}) or nil
    local ns = {}
    for _, path in ipairs(RUNTIME) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk(ADDON, ns)
    end
    state.env, state.ns, state.toolkit = env, ns, env.DyresToolkit
    -- The client: the AddOn's SavedVariables, then login.
    local events = state.frames[2]
    for _, frame in ipairs(state.frames) do
        if frame.scripts.OnEvent and frame.events.ADDON_LOADED then events = frame end
    end
    state.events = events
    events.scripts.OnEvent(events, "ADDON_LOADED", ADDON)
    if not options.noLogin then
        events.scripts.OnEvent(events, "PLAYER_LOGIN")
    end
    function state.slash(text) env.SlashCmdList.DYRESTOOLKIT(text) end
    function state.said(fragment)
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then return true end
        end
        return false
    end
    function state.last() return state.messages[#state.messages] end
    return state
end

-- A minimal menu description that records what the generator adds.
local function menuRoot()
    local root = {entries = {}}
    local function add(kind, text, a, b)
        root.entries[#root.entries + 1] = {kind = kind, text = text, a = a, b = b}
    end
    function root:CreateTitle(text) add("title", text) end
    function root:CreateButton(text, callback) add("button", text, callback) end
    function root:CreateCheckbox(text, isSelected, setSelected) add("checkbox", text, isSelected, setSelected) end
    function root:CreateDivider() add("divider") end
    return root
end

-- The interface ---------------------------------------------------------------------

test("the toolkit is the global DyresToolkit behind a contract", function()
    local toolkit = fixture().toolkit
    equal(toolkit.RequireContract(1), toolkit, "contract 1 clients keep working")
    equal(toolkit.RequireContract(2), toolkit, "widgets")
    equal(toolkit.RequireContract(3), nil, "a newer contract than this toolkit offers")
    equal(toolkit.RequireContract("1"), nil)
end)

test("saved settings are repaired on load, and frames always start locked", function()
    local state = fixture({saved = {locked = false, grid = "yes", snapToGrid = 1, gridSize = 1000, minimap = 5}})
    local db = state.env.DyresToolkitDB
    equal(db.locked, true, "never unlocked at login")
    equal(db.grid, true)
    equal(db.snapToGrid, true, "not a boolean: the default, on")
    equal(db.gridSize, 128, "clamped to the largest size")
    equal(type(db.minimap), "table")
    equal(state.ns.SanitizeDB({gridSize = 3}).gridSize, 8)
    equal(state.ns.SanitizeDB({gridSize = 0 / 0}).gridSize, 32, "not a number: the default")
end)

test("a fresh install snaps to the grid; a saved choice stays", function()
    equal(fixture({fresh = true}).ns.db.snapToGrid, true, "on by default")
    equal(fixture({saved = {snapToGrid = false}}).ns.db.snapToGrid, false, "off when the player turned it off")
end)

test("AddOns register by folder and title, sorted by title", function()
    local toolkit = fixture().toolkit
    equal(toolkit.RegisterAddOn({addon = "WarlockToolsForever", title = "Warlock Tools Forever"}), true)
    equal(toolkit.RegisterAddOn({addon = "DyresBuffReminders", title = "Dyre's Buff Reminders"}), true)
    equal(toolkit.RegisterAddOn({addon = "", title = "Nameless"}), false)
    equal(toolkit.RegisterAddOn({addon = "X"}), false)
    equal(toolkit.RegisterAddOn(nil), false)
    toolkit.RegisterAddOn({addon = "WarlockToolsForever", title = "Warlock Tools Forever"})
    toolkit.RegisterAddOn({addon = "DyresQuestTargeting", title = "Dyre's Quest Targeting"})
    local list = toolkit.AddOns()
    equal(#list, 3, "registering again replaces, it does not add")
    equal(list[1].title, "Dyre's Buff Reminders", "sorted by the short name: Buff, Quest, Warlock")
    equal(list[2].title, "Dyre's Quest Targeting")
end)

test("one layout mode: every AddOn locks and unlocks together, with one line in chat", function()
    local state = fixture()
    local toolkit = state.toolkit
    local seen = {}
    toolkit.RegisterAddOn({addon = "A", title = "A", setLocked = function(locked) seen.A = locked end})
    toolkit.RegisterAddOn({addon = "B", title = "B", setLocked = function(locked) seen.B = locked end})
    toolkit.Unlock()
    equal(seen.A, false)
    equal(seen.B, false)
    equal(toolkit.IsLocked(), false)
    contains(state.last(), "Dyre: Frames unlocked")
    local count = #state.messages
    toolkit.RegisterAddOn({addon = "C", title = "C", setLocked = function(locked) seen.C = locked end})
    equal(seen.C, false, "an AddOn that joins while unlocked shows its frames too")
    toolkit.ToggleLock()
    equal(seen.A, true)
    equal(seen.C, true)
    equal(#state.messages, count + 1)
    equal(state.last(), "Dyre: Frames locked.")
    state.combat = true
    toolkit.Unlock()
    contains(state.last(), "after combat")
end)

-- Layout --------------------------------------------------------------------------

test("frames drag only while unlocked and out of combat", function()
    local state = fixture()
    local toolkit = state.toolkit
    local frame = newFrame(state, 500, 500)
    local saved
    equal(toolkit.RegisterMovable(frame, function(position) saved = position end), true)
    equal(toolkit.RegisterMovable(frame, "no"), false)
    toolkit.BeginDrag(frame)
    equal(frame.moving, false, "locked")
    toolkit.Unlock()
    state.combat = true
    toolkit.BeginDrag(frame)
    equal(frame.moving, false, "in combat")
    state.combat = false
    toolkit.BeginDrag(frame)
    equal(frame.moving, true)
    frame.x, frame.y = 700, 300
    toolkit.EndDrag(frame)
    equal(frame.moving, false)
    equal(saved.point, "CENTER")
    equal(saved.x, 700)
    equal(saved.y, 300)
    local stranger = newFrame(state, 0, 0)
    toolkit.BeginDrag(stranger)
    equal(stranger.moving, false, "an unregistered frame does not drag")
end)

-- As in the client: GetCenter and the anchor offsets are in the frame's own
-- scaled units, so the screen center is offset * scale, and a bare SetScale moves it.
local function clientFrame(state, screenX, screenY, width, height)
    local frame = newFrame(state, 0, 0, width, height)
    function frame:GetScale() return self.scale end
    function frame:GetCenter()
        self.centerReads = (self.centerReads or 0) + 1
        return self.cx, self.cy
    end
    function frame:GetPoint() return unpack(self.anchor) end
    function frame:GetNumPoints() return self.anchor and 1 or 0 end
    function frame:SetSize(w, h) self.width, self.height = w, h end
    function frame:SetPoint(point, relative, relativePoint, px, py)
        self.anchor = {point, relative, relativePoint, px, py}
        self.cx, self.cy = px, py
    end
    -- Rounded: scales like 1.5 and 3 leave float noise.
    function frame:ScreenCenter()
        return math.floor(self.cx * self.scale + 0.5), math.floor(self.cy * self.scale + 0.5)
    end
    frame:SetPoint("CENTER", state.UIParent, "BOTTOMLEFT", screenX, screenY)
    return frame
end

test("ResizeFromCenter changes scale and size without moving the center", function()
    local state = fixture()
    local toolkit = state.toolkit
    local bare = clientFrame(state, 500, 300, 100, 20)
    bare:SetScale(2)
    local bx, by = bare:ScreenCenter()
    equal(bx, 1000, "a bare SetScale moves the center (the bug)")
    equal(by, 600)

    local saved, saves = nil, 0
    local frame = clientFrame(state, 500, 300, 100, 20)
    toolkit.RegisterMovable(frame, function(position) saved, saves = position, saves + 1 end)
    toolkit.ResizeFromCenter(frame, 2)
    local x, y = frame:ScreenCenter()
    equal(x, 500, "scale up keeps the center")
    equal(y, 300)
    equal(saved.point, "CENTER")
    equal(saved.x, 250, "saved in the frame's own units")
    toolkit.ResizeFromCenter(frame, 0.5, 200, 40)
    x, y = frame:ScreenCenter()
    equal(x, 500, "scale down and resize keep the center")
    equal(y, 300)
    equal(frame.width, 200)
    equal(frame.height, 40)
    local before = saves
    toolkit.ResizeFromCenter(frame, 0.5, 200, 40)
    equal(saves, before, "nothing changes, nothing is saved")

    local loose = clientFrame(state, 800, 200, 50, 50)
    toolkit.ResizeFromCenter(loose, 1.5, 60, 60)
    x, y = loose:ScreenCenter()
    equal(x, 800, "an unregistered frame is re-anchored too")
    equal(y, 200)

    local unplaced = clientFrame(state, 0, 0, 10, 10)
    unplaced.anchor = nil
    toolkit.ResizeFromCenter(unplaced, 2, 20, 20)
    equal(unplaced.scale, 2, "a frame with no place yet just takes the new scale and size")
    equal(unplaced.width, 20)

    local old = clientFrame(state, 400, 400, 40, 40)
    toolkit.RegisterMovable(old, function() end)
    toolkit.ScaleKeepingCenter(old, 3)
    x, y = old:ScreenCenter()
    equal(x, 400, "ScaleKeepingCenter keeps working")
    equal(y, 400)
end)

test("a dropped frame snaps beside a neighbor, also one from another AddOn", function()
    local state = fixture()
    local toolkit = state.toolkit
    local mine = newFrame(state, 0, 0)
    local theirs = newFrame(state, 500, 500)
    local saved = {}
    toolkit.RegisterMovable(mine, function(position) saved.mine = position end)
    toolkit.RegisterMovable(theirs, function(position) saved.theirs = position end)
    toolkit.Unlock()
    toolkit.BeginDrag(mine)
    -- 40 wide each, 20 apart: a neighbor's spot is 60 right of its center.
    mine.x, mine.y = 562, 505
    toolkit.EndDrag(mine)
    equal(saved.mine.x, 560, "beside, the gap apart")
    equal(saved.mine.y, 500, "lined up by centers")
end)

test("with Snap to the grid on, a frame with no neighbor in reach goes to the nearest grid point", function()
    local state = fixture()
    local toolkit = state.toolkit
    local frame = newFrame(state, 0, 0)
    local saved
    toolkit.RegisterMovable(frame, function(position) saved = position end)
    toolkit.Unlock()
    toolkit.BeginDrag(frame)
    frame.x, frame.y = 1003, 525
    toolkit.EndDrag(frame)
    equal(saved.x, 1003, "off: where it was dropped")
    state.slash("snap")
    contains(state.last(), "snap to the grid")
    -- Lines 32 apart from the center (960, 540); the frame is 40 by 40.
    -- The grey lines take an edge within a quarter of the size (8): the left
    -- edge (1183) is 1 left of 1184; the top edge (727) is 5 below 732.
    toolkit.BeginDrag(frame)
    frame.x, frame.y = 1203, 707
    toolkit.EndDrag(frame)
    equal(saved.x, 1204, "the left edge onto a grey line")
    equal(saved.y, 712, "the top edge onto a grey line")
    -- Farther than 8 from every grey line, the frame stays where it was
    -- dropped: edges 1194 and 1234 are 10 from 1184 and 14 from 1248.
    toolkit.BeginDrag(frame)
    frame.x, frame.y = 1214, 700
    toolkit.EndDrag(frame)
    equal(saved.x, 1214, "no grey line in reach: no move")
    -- Centering on a center line comes first: the center (938) is 22 from
    -- x 960, though the right edge (958) is only 2 from it.
    toolkit.BeginDrag(frame)
    frame.x, frame.y = 938, 523
    toolkit.EndDrag(frame)
    equal(saved.x, 960, "centered on the center line")
    equal(saved.y, 540)
    -- With the center out of reach, an edge in reach goes onto the center
    -- line: the left edge (970) 10 right of x 960; the bottom edge (560) 20
    -- above y 540.
    toolkit.BeginDrag(frame)
    frame.x, frame.y = 990, 580
    toolkit.EndDrag(frame)
    equal(saved.x, 980, "the left edge onto the center line")
    equal(saved.y, 560, "the bottom edge onto the center line")
    state.ns.SetGridSize(64)
    local moveX = state.ns.GridShift({newFrame(state, 1203, 707)})
    equal(moveX, -7, "a new size: lines 64 apart, reach 16; the right edge (1223) onto 1216")
end)

test("a neighbor in reach comes before the grid", function()
    local state = fixture()
    local toolkit = state.toolkit
    local mine = newFrame(state, 0, 0)
    local theirs = newFrame(state, 1300, 800)
    local saved
    toolkit.RegisterMovable(mine, function(position) saved = position end)
    toolkit.RegisterMovable(theirs, function() end)
    toolkit.Unlock()
    state.slash("snap")
    toolkit.BeginDrag(mine)
    mine.x, mine.y = 1363, 803
    toolkit.EndDrag(mine)
    equal(saved.x, 1360, "beside the neighbor, not on a grid line")
    equal(saved.y, 800)
end)

test("Ctrl held at the drop skips snapping, to neighbors and to the grid", function()
    local state = fixture()
    local toolkit = state.toolkit
    local mine = newFrame(state, 0, 0)
    local theirs = newFrame(state, 500, 500)
    local saved
    toolkit.RegisterMovable(mine, function(position) saved = position end)
    toolkit.RegisterMovable(theirs, function() end)
    toolkit.Unlock()
    state.slash("snap")
    toolkit.BeginDrag(mine)
    state.ctrl = true
    mine.x, mine.y = 562, 505
    toolkit.EndDrag(mine)
    equal(saved.x, 562, "a neighbor in reach, but Ctrl: where it was dropped")
    equal(saved.y, 505)
    toolkit.BeginDrag(mine)
    mine.x, mine.y = 1203, 707
    toolkit.EndDrag(mine)
    equal(saved.x, 1203, "a grid line in reach, but Ctrl: where it was dropped")
    state.ctrl = false
    toolkit.BeginDrag(mine)
    mine.x, mine.y = 562, 505
    toolkit.EndDrag(mine)
    equal(saved.x, 560, "without Ctrl it snaps again")
end)

test("a Shift-dragged group snaps to the grid as one box", function()
    local state = fixture()
    local toolkit = state.toolkit
    local lead = newFrame(state, 500, 300)
    local follower = newFrame(state, 560, 300)
    local saved = {}
    toolkit.RegisterMovable(lead, function(position) saved.lead = position end)
    toolkit.RegisterMovable(follower, function(position) saved.follower = position end)
    toolkit.Unlock()
    state.slash("snap")
    state.shift = true
    toolkit.BeginDrag(lead)
    -- The group's box: 1181 to 1261 across, 683 to 723 up. Its left edge
    -- goes onto 1184 (+3). Up and down, the lines are 668, 700, and 732:
    -- the bottom (683) and top (723) edges are 15 and 9 away, out of reach.
    lead.x, lead.y = 1201, 703
    follower.x, follower.y = 1241, 703
    toolkit.EndDrag(lead)
    equal(saved.lead.x, 1204)
    equal(saved.follower.x, 1244, "the group moves as one")
    equal(saved.lead.y, 703, "no edge in reach up or down: no move")
    equal(saved.follower.y, 703)
end)

test("Shift-drag moves the snapped group", function()
    local state = fixture()
    local toolkit = state.toolkit
    local lead = newFrame(state, 500, 500)
    local follower = newFrame(state, 560, 500)
    local saved = {}
    toolkit.RegisterMovable(lead, function(position) saved.lead = position end)
    toolkit.RegisterMovable(follower, function(position) saved.follower = position end)
    toolkit.Unlock()
    state.shift = true
    toolkit.BeginDrag(lead)
    equal(follower.anchor[2], lead, "the follower is anchored to the dragged frame")
    lead.x, lead.y = 100, 100
    follower.x, follower.y = 160, 100
    toolkit.EndDrag(lead)
    equal(saved.lead.x, 100)
    equal(saved.follower.x, 160)
end)

test("a drop in combat waits until combat ends", function()
    local state = fixture()
    local toolkit = state.toolkit
    local frame = newFrame(state, 0, 0)
    local saved
    toolkit.RegisterMovable(frame, function(position) saved = position end)
    toolkit.Unlock()
    toolkit.BeginDrag(frame)
    state.combat = true
    frame.x, frame.y = 300, 300
    toolkit.EndDrag(frame)
    equal(saved, nil)
    state.combat = false
    for _, other in ipairs(state.frames) do
        if other.events.PLAYER_REGEN_ENABLED then other.scripts.OnEvent(other, "PLAYER_REGEN_ENABLED") end
    end
    equal(saved.x, 300)
end)

test("the grid shows only while unlocked and switched on", function()
    local state = fixture()
    local ns = state.ns
    equal(ns.grid, nil, "nothing is built while locked")
    state.toolkit.Unlock()
    equal(ns.grid.shown, true)
    local lines = state.textures
    equal(lines > 0, true)
    state.slash("grid")
    equal(ns.grid.shown, false)
    state.slash("grid")
    ns.SetGridSize(64)
    equal(state.textures > lines, true, "a new size rebuilds the lines")
    state.toolkit.Lock()
    equal(ns.grid.shown, false)
end)

-- Settings --------------------------------------------------------------------------

test("one Dyre's AddOns home, with each AddOn's page under it", function()
    local state = fixture()
    local toolkit = state.toolkit
    local home = toolkit.SettingsCategory()
    equal(home.name, "Dyre's AddOns")
    equal(state.registered, home)
    local page, layout = toolkit.RegisterSettingsCategory("Mage Tools Forever")
    equal(page.name, "Mage Tools Forever", "a name without Dyre's stays")
    equal(toolkit.RegisterSettingsCategory("Dyre's Buff Reminders").name, "Buff Reminders",
        "under Dyre's AddOns, Dyre's is said once")
    equal(layout.category, page)
    equal(home.subcategories[1], page)
    equal(state.homes, 1, "the home is made once")
    equal(toolkit.RegisterSettingsCategory(""), nil)
    equal(state.settings.DYRE_GRID.get(), true)
    state.settings.DYRE_UNLOCKED.set(true)
    equal(toolkit.IsLocked(), false)
    state.settings.DYRE_GRID_SIZE.set(48)
    equal(state.env.DyresToolkitDB.gridSize, 48)
end)

test("an AddOn may ask for its page before the toolkit's own login", function()
    local state = fixture({noLogin = true})
    local page = state.toolkit.RegisterSettingsCategory("Dyre's Shields Up")
    equal(page.name, "Shields Up")
    state.events.scripts.OnEvent(state.events, "PLAYER_LOGIN")
    equal(state.homes, 1)
end)

test("/dyre opens the settings, never in combat; without the settings API it explains", function()
    local state = fixture()
    state.slash("")
    equal(state.opened, "id:Dyre's AddOns")
    state.opened = nil
    state.combat = true
    state.slash("")
    equal(state.opened, nil)
    contains(state.last(), "out of combat")
    local bare = fixture({noSettings = true})
    equal(bare.toolkit.RegisterSettingsCategory("X"), nil)
    bare.slash("")
    contains(bare.last(), "unavailable")
    bare.slash("bogus")
    contains(bare.last(), "Use /dyre")
end)

-- Minimap -----------------------------------------------------------------------------

test("the minimap button: left-click locks or unlocks, right-click opens the menu", function()
    local state = fixture()
    equal(state.icon.name, ADDON)
    equal(state.icon.db, state.env.DyresToolkitDB.minimap, "LibDBIcon keeps its place in the saved settings")
    state.launcher.OnClick("button", "LeftButton")
    equal(state.toolkit.IsLocked(), false)
    local opened = false
    state.toolkit.RegisterAddOn({addon = "MageToolsForever", title = "Mage Tools Forever",
        openSettings = function() opened = true end})
    state.toolkit.RegisterAddOn({addon = "DyresShieldsUp", title = "Dyre's Shields Up", openSettings = function() end})
    state.launcher.OnClick("button", "RightButton")
    equal(state.menuOwner, "button")
    local root = menuRoot()
    state.menu("button", root)
    equal(root.entries[1].text, "Dyre's Toolkit")
    equal(root.entries[2].text, "Lock frames")
    local last = root.entries[#root.entries]
    equal(root.entries[#root.entries - 1].text, "Mage Tools Forever")
    equal(last.text, "Shields Up", "short names in the menu, sorted by them")
    last = root.entries[#root.entries - 1]
    last.a()
    equal(opened, true)
    state.slash("minimap")
    equal(state.iconShown, false)
    equal(state.env.DyresToolkitDB.minimap.hide, true)
    state.slash("minimap")
    equal(state.iconShown, true)
end)

test("without the minimap libraries there is no button, and nothing breaks", function()
    local state = fixture({noLibraries = true})
    equal(state.icon, nil)
    state.slash("minimap")
    state.toolkit.Unlock()
    equal(state.toolkit.IsLocked(), false)
end)

-- Widgets (contract 2) -------------------------------------------------------------

local function endCombat(state)
    state.combat = false
    for _, frame in ipairs(state.frames) do
        if frame.events.PLAYER_REGEN_ENABLED and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
        end
    end
end

local function barSpec(store, extra)
    local spec = {addon = "MageToolsForever", key = "polymorph", title = "Polymorph bar", store = store,
        width = 200, height = 40, point = {"CENTER", "CENTER", 0, -120},
        sizes = {scale = true, width = {min = 120, max = 400, step = 10}, height = {min = 10, max = 40, step = 1},
            opacity = true}}
    for key, value in pairs(extra or {}) do spec[key] = value end
    return spec
end

test("a widget places itself, shows its outline only while unlocked, and takes clicks only then", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store, unlocks = {}, {}
    local widget = toolkit.CreateWidget(barSpec(store, {onUnlock = function(_, unlocked) unlocks[#unlocks + 1] = unlocked end}))
    equal(widget.anchor[1], "CENTER", "the default place")
    equal(widget.anchor[5], -120)
    equal(widget.width, 200)
    equal(widget.height, 40)
    equal(widget.dyre.mover.shown, false, "locked at login")
    equal(widget.mouse, false, "no clicks while locked: the world gets them")
    contains(widget.dyre.mover.hint.text, "Polymorph bar")
    equal(store.scale, 100, "repaired to the defaults")
    equal(store.opacity, 100)
    equal(store.width, 200, "the width default comes from the widget's own size")
    toolkit.Unlock()
    equal(widget.dyre.mover.shown, true)
    equal(widget.mouse, true)
    equal(unlocks[#unlocks], true, "the AddOn shows its samples")
    toolkit.BeginDrag(widget)
    widget.x, widget.y = 700, 300
    toolkit.EndDrag(widget)
    equal(store.position.point, "CENTER", "a drag saves into the AddOn's table")
    equal(store.position.x, 700)
    toolkit.Lock()
    equal(widget.dyre.mover.shown, false)
    equal(widget.mouse, false)
    equal(unlocks[#unlocks], false)
end)

test("a widget's saved place and settings come back, repaired, under the AddOn's own keys", function()
    local state = fixture()
    local store = {barScale = 999, barOpacity = "x", position = {point = "CENTER", relativePoint = "BOTTOMLEFT",
        x = 321, y = 123}}
    local widget = state.toolkit.CreateWidget(barSpec(store, {keys = {scale = "barScale", opacity = "barOpacity"}}))
    equal(store.barScale, 150, "clamped to the range")
    equal(store.barOpacity, 100, "not a number: the default")
    equal(widget.anchor[3], "BOTTOMLEFT", "the saved place")
    equal(widget.anchor[4], 321)
    equal(widget.scale, 1.5)
    equal(widget.alpha, 1)
end)

test("size settings change a widget from its center; opacity applies at once", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store, layouts, alphas = {}, {}, {}
    local frame = clientFrame(state, 500, 300, 200, 40)
    local widget = toolkit.CreateWidget(barSpec(store, {frame = frame,
        point = {"CENTER", "BOTTOMLEFT", 500, 300},
        onLayout = function(_, w, h, s) layouts[#layouts + 1] = {w, h, s} end,
        onOpacity = function(_, alpha) alphas[#alphas + 1] = alpha end}))
    equal(widget, frame, "the AddOn's own frame becomes the widget")
    widget:SetSetting("scale", 150)
    local x, y = frame:ScreenCenter()
    equal(x, 500, "bigger, same center")
    equal(y, 300)
    equal(store.scale, 150)
    widget:SetSetting("width", 333)
    equal(store.width, 330, "rounded to the step")
    equal(frame.width, 330)
    x, y = frame:ScreenCenter()
    equal(x, 500)
    equal(layouts[#layouts][1], 330, "the AddOn lays out its content at the new size")
    widget:SetSetting("opacity", 40)
    equal(frame.alpha, 0.4)
    equal(alphas[#alphas], 0.4)
    widget:ResetSize()
    equal(store.scale, 100)
    equal(store.width, 200)
    equal(store.opacity, 40, "Reset size keeps the opacity")
    x, y = frame:ScreenCenter()
    equal(x, 500, "and the center")
    equal(y, 300)
    widget:SetContentSize(260, 40)
    equal(frame.width, 200, "a width setting wins over the content width")
end)

test("a protected widget changes size and mouse only out of combat; opacity at once", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store = {}
    local widget = toolkit.CreateWidget(barSpec(store))
    widget.protected = true
    state.combat = true
    widget:SetSetting("width", 300)
    equal(store.width, 300, "saved at once")
    equal(widget.width, 200, "not resized in combat")
    widget:SetSetting("opacity", 50)
    equal(widget.alpha, 0.5, "opacity is not protected")
    toolkit.Unlock()
    equal(widget.mouse, false, "the mouse waits too")
    equal(widget.dyre.mover.shown, true, "the outline shows at once")
    endCombat(state)
    equal(widget.width, 300, "applied when combat ends")
    equal(widget.mouse, true)
end)

test("mouse modes: always takes clicks, client leaves the mouse to the AddOn", function()
    local state = fixture()
    local toolkit = state.toolkit
    local always = toolkit.CreateWidget(barSpec({}, {key = "conjure", mouse = "always"}))
    local client = toolkit.CreateWidget(barSpec({}, {key = "holder", mouse = "client"}))
    equal(always.mouse, true, "a bar of buttons takes clicks while locked")
    equal(client.mouse, nil, "the AddOn decides")
    toolkit.Unlock()
    equal(client.mouse, nil)
end)

test("ResetWidgets puts an AddOn's widgets back, and only that AddOn's", function()
    local state = fixture()
    local toolkit = state.toolkit
    local mine = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 10, y = 10}}
    local theirs = {position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 20, y = 20}}
    local a = toolkit.CreateWidget(barSpec(mine))
    local b = toolkit.CreateWidget(barSpec(theirs, {addon = "WarlockToolsForever"}))
    toolkit.ResetWidgets("MageToolsForever")
    equal(mine.position, nil)
    equal(a.anchor[5], -120, "the default place")
    equal(theirs.position.x, 20, "another AddOn's widget stays")
    equal(#toolkit.Widgets("MageToolsForever"), 1)
    equal(b.anchor[4], 20)
end)

test("AddWidgetSettings adds a slider for each size, wired to the widget", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store = {}
    local widget = toolkit.CreateWidget(barSpec(store))
    local page = state.env.Settings.RegisterVerticalLayoutCategory("Mage Tools Forever")
    equal(toolkit.AddWidgetSettings(page, nil, widget, {labels = {scale = "Bar size (%)"}}), true)
    local scale = state.settings.DYRE_MAGETOOLSFOREVER_POLYMORPH_SCALE
    equal(scale.name, "Bar size (%)")
    equal(scale.get(), 100)
    scale.set(120)
    equal(store.scale, 120)
    equal(state.settings.DYRE_MAGETOOLSFOREVER_POLYMORPH_WIDTH.name, "Width")
    equal(state.settings.DYRE_MAGETOOLSFOREVER_POLYMORPH_HEIGHT.name, "Height")
    state.settings.DYRE_MAGETOOLSFOREVER_POLYMORPH_OPACITY.set(30)
    equal(widget.alpha, 0.3)
    equal(#page.initializers, 4)
end)

test("an AddOn's own size settings and measure decide the frame's size", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store = {barWidth = 200}
    local frame = clientFrame(state, 400, 400, 200, 40)
    local widget = toolkit.CreateWidget({addon = "MageToolsForever", key = "polymorph", title = "Polymorph bar",
        store = store, frame = frame, width = 200, height = 40, point = {"CENTER", "BOTTOMLEFT", 400, 400},
        keys = {width = "barWidth"},
        sizes = {scale = true, width = {min = 120, max = 400, step = 10},
            barHeight = {min = 10, max = 40, step = 1, default = 16, label = "Bar height"},
            textScale = {min = 50, max = 200, step = 5, default = 100, label = "Text size", percent = true},
            opacity = true},
        sizeOrder = {"scale", "width", "barHeight", "textScale"},
        measure = function(w)
            return w:GetSetting("width"), math.floor(18 * w:GetSetting("textScale") / 100 + 0.5)
                + w:GetSetting("barHeight") + 6
        end})
    equal(frame.height, 40, "18 + 16 + 6 at the defaults")
    equal(store.barHeight, 16, "a custom setting is saved under its own name")
    widget:SetSetting("textScale", 200)
    equal(frame.height, 58, "36 + 16 + 6")
    local x, y = frame:ScreenCenter()
    equal(x, 400, "from the center")
    equal(y, 400)
    widget:SetSetting("barHeight", 99)
    equal(store.barHeight, 40, "clamped")
    widget:ResetSize()
    equal(store.textScale, 100, "Reset size covers the custom sizes")
    equal(frame.height, 40)
    local page = state.env.Settings.RegisterVerticalLayoutCategory("Mage Tools Forever")
    toolkit.AddWidgetSettings(page, nil, widget)
    local names = {}
    for _, setting in ipairs(page.initializers) do names[#names + 1] = setting.name end
    equal(table.concat(names, ","), "Size,Width,Bar height,Text size,Opacity", "in the AddOn's order, opacity last")
end)

test("resetSizes picks what Reset size restores; a hint and drag handles are the AddOn's", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store = {scale = 120, width = 300, opacity = 50}
    local widget = toolkit.CreateWidget(barSpec(store, {resetSizes = {"width", "height"},
        hint = "Polymorph bar · drag to move · scroll to resize"}))
    widget:ResetSize()
    equal(store.width, 200, "listed: reset")
    equal(store.scale, 120, "not listed: Bar size (%) stays")
    equal(store.opacity, 50)
    equal(widget.dyre.mover.hint.text, "Polymorph bar · drag to move · scroll to resize")
    local button = newFrame(state, 0, 0)
    widget:AddDragHandle(button)
    toolkit.Unlock()
    button.scripts.OnDragStart(button)
    equal(widget.moving, true, "a drag on a button moves the widget")
    widget.x, widget.y = 640, 360
    button.scripts.OnDragStop(button)
    equal(widget.moving, false)
    equal(store.position.x, 640)
end)

test("SetContentSize can keep the left or right edge fixed; settings still resize from the center", function()
    local state = fixture()
    local toolkit = state.toolkit
    local store = {}
    local frame = clientFrame(state, 500, 300, 200, 40)
    local widget = toolkit.CreateWidget({addon = "DyresBuffReminders", key = "mybuffs", title = "My buffs",
        store = store, frame = frame, width = 200, height = 40, point = {"CENTER", "BOTTOMLEFT", 500, 300},
        sizes = {scale = true}})
    local function edges()
        local x = frame:ScreenCenter()
        local half = frame.width * frame.scale / 2
        return math.floor(x - half + 0.5), math.floor(x + half + 0.5)
    end
    local left, right = edges()
    equal(left, 400)
    equal(right, 600)
    widget:SetContentSize(100, 40, "LEFT")
    left, right = edges()
    equal(left, 400, "LEFT: the left edge stays")
    equal(right, 500)
    widget:SetContentSize(300, 40, "RIGHT")
    left, right = edges()
    equal(right, 500, "RIGHT: the right edge stays")
    equal(left, 200)
    widget:SetContentSize(100, 40)
    left, right = edges()
    equal(left, 300, "the default keeps the center (350)")
    equal(right, 400)
    widget:SetSetting("scale", 200)
    local x = frame:ScreenCenter()
    equal(x, 350, "a later setting change is from the center again")
end)

test("SetContentSize can keep the top, the bottom, or a corner fixed", function()
    local state = fixture()
    local toolkit = state.toolkit
    local frame = clientFrame(state, 500, 300, 200, 100)
    local widget = toolkit.CreateWidget({addon = "DyresQuestTargeting", key = "box", title = "Quest Targets",
        store = {}, frame = frame, width = 200, height = 100, point = {"CENTER", "BOTTOMLEFT", 500, 300}})
    local function box()
        local x, y = frame:ScreenCenter()
        local hw, hh = frame.width * frame.scale / 2, frame.height * frame.scale / 2
        return math.floor(x - hw + 0.5), math.floor(x + hw + 0.5), math.floor(y - hh + 0.5), math.floor(y + hh + 0.5)
    end
    local left, right, bottom, top = box()
    equal(top, 350)
    widget:SetContentSize(200, 40, "TOP")
    left, right, bottom, top = box()
    equal(top, 350, "TOP: collapsing keeps the top edge")
    equal(bottom, 310)
    widget:SetContentSize(200, 100, "TOP")
    left, right, bottom, top = box()
    equal(top, 350, "and expanding too")
    equal(bottom, 250)
    widget:SetContentSize(200, 60, "BOTTOM")
    left, right, bottom, top = box()
    equal(bottom, 250, "BOTTOM keeps the bottom edge")
    widget:SetContentSize(100, 40, "TOPLEFT")
    left, right, bottom, top = box()
    equal(left, 400, "TOPLEFT keeps the left edge")
    equal(top, 310, "and the top edge")
end)

test("resizing a placed widget reads its anchor, not GetCenter (no forced layout in our call)", function()
    local state = fixture()
    local frame = clientFrame(state, 500, 300, 200, 100)
    local widget = state.toolkit.CreateWidget({addon = "DyresQuestTargeting", key = "box", title = "Quest Targets",
        store = {}, frame = frame, width = 200, height = 100, point = {"CENTER", "BOTTOMLEFT", 500, 300}})
    frame.centerReads = 0
    widget:SetContentSize(200, 40, "TOP")
    widget:SetContentSize(260, 80)
    widget:SetSetting("scale", 120)
    equal(frame.centerReads, 0, "no GetCenter while the toolkit's own anchor holds")
    local _, y = frame:ScreenCenter()
    equal(y, 330, "the top edge still held (350), then the center")
end)

test("a widget that grows from an edge comes back to the same place after a reload", function()
    local store = {}
    local function load()
        local state = fixture()
        local frame = clientFrame(state, 500, 300, 200, 100)
        local widget = state.toolkit.CreateWidget({addon = "DyresQuestTargeting", key = "box", title = "Quest Targets",
            store = store, frame = frame, width = 200, height = 100, point = {"CENTER", "BOTTOMLEFT", 500, 300}})
        -- The content arrives after login and folds the box toward its top.
        widget:SetContentSize(200, 40, "TOP")
        return state, frame, widget
    end
    local function top(frame)
        local _, y = frame:ScreenCenter()
        return y + frame.height * frame.scale / 2
    end
    local state, frame, widget = load()
    state.ctrl = true
    state.toolkit.BeginDrag(widget)
    -- A drag re-anchors the frame (the client does; here by hand).
    frame.cx, frame.cy, frame.anchor = 700, 500, {"TOPLEFT", state.UIParent, "BOTTOMLEFT", 0, 0}
    state.toolkit.EndDrag(widget)
    equal(top(frame), 520, "dropped with its top at 520")
    state, frame = load()
    equal(top(frame), 520, "after the reload the top is where it was dropped")
    local x = frame:ScreenCenter()
    equal(x, 700)
end)

test("while locked, a Ctrl-drag moves one frame freely; without Ctrl, nothing", function()
    local state = fixture()
    local toolkit = state.toolkit
    local mine = newFrame(state, 0, 0)
    local theirs = newFrame(state, 500, 500)
    local friend = newFrame(state, 560, 500)
    local saved = {}
    toolkit.RegisterMovable(mine, function(position) saved.mine = position end)
    toolkit.RegisterMovable(theirs, function(position) saved.theirs = position end)
    toolkit.RegisterMovable(friend, function(position) saved.friend = position end)
    equal(state.ns.db.locked, true, "locked at login")
    toolkit.BeginDrag(mine)
    equal(mine.moving, false, "locked, no Ctrl: no drag")
    state.ctrl = true
    toolkit.BeginDrag(mine)
    equal(mine.moving, true, "locked, Ctrl: it drags")
    mine.x, mine.y = 562, 505
    state.ctrl = false
    toolkit.EndDrag(mine)
    equal(saved.mine.x, 562, "the drop is free: no neighbor snap, even with Ctrl released")
    equal(saved.mine.y, 505)
    state.ctrl, state.shift = true, true
    toolkit.BeginDrag(theirs)
    theirs.x = 520
    toolkit.EndDrag(theirs)
    equal(saved.friend, nil, "no Shift group while locked: only the one frame moves")
    state.combat = true
    toolkit.BeginDrag(mine)
    equal(mine.moving, false, "never in combat")
    state.combat, state.ctrl, state.shift = false, false, false
    toolkit.Unlock()
    toolkit.BeginDrag(mine)
    mine.x, mine.y = 562, 505
    toolkit.EndDrag(mine)
    equal(saved.mine.x, 580, "unlocked, as before: it snaps beside theirs (now at 520)")
end)

test("AddSettingsLink opens another Dyre's AddOn's page, and is greyed with a hint while it is missing", function()
    local state = fixture()
    local toolkit = state.toolkit
    local made = {}
    state.env.CreateSettingsButtonInitializer = function(name, button, click, tooltip)
        local initializer = {name = name, button = button, click = click, tooltip = tooltip, predicates = {}}
        function initializer:AddModifyPredicate(predicate) self.predicates[#self.predicates + 1] = predicate end
        made[#made + 1] = initializer
        return initializer
    end
    local layout = {rows = {}}
    function layout:AddInitializer(initializer) self.rows[#self.rows + 1] = initializer end
    local link = toolkit.AddSettingsLink(nil, layout, {addon = "DyresShieldsUp", name = "Shield display",
        button = "Open Shield settings", tooltip = "Opens Dyre's Shields Up.",
        missing = "Install Dyre's Shields Up from CurseForge for the shield display."})
    equal(layout.rows[1], link, "added to the page")
    equal(link.button, "Open Shield settings")
    equal(link.tooltip, "Install Dyre's Shields Up from CurseForge for the shield display.", "missing: the hint")
    equal(link.predicates[1](), false, "greyed while missing")
    link.click()
    contains(state.messages[#state.messages], "Install Dyre's Shields Up from CurseForge")
    local opened = 0
    toolkit.RegisterAddOn({addon = "DyresShieldsUp", title = "Dyre's Shields Up",
        openSettings = function() opened = opened + 1 end})
    equal(link.predicates[1](), true, "an AddOn that joins later counts")
    link.click()
    equal(opened, 1, "opens its page")
    state.combat = true
    link.click()
    equal(opened, 1, "never in combat")
    contains(state.messages[#state.messages], "out of combat")
    state.combat = false
    local present = toolkit.AddSettingsLink(nil, layout, {addon = "DyresShieldsUp", name = "Shield display",
        tooltip = "Opens Dyre's Shields Up."})
    equal(present.tooltip, "Opens Dyre's Shields Up.", "present: its own tooltip")
    equal(present.button, "Open settings", "the default button text")
    equal(toolkit.AddSettingsLink(nil, nil, {addon = "X", name = "Y"}), nil, "no layout: nothing")
end)

test("AddDefaultTick is public for an AddOn's own sliders", function()
    local toolkit = fixture().toolkit
    equal(type(toolkit.AddDefaultTick), "function")
    local initializer = {InitFrame = function() end}
    toolkit.AddDefaultTick(initializer, {min = 5, max = 120, default = 60})
    equal(initializer.dyreDefault.default, 60, "the range is kept for the mark")
    toolkit.AddDefaultTick(nil, {min = 0, max = 1, default = 0})
end)

test("the TOC loads the libraries, then the runtime, in order", function()
    local files = {}
    for line in io.lines(ADDON .. ".toc") do
        if line:match("%S") and not line:match("^#") then files[#files + 1] = line end
    end
    equal(table.concat(files, ","), "Libs\\LibStub\\LibStub.lua,Libs\\CallbackHandler-1.0\\CallbackHandler-1.0.lua,"
        .. "Libs\\LibDataBroker-1.1\\LibDataBroker-1.1.lua,Libs\\LibDBIcon-1.0\\LibDBIcon-1.0.lua,"
        .. "Core.lua,Layout.lua,Widgets.lua,Settings.lua,Minimap.lua,Auras.lua,Units.lua,HealthBars.lua,"
        .. "Spells.lua,Macros.lua,Announce.lua,ClassData.lua,Owners.lua,Control.lua,DotTracker.lua,"
        .. "PlateDots.lua,DotPredict.lua")
end)

-- Shared code for trackers (2.4.0) -------------------------------------------------

-- A value the client keeps secret: only issecretvalue may look at it.
local SECRET = setmetatable({}, {__tostring = function() error("a secret was printed") end,
    __eq = function() error("a secret was compared") end})

-- The units the client shows: {[token] = {guid, name, canAttack, dead}}, any
-- field possibly SECRET; and your focus, which Era never has.
local function world(state, units)
    local env = state.env
    state.units = units or {}
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    local function get(unit, field)
        local info = state.units[unit]
        return info and info[field]
    end
    env.UnitExists = function(unit) return state.units[unit] ~= nil end
    env.UnitGUID = function(unit) return get(unit, "guid") end
    env.UnitName = function(unit) return get(unit, "name") end
    env.UnitCanAttack = function(_, unit) return get(unit, "canAttack") end
    env.UnitIsDead = function(unit) return get(unit, "dead") end
    env.UnitIsUnit = function(a, b)
        local x, y = state.units[a], state.units[b]
        if x and x.same ~= nil then return x.same == b end
        return x ~= nil and x == y
    end
    return env
end

local function mob(guid, name, extra)
    local info = {guid = guid, name = name, canAttack = true, dead = false}
    for key, value in pairs(extra or {}) do info[key] = value end
    return info
end

test("unit readers give nil for a secret, and Describe never shows one", function()
    local state = fixture()
    world(state, {target = mob(SECRET, SECRET, {dead = SECRET}), focus = mob("Creature-1", "Grunt")})
    local toolkit = state.toolkit
    equal(toolkit.ReadGUID("target"), nil)
    equal(toolkit.ReadName("target"), nil)
    equal(toolkit.IsDead("target"), false, "a secret dead counts as alive")
    equal(toolkit.ReadGUID("focus"), "Creature-1")
    equal(toolkit.ReadName("focus"), "Grunt")
    equal(toolkit.Describe(SECRET), "secret")
    equal(toolkit.Describe(true), "true")
    equal(toolkit.IsSecret(SECRET), true)
end)

test("the plate memory learns a plate from its GUID, else from your target", function()
    local state = fixture()
    local target = mob("Creature-7", "Grunt")
    world(state, {nameplate3 = mob("Creature-5", "Grunt"), nameplate4 = target, target = target})
    local toolkit = state.toolkit
    state.units.nameplate4 = mob(SECRET, "Grunt", {same = "target"})
    toolkit.LearnPlates()
    equal(toolkit.PlateGUID("nameplate3"), "Creature-5", "a readable GUID")
    equal(toolkit.PlateGUID("nameplate4"), "Creature-7", "secret: the target it is")
    equal(toolkit.KnownPlate("Creature-7"), "nameplate4")
    toolkit.ForgetPlate("nameplate4")
    equal(toolkit.KnownPlate("Creature-7"), nil, "a plate that went is forgotten")
    toolkit.LearnPlate("nameplate9")
    equal(toolkit.PlateGUID("nameplate9"), nil, "no such plate")
end)

test("FindUnit follows the caller's order, with plates and the plate memory", function()
    local state = fixture()
    world(state, {target = mob("Creature-1", "A"), focus = mob("Creature-1", "A"),
        nameplate2 = mob("Creature-2", "B"), nameplate6 = mob(SECRET, "C", {same = "focus"})})
    local toolkit = state.toolkit
    equal(toolkit.FindUnit("Creature-1"), "focus", "default: focus first")
    equal(toolkit.FindUnit("Creature-1", {"plates", "target", "focus"}), "target")
    equal(toolkit.FindUnit("Creature-2"), "nameplate2")
    state.units.focus = mob("Creature-3", "C")
    toolkit.LearnPlate("nameplate6")
    state.units.focus = nil
    equal(toolkit.FindUnit("Creature-3"), "nameplate6", "a secret plate, from the memory")
    equal(toolkit.FindUnit("Creature-3", {"focus", "target", "plates"}), nil, "no memory asked for")
    equal(toolkit.FindUnit(nil), nil)
end)

test("LockCast keeps each caller's rules", function()
    local state = fixture()
    local toolkit = state.toolkit
    -- WTF's DoT tracker: target, focus, mouseover, plates; the first unit with
    -- the name decides; dead is not checked; a secret "can attack" is no.
    local tracker = {units = {"target", "focus", "mouseover", "plates"}, stopAtName = true, allowDead = true}
    world(state, {target = mob("Creature-1", "Grunt", {canAttack = SECRET}), focus = mob("Creature-2", "Grunt")})
    equal(toolkit.LockCast("Grunt", tracker), nil, "the target has the name; a secret attack is no")
    state.units.target = mob("Creature-1", "Grunt", {dead = true})
    equal(toolkit.LockCast("Grunt", tracker), "Creature-1", "dead not checked")
    -- WTF's Control bar: focus, mouseover, target, plates; the memory; a secret
    -- "can attack" is yes; skips to the next unit with the name.
    local control = {units = {"focus", "mouseover", "target", "plates"}, memory = true, secretHostile = true}
    world(state, {focus = mob("Creature-2", "Grunt", {dead = true}), target = mob("Creature-1", "Grunt"),
        nameplate1 = mob(SECRET, "Imp", {canAttack = SECRET, same = "target"})})
    local guid, unit, look = toolkit.LockCast("Grunt", control)
    equal(guid, "Creature-1", "the dead focus is skipped")
    equal(unit, "target")
    contains(table.concat(look, " "), "focus(attack=true dead=true guid=true)")
    state.units.target = mob("Creature-9", "Boss")
    toolkit.LearnPlate("nameplate1")
    state.units.target = nil
    guid, unit = toolkit.LockCast("Imp", control)
    equal(guid, "Creature-9", "a secret plate from the memory, a secret attack is yes")
    equal(unit, "nameplate1")
    -- MTF without a focus: focus, then mouseover if there is one, else target.
    local chain = {units = {"focus", "mouseover", "target"}, stopAt = {mouseover = true}}
    world(state, {mouseover = mob("Creature-4", "Wolf"), target = mob("Creature-1", "Grunt")})
    equal(toolkit.LockCast("Grunt", chain), nil, "a mouseover ends the chain")
    state.units.mouseover = nil
    equal(toolkit.LockCast("Grunt", chain), "Creature-1")
    equal(toolkit.LockCast(SECRET, chain), nil, "a secret name")
    equal(toolkit.LockCast("", chain), nil)
end)

test("focusWorks is one flag for every AddOn, learned once from a readable focus", function()
    local state = fixture()
    local toolkit = state.toolkit
    world(state, {})
    local heard = {}
    equal(toolkit.OnFocusWorks(function(works) heard[#heard + 1] = works end), true)
    equal(toolkit.OnFocusWorks("no"), false)
    equal(toolkit.FocusWorks(), false, "nil at first")
    local frame
    for _, candidate in ipairs(state.frames) do
        if candidate.events.PLAYER_FOCUS_CHANGED then frame = candidate end
    end
    frame.scripts.OnEvent(frame, "PLAYER_FOCUS_CHANGED")
    equal(toolkit.FocusWorks(), false, "Era: /focus leaves no focus")
    state.env.UnitExists = function() return SECRET end
    frame.scripts.OnEvent(frame, "PLAYER_FOCUS_CHANGED")
    equal(toolkit.FocusWorks(), false, "a secret answer teaches nothing")
    state.units.focus = mob("Creature-1", "Grunt")
    world(state, state.units)
    frame.scripts.OnEvent(frame, "PLAYER_FOCUS_CHANGED")
    equal(toolkit.FocusWorks(), true)
    equal(state.env.DyresToolkitDB.focusWorks, true, "saved account-wide in the toolkit's table")
    state.units.focus = nil
    frame.scripts.OnEvent(frame, "PLAYER_FOCUS_CHANGED")
    equal(toolkit.FocusWorks(), true, "never goes back on its own")
    equal(#heard, 1)
    toolkit.ResetFocusWorks()
    equal(toolkit.FocusWorks(), false)
    equal(heard[2], false, "listeners hear the reset")
    toolkit.NoteFocusWorks()
    equal(toolkit.FocusWorks(), true, "an AddOn's older flag carries over")
    equal(#heard, 3)
    toolkit.ResetFocusWorks()
    toolkit.ResetFocusWorks()
    equal(#heard, 5, "every reset is told, also a second one (WTF rebuilds its macros on each)")
    equal(heard[5], false)
    contains(toolkit.FOCUS_RESET_TEXT, "every Dyre's AddOn")
    toolkit.NoteFocusWorks()
    local saved = fixture({saved = {snapToGrid = false, focusWorks = true}})
    equal(saved.toolkit.FocusWorks(), true, "kept across reloads; Core's repair keeps the key")
    equal(fixture({saved = {focusWorks = "yes"}}).toolkit.FocusWorks(), false, "only true counts")
end)

-- A client object: every method a no-op that records its arguments, with
-- the few readers the code needs.
local function stub(fields)
    local object = {calls = {}}
    for key, value in pairs(fields or {}) do object[key] = value end
    -- Methods only (capitalized, as the client's): a field the code sets stays nil until set.
    return setmetatable(object, {__index = function(self, key)
        if not key:match("^%u") then return nil end
        return function(_, ...)
            rawget(self, "calls")[key] = {...}
        end
    end})
end

local function auraWorld(state)
    local env = world(state, {target = mob("Creature-1", "Grunt")})
    state.now, state.auras = 100, {}
    env.GetTime = function() return state.now end
    env.C_XMLUtil = nil
    env.C_UnitAuras = {GetAuraDataByIndex = function(unit, index, filter)
        local list = state.auras[unit .. ":" .. filter]
        return list and list[index]
    end}
    env.CreateFrame = function(kind, name, parent)
        local frame = newFrame(state, 0, 0)
        frame.kind, frame.parent = kind, parent
        return frame
    end
    return env
end

local function region()
    return stub({SetTexture = function(self, value, wrap) self.texture, self.wrap = value, wrap end,
        SetText = function(self, value) self.text = value end,
        SetValue = function(self, value) self.value = value end,
        SetMinMaxValues = function(self, low, high) self.max = high end})
end

test("on Era the aura container is plain Lua, with the engine's slots", function()
    local state = fixture()
    auraWorld(state)
    local toolkit = state.toolkit
    equal(toolkit.AuraEngineKind(), "lua")
    contains(toolkit.AURA_ENGINE_MISSING, "CustomAuraContainerTemplate")
    local container = toolkit.CreateAuraContainer(state.UIParent)
    local display = {}
    container:AddAuraSlot("dot", "HARMFUL|PLAYER", {candidateFilters = {includeSpellIDs = {[172] = true}},
        initializeFrame = function(button)
            display.icon, display.text, display.bar = region(), region(), region()
            button:SetIcon(display.icon)
            button:SetDurationText(display.text)
            button:SetDurationBar(display.bar)
            display.button = button
        end})
    equal(display.button.shown, false, "hidden until an aura matches")
    state.auras["target:HARMFUL|PLAYER"] = {{spellId = 999, name = "Other"},
        {spellId = 172, name = "Corruption", icon = "corruption", duration = 12, expirationTime = 106}}
    container:SetUnit("target")
    equal(display.button.shown, true)
    equal(display.icon.texture, "corruption")
    equal(display.text.text, "6 s")
    equal(display.bar.value, 6)
    -- One ticker for every timed slot, only while one shows.
    local ticker
    for _, frame in ipairs(state.frames) do
        if frame.scripts.OnUpdate then ticker = frame end
    end
    equal(ticker ~= nil, true, "a timed aura ticks")
    state.now = 104.2
    ticker.scripts.OnUpdate(ticker, 1)
    equal(display.text.text, "2 s")
    state.auras["target:HARMFUL|PLAYER"] = {}
    local dispatcher
    for _, frame in ipairs(state.frames) do
        if frame.events.UNIT_AURA then dispatcher = frame end
    end
    dispatcher.scripts.OnEvent(dispatcher, "UNIT_AURA", "target")
    equal(display.button.shown, false, "the aura went")
    equal(ticker.scripts.OnUpdate, nil, "no slot ticking: no OnUpdate")
    local ok = pcall(container.SetAuraSlotCandidateFilters, container, "missing", {})
    equal(ok, false, "an unknown slot raises, as the engine does")
end)

test("on Forever the aura container is the engine's", function()
    local state = fixture()
    local env = auraWorld(state)
    env.C_XMLUtil = {GetTemplateInfo = function(name) return name == "CustomAuraContainerTemplate" and {} or nil end}
    local made
    env.CreateFrame = function(kind, name, parent, template)
        made = {kind = kind, template = template}
        return newFrame(state, 0, 0)
    end
    equal(state.toolkit.AuraEngineKind(), "engine")
    state.toolkit.CreateAuraContainer(state.UIParent)
    equal(made.kind, "AuraContainer")
    equal(made.template, "CustomAuraContainerTemplate")
end)

-- A health bar of some frame AddOn, with its texts.
local function healthBar(options)
    options = options or {}
    local fill = stub({GetAtlas = function() return options.atlas end, GetTexture = function() return "bar.tga" end})
    local bar = stub({regions = {}, parentFrame = options.parent})
    function bar:GetStatusBarTexture() return fill end
    function bar:GetReverseFill() return options.reverse == true end
    function bar:GetFrameLevel() return 5 end
    function bar:GetStatusBarColor() return 0, 1, 0 end
    function bar:GetOrientation() return options.vertical and "VERTICAL" or "HORIZONTAL" end
    function bar:GetRegions() return unpack(self.regions) end
    function bar:GetParent() return self.parentFrame end
    function bar:IsForbidden() return false end
    bar.fill = fill
    return bar
end

-- A shown text anchored with point to relativePoint of `to`.
local function sideText(to, point, relativePoint, shown)
    local text = stub()
    function text:GetObjectType() return "FontString" end
    function text:IsShown() return shown ~= false end
    function text:GetNumPoints() return 1 end
    function text:GetPoint() return point, to, relativePoint, 0, 0 end
    return text
end

local function barWorld(state)
    local env = world(state, {})
    state.made = {}
    env.CreateFrame = function(kind, _, parent)
        local frame = stub({kind = kind, shown = true, parentFrame = parent, hooks = {}})
        function frame:HookScript(script, callback) self.hooks[script] = callback end
        function frame:Show()
            self.shown = true
            if self.hooks.OnShow then self.hooks.OnShow(self) end
        end
        function frame:Hide()
            self.shown = false
            if self.hooks.OnHide then self.hooks.OnHide(self) end
        end
        function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
        function frame:GetStatusBarTexture() return self.span end
        function frame:GetEffectiveScale() return 0.5 end
        function frame:SetValue(value) self.value = value end
        function frame:SetMinMaxValues(low, high) self.max = high end
        function frame:SetPoint(...) self.point = {...} end
        function frame:CreateTexture() return region() end
        function frame:CreateFontString()
            return stub({GetStringWidth = function() return 30 end})
        end
        frame.span = region()
        state.made[#state.made + 1] = frame
        return frame
    end
    env.UIParent = stub({GetEffectiveScale = function() return 1 end})
    return env
end

local STYLE = {fill = "stripes", color = {0.6, 0.2, 0.9}, opacity = 70, outline = "solid", dies = true}

test("the block shows the damage to come, and DIES when it kills", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    equal(toolkit.DrawPrediction(bar, "target", 300, 1000, STYLE), false, "not lethal")
    local overlay = state.made[1]
    equal(overlay.kind, "StatusBar")
    equal(overlay.max, 1000)
    equal(overlay.value, 300)
    equal(overlay.shown, true)
    local dies, side = toolkit.DrawPrediction(bar, "target", 1200, 1000, STYLE)
    equal(dies, true)
    equal(side, "left", "unit frames: left of the bar")
    equal(overlay.value, 1000, "never past the health")
    equal(state.made[2].point[1], "RIGHT")
    equal(state.made[2].point[3], "LEFT")
    equal(state.made[2].shown, true)
    equal(toolkit.DrawPrediction(bar, "target", 1200, 1000, {dies = false}), false, "DIES off")
    for _, health in ipairs({0, nil}) do
        toolkit.DrawPrediction(bar, "target", 300, health, STYLE)
        equal(overlay.shown, false, "no health: hidden")
        overlay.shown = true
    end
    toolkit.DrawPrediction(bar, "target", 0, 1000, STYLE)
    equal(overlay.shown, false, "no damage")
    equal(toolkit.DrawPrediction(healthBar({vertical = true}), "plate", 300, 1000, STYLE), false, "vertical")
    equal(toolkit.DrawPrediction(bar, "wrong", 300, 1000, STYLE), false)
    toolkit.DrawPrediction(bar, "target", 300, 1000, STYLE)
    toolkit.HidePrediction(bar)
    equal(overlay.shown, false)
end)

test("a secret health still draws: the bars compare it, and DIES goes through the gate", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    local dies = toolkit.DrawPrediction(bar, "target", 300, SECRET, STYLE)
    equal(dies, nil, "unknown to Lua")
    local overlay = state.made[1]
    equal(rawequal(overlay.max, SECRET), true, "the secret health is the block's scale")
    equal(overlay.value, 300, "the bar clamps it, Lua does not")
    equal(overlay.shown, true)
    equal(overlay.dies.shown, false, "the plain badge stays hidden")
    local gate = overlay.gate
    equal(gate.calls.SetClipsChildren[1], true, "a clip window")
    equal(gate.calls.SetSize[1], overlay.dies.width, "the badge's size")
    equal(gate.shown, true)
    equal(rawequal(gate.meter.max, SECRET), true)
    equal(gate.meter.value, 300)
    equal(gate.meter.calls.SetSize[1], 10000, "1% short of lethal is 100 px out of view")
    equal(gate.meter.point[1], "RIGHT")
    equal(gate.meter.point[2], gate, "its right edge on the window's")
    equal(gate.badge.point[1], "RIGHT")
    equal(gate.badge.point[2], gate.meter.span, "the badge rides the fill's end")
    equal(gate.point[1], "RIGHT", "the window where the badge goes: left of a unit frame's bar")
    equal(gate.point[3], "LEFT")
    toolkit.DrawPrediction(bar, "target", 300, SECRET, {dies = false})
    equal(gate.shown, false, "DIES off")
    toolkit.DrawPrediction(bar, "target", 1200, 1000, STYLE)
    equal(gate.shown, false, "a readable health uses the plain badge")
    equal(overlay.dies.shown, true)
    toolkit.MoveDies(bar, nil)
    equal(gate.point[1], "RIGHT", "a row's place moves the gate too")
    equal(gate.point[2], bar)
end)

test("under a frame that clips (EllesmereUI's unit frames), DIES goes on a holder above it", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local unitFrame = stub({GetFrameLevel = function() return 10 end})
    local clip = stub({GetParent = function() return unitFrame end, DoesClipChildren = function() return true end})
    local bar = healthBar({parent = clip})
    toolkit.DrawPrediction(bar, "target", 1200, 1000, STYLE)
    local overlay = state.made[1]
    local holder = overlay.holder
    assert(holder, "a holder")
    equal(holder.parentFrame, unitFrame, "on the clipping frame's parent")
    equal(overlay.dies.parentFrame, holder)
    equal(holder.shown, true, "shows with the block")
    equal(overlay.dies.shown, true)
    equal(overlay.dies.calls.SetFrameLevel[1], 35, "above the unit frame's texts and portrait")
    equal(overlay.dies.point[2], bar, "still placed from the bar")
    toolkit.DrawPrediction(bar, "target", 300, SECRET, STYLE)
    equal(overlay.gate.parentFrame, holder, "the gate too")
    toolkit.HidePrediction(bar)
    equal(holder.shown, false, "hides with the block")
    -- No clipping frame: the badge stays on the block.
    local plain = healthBar()
    toolkit.DrawPrediction(plain, "target", 1200, 1000, STYLE)
    local other
    for _, frame in ipairs(state.made) do
        if frame.kind == "StatusBar" and frame ~= overlay and frame.dies then other = frame end
    end
    assert(other, "the plain bar's block")
    equal(other.holder, nil)
    equal(other.dies.parentFrame, other)
end)

test("the player's DIES place and offsets move the badge and the gate; bad offsets are 0", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    local style = {dies = true, side = "center", x = 5, y = -3}
    local dies, side = toolkit.DrawPrediction(bar, "target", 1200, 1000, style)
    equal(dies, true)
    equal(side, "center")
    local badge = state.made[1].dies
    equal(badge.point[1], "CENTER")
    equal(badge.point[2], bar)
    equal(badge.point[3], "CENTER")
    equal(badge.point[4], 5)
    equal(badge.point[5], -3)
    toolkit.DrawPrediction(bar, "target", 1200, 1000, {dies = true, side = "above", x = 999, y = "up"})
    equal(badge.point[1], "BOTTOM")
    equal(badge.point[3], "TOP")
    equal(badge.point[4], 200, "at most 200 px")
    equal(badge.point[5], 2, "not a number: no offset")
    toolkit.DrawPrediction(bar, "target", 1200, 1000, {dies = true, side = "nowhere", x = -4})
    equal(badge.point[1], "RIGHT", "an unknown place is the toolkit's choice: left of a unit frame's bar")
    equal(badge.point[4], -7, "the offset still applies")
    local plate = healthBar()
    toolkit.DrawPrediction(plate, "plate", 300, SECRET, {dies = true, side = "below", y = -6})
    local gate
    for _, frame in ipairs(state.made) do
        if frame.meter then gate = frame end
    end
    equal(gate.point[1], "TOP")
    equal(gate.point[3], "BOTTOM")
    equal(gate.point[5], -8, "the gate goes where the badge would")
end)

test("a reverse-filled bar gets the mirror block", function()
    local state = fixture()
    barWorld(state)
    local bar = healthBar({reverse = true})
    state.toolkit.DrawPrediction(bar, "target", 300, 1000, STYLE)
    equal(state.made[1].calls.SetReverseFill[1], false)
    local plain = healthBar()
    state.toolkit.DrawPrediction(plain, "target", 300, 1000, STYLE)
    equal(state.made[3].calls.SetReverseFill[1], true, "fills from the right, from the health's end")
end)

test("DIES draws past a restricted text (Threat Plates' target-of-target on Forever)", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar({})
    -- In client: "Can't measure restricted regions" from FontString:GetPoint().
    local reads = 0
    local flagged = sideText(bar, "LEFT", "RIGHT")
    function flagged:IsAnchoringRestricted() return true end
    function flagged:GetPoint()
        reads = reads + 1
        error("Action[FrameMeasurement] failed because[Can't measure restricted regions]")
    end
    bar.regions = {flagged}
    local _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "right", "a restricted text leaves its side free")
    equal(reads, 0, "a region that says it is restricted is not read")
    function flagged:IsAnchoringRestricted() return SECRET end
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "right", "a secret answer counts as restricted")
    equal(reads, 0, "and it is not read")
    function flagged:IsAnchoringRestricted() return false end
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "right", "an error from GetPoint stops nothing")
    equal(reads > 0, true, "that text was read")
    local free = sideText(bar, "LEFT", "RIGHT")
    function free:IsAnchoringRestricted() return false end
    bar.regions = {flagged, free}
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "left", "the next text is still read")
end)

test("DIES avoids a side another AddOn writes on (Plater's target-of-target)", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local plate = stub({regions = {}})
    function plate:GetRegions() return unpack(self.regions) end
    local bar = healthBar({parent = plate})
    local _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "right", "nameplates: right of the bar")
    -- John's screenshot: "[Juk'taz]" just right of the bar made "DIESJuk'taz ]".
    plate.regions = {sideText(bar, "LEFT", "RIGHT")}
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "left", "moves to the free side")
    bar.regions = {sideText(bar, "RIGHT", "LEFT")}
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "inside", "both taken: inside the bar's right end")
    bar.regions = {sideText(bar, "RIGHT", "LEFT", false), sideText(bar, "LEFT", "LEFT")}
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "left", "a hidden text, or one inside the bar, does not count")
    plate.regions = {sideText(SECRET, "LEFT", "RIGHT")}
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, STYLE)
    equal(side, "right", "a secret anchor is never compared")
    local forced = {}
    for key, value in pairs(STYLE) do forced[key] = value end
    forced.side = "inside"
    _, side = toolkit.DrawPrediction(bar, "plate", 900, 500, forced)
    equal(side, "inside", "the caller's side wins")
    -- An adapter's own place (Platynator, past its arrows) when its side is free.
    local other = healthBar()
    toolkit.DrawPrediction(other, "plate", 900, 500, STYLE, {place = {"LEFT", "RIGHT", 22, 0}, strata = "LOW"})
    local badge = state.made[#state.made]
    equal(badge.point[4], 22)
    equal(badge.calls.SetFrameStrata[1], "LOW")
end)

test("a tracker row moves DIES where it wants it", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    equal(toolkit.MoveDies(bar, nil), false, "no block yet")
    local _, side = toolkit.DrawPrediction(bar, "row", 900, 500, STYLE)
    equal(side, "inside")
    local number = stub()
    toolkit.MoveDies(bar, {"RIGHT", number, "LEFT", -2})
    local badge = state.made[2]
    equal(badge.point[2], number)
    toolkit.DrawPrediction(bar, "row", 900, 500, STYLE)
    equal(badge.point[2], number, "a draw keeps the row's place")
    toolkit.MoveDies(bar, nil)
    equal(badge.point[2], bar, "back to the bar's right end")
end)

-- A shown, or hidden, object with IsShown.
local function showing(shown, fields)
    local object = stub(fields)
    function object:IsShown() return shown end
    return object
end

-- A plate with Threat Plates' frame and widgets, as its Era source has them.
local function threatPlate(widgets)
    local bar = healthBar()
    local plate = stub({TPFrame = {Active = true, visual = {Healthbar = bar}, widgets = widgets or {}}})
    function plate:IsForbidden() return false end
    return plate, bar
end

test("DIES on Threat Plates leaves the side of its target-of-target, crowd control, and threat texts", function()
    local state = fixture()
    local env = barWorld(state)
    local toolkit = state.toolkit
    local widgets = {}
    local plate, bar = threatPlate(widgets)
    env.C_NamePlate = {GetNamePlateForUnit = function() return plate end}
    local function side()
        local found, info = toolkit.FindPlateBar("nameplate1")
        equal(found, bar)
        equal(info.name, "Threat Plates", "the debug name stays")
        return select(2, toolkit.DrawPrediction(found, "plate", 900, 500, STYLE, info))
    end
    equal(side(), "right", "nothing beside the bar: right, as before")
    -- John's screenshot: "[ Juk'taz ]", the target-of-target text.
    bar.TargetUnit = showing(true)
    equal(side(), "left")
    bar.TargetUnit = showing(false)
    widgets.Auras = {CrowdControl = showing(true, {ActiveAuras = 1})}
    equal(side(), "left", "crowd control icons right of the bar")
    widgets.Auras.CrowdControl.ActiveAuras = SECRET
    equal(side(), "right", "a secret count is not read")
    widgets.Threat = showing(true)
    equal(side(), "inside", "in a group its threat art and percent take both sides")
end)

test("DIES on Plater leaves the side of its cast target name and its raid marker", function()
    local state = fixture()
    local env = barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    local raid = showing(false)
    local plate = stub({unitFrame = {healthBar = bar, PlaterRaidTargetFrame = {RaidTargetIcon = raid}}})
    function plate:IsForbidden() return false end
    env.C_NamePlate = {GetNamePlateForUnit = function() return plate end}
    local profile = {castbar_target_show = false, castbar_target_anchor = {side = 6},
        indicator_raidmark_anchor = {side = 2}}
    env.Plater = {db = {profile = profile}}
    local function side()
        local found, info = toolkit.FindPlateBar("nameplate1")
        equal(info.name, "Plater")
        return select(2, toolkit.DrawPrediction(found, "plate", 900, 500, STYLE, info))
    end
    equal(side(), "right")
    profile.castbar_target_show = true
    equal(side(), "left", "John's profile: the cast's target right of the cast bar (side 6)")
    profile.castbar_target_anchor = {side = 11}
    equal(side(), "right", "inside the cast bar: not in the way")
    profile.castbar_target_anchor = {side = 6}
    raid.IsShown = function() return true end
    equal(side(), "inside", "and a raid marker left of the bar")
    env.Plater = {}
    equal(side(), "right", "no profile: only the marker, on its default side, left")
end)

test("UseBar hides the block on the bar a unit left", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local shown = {}
    local first, second = healthBar(), healthBar()
    toolkit.UseBar(shown, "nameplate1", first, {name = "Threat Plates"})
    toolkit.DrawPrediction(first, "plate", 300, 1000, STYLE)
    local overlay = state.made[1]
    equal(overlay.shown, true)
    toolkit.UseBar(shown, "nameplate1", first, {name = "Threat Plates"})
    equal(overlay.shown, true, "the same bar: kept")
    toolkit.UseBar(shown, "nameplate1", second, {name = "Blizzard"})
    equal(overlay.shown, false, "Threat Plates let the plate go")
    equal(shown.nameplate1.name, "Blizzard")
    toolkit.UseBar(shown, "nameplate1", nil)
    equal(shown.nameplate1, nil, "the plate went")
end)

test("PrepareBar makes the block out of combat, hidden until a draw", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    equal(toolkit.PrepareBar(bar, "target"), true)
    equal(#state.made, 2, "the block and its badge")
    equal(state.made[1].shown, false)
    toolkit.DrawPrediction(bar, "target", 300, 1000, STYLE)
    equal(#state.made, 2, "a draw uses it")
    equal(toolkit.PrepareBar(nil, "target"), false)
    equal(toolkit.PrepareBar(bar, "other"), false)
end)

local function near(actual, expected, context)
    if math.abs(actual - expected) > 0.001 then
        error((context or "value") .. ": expected " .. expected .. ", got " .. tostring(actual), 2)
    end
end

-- WTF 1.4.0's block style and DIES tests, as the spec.
test("block style: stripes tiled, the caller's color and opacity, a 1 px outline a little lighter", function()
    local state = fixture()
    barWorld(state)
    local bar = healthBar()
    state.toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "stripes", color = {0.64, 0.21, 0.93},
        opacity = 70, outline = "solid"})
    local overlay = state.made[1]
    local block = overlay.block
    equal(block.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\Stripes", "the toolkit's stripes")
    equal(block.wrap, "REPEAT", "tiled")
    equal(block.calls.SetHorizTile[1], true)
    equal(block.calls.SetVertTile[1], true)
    near(block.calls.SetVertexColor[1], 0.64, "purple")
    near(block.calls.SetVertexColor[4], 0.7, "70%")
    equal(#overlay.edges, 4)
    for _, edge in ipairs(overlay.edges) do
        equal(edge.calls.SetShown[1], true, "the outline")
        near(edge.calls.SetColorTexture[4], 1, "70% + 30%, at most 1")
        near(edge.calls.SetColorTexture[1], 0.64 + 0.36 * 0.4, "40% lighter")
    end
    equal(overlay.edges[1].calls.SetHeight[1], 1, "1 px")
    equal(overlay.calls.SetStatusBarColor[4], 0, "the measuring fill is clear")
end)

test("block style: solid, the bar's own texture or atlas, no outline, lighter on a bar of its color", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    local bar = healthBar()
    toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "solid", color = {0.2, 0.9, 0.2}, opacity = 40,
        outline = "none"})
    local overlay = state.made[1]
    equal(overlay.block.texture, "Interface\\Buttons\\WHITE8X8")
    equal(overlay.block.calls.SetHorizTile[1], false)
    near(overlay.block.calls.SetVertexColor[4], 0.4)
    equal(overlay.edges[1].calls.SetShown[1], false, "no outline")
    toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "bar", color = {0.2, 0.9, 0.2}})
    equal(overlay.block.texture, "bar.tga", "the bar's own file")
    local atlas = healthBar({atlas = "UI-HUD-CoolDownManager-Bar"})
    toolkit.DrawPrediction(atlas, "plate", 300, 1000, {fill = "bar"})
    equal(state.made[3].block.calls.SetAtlas[1], "UI-HUD-CoolDownManager-Bar", "Era's plate atlas")
    -- healthBar's own color is green (0, 1, 0): 0.12 from 0.04, 0.96, 0.04.
    toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "solid", color = {0.04, 0.96, 0.04}})
    near(overlay.block.calls.SetVertexColor[1], 0.52, "50% lighter on a bar of the same color")
    toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "solid", color = {0.64, 0.21, 0.93}})
    near(overlay.block.calls.SetVertexColor[1], 0.64, "another color keeps it")
    toolkit.DrawPrediction(bar, "plate", 300, 1000, {fill = "glitter", color = "purple", opacity = "x"})
    equal(overlay.block.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\Stripes", "a bad style: the defaults")
end)

test("DIES: a red level skull and bold red text, above the bar's texts, at UI scale, sized per kind", function()
    local state = fixture()
    barWorld(state)
    local toolkit = state.toolkit
    for _, case in ipairs({{"target", 14, 1}, {"plate", 11, 1}, {"row", 10, 0}}) do
        local bar = healthBar()
        local before = #state.made
        toolkit.DrawPrediction(bar, case[1], 900, 500, STYLE)
        local overlay, dies = state.made[before + 1], state.made[before + 2]
        equal(overlay.calls.SetFrameLevel[1], 5 + case[3], case[1] .. ": the block's level")
        equal(dies.calls.SetFrameLevel[1], 5 + 12, case[1] .. ": the badge above the bar's texts")
        near(dies.calls.SetScale[1], 2, case[1] .. ": UIParent 1 over the bar's 0.5")
        equal(dies.skull.texture, "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", "the level skull, not a raid icon")
        near(dies.skull.calls.SetVertexColor[1], 1, "tinted red")
        local font = dies.label.calls.SetFont
        equal(font[2], case[2], case[1] .. ": size")
        equal(font[3], "THICKOUTLINE")
        equal(dies.label.calls.SetText[1], "DIES")
    end
end)

test("the frame adapters find each AddOn's bar, Blizzard's last", function()
    local state = fixture()
    local env = barWorld(state)
    local toolkit = state.toolkit
    local blizzard = healthBar()
    local plate = stub({UnitFrame = {healthBar = blizzard}})
    function plate:IsForbidden() return false end
    env.C_NamePlate = {GetNamePlateForUnit = function() return plate end}
    local bar, info = toolkit.FindPlateBar("nameplate1")
    equal(bar, blizzard)
    equal(info.name, "Blizzard")
    plate.unitFrame = {healthBar = healthBar()}
    equal(select(2, toolkit.FindPlateBar("nameplate1")).name, "Blizzard", "Plater's frame without Plater")
    env.Plater = {}
    equal(select(2, toolkit.FindPlateBar("nameplate1")).name, "Plater")
    plate.TPFrame = {Active = true, visual = {Healthbar = healthBar()}}
    equal(select(2, toolkit.FindPlateBar("nameplate1")).name, "Threat Plates")
    function plate:IsForbidden() return true end
    equal(toolkit.FindPlateBar("nameplate1"), nil, "a forbidden plate")
    -- Unit frames: SUF, then BetterBlizzFrames' smooth bar, then Blizzard's.
    local stock = healthBar()
    env.TargetFrame = {healthbar = stock}
    equal(select(2, toolkit.FindUnitBar("target")).name, "Blizzard")
    stock.bbfSmoothOverlay = healthBar()
    local smooth, smoothInfo = toolkit.FindUnitBar("target")
    equal(smooth, stock.bbfSmoothOverlay, "the eased bar you see")
    equal(smoothInfo.name, "BetterBlizzFrames")
    env.ShadowUF = {Units = {unitFrames = {target = {healthBar = healthBar()}}}}
    equal(select(2, toolkit.FindUnitBar("target")).name, "Shadowed Unit Frames")
    -- An AddOn can add one, before Blizzard's.
    local own = healthBar()
    equal(toolkit.RegisterBarAdapter("unit", {name = "Mine", bar = function() return own end}, "Shadowed Unit Frames"),
        true)
    equal(toolkit.FindUnitBar("target"), own)
    equal(toolkit.RegisterBarAdapter("unit", {name = "Mine", bar = function() end}), false, "one name once")
    equal(toolkit.RegisterBarAdapter("other", {name = "X", bar = function() end}), false)
end)

-- The public API (John, 2026-10-31) ------------------------------------------------

test("HealthBars.RegisterAdapter: another AddOn's bar comes first, nil falls through", function()
    local state = fixture()
    local env = barWorld(state)
    local api = state.toolkit.HealthBars
    equal(api.API_VERSION, 1)
    local blizzard = healthBar()
    local plate = stub({UnitFrame = {healthBar = blizzard}, TPFrame = {Active = true, visual = {Healthbar = healthBar()}}})
    function plate:IsForbidden() return false end
    env.C_NamePlate = {GetNamePlateForUnit = function() return plate end}
    local own, mine = healthBar(), true
    equal(api.RegisterAdapter({name = "My Plates", plate = function(p, unit)
        if mine and p == plate and unit == "nameplate1" then return own end
    end}), true)
    local bar, info = state.toolkit.FindPlateBar("nameplate1")
    equal(bar, own, "before Threat Plates")
    equal(info.name, "My Plates")
    mine = false
    equal(select(2, state.toolkit.FindPlateBar("nameplate1")).name, "Threat Plates", "nil falls through")
    equal(select(2, state.toolkit.FindUnitBar("target")), nil, "a plate adapter is not asked for unit frames")
    -- Bad specs say why.
    local ok, why = api.RegisterAdapter({name = "X"})
    equal(ok, false)
    contains(why, "spec.plate or spec.unit")
    equal(select(2, api.RegisterAdapter({name = "X", unit = function() end, side = "top"})) ~= nil, true)
    equal(api.UnregisterAdapter("My Plates"), true)
    equal(api.UnregisterAdapter("My Plates"), false)
end)

test("HealthBars: an adapter's side, anchor, strata, level, and avoid place DIES", function()
    local state = fixture()
    barWorld(state)
    local api, toolkit = state.toolkit.HealthBars, state.toolkit
    local bar = healthBar()
    api.RegisterAdapter({name = "Mine", unit = function() return bar end, side = "right", level = 30})
    local found, info = toolkit.FindUnitBar("target")
    local dies, side = toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info)
    equal(dies, true)
    equal(side, "right", "the adapter's side, not unit frames' left")
    local badge = state.made[2]
    equal(badge.calls.SetFrameLevel[1], 35, "bar level 5 + 30")
    equal(select(2, toolkit.DrawPrediction(found, "target", 900, 500, {side = "left"}, info)), "left",
        "the player's own setting wins")
    api.RegisterAdapter({name = "Mine", unit = function() return bar end, anchor = {"BOTTOM", "TOP", 0, 4},
        strata = "HIGH"})
    found, info = toolkit.FindUnitBar("target")
    toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info)
    equal(badge.point[1], "BOTTOM")
    equal(badge.point[3], "TOP")
    equal(badge.point[5], 4)
    equal(badge.calls.SetFrameStrata[1], "HIGH")
    -- avoid: the adapter says its frame writes on the right.
    api.RegisterAdapter({name = "Mine", unit = function() return bar end,
        avoid = function(plate, b) return b == bar and plate == nil and {left = true} or nil end})
    found, info = toolkit.FindUnitBar("target")
    equal(select(2, toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info)), "right", "left avoided")
end)

test("HealthBars: suppress and SetSuppressed draw nothing on a bar", function()
    local state = fixture()
    barWorld(state)
    local api, toolkit = state.toolkit.HealthBars, state.toolkit
    local bar, busy = healthBar(), true
    api.RegisterAdapter({name = "Mine", unit = function() return bar end,
        suppress = function(b, unit) return busy and b == bar and unit == "target" end})
    local found, info = toolkit.FindUnitBar("target")
    equal(toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info), false)
    equal(#state.made, 0, "no block made")
    busy = false
    equal(toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info), true)
    equal(api.SetSuppressed(bar, true), true)
    equal(state.made[1].shown, false, "hidden at once")
    equal(toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info), false)
    api.SetSuppressed(bar, false)
    equal(toolkit.DrawPrediction(found, "target", 900, 500, STYLE, info), true)
    equal(api.SetSuppressed(nil, true), false)
end)

test("HealthBars: a failing hook is turned off, falls through, and is said only in debug mode", function()
    local state = fixture()
    local env = barWorld(state)
    local api, toolkit = state.toolkit.HealthBars, state.toolkit
    local blizzard = healthBar()
    env.TargetFrame = {healthbar = blizzard}
    local calls = 0
    api.RegisterAdapter({name = "Broken", unit = function() calls = calls + 1; error("boom") end})
    local before = #state.messages
    local bar, info = toolkit.FindUnitBar("target")
    equal(bar, blizzard, "Blizzard's bar instead")
    equal(info.name, "Blizzard")
    equal(#state.messages, before, "nothing in chat outside debug mode")
    toolkit.FindUnitBar("target")
    equal(calls, 1, "off until reload")
    state.slash("debug")
    equal(state.said("Debug mode is on"), true)
    equal(state.said("\"Broken\" failed and is off until you reload"), true, "the failures so far")
    api.RegisterAdapter({name = "Also broken", unit = function() error("bang") end})
    toolkit.FindUnitBar("target")
    equal(state.said("\"Also broken\" failed"), true, "said at once in debug mode")
    state.slash("debug")
    equal(state.said("Debug mode is off."), true)
end)

local function family(env, groups)
    env.C_AddOns = {GetAddOnMetadata = function(addon, field)
        return field == "Group" and groups[addon] or nil
    end}
end

test("HealthBars: damage sources are Dyre's AddOns only, and the highest priority wins", function()
    local state = fixture()
    local env = barWorld(state)
    family(env, {DyresDebuffTracker = "DyresToolkit", WarlockToolsForever = "DyresToolkit"})
    local api = state.toolkit.HealthBars
    equal(api.GetPredictedDamage("target"), nil, "no source")
    equal(api.RegisterSource({addon = "SomeoneElse", priority = 99, damage = function() return 1 end}), false)
    equal(api.RegisterSource({addon = "WarlockToolsForever", priority = 10, damage = function() return 300 end}),
        true)
    equal(api.IsActiveSource("WarlockToolsForever"), true)
    equal(api.GetPredictedDamage("target"), 300)
    api.RegisterSource({addon = "DyresDebuffTracker", priority = 20, damage = function(unit)
        return unit == "target" and 450 or nil
    end})
    equal(api.IsActiveSource("DyresDebuffTracker"), true)
    equal(api.IsActiveSource("WarlockToolsForever"), false, "counted once")
    equal(api.GetPredictedDamage("target"), 450)
    equal(api.GetPredictedDamage("focus"), nil)
    api.SetSourceEnabled("DyresDebuffTracker", false)
    equal(api.GetPredictedDamage("target"), 300, "steps aside while its prediction is off")
end)

test("HealthBars.WillDie: true or false from readable health, nil for a secret one", function()
    local state = fixture()
    local env = barWorld(state)
    family(env, {DyresDebuffTracker = "DyresToolkit"})
    state.units.target = mob("Creature-1", "Grunt")
    local health = 400
    env.UnitHealth = function() return health end
    local api = state.toolkit.HealthBars
    api.RegisterSource({addon = "DyresDebuffTracker", priority = 20, damage = function(unit)
        return unit ~= "focus" and 450 or 0
    end})
    equal(api.WillDie("target"), true)
    equal(api.WillDie("Creature-1"), true, "by GUID")
    health = 600
    equal(api.WillDie("target"), false)
    health = SECRET
    equal(api.WillDie("target"), nil, "secret health")
    equal(api.WillDie("focus"), false, "no damage")
    equal(api.WillDie("Creature-9"), nil, "not found")
end)

test("HealthBars: PREDICTION_CHANGED from the active source only; a failing callback is dropped", function()
    local state = fixture()
    local env = barWorld(state)
    family(env, {DyresDebuffTracker = "DyresToolkit", WarlockToolsForever = "DyresToolkit"})
    local api = state.toolkit.HealthBars
    api.RegisterSource({addon = "WarlockToolsForever", priority = 10, damage = function() end})
    api.RegisterSource({addon = "DyresDebuffTracker", priority = 20, damage = function() end})
    local heard = {}
    local function listen(event, unit, guid) heard[#heard + 1] = event .. ":" .. tostring(unit) .. ":" .. tostring(guid) end
    equal(api.RegisterCallback("PREDICTION_CHANGED", listen), true)
    equal(api.RegisterCallback("PREDICTION_CHANGED", listen), true, "once")
    equal(api.RegisterCallback("OTHER", listen), false)
    local failing = 0
    api.RegisterCallback("PREDICTION_CHANGED", function() failing = failing + 1; error("x") end)
    equal(api.NotifyChanged("WarlockToolsForever", "target"), false, "not the active source")
    equal(api.NotifyChanged("DyresDebuffTracker", "target", "Creature-1"), true)
    api.NotifyChanged("DyresDebuffTracker", nil, "Creature-2")
    equal(#heard, 2)
    equal(heard[1], "PREDICTION_CHANGED:target:Creature-1")
    equal(failing, 1, "dropped after failing")
    equal(api.UnregisterCallback("PREDICTION_CHANGED", listen), true)
    api.NotifyChanged("DyresDebuffTracker", "target")
    equal(#heard, 2)
end)

test("HealthBars.Refresh asks the active source to draw again, once, on the next frame", function()
    local state = fixture()
    local env = barWorld(state)
    family(env, {DyresDebuffTracker = "DyresToolkit"})
    local later = {}
    env.C_Timer = {After = function(_, callback) later[#later + 1] = callback end}
    local api = state.toolkit.HealthBars
    local drawn = {}
    api.RegisterSource({addon = "DyresDebuffTracker", priority = 20, damage = function() end,
        refresh = function(unit) drawn[#drawn + 1] = tostring(unit) end})
    api.Refresh("nameplate1")
    api.Refresh("nameplate1")
    api.Refresh("target")
    equal(#later, 1, "one timer")
    equal(#drawn, 0, "not yet")
    later[1]()
    equal(#drawn, 2, "each unit once")
    api.Refresh("target")
    api.Refresh(nil)
    later[2]()
    equal(#drawn, 3, "nil: every unit, in one call")
    equal(drawn[3], "nil")
    equal(api.Refresh(5), false)
end)

-- Engine stage A (2.5.0): spells, macros, announcements, class data ----------------

-- The client's spells: names by ID, a spellbook of {id, name, future}, the IDs
-- you know, and your pet's spells.
local function spellbook(state, options)
    local env = state.env
    options = options or {}
    local names = options.names or {}
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.C_Spell = {GetSpellName = function(id) return names[id] end}
    env.Enum = {SpellBookItemType = {Spell = 1, FutureSpell = 2}}
    if not options.noEnum then
        env.Enum.SpellBookSpellBank = {Player = 0, Pet = 1}
    end
    local items = options.book or {}
    local known = options.known or {}
    local pet = options.pet or {}
    state.knownCalls = {}
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #items} end,
        GetSpellBookItemInfo = function(index, bank)
            if bank == 1 then
                return pet[index] and {name = pet[index]}
            end
            local item = items[index]
            return item and {spellID = item[1], name = item[2], itemType = item[3] and 2 or 1}
        end,
        IsSpellKnown = function(id, bank)
            state.knownCalls[#state.knownCalls + 1] = {id, bank}
            if bank == 1 then
                return options.petKnown and options.petKnown[id] == true
            end
            return known[id] == true
        end,
        HasPetSpells = function() return #pet end,
    }
    if options.era then
        -- Classic Era: no GetSpellBookItemInfo, only the pet spellbook by name.
        env.C_SpellBook.GetSpellBookItemInfo = nil
        env.GetSpellBookItemName = function(index, book) return book == "pet" and pet[index] or nil end
    end
    return env
end

test("spells by name: Classic IDs plus every spellbook rank, learned names only", function()
    local state = fixture()
    spellbook(state, {names = {[5782] = "Fear", [6213] = "Fear", [980] = "Bane of Agony"},
        book = {{9001, "Fear"}, {9002, "Fear"}, {9100, "Bane of Doom"}, {9200, "Fear", true}}})
    local toolkit = state.toolkit
    local byName, learned = toolkit.SpellbookIDsByName()
    equal(#byName.Fear, 3, "every Fear in the book, the future one too")
    equal(learned.Fear, true)
    equal(learned["Bane of Doom"], true)
    local set, names, known = toolkit.SpellSet({5782, 6213})
    equal(set[5782] and set[6213] and set[9001] and set[9002] and set[9200], true, "the book's ranks join")
    equal(names.Fear, true)
    equal(known, true)
    local banes, _, banesKnown = toolkit.SpellSet({980}, {"Bane of Doom", "Bane of Havoc"})
    equal(banes[9100], true, "a name-only spell")
    equal(banesKnown, true)
    local _, _, nothing = toolkit.SpellSet({12345})
    equal(nothing, false, "a spell not in the book is not learned")
    local byID, sets, keys = toolkit.IndexSpells({{key = "fear", ids = {5782}}, {key = "again", ids = {5782}},
        {key = "bane", ids = {980}, names = {"Bane of Doom"}}})
    equal(byID[9001].key, "fear")
    equal(byID[5782].key, "fear", "the first def listing an ID wins")
    equal(sets.bane[9100], true)
    equal(keys.fear, true)
end)

test("spells by name: no spellbook API, or a secret name, gives nothing and no error", function()
    local state = fixture()
    spellbook(state, {names = {[5782] = SECRET}})
    state.env.C_SpellBook.GetNumSpellBookSkillLines = nil
    local toolkit = state.toolkit
    local byName = toolkit.SpellbookIDsByName()
    equal(next(byName), nil)
    local set, names, known = toolkit.SpellSet({5782})
    equal(set[5782], true)
    equal(next(names), nil, "a secret name is not used")
    equal(known, false)
    equal(toolkit.SpellName(5782), nil)
end)

test("KnowsAny takes a list or a set; without IsSpellKnown it is false", function()
    local state = fixture()
    spellbook(state, {known = {[6213] = true}})
    local toolkit = state.toolkit
    equal(toolkit.KnowsAny({5782, 6213}), true)
    equal(toolkit.KnowsAny({[5782] = true, [6213] = true}), true)
    equal(toolkit.KnowsAny({5782}), false)
    equal(toolkit.KnowsAny(nil), false)
    state.env.C_SpellBook.IsSpellKnown = nil
    equal(toolkit.KnowsAny({6213}), false)
end)

test("PetKnows: by ID with the bank enum, else the legacy call, else the pet spellbook by name", function()
    local state = fixture()
    spellbook(state, {names = {[6358] = "Seduction"}, petKnown = {[6358] = true}})
    local toolkit = state.toolkit
    equal(toolkit.PetKnows(6358), true)
    equal(state.knownCalls[1][2], 1, "the Pet bank enum, never true")
    -- Forever's Incubus: another ID, the same name.
    spellbook(state, {names = {[6358] = "Seduction"}, pet = {"Lash of Pain", "Seduction"}})
    equal(toolkit.PetKnows(6358), true)
    spellbook(state, {names = {[6358] = "Seduction"}, pet = {"Lash of Pain"}})
    equal(toolkit.PetKnows(6358), false)
    -- Classic Era: no enum, no GetSpellBookItemInfo.
    spellbook(state, {names = {[6358] = "Seduction"}, pet = {"Seduction"}, era = true, noEnum = true})
    state.env.IsSpellKnown = function(id, isPet) return false end
    equal(toolkit.PetKnows(6358), true, "found by name in the pet book")
    spellbook(state, {names = {[6358] = "Seduction"}, era = true, noEnum = true})
    state.env.IsSpellKnown = function(id, isPet) return isPet == true and id == 6358 end
    equal(toolkit.PetKnows(6358), true, "the legacy call")
    state.env.C_SpellBook = nil
    equal(toolkit.PetKnows(6358), false)
end)

-- The client's character macros: {name, body} by index, character ones only.
local function macroClient(state, limit)
    local env = state.env
    state.macros = {}
    env.Constants = {MacroConsts = {MAX_CHARACTER_MACROS = limit or 18}}
    env.GetMacroIndexByName = function(name)
        for index, macro in ipairs(state.macros) do
            if macro.name == name then return index end
        end
        return 0
    end
    env.GetNumMacros = function() return 120, #state.macros end
    env.GetMacroBody = function(index) return state.macros[index].body end
    env.CreateMacro = function(name, icon, body, perCharacter)
        assert(perCharacter == true, "a character macro")
        state.macros[#state.macros + 1] = {name = name, body = body, icon = icon}
    end
    env.EditMacro = function(index, name, icon, body)
        state.macros[index] = {name = name, body = body, icon = icon}
        state.edits = (state.edits or 0) + 1
    end
    env.DeleteMacro = function(index) table.remove(state.macros, index) end
    env.SetRaidTarget = function() error("never SetRaidTarget") end
end

test("a macro keeper creates, adopts by exact name, renames old names, and edits only on change", function()
    local state = fixture()
    macroClient(state)
    local toolkit = state.toolkit
    local warned = {}
    local keeper = toolkit.CreateMacroKeeper({warn = function(text) warned[#warned + 1] = text end})
    equal(keeper:Available(), true)
    equal(keeper:Write("! Polymorph", "one"), "created")
    equal(state.macros[1].icon, 134400, "the question mark, filled by #showtooltip")
    equal(keeper:Write("! Polymorph", "one"), "unchanged")
    equal(state.edits, nil, "no edit for the same text")
    equal(keeper:Write("! Polymorph", "two"), "edited")
    -- Another AddOn's macro of the same name: kept in place, never a copy.
    state.macros[2] = {name = "! Fear", body = "theirs"}
    equal(keeper:Write("! Fear", "ours"), "adopted")
    equal(#state.macros, 2, "no second copy")
    equal(state.macros[2].body, "ours")
    equal(keeper:Write("! Fear", "ours"), "unchanged", "adopted once")
    state.macros[3] = {name = "WTF Healthstone", body = "old"}
    equal(keeper:Write("! Healthstone", "new", {"!WTF Healthstone", "WTF Healthstone"}), "renamed")
    equal(state.macros[3].name, "! Healthstone")
    equal(keeper:Has("! Healthstone"), true)
    state.combat = true
    local result, why = keeper:Write("! Banish", "x")
    equal(result, nil)
    equal(why, "combat")
    equal(keeper:Delete("! Fear"), false, "nothing changes in combat")
    state.combat = false
    equal(keeper:Delete("! Fear"), true)
    equal(keeper:Delete("! Fear"), false)
    equal(keeper:Write("! Fear", "ours"), "created", "deleted, then made again")
end)

test("a macro keeper's ownership lives in the caller's saved table, so a reload never adopts again", function()
    local state = fixture()
    macroClient(state)
    local toolkit = state.toolkit
    local store = {owned = {}}
    state.macros[1] = {name = "! Fear", body = "WTF's"}
    local keeper = toolkit.CreateMacroKeeper({owned = store.owned})
    equal(keeper:Write("! Fear", "ours"), "adopted", "the first time")
    equal(keeper:Write("! Banish", "ours"), "created")
    equal(store.owned["! Fear"] and store.owned["! Banish"], true, "kept in the caller's table")
    -- /reload: a new keeper on the same saved table.
    local reloaded = toolkit.CreateMacroKeeper({owned = store.owned})
    equal(reloaded:Write("! Fear", "ours"), "unchanged", "never adopted again")
    equal(reloaded:Write("! Banish", "new"), "edited")
    equal(reloaded:Delete("! Banish"), true)
    equal(store.owned["! Banish"], nil, "a deleted macro is no longer ours")
    state.macros[#state.macros + 1] = {name = "! Banish", body = "someone's"}
    equal(toolkit.CreateMacroKeeper({owned = store.owned}):Write("! Banish", "ours"), "adopted")
end)

test("a macro keeper leaves the last character slots free and warns once", function()
    local state = fixture()
    macroClient(state, 4)
    local toolkit = state.toolkit
    local warned = {}
    local keeper = toolkit.CreateMacroKeeper({warn = function(text) warned[#warned + 1] = text end})
    equal(keeper:Write("a", "1"), "created")
    equal(keeper:Write("b", "1"), "created")
    local result, why = keeper:Write("c", "1")
    equal(result, nil)
    equal(why, "full")
    keeper:Write("d", "1")
    equal(#warned, 1, "warned once")
    contains(warned[1], "\"c\"")
    equal(keeper:Write("a", "2"), "edited", "an existing macro still changes")
end)

test("without a macro function or the slot constant, macros stay off", function()
    local state = fixture()
    macroClient(state)
    local toolkit = state.toolkit
    state.env.Constants = nil
    local ok, missing = toolkit.MacrosAvailable()
    equal(ok, false)
    equal(missing, "Constants.MacroConsts.MAX_CHARACTER_MACROS")
    state.env.MAX_CHARACTER_MACROS = 18
    equal((toolkit.MacrosAvailable()), true, "the global, once the Macro window loaded")
    state.env.EditMacro = nil
    ok, missing = toolkit.MacrosAvailable()
    equal(missing, "EditMacro")
    local result, why = toolkit.CreateMacroKeeper():Write("x", "y")
    equal(result, nil)
    equal(why, "unavailable")
end)

test("OutOfCombat runs now, or once when combat ends with the latest request per key", function()
    local state = fixture()
    local toolkit = state.toolkit
    local runs = {}
    equal(toolkit.OutOfCombat("macros", function() runs[#runs + 1] = "now" end), true)
    state.combat = true
    local before = #state.frames
    equal(toolkit.OutOfCombat("macros", function() runs[#runs + 1] = "first" end), false)
    toolkit.OutOfCombat("other", function() runs[#runs + 1] = "other" end)
    toolkit.OutOfCombat("macros", function() runs[#runs + 1] = "latest" end)
    local regen = state.frames[before + 1]
    equal(regen.events.PLAYER_REGEN_ENABLED, true)
    state.combat = false
    regen.scripts.OnEvent(regen, "PLAYER_REGEN_ENABLED")
    equal(table.concat(runs, ","), "now,latest,other")
    equal(regen.events.PLAYER_REGEN_ENABLED, nil, "no event left registered")
    regen.scripts.OnEvent(regen, "PLAYER_REGEN_ENABLED")
    equal(#runs, 3, "each ran once")
end)

local function macroSpells(state, focusWorks)
    spellbook(state, {names = {[710] = "Banish", [5782] = "Fear", [6358] = "Seduction", [118] = "Polymorph",
        [5484] = "Howl of Terror"}})
    state.toolkit.FocusWorks = function() return focusWorks end
end

test("MarkLine: /tm for a marker, nothing for none", function()
    local toolkit = fixture().toolkit
    equal(toolkit.MarkLine("focus", 5), "/tm [@focus,harm,nodead,exists] !5")
    equal(toolkit.MarkLine("focus", 0), nil)
    equal(toolkit.MarkLine("focus", nil), nil)
end)

test("FocusCastMacro writes WTF 1.4.1's Banish and Seduction macros, focus or chain", function()
    local state = fixture()
    local toolkit = state.toolkit
    macroSpells(state, true)
    equal(toolkit.FocusCastMacro({spell = 710, marker = 5}), "#showtooltip Banish\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/tm [@focus,harm,nodead,exists] !5\n"
        .. "/use [@focus,exists,harm,nodead] Banish")
    equal(toolkit.FocusCastMacro({spell = 6358, condition = ",pet:Succubus/Incubus"}), "#showtooltip Seduction\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/use [@focus,exists,harm,nodead,pet:Succubus/Incubus] Seduction")
    macroSpells(state, false)
    equal(toolkit.FocusCastMacro({spell = 710, marker = 5}), "#showtooltip Banish\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/tm [@focus,harm,nodead,exists][@mouseover,harm,nodead][harm,nodead] !5\n"
        .. "/use [@focus,exists,harm,nodead][@mouseover,harm,nodead][harm,nodead] Banish")
    equal(toolkit.FocusCastMacro({spell = 6358, condition = ",pet:Succubus/Incubus"}), "#showtooltip Seduction\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/use [@focus,exists,harm,nodead,pet:Succubus/Incubus][@mouseover,harm,nodead,pet:Succubus/Incubus]"
        .. "[harm,nodead,pet:Succubus/Incubus] Seduction")
    equal(toolkit.FocusCastMacro({spell = 710, marker = 5, chain = false}):find("%[@mouseover,harm,nodead%] !"),
        nil, "chain = false overrides the flag")
end)

test("FocusCastMacro writes WTF 1.4.1's Fear macro: Shift keeps your focus", function()
    local state = fixture()
    local toolkit = state.toolkit
    macroSpells(state, true)
    equal(toolkit.FocusCastMacro({spell = 5782, shift = true}), "#showtooltip Fear\n"
        .. "/focus [nomod:shift,@mouseover,harm,nodead][nomod:shift,harm,nodead]\n"
        .. "/use [mod:shift,@mouseover,harm,nodead][mod:shift,harm,nodead][@focus,exists,harm,nodead] Fear")
    macroSpells(state, false)
    equal(toolkit.FocusCastMacro({spell = 5782, shift = true, marker = 8}), "#showtooltip Fear\n"
        .. "/focus [nomod:shift,@mouseover,harm,nodead][nomod:shift,harm,nodead]\n"
        .. "/use [mod:shift,@mouseover,harm,nodead][mod:shift,harm,nodead][@focus,exists,harm,nodead]"
        .. "[@mouseover,harm,nodead][harm,nodead] Fear", "no marker in the Shift form")
end)

test("FocusCastMacro writes MTF 1.2.3's Polymorph macro once focus works; untargeted and unknown spells", function()
    local state = fixture()
    local toolkit = state.toolkit
    macroSpells(state, true)
    equal(toolkit.FocusCastMacro({spell = 118, marker = 5}), "#showtooltip Polymorph\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/tm [@focus,harm,nodead,exists] !5\n"
        .. "/use [@focus,exists,harm,nodead] Polymorph")
    equal(toolkit.FocusCastMacro({spell = 118}), "#showtooltip Polymorph\n"
        .. "/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/use [@focus,exists,harm,nodead] Polymorph", "the mark switch off: no /tm")
    equal(toolkit.FocusCastMacro({spell = 5484, untargeted = true}), "#showtooltip Howl of Terror\n/use Howl of Terror")
    equal(toolkit.FocusCastMacro({spell = 99999}), nil, "a spell this client lacks")
    equal(toolkit.FocusCastMacro({spell = "Shackle Undead", chain = false}):sub(-14), "Shackle Undead")
end)

test("GroupChannel: raid, party, nothing alone, or Say", function()
    local state = fixture()
    local toolkit = state.toolkit
    local raid, party = false, false
    state.env.IsInRaid = function() return raid end
    state.env.IsInGroup = function() return party end
    equal(toolkit.GroupChannel(), nil)
    party = true
    equal(toolkit.GroupChannel(), "PARTY")
    raid = true
    equal(toolkit.GroupChannel(), "RAID")
    equal(toolkit.GroupChannel(true), "SAY")
end)

test("FormatAnnouncement fills tokens from a values table; a missing marker takes its space", function()
    local state = fixture()
    local toolkit = state.toolkit
    state.env.issecretvalue = function(value) return rawequal(value, SECRET) end
    equal(toolkit.FormatAnnouncement("Banishing %T %M!", {T = "Grunt", M = "{moon}"}), "Banishing Grunt {moon}!")
    equal(toolkit.FormatAnnouncement("Banishing %T %M!", {T = "Grunt", M = ""}), "Banishing Grunt!")
    equal(toolkit.FormatAnnouncement("Banishing %T %M!", {T = "Grunt", M = false}), "Banishing Grunt!")
    equal(toolkit.FormatAnnouncement("Summoning %T in %Z", {T = "100% Bob", Z = "Orgrimmar"}),
        "Summoning 100% Bob in Orgrimmar", "a % in a name is kept as it is")
    equal(toolkit.FormatAnnouncement("%C %I for %X", {C = 20, I = "Water"}), "20 Water for %X",
        "an unknown token stays")
    equal(toolkit.FormatAnnouncement("Sheep %T", {T = SECRET}), "Sheep", "a secret name is never used")
    equal(toolkit.MarkerCode(5), "{moon}")
    equal(toolkit.MarkerCode(0), "")
    equal(toolkit.MarkerCode(42), "")
    equal(toolkit.ValidMarker(8), true)
    equal(toolkit.ValidMarker(9), false)
    equal(#toolkit.RAID_MARKERS, 9)
end)

test("an announcer sends each kind at most once every few seconds, only in a group", function()
    local state = fixture()
    local toolkit = state.toolkit
    local sent = {}
    state.now = 100
    state.env.GetTime = function() return state.now end
    state.env.C_ChatInfo = {SendChatMessage = function(message, chatType) sent[#sent + 1] = chatType .. ":" .. message end}
    local party, say, enabled = false, false, true
    state.env.IsInRaid = function() return false end
    state.env.IsInGroup = function() return party end
    local announcer = toolkit.CreateAnnouncer({say = function() return say end, enabled = function() return enabled end})
    equal(announcer:SendGroup("fear", "Fear on Grunt"), false, "alone")
    party = true
    equal(announcer:SendGroup("fear", "Fear on Grunt"), true, "alone is no throttle")
    equal(announcer:SendGroup("fear", "Fear on Grunt"), false, "the same kind within 3 seconds")
    equal(announcer:SendGroup("banish", "Banish on Imp"), true, "another kind")
    state.now = 103
    say = true
    equal(announcer:SendGroup("fear", "Fear on Grunt"), true)
    enabled = false
    state.now = 200
    equal(announcer:SendGroup("fear", "Fear on Grunt"), false, "switched off")
    equal(table.concat(sent, "|"), "PARTY:Fear on Grunt|PARTY:Banish on Imp|SAY:Fear on Grunt")
end)

test("class data: Warlock and Mage tables are whole, and Agony's weights match WTF's ramp", function()
    local toolkit = fixture().toolkit
    equal(toolkit.ClassSpells("PRIEST"), nil, "no table until its IDs are checked")
    for _, class in ipairs({"WARLOCK", "MAGE"}) do
        local data = toolkit.ClassSpells(class)
        local controls, ids = {}, {}
        for _, spell in ipairs(data.control) do
            assert(type(spell.key) == "string" and type(spell.label) == "string" and #spell.ids > 0, class)
            controls[spell.key] = spell
            for _, id in ipairs(spell.ids) do
                assert(not ids[id], class .. ": " .. id .. " twice")
                ids[id] = true
            end
            if spell.bar then
                assert(spell.longest > 0, spell.key)
            end
        end
        for _, macro in ipairs(data.macros) do
            assert(macro.name:sub(1, 2) == "! " and #macro.name <= 16, macro.name)
            assert(macro.pet or controls[macro.known], macro.name .. " knows a control spell")
            assert(not macro.marker or controls[macro.marker].marker, macro.name .. " marker")
        end
        for _, slot in ipairs(data.dots) do
            assert(slot.color:match("^%x%x%x%x%x%x%x%x$"), slot.key)
        end
        for id, rank in pairs(data.ranks) do
            assert(data.families[rank[1]], id .. " has a family")
        end
    end
    local warlock = toolkit.ClassSpells("WARLOCK")
    -- WTF 1.4.1 Predict.lua Weight(): ticks 1-4 half, 5-8 one, then one and a half.
    for tick = 1, 12 do
        local expected = tick <= 4 and 0.5 or tick <= 8 and 1 or 1.5
        equal(toolkit.TickWeight(warlock.families.agony, tick), expected, "agony tick " .. tick)
        equal(toolkit.TickWeight(warlock.families.corruption, tick), 1)
    end
    equal(toolkit.ClassSpells("MAGE").control[1].longest, 50)
    equal(warlock.control[1].plateTimer, true, "Fear's plate timer is data")
end)

-- Engine stage B (2.5.0): one owner per kind, the control tracker ------------------

-- Every AddOn named in these tests is a Dyre's AddOn unless listed here.
local function familyAll(env, outsiders)
    outsiders = outsiders or {}
    family(env, setmetatable({}, {__index = function(_, addon)
        return not outsiders[addon] and "DyresToolkit" or nil
    end}))
end

test("owners: the highest enabled claim owns a kind; a tie goes to the first", function()
    local state = fixture()
    familyAll(state.env)
    local toolkit = state.toolkit
    local heard = {}
    toolkit.OnOwnerChanged("control:WARLOCK", function(owner, kind) heard[#heard + 1] = tostring(owner) end)
    equal(toolkit.ClaimOwner("control:WARLOCK", "DyresDebuffTracker", 5), true, "alone, it owns")
    equal(toolkit.ClaimOwner("control:WARLOCK", "WarlockToolsForever", 10), true, "the class AddOn wins")
    equal(toolkit.IsOwner("control:WARLOCK", "DyresDebuffTracker"), false)
    equal(toolkit.KindOwner("control:WARLOCK"), "WarlockToolsForever")
    toolkit.SetOwnerEnabled("control:WARLOCK", "WarlockToolsForever", false)
    equal(toolkit.KindOwner("control:WARLOCK"), "DyresDebuffTracker", "switched off steps aside")
    toolkit.SetOwnerEnabled("control:WARLOCK", "WarlockToolsForever", true)
    equal(table.concat(heard, ","), "DyresDebuffTracker,WarlockToolsForever,DyresDebuffTracker,WarlockToolsForever")
    toolkit.ClaimOwner("macros:MAGE", "A", 5)
    toolkit.ClaimOwner("macros:MAGE", "B", 5)
    equal(toolkit.KindOwner("macros:MAGE"), "A", "a tie: the first claim")
    equal(toolkit.KindOwner("announce:MAGE"), nil)
    equal(toolkit.SetOwnerEnabled("announce:MAGE", "A", false), false, "never claimed")
    equal(toolkit.ClaimOwner(nil, "A", 1), false)
end)

test("the plate memory is idempotent: two engines feeding the same plate events agree", function()
    local state = fixture()
    local target = mob("Creature-7", "Grunt")
    world(state, {nameplate4 = mob(SECRET, "Grunt", {same = "target"}), target = target})
    local toolkit = state.toolkit
    toolkit.LearnPlate("nameplate4")
    toolkit.LearnPlate("nameplate4")
    toolkit.LearnPlates()
    toolkit.LearnPlates()
    equal(toolkit.PlateGUID("nameplate4"), "Creature-7", "learned once, the same after twice")
    equal(toolkit.KnownPlate("Creature-7"), "nameplate4")
    toolkit.ForgetPlate("nameplate4")
    toolkit.ForgetPlate("nameplate4")
    equal(toolkit.PlateGUID("nameplate4"), nil)
    equal(toolkit.KnownPlate("Creature-7"), nil)
end)

test("owners: only Dyre's AddOns may claim, so no other AddOn silences one", function()
    local state = fixture()
    familyAll(state.env, {Outsider = true})
    local toolkit = state.toolkit
    toolkit.ClaimOwner("control:WARLOCK", "WarlockToolsForever", 10)
    local ok, why = toolkit.ClaimOwner("control:WARLOCK", "Outsider", 999)
    equal(ok, false)
    equal(why, "owner claims are for Dyre's AddOns")
    equal(toolkit.KindOwner("control:WARLOCK"), "WarlockToolsForever", "WTF still owns it")
    ok, why = toolkit.SetOwnerEnabled("control:WARLOCK", "Outsider", true)
    equal(ok, false)
    state.env.C_AddOns = nil
    equal((toolkit.ClaimOwner("control:MAGE", "MageToolsForever", 10)), false, "no metadata API: no claim")
end)

test("owners: a failing listener is off until reload, said only in debug mode", function()
    local state = fixture()
    familyAll(state.env)
    local toolkit = state.toolkit
    local calls = 0
    toolkit.OnOwnerChanged("bar:X", function() calls = calls + 1; error("boom") end)
    toolkit.ClaimOwner("bar:X", "A", 1)
    toolkit.ClaimOwner("bar:X", "B", 2)
    equal(calls, 1, "off after its first failure")
    equal(state.said("boom"), false, "quiet outside debug mode")
end)

-- A client frame for the tracker: shown state, attributes, events, and the
-- client's rule that a secure frame changes nothing in combat.
local SECURE_IN_COMBAT = {SetAttribute = true, Show = true, Hide = true, SetShown = true, SetScale = true,
    EnableMouse = true, SetSize = true, SetPoint = true, ClearAllPoints = true}

local function uiFrame(state, kind, name, parent, template)
    local frame = stub({kind = kind, name = name, parent = parent, template = template, shown = true,
        attributes = {}, events = {}, scripts = {}, alpha = 1, scale = 1})
    local secure = template == "SecureActionButtonTemplate"
    local methods = {}
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetShown(shown) self.shown = shown and true or false end
    function methods:SetAttribute(key, value) self.attributes[key] = value end
    function methods:SetScale(scale) self.scale = scale end
    function methods:EnableMouse(enabled) self.mouse = enabled end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetPoint(...) self.point = {...} end
    function methods:ClearAllPoints() self.point = nil end
    for key, method in pairs(methods) do
        frame[key] = function(self, ...)
            if secure and state.combat and SECURE_IN_COMBAT[key] then
                error(key .. " on a secure frame in combat")
            end
            return method(self, ...)
        end
    end
    function frame:IsShown() return self.shown end
    function frame:IsVisible()
        return self.shown and (not self.parent or type(self.parent.IsVisible) ~= "function" or self.parent:IsVisible())
    end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:RegisterUnitEvent(event) self.events[event] = true end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:SetAlpha(alpha) self.alpha = alpha end
    function frame:SetParent(newParent) self.parent = newParent end
    function frame:IsForbidden() return false end
    frame.level = 1
    function frame:GetFrameLevel() return self.level end
    function frame:SetFrameLevel(level) self.level = level end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:CreateFontString()
        local text = stub()
        function text:SetText(value) self.text = value end
        function text:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
        function text:SetFont(font, size) self.size = size end
        return text
    end
    function frame:CreateTexture() return stub() end
    function frame:CreateMaskTexture() return stub() end
    state.uiFrames[#state.uiFrames + 1] = frame
    if name then
        state.named[name] = frame
    end
    return frame
end

local function emit(state, event, ...)
    for _, frame in ipairs(state.uiFrames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

-- Runs the timers due by now.
local function advance(state, seconds)
    state.now = state.now + seconds
    local due = {}
    for index = #state.timers, 1, -1 do
        if state.timers[index].at <= state.now then
            due[#due + 1] = table.remove(state.timers, index)
        end
    end
    for index = #due, 1, -1 do
        due[index].fn()
    end
end

local CONTROL_NAMES = {[5782] = "Fear", [6213] = "Fear", [6215] = "Fear", [710] = "Banish", [18647] = "Banish",
    [1098] = "Enslave Demon", [5484] = "Howl of Terror", [6358] = "Seduction", [118] = "Polymorph",
    [12824] = "Polymorph", [28272] = "Polymorph: Pig"}

local function controlWorld(state, units, options)
    options = options or {}
    local env = world(state, units)
    familyAll(env)
    spellbook(state, {names = CONTROL_NAMES, known = options.known or {[5782] = true, [710] = true, [118] = true},
        petKnown = options.petKnown})
    macroClient(state)
    state.uiFrames, state.named, state.timers, state.sent, state.drivers = {}, {}, {}, {}, {}
    state.now, state.auras, state.plateFrames = 100, {}, {}
    env.Enum.StatusBarTimerDirection = {RemainingTime = 1}
    env.GetTime = function() return state.now end
    env.C_Timer = {After = function(delay, fn) state.timers[#state.timers + 1] = {at = state.now + delay, fn = fn} end}
    env.C_XMLUtil = nil
    env.C_UnitAuras = {GetAuraDataByIndex = function(unit, index)
        local list = state.auras[unit]
        return list and list[index]
    end}
    env.C_Spell.GetSpellTexture = function() return 136183 end
    env.GetZoneText = function() return "Orgrimmar" end
    env.IsInRaid = function() return false end
    env.IsInGroup = function() return state.group == true end
    env.C_ChatInfo = {SendChatMessage = function(message, channel) state.sent[#state.sent + 1] = channel .. ":" .. message end}
    env.RegisterStateDriver = function(frame, _, value) state.drivers[frame] = value end
    env.UnregisterStateDriver = function(frame) state.drivers[frame] = nil end
    env.GameTooltip = stub()
    env.C_NamePlate = {GetNamePlateForUnit = function(unit) return state.plateFrames[unit] end}
    env.CreateFrame = function(kind, name, parent, template) return uiFrame(state, kind, name, parent, template) end
    state.focusWorks = function(works) state.toolkit.FocusWorks = function() return works end end
    return env
end

-- The player's cast: its start names the mob, its success lands it.
local function cast(state, target, spellID, castGUID, land)
    emit(state, "UNIT_SPELLCAST_SENT", "player", target, castGUID, spellID)
    if land ~= false then
        emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", castGUID, spellID)
    end
end

local function warlockTracker(state, extra)
    local store = {enabled = true, markers = {banish = 5}, plateTimers = true, macros = true}
    local anchor = uiFrame(state, "Frame", "WarlockToolsForeverControl", state.UIParent)
    local texts = {fear = "Fearing %T", banish = "Banishing %T %M", howl = "Howling"}
    local spec = {addon = "WarlockToolsForever", priority = 10, class = "WARLOCK", store = store,
        names = {row = "WarlockToolsForeverControlRow", click = "WarlockToolsForeverControlClick",
            focus = "WarlockToolsForeverControlFocus"},
        parent = anchor, rows = 5, locked = function() return state.locked ~= false end,
        samples = {"Fear (sample)", "Banish (sample)"}, focusBox = {key = "fear"},
        announce = {text = function(key) return texts[key] end},
        keeper = {owned = {}}}
    for key, value in pairs(extra or {}) do spec[key] = value end
    local tracker, missing = state.toolkit.CreateControlTracker(spec)
    assert(tracker, tostring(missing))
    return tracker, store, spec
end

test("the control tracker keeps every frame name it is given", function()
    local state = fixture()
    controlWorld(state)
    state.focusWorks(true)
    local tracker = warlockTracker(state)
    for index = 1, 5 do
        assert(state.named["WarlockToolsForeverControlRow" .. index], "row " .. index)
        assert(state.named["WarlockToolsForeverControlClick" .. index], "click " .. index)
        equal(state.named["WarlockToolsForeverControlClick" .. index].template, "SecureActionButtonTemplate")
    end
    assert(state.named.WarlockToolsForeverControlFocus, "the Focus box")
    equal(#tracker.rows, 5)
    equal(state.toolkit.CreateControlTracker({addon = "X"}), nil, "a spec without store and names")
end)

test("a Fear locks its mob as it starts and binds the row by GUID, never by name later", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-1", "Grunt"), nameplate2 = mob("Creature-2", "Grunt")})
    state.focusWorks(true)
    state.group = true
    local tracker = warlockTracker(state)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", "cast-1", 5782)
    -- A tab mid-cast: the target is the other Grunt now.
    state.units.target = state.units.nameplate2
    state.units.nameplate1 = mob("Creature-1", "Grunt")
    emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 5782)
    local row = tracker.rows[1]
    equal(row.guid, "Creature-1", "the mob locked as the cast started")
    equal(row.boundUnit, "nameplate1")
    equal(row.name.text, "Grunt")
    equal(row.shown, true)
    equal(state.sent[1], "PARTY:Fearing Grunt", "told as it starts")
    equal(row.holder.attributes.type1, nil, "a Fear row has no click")
    contains(tracker:DebugLines()[3], "lastSent spell=5782 target=Grunt unit=target locked=true")
    -- Gone after the longest Fear plus 5 s.
    advance(state, 24)
    equal(row.guid, "Creature-1")
    advance(state, 1)
    equal(row.guid, nil)
    equal(row.boundUnit, "none")
end)

test("a recast keeps its row; a death through any unit forgets it; a dead mob gets none", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-1", "Grunt"), nameplate3 = mob("Creature-1", "Grunt")})
    state.focusWorks(true)
    local tracker = warlockTracker(state)
    cast(state, "Grunt", 5782, "c1")
    cast(state, "Grunt", 6213, "c2")
    equal(tracker.rows[1].guid, "Creature-1")
    equal(tracker.rows[2].guid, nil, "the same mob, the same row")
    state.units.nameplate3.dead = true
    emit(state, "UNIT_HEALTH", "nameplate3")
    equal(tracker.rows[1].guid, nil, "dead, seen on its plate")
    state.units.target.dead = true
    cast(state, "Grunt", 5782, "c3")
    equal(tracker.rows[1].guid, nil, "no row for a dead mob")
end)

test("a secret cast, target, or spell ID is never read", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-1", "Grunt")})
    local tracker = warlockTracker(state)
    emit(state, "UNIT_SPELLCAST_SENT", "player", SECRET, "c1", 5782)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", SECRET, 5782)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", "c1", SECRET)
    emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", SECRET, 5782)
    emit(state, "UNIT_SPELLCAST_FAILED", "player", SECRET, 5782)
    emit(state, "UNIT_HEALTH", SECRET)
    equal(tracker.rows[1].guid, nil)
end)

test("Banish with a working focus counts only at your focus, clicks to recast, and goes with the focus", function()
    local state = fixture()
    controlWorld(state, {focus = mob("Creature-9", "Imp"), target = mob("Creature-3", "Felhound")})
    state.focusWorks(true)
    state.group = true
    local tracker = warlockTracker(state)
    cast(state, "Felhound", 710, "c1")
    equal(tracker.rows[1].guid, nil, "not your focus: no row")
    equal(state.sent[1], "PARTY:Banishing Felhound", "no marker named off your focus")
    advance(state, 5)
    cast(state, "Imp", 710, "c2")
    local row = tracker.rows[1]
    equal(row.guid, "Creature-9")
    equal(row.boundUnit, "focus")
    equal(row.holder.attributes.type1, "macro")
    equal(row.holder.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Banish")
    equal(row.holder.shown, true)
    equal(state.sent[2], "PARTY:Banishing Imp {moon}", "%M: the moon the macro gives your focus")
    state.units.focus = mob("Creature-10", "Imp")
    emit(state, "PLAYER_FOCUS_CHANGED")
    equal(row.guid, nil, "your focus became another mob")
    equal(row.holder.attributes.macrotext1, nil)
end)

test("a click is set as a pull's cast starts; in combat it waits, and a failed cast gives it back", function()
    local state = fixture()
    controlWorld(state, {focus = mob("Creature-9", "Imp")})
    state.focusWorks(true)
    local tracker = warlockTracker(state)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Imp", "c1", 710)
    local holder = tracker.rows[1].holder
    equal(holder.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Banish", "before combat")
    emit(state, "UNIT_SPELLCAST_FAILED", "player", "c1", 710)
    equal(holder.attributes.macrotext1, nil, "a cast that never landed gives the row back")
    state.combat = true
    cast(state, "Imp", 710, "c2")
    equal(tracker.rows[1].guid, "Creature-9", "the row shows in combat")
    equal(holder.attributes.macrotext1, nil, "no secure change in combat")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(holder.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Banish", "set when combat ends")
end)

test("the Focus box: Fear on your focus shows there, not twice; its click fears your focus", function()
    local state = fixture()
    local focus = mob("Creature-9", "Grunt")
    controlWorld(state, {focus = focus})
    state.focusWorks(true)
    local tracker = warlockTracker(state)
    local box = state.named.WarlockToolsForeverControlFocus
    equal(box.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Fear")
    equal(state.drivers[box], "[@focus,exists,harm,nodead] show; hide")
    cast(state, "Grunt", 5782, "c1")
    equal(tracker.rows[1].guid, "Creature-9")
    equal(tracker.rows[1].shown, false, "the box shows it")
    equal(box.display.name.text, "Focus: Grunt")
    state.units.focus = nil
    emit(state, "PLAYER_FOCUS_CHANGED")
    equal(tracker.rows[1].shown, true, "back once it is not your focus")
    state.focusWorks(false)
    tracker:Refresh()
    equal(state.drivers[box], "hide", "no box until focus works")
end)

test("while unlocked, samples show; turned off, nothing shows and nothing is tracked", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-1", "Grunt")})
    state.focusWorks(true)
    state.locked = false
    local tracker, store = warlockTracker(state)
    equal(tracker.rows[1].name.text, "Fear (sample)")
    equal(tracker.rows[1].holder.shown, true, "a slot to drag by")
    equal(tracker.rows[3].shown, false)
    state.locked = true
    store.enabled = false
    tracker:Refresh()
    cast(state, "Grunt", 5782, "c1")
    equal(tracker.rows[1].guid, nil)
    equal(tracker.rows[1].shown, false)
    equal(tracker:IsOwner("control"), false, "off steps aside")
end)

test("without a working focus, Banish rows start from the cast and take no click", function()
    local state = fixture()
    controlWorld(state, {mouseover = mob("Creature-4", "Imp")})
    state.focusWorks(false)
    local tracker = warlockTracker(state)
    cast(state, "Imp", 710, "c1")
    local row = tracker.rows[1]
    equal(row.guid, "Creature-4", "locked through the mouseover")
    equal(row.focusOnly, nil)
    equal(row.holder.attributes.macrotext1, nil)
    equal(state.drivers[state.named.WarlockToolsForeverControlFocus], "hide")
end)

test("Fear timers attach to nameplates and come off with them; the switch turns them off", function()
    local state = fixture()
    controlWorld(state, {nameplate1 = mob("Creature-1", "Grunt")})
    state.focusWorks(true)
    state.plateFrames.nameplate1 = uiFrame(state, "Frame", nil, state.UIParent)
    local tracker, store = warlockTracker(state)
    local timer = tracker.plateTimers.nameplate1
    assert(timer, "attached at Refresh")
    equal(timer.parent, state.plateFrames.nameplate1)
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(tracker.plateTimers.nameplate1, nil)
    equal(timer.shown, false)
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(tracker.plateTimers.nameplate1, timer, "pooled")
    store.plateTimers = false
    tracker:Refresh()
    equal(tracker.plateTimers.nameplate1, nil)
end)

test("Howl of Terror only announces; announcements need the announce kind", function()
    local state = fixture()
    controlWorld(state)
    state.group = true
    local tracker = warlockTracker(state)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "", "c1", 5484)
    equal(state.sent[1], "PARTY:Howling")
    equal(tracker.rows[1].guid, nil)
    state.toolkit.ClaimOwner("announce:WARLOCK", "SomeClassAddOn", 20)
    advance(state, 5)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "", "c2", 5484)
    equal(#state.sent, 1, "another AddOn owns it: said once")
end)

test("the control macros: WTF's text, written only while known, owned, and out of combat", function()
    local state = fixture()
    controlWorld(state)
    state.focusWorks(true)
    local adopted = {}
    state.macros[1] = {name = "! Fear", body = "older"}
    local tracker, store = warlockTracker(state, {onAdopt = function(name) adopted[#adopted + 1] = name end})
    local byName = {}
    for _, macro in ipairs(state.macros) do byName[macro.name] = macro.body end
    equal(byName["! Fear"], state.toolkit.FocusCastMacro({spell = 5782, shift = true}))
    equal(byName["! Banish"], state.toolkit.FocusCastMacro({spell = 710, marker = 5}))
    equal(byName["! Seduction"], nil, "no demon that knows it")
    equal(table.concat(adopted, ","), "! Fear", "another AddOn's macro, kept in place")
    -- A demon that knows Seduction.
    state.env.C_SpellBook.IsSpellKnown = function(id, bank) return bank == 1 and id == 6358 or id == 5782 or id == 710 end
    state.combat = true
    emit(state, "UNIT_PET", "player")
    equal(state.toolkit.FocusCastMacro({spell = 6358}) ~= nil, true)
    for _, macro in ipairs(state.macros) do byName[macro.name] = macro.body end
    equal(byName["! Seduction"], nil, "in combat it waits")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    byName = {}
    for _, macro in ipairs(state.macros) do byName[macro.name] = macro.body end
    contains(byName["! Seduction"], "/use [@focus,exists,harm,nodead,pet:Succubus/Incubus] Seduction")
    store.macros = false
    tracker:Refresh()
    equal(#state.macros, 0, "off deletes them")
end)

test("a class Tools AddOn owns its class over Dyre's Debuff Tracker: bars, macros, announcements", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-1", "Grunt")})
    state.focusWorks(true)
    state.group = true
    local wtf, wtfStore = warlockTracker(state)
    local ddt = warlockTracker(state, {addon = "DyresDebuffTracker", priority = 5,
        names = {row = "DyresDebuffTrackerControlRow", click = "DyresDebuffTrackerControlClick"}})
    equal(ddt:IsOwner("control"), false)
    equal(ddt:Owner("macros"), "WarlockToolsForever")
    cast(state, "Grunt", 5782, "c1")
    equal(wtf.rows[1].guid, "Creature-1")
    equal(ddt.rows[1].guid, nil, "one bar only")
    equal(#state.sent, 1, "one announcement only")
    wtfStore.enabled = false
    wtf:Refresh()
    equal(ddt:IsOwner("control"), true, "WTF's bar off: the Debuff Tracker's shows")
    equal(wtf.rows[1].shown, false)
end)

local function mageTracker(state, extra)
    local store = {enabled = true, macros = true}
    local spec = {addon = "MageToolsForever", priority = 10, class = "MAGE", store = store, rows = 1,
        names = {row = {"MageToolsForeverPolymorphBar"}, click = {"MageToolsForeverPolymorph"}},
        markerFor = function() return store.mark ~= false and 5 or 0 end,
        find = {"focus", "target", "plates"},
        lock = {units = {"focus", "mouseover", "target"}, stopAt = {mouseover = true}},
        focusLock = {units = {"focus"}}, countdown = true, clickThrough = true, look = {color = {0.75, 0.45, 0.95},
            label = true}, locked = function() return state.locked ~= false end,
        announce = {text = function(key) return key == "polymorph" and "Sheeping %T" or nil end},
        keeper = {owned = {}}}
    for key, value in pairs(extra or {}) do spec[key] = value end
    local tracker, missing = state.toolkit.CreateControlTracker(spec)
    assert(tracker, tostring(missing))
    return tracker, store
end

test("MTF's Polymorph bar: one row, its exact names, and a new sheep replaces the old", function()
    local state = fixture()
    controlWorld(state, {focus = mob("Creature-1", "Boar")})
    state.focusWorks(true)
    local tracker = mageTracker(state)
    assert(state.named.MageToolsForeverPolymorph and state.named.MageToolsForeverPolymorphBar, "exact names")
    cast(state, "Boar", 118, "c1")
    equal(tracker.rows[1].guid, "Creature-1")
    equal(tracker.rows[1].holder.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Polymorph")
    state.units.focus = mob("Creature-2", "Wolf")
    cast(state, "Wolf", 28272, "c2")
    equal(tracker.rows[1].guid, "Creature-2", "the next sheep at your focus")
    equal(tracker.rows[1].holder.attributes.macrotext1, "/use [@focus,exists,harm,nodead] Polymorph: Pig")
    equal(tracker.rows[1].holder.mouse, true, "a sheep to click")
    local byName = {}
    for _, macro in ipairs(state.macros) do byName[macro.name] = macro.body end
    equal(byName["! Polymorph"], "#showtooltip Polymorph\n/focus [@mouseover,harm,nodead][nocombat,harm,nodead]\n"
        .. "/tm [@focus,harm,nodead,exists] !5\n/use [@focus,exists,harm,nodead] Polymorph", "MTF 1.2.3's macro")
end)

test("MTF without focus: the chain locks the mob, and with no unit the name counts the time down", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-5", "Boar"), mouseover = mob("Creature-6", "Wolf")})
    state.focusWorks(false)
    local tracker = mageTracker(state)
    cast(state, "Boar", 118, "c1")
    equal(tracker.rows[1].guid, nil, "a mouseover is there: only the mouseover counts (MTF's chain)")
    state.units.mouseover = nil
    state.auras.target = {{spellId = 118, expirationTime = 150}}
    cast(state, "Boar", 118, "c2")
    local row = tracker.rows[1]
    equal(row.guid, "Creature-5")
    equal(row.boundUnit, "target")
    equal(row.holder.attributes.macrotext1, nil, "no click without a focus")
    equal(row.holder.mouse, false, "clicks pass through while locked")
    equal(row.holder.shown, true, "the holder stays with the bar")
    state.units.target = nil
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(row.boundUnit, "none")
    equal(row.name.text, "Boar  |cff999999" .. "50 s|r")
    advance(state, 1)
    equal(row.name.text, "Boar  |cff999999" .. "49 s|r", "counts down while no unit shows it")
    equal(#state.timers > 0, true)
    advance(state, 60)
    equal(row.guid, nil, "forgotten after the longest Polymorph plus 5 s")
    local before = #state.timers
    advance(state, 1)
    equal(#state.timers <= before, true, "the countdown stops on its own")
end)

test("a counted-down mob whose nameplate comes into view drops its countdown text at once", function()
    local state = fixture()
    controlWorld(state, {target = mob("Creature-5", "Boar")})
    state.focusWorks(false)
    local tracker = mageTracker(state)
    state.auras.target = {{spellId = 118, expirationTime = 150}}
    cast(state, "Boar", 118, "c1")
    local row = tracker.rows[1]
    state.units.target = nil
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(row.name.text, "Boar  |cff999999" .. "50 s|r")
    state.units.nameplate1 = mob("Creature-5", "Boar")
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(row.boundUnit, "nameplate1")
    equal(row.name.text, "Boar", "no countdown once a unit shows the mob, before the next tick")
end)

test("ApplyLook resizes the rows at once, also in combat, and rebuilds no engine slot", function()
    local state = fixture()
    controlWorld(state, {focus = mob("Creature-1", "Boar")})
    state.focusWorks(true)
    local tracker = mageTracker(state)
    local frames = #state.uiFrames
    local width = tracker.rows[1].width
    state.inCombat = true
    tracker:ApplyLook()
    equal(#state.uiFrames, frames, "no new frame")
    equal(tracker.rows[1].width, width, "same look, same size")
    state.inCombat = false
end)

test("without either aura engine the tracker stays off and says what is missing", function()
    local state = fixture()
    controlWorld(state)
    state.env.C_UnitAuras = nil
    local tracker, missing = state.toolkit.CreateControlTracker({addon = "X", store = {}, class = "WARLOCK",
        names = {row = "R", click = "C"}})
    equal(tracker, nil)
    contains(missing, "CustomAuraContainerTemplate")
end)

-- Engine stage C (2.5.0): the DoT tracker, the plate dots, the prediction --------------

local DOT_NAMES = {[172] = "Corruption", [6222] = "Corruption", [348] = "Immolate", [980] = "Curse of Agony",
    [603] = "Curse of Doom", [702] = "Curse of Weakness", [18265] = "Siphon Life", [5782] = "Fear"}

-- WTF's db.tracker at its defaults, as the owner repairs it.
local function trackerStore(extra)
    local store = {enabled = true, theme = "bars", order = {"curse", "bane", "corruption", "immolate", "siphon", "control"},
        sizes = {compact = {iconSize = 22, nameWidth = 110, textScale = 100, namePosition = "left"},
            bars = {barWidth = 290, lineHeight = 16, textScale = 100, namePosition = "above"}},
        health = false, healthText = "none", panelOpacity = {target = 100, focus = 100, list = 100}, sections = {},
        onPlates = {curse = true, bane = true, corruption = true, immolate = true, siphon = true},
        plateDots = true, plateDotsOffset = 50, plateDotsOpacity = 100}
    for key, value in pairs(extra or {}) do store[key] = value end
    return store
end

local function dotWorld(state, units, known)
    local env = controlWorld(state, units)
    spellbook(state, {names = DOT_NAMES, book = known or {{172, "Corruption"}, {348, "Immolate"}, {980, "Curse of Agony"}}})
    env.Enum.StatusBarTimerDirection = {RemainingTime = 1}
    env.C_Spell.GetSpellTexture = function() return 136183 end
    return env
end

local function dotTracker(state, extra)
    local store = trackerStore(extra and extra.store)
    local saved = {}
    local spec = {addon = "WarlockToolsForever", priority = 10, class = "WARLOCK", store = store,
        names = {target = "WarlockToolsForeverTracker", focus = "WarlockToolsForeverTrackerFocus",
            list = "WarlockToolsForeverTrackerList"},
        locked = function() return state.locked ~= false end,
        movable = {register = function(frame, save) saved[frame] = save end}}
    for key, value in pairs(extra or {}) do
        if key ~= "store" then spec[key] = value end
    end
    local tracker, missing = state.toolkit.CreateDotTracker(spec)
    assert(tracker, tostring(missing))
    return tracker, store, saved
end

test("the DoT tracker keeps WTF's three section names and its pinned recasts", function()
    local state = fixture()
    dotWorld(state)
    local tracker, store, saved = dotTracker(state)
    for _, name in ipairs({"WarlockToolsForeverTracker", "WarlockToolsForeverTrackerFocus",
        "WarlockToolsForeverTrackerList"}) do
        assert(state.named[name], name)
    end
    equal(tracker.sections.focus, state.named.WarlockToolsForeverTrackerFocus)
    -- One slot per family you know, in the saved order: Bane, Corruption, Immolate.
    equal(#tracker.shown, 3)
    local macros = {}
    for _, button in pairs(tracker.pinned.target.casts) do macros[#macros + 1] = button.attributes.macrotext1 end
    table.sort(macros)
    equal(table.concat(macros, "|"), "/use [@target,harm,nodead] Corruption|/use [@target,harm,nodead] Curse of Agony|"
        .. "/use [@target,harm,nodead] Immolate")
    local focusCast = next(tracker.pinned.focus.casts) and select(2, next(tracker.pinned.focus.casts))
    contains(focusCast.attributes.macrotext1, "[@focus,exists,harm,nodead]")
    equal(state.drivers[tracker.pinned.target], "[@target,harm,nodead] show; hide")
    saved[tracker.sections.list]({point = "TOP", relativePoint = "TOP", x = 1, y = 2})
    equal(store.sections.list.x, 1, "a drag saves into the owner's table")
    equal(state.toolkit.CreateDotTracker({addon = "X"}), nil)
end)

test("a DoT lists the mob it was aimed at as it started, not the one you tabbed to", function()
    local state = fixture()
    local first = mob("Creature-1", "Grunt")
    dotWorld(state, {target = first, nameplate1 = first})
    local tracker = dotTracker(state)
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", "c1", 172)
    state.units.target = mob("Creature-2", "Grunt")
    emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "c1", 172)
    local row = tracker.rows[1]
    equal(row.guid, "Creature-1")
    equal(row.boundUnit, "nameplate1", "its nameplate first")
    equal(row.shown, true, "listed: not your target any more")
    equal(row.name.text, "Grunt")
    contains(tracker:DebugLines()[1], "owner=WarlockToolsForever")
    -- Your target is never listed twice.
    state.units.target = first
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(row.shown, false)
end)

test("a DoT row goes with its mob's death, after combat, and out of combat when unseen 10 s", function()
    local state = fixture()
    dotWorld(state, {nameplate1 = mob("Creature-1", "Grunt"), mouseover = mob("Creature-3", "Imp")})
    local tracker = dotTracker(state)
    cast(state, "Grunt", 172, "c1")
    equal(tracker.rows[1].guid, "Creature-1")
    state.units.nameplate1.dead = true
    emit(state, "UNIT_HEALTH", "nameplate1")
    equal(tracker.rows[1].guid, nil, "dead")
    cast(state, "Grunt", 348, "c2")
    equal(tracker.rows[1].guid, nil, "a dead mob is not listed again until combat ends")
    emit(state, "PLAYER_REGEN_ENABLED")
    cast(state, "Imp", 172, "c3")
    local row = tracker.rows[1]
    equal(row.guid, "Creature-3")
    state.units.mouseover = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate9")
    equal(row.boundUnit, "none")
    advance(state, 11)
    equal(row.guid, nil, "unseen out of combat")
end)

-- Instances: creature GUIDs are secret (WTF player reports, 2026-11).
test("secret GUIDs: a DoT lists the mob by its plate, leaves out your target, and goes with the plate", function()
    local state = fixture()
    local grunt, orc = mob(SECRET, "Grunt"), mob(SECRET, "Orc")
    dotWorld(state, {target = grunt, nameplate1 = grunt, nameplate2 = orc})
    local tracker = dotTracker(state)
    cast(state, "Grunt", 172, "c1")
    local row = tracker.rows[1]
    equal(row.guid, "plate:nameplate1")
    equal(row.boundUnit, "nameplate1", "the engine reads its auras through the plate")
    equal(row.shown, false, "your target has its pinned row")
    cast(state, "Grunt", 348, "c2")
    equal(tracker.rows[2].guid, nil, "a second DoT, the same row")
    state.units.target = orc
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(row.shown, true, "listed once you tab away")
    equal(row.name.text, "Grunt")
    cast(state, "Orc", 172, "c3")
    equal(tracker.rows[2].guid, "plate:nameplate2")
    equal(tracker.rows[2].shown, false)
    local text = table.concat(tracker:DebugLines(), "\n")
    contains(text, "slot=corruption mob=plate")
    contains(text, "name=Grunt key=plate unit=nameplate1")
    -- The token may show another mob next, so the row goes now.
    state.units.nameplate1 = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(row.guid, nil, "gone with its plate")
    equal(row.shown, false)
    state.units.nameplate1 = mob(SECRET, "Imp")
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(row.guid, nil, "the new mob on that token is not listed")
    equal(tracker.rows[2].guid, "plate:nameplate2", "another plate's row stays")
end)

test("secret GUIDs: the target's plate comes from GetNamePlateForUnit while UnitIsUnit is secret", function()
    local state = fixture()
    local env = dotWorld(state, {target = mob(SECRET, "Grunt"), nameplate7 = mob(SECRET, "Grunt")})
    env.UnitIsUnit = function() return SECRET end
    state.plateFrames.target = {namePlateUnitToken = "nameplate7"}
    equal(state.toolkit.PlateToken("target"), "nameplate7")
    equal(state.toolkit.MobKey("target"), "plate:nameplate7")
    state.plateFrames.target = {UnitFrame = {unit = "nameplate7"}}
    equal(state.toolkit.PlateToken("target"), "nameplate7", "the plate's unit frame")
    state.plateFrames.target = {namePlateUnitToken = "nameplate7", IsForbidden = function() return true end}
    equal(state.toolkit.PlateToken("target"), nil, "a forbidden plate is not read")
    state.plateFrames.target = {namePlateUnitToken = SECRET}
    equal(state.toolkit.PlateToken("target"), nil, "a secret token is not read")
    env.C_NamePlate.GetNamePlateForUnit = function() error("not allowed") end
    equal(state.toolkit.PlateToken("target"), nil, "an error is no plate")
    equal(state.toolkit.FindUnit("plate:nameplate7"), "nameplate7")
    equal(state.toolkit.FindUnit("plate:nameplate8"), nil, "no plate now")
    equal(state.toolkit.KeyPlate("Creature-1"), nil)
end)

test("secret GUIDs: no plate lists nothing; the plate memory's GUID is the mob's key", function()
    local state = fixture()
    local grunt = mob(SECRET, "Grunt")
    dotWorld(state, {target = grunt})
    local tracker = dotTracker(state)
    cast(state, "Grunt", 172, "c1")
    equal(tracker.rows[1].guid, nil, "enemy nameplates off: only the pinned row shows it")
    contains(table.concat(tracker:DebugLines(), "\n"), "mob=none")
    state.units.nameplate1 = grunt
    state.toolkit.LearnPlate("nameplate1")
    equal(state.toolkit.PlateGUID("nameplate1"), nil)
    state.units.focus = mob("Creature-5", "Orc")
    state.units.nameplate2 = mob(SECRET, "Orc", {same = "focus"})
    state.toolkit.LearnPlate("nameplate2")
    equal(state.toolkit.MobKey("nameplate2"), "Creature-5", "a real GUID when one is known")
end)

test("secret GUIDs: a secret name goes to your target, and its text takes the secret", function()
    local state = fixture()
    local grunt = mob(SECRET, SECRET)
    dotWorld(state, {target = grunt, nameplate1 = grunt})
    local tracker = dotTracker(state)
    cast(state, SECRET, 172, "c1")
    local row = tracker.rows[1]
    equal(row.guid, "plate:nameplate1")
    state.units.target = nil
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(rawequal(row.name.text, SECRET), true)
    contains(table.concat(tracker:DebugLines(), "\n"), "name=secret key=plate")
    -- A readable name for the cast, with your target's secret: the same.
    state.units.target = mob(SECRET, SECRET)
    state.units.nameplate2 = state.units.target
    cast(state, "Orc", 172, "c2")
    equal(tracker.rows[2].guid, "plate:nameplate2")
    equal(rawequal(tracker.rows[2].mobName, SECRET), true, "the name your target shows")
end)

test("secret GUIDs: a death frees the row and never bars the token; a cast dies with its plate", function()
    local state = fixture()
    local grunt = mob(SECRET, "Grunt")
    dotWorld(state, {target = grunt, nameplate1 = grunt})
    local tracker = dotTracker(state)
    cast(state, "Grunt", 172, "c1")
    grunt.dead = true
    emit(state, "UNIT_HEALTH", "nameplate1")
    equal(tracker.rows[1].guid, nil, "dead")
    local next_mob = mob(SECRET, "Grunt")
    state.units.target, state.units.nameplate1 = next_mob, next_mob
    cast(state, "Grunt", 172, "c2")
    equal(tracker.rows[1].guid, "plate:nameplate1", "the token shows a new mob now")
    emit(state, "PLAYER_REGEN_ENABLED")
    equal(tracker.rows[1].guid, nil, "combat ended")
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", "c3", 172)
    state.units.nameplate1 = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    state.units.nameplate1 = mob(SECRET, "Imp")
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "c3", 172)
    equal(tracker.rows[1].guid, nil, "the token now shows another mob")
end)

test("secret GUIDs: a pinned row's prediction asks the predictor for the mob's key", function()
    local state = fixture()
    local grunt = mob(SECRET, "Grunt")
    local env = dotWorld(state, {target = grunt, nameplate1 = grunt})
    env.UnitHealth = function() return SECRET end
    env.UnitHealthMax = function() return SECRET end
    local seen
    local stubPredictor = {Available = function() return true end, Key = function() return "plate:nameplate1" end,
        DrawRow = function(_, _, guid) seen = guid or seen return false end}
    dotTracker(state, {predictor = stubPredictor, store = {health = true}})
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(seen, "plate:nameplate1")
end)

test("secret GUIDs: the control bar keeps a Banish by its plate, and a focus row through plate changes", function()
    local state = fixture()
    local grunt = mob(SECRET, "Grunt")
    controlWorld(state, {target = grunt, nameplate1 = grunt})
    state.focusWorks(false)
    local tracker = warlockTracker(state)
    cast(state, "Grunt", 710, "c1")
    local row = tracker.rows[1]
    equal(row.guid, "plate:nameplate1")
    equal(row.boundUnit, "nameplate1")
    grunt.dead = true
    emit(state, "UNIT_HEALTH", "nameplate1")
    equal(row.guid, nil, "dead")
    grunt.dead = false
    cast(state, "Grunt", 710, "c2")
    equal(row.guid, "plate:nameplate1")
    state.units.nameplate1 = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(row.guid, nil, "gone with its plate")
    state.units.nameplate1 = grunt
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    emit(state, "UNIT_SPELLCAST_SENT", "player", "Grunt", "c3", 710)
    state.units.nameplate1 = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    emit(state, "UNIT_SPELLCAST_SUCCEEDED", "player", "c3", 710)
    equal(row.guid, nil, "the plate went during the cast")

    state.focusWorks(true)
    state.units.target = nil
    state.units.focus, state.units.nameplate2 = grunt, grunt
    cast(state, "Grunt", 710, "c4")
    equal(row.guid, "plate:nameplate2")
    equal(row.boundUnit, "focus")
    state.units.nameplate2 = nil
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate2")
    equal(row.guid, "plate:nameplate2", "your focus left its plate, not you")
    state.units.nameplate5 = grunt
    emit(state, "NAME_PLATE_UNIT_ADDED", "nameplate5")
    equal(row.guid, "plate:nameplate2", "back under another token: the same focus")
    state.units.focus = mob(SECRET, "Orc")
    emit(state, "PLAYER_FOCUS_CHANGED")
    equal(row.guid, nil, "a new focus ends it")
end)

test("a Bane cast is remembered in the owner's store, and the pinned slot recasts it", function()
    local state = fixture()
    dotWorld(state, {target = mob("Creature-1", "Grunt")}, {{980, "Curse of Agony"}, {603, "Curse of Doom"}})
    local tracker, store = dotTracker(state)
    cast(state, "Grunt", 603, "c1")
    equal(store.lastBane, "Curse of Doom")
    local recast
    for _, button in pairs(tracker.pinned.target.casts) do
        if button.spellName == "Curse of Doom" then recast = button end
    end
    assert(recast, "the Bane slot recasts the last one")
    equal(recast.attributes.macrotext1, "/use [@target,harm,nodead] Curse of Doom")
end)

test("a rebuild in combat waits; the tracker never changes a secure row in combat", function()
    local state = fixture()
    dotWorld(state)
    local tracker, store = dotTracker(state)
    local before = tracker.pinned.target
    state.combat = true
    store.theme = "compact"
    tracker:Rebuild()
    equal(tracker.pinned.target, before, "not yet")
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    assert(tracker.pinned.target ~= before, "rebuilt when combat ends")
    equal(tracker.theme, "compact")
end)

test("the pinned rows' outline width: 3 px by default, 0 draws none, at most 20, the stack follows", function()
    local state = fixture()
    dotWorld(state)
    local tracker, store = dotTracker(state)
    equal(state.toolkit.TRACKER_OUTLINE.default, 3)
    assert(tracker.pinned.target.outline and tracker.pinned.focus.outline, "an outline by default")
    local defaultHeight = tracker.stack.height
    store.outlineWidth = 0
    tracker:Rebuild()
    equal(tracker.pinned.target.outline, nil, "0 draws no outline")
    equal(tracker.pinned.focus.outline, nil)
    equal(tracker.stack.height, defaultHeight - 2 * 3, "the rows close up by the outline")
    store.outlineWidth = 99
    tracker:Rebuild()
    assert(tracker.pinned.target.outline, "an outline again")
    equal(tracker.stack.height, defaultHeight + 2 * 17, "clamped to 20 px")
    store.outlineWidth = "junk"
    tracker:Rebuild()
    equal(tracker.stack.height, defaultHeight, "a bad value is the default")
end)

test("Dyre's Debuff Tracker's DoT tracker steps aside for the class AddOn's", function()
    local state = fixture()
    dotWorld(state, {nameplate1 = mob("Creature-1", "Grunt")})
    local wtf, wtfStore = dotTracker(state)
    local ddt = dotTracker(state, {addon = "DyresDebuffTracker", priority = 5,
        names = {target = "DDTTarget", focus = "DDTFocus", list = "DDTList"}})
    equal(ddt:IsOwner(), false)
    equal(ddt.sections.target.shown, false, "hidden")
    cast(state, "Grunt", 172, "c1")
    equal(wtf.rows[1].guid, "Creature-1")
    equal(ddt.rows[1].guid, nil, "one tracker only")
    wtfStore.enabled = false
    wtf:Refresh()
    equal(ddt:IsOwner(), true)
    equal(ddt.sections.target.shown, true)
end)

test("mob health on a row: the predictor draws the damage to come with the row's health", function()
    local state = fixture()
    local grunt = mob("Creature-1", "Grunt")
    dotWorld(state, {nameplate1 = grunt})
    state.env.UnitHealth = function() return 300 end
    state.env.UnitHealthMax = function() return 500 end
    local drawn = {}
    local predictor = {Available = function() return true end,
        DrawRow = function(_, bar, guid, health) drawn[#drawn + 1] = tostring(guid) .. ":" .. tostring(health); return false end,
        SetTracker = function(self, tracker) self.tracker = tracker end}
    local tracker = dotTracker(state, {store = {health = true, healthText = "both"}, predictor = predictor})
    equal(predictor.tracker, tracker, "the predictor redraws these rows")
    cast(state, "Grunt", 172, "c1")
    equal(drawn[#drawn], "Creature-1:300")
    equal(tracker.rows[1].knownHealth.health, 300, "kept for when no unit shows it")
    tracker:RefreshPrediction("Creature-1")
    equal(drawn[#drawn], "Creature-1:300")
end)

test("with a secret health a row keeps its numbers, and DIES goes just left of them", function()
    local state = fixture()
    dotWorld(state, {nameplate1 = mob("Creature-1", "Grunt")})
    local health = 300
    state.env.UnitHealth = function() return health end
    state.env.UnitHealthMax = function() return 500 end
    local places = {}
    local predictor = {Available = function() return true end, SetTracker = function() end,
        DrawRow = function(_, _, _, _, place, secretPlace)
            places.place, places.secret = place, secretPlace
            return false
        end}
    local tracker = dotTracker(state, {store = {health = true, healthText = "both"}, predictor = predictor})
    cast(state, "Grunt", 172, "c1")
    local row = tracker.rows[1]
    equal(places.place[2], row.healthNumber, "readable: in place of the number")
    equal(places.secret[1], "RIGHT")
    equal(places.secret[2], row.healthPercent, "secret: left of the first text")
    equal(places.secret[3], "LEFT")
end)

test("plate dots: a bubble per live hostile plate in combat, one dot per known DoT you chose", function()
    local state = fixture()
    dotWorld(state, {nameplate1 = mob("Creature-1", "Grunt")})
    state.env.UnitAffectingCombat = function() return false end
    state.plateFrames.nameplate1 = uiFrame(state, "Frame", nil, state.UIParent)
    local tracker, store = dotTracker(state)
    local dots = assert(state.toolkit.CreatePlateDots({tracker = tracker, store = store}))
    local bubble = dots.byUnit.nameplate1
    assert(bubble, "attached")
    equal(bubble.parent, state.plateFrames.nameplate1)
    equal(#dots.known, 3, "Bane, Corruption, Immolate")
    equal(bubble.shown, false, "out of combat")
    emit(state, "PLAYER_REGEN_DISABLED")
    equal(bubble.shown, true)
    state.units.nameplate1.dead = true
    emit(state, "UNIT_HEALTH", "nameplate1")
    equal(bubble.shown, false, "a dead mob")
    store.plateDotsOpacity = 40
    dots:ApplyOpacity()
    equal(bubble.alpha, 0.4)
    store.onPlates.corruption = false
    dots:Refresh()
    equal(#dots.known, 2)
    store.plateDots = false
    dots:Refresh()
    equal(dots.byUnit.nameplate1, nil, "switched off")
end)

-- The combat log, as the client gives it: one event at a time.
-- The smart curse (2.7.0) ---------------------------------------------------------------

local CURSE_BOOK = {{702, "Curse of Weakness"}, {1714, "Curse of Tongues"}, {1490, "Curse of the Elements"},
    {704, "Curse of Recklessness"}, {172, "Corruption"}}

local function curseWorld(state, units, book)
    local env = dotWorld(state, units, book or CURSE_BOOK)
    local names = {}
    for id, name in pairs(DOT_NAMES) do names[id] = name end
    for _, item in ipairs(CURSE_BOOK) do names[item[1]] = item[2] end
    env.C_Spell.GetSpellName = function(id) return names[id] end
    env.UnitPowerType = function(unit) return state.units[unit] and state.units[unit].power end
    env.UnitPowerMax = function(unit) return state.units[unit] and state.units[unit].mana end
    return env
end

local function curseButton(tracker, key)
    for slotIndex, button in pairs(tracker.pinned[key].casts) do
        if button.mark then return button, slotIndex end
    end
end

test("the smart curse macro: modifiers first, then the pick; only known curses", function()
    local state = fixture()
    curseWorld(state, {target = mob("Creature-1", "Shaman", {power = 0, mana = 500})})
    local toolkit = state.toolkit
    local all = {weakness = "Curse of Weakness", tongues = "Curse of Tongues", elements = "Curse of the Elements",
        recklessness = "Curse of Recklessness"}
    equal(toolkit.SmartCurseMacro(all, nil), "/use [mod:alt] Curse of Recklessness; [mod:shift] Curse of Weakness; "
        .. "[mod:ctrl] Curse of Tongues; Curse of the Elements")
    equal(toolkit.SmartCurseMacro(all, "Curse of Tongues", "focus"),
        "/use [@focus,exists,harm,nodead,mod:alt] Curse of Recklessness; [@focus,exists,harm,nodead,mod:shift] "
        .. "Curse of Weakness; [@focus,exists,harm,nodead,mod:ctrl] Curse of Tongues; "
        .. "[@focus,exists,harm,nodead] Curse of Tongues")
    equal(toolkit.SmartCurseMacro({weakness = "Curse of Weakness"}),
        "/use [mod:shift] Curse of Weakness; [mod:ctrl] Curse of Weakness; Curse of Weakness",
        "Weakness alone: every click is Weakness")
    equal(toolkit.SmartCurseMacro({tongues = "Curse of Tongues"}), nil, "nothing without Weakness")
    equal(toolkit.SmartCursePick(all, "target"), "Curse of Tongues", "a mob with mana")
    state.units.target.power = 1
    equal(toolkit.SmartCursePick(all, "target"), "Curse of the Elements", "a mob with rage")
    state.units.target.power, state.units.target.mana = 0, 0
    equal(toolkit.SmartCursePick(all, "target"), "Curse of the Elements", "a mana bar with no mana")
    state.units.target.power = SECRET
    equal(toolkit.UnitHasMana("target"), nil, "secret: unknown")
    equal(toolkit.SmartCursePick(all, "target"), "Curse of the Elements", "unknown: the default")
    equal(toolkit.SmartCursePick({weakness = "Curse of Weakness"}, "target"), "Curse of Weakness")
end)

test("smart mode: the pinned Curse slot picks by mob out of combat, and the marker follows in combat", function()
    local state = fixture()
    curseWorld(state, {target = mob("Creature-1", "Shaman", {power = 0, mana = 500})})
    local bodies = {}
    local tracker, store = dotTracker(state, {store = {curseMode = "smart", lastCurse = "Curse of Weakness"},
        names = {target = "T", focus = "F", list = "L", smartCurse = "WarlockToolsForeverSmartCurse"},
        onSmartCurse = function(body) bodies[#bodies + 1] = body end})
    local button = curseButton(tracker, "target")
    assert(button, "a marker on the Curse slot")
    contains(button.attributes.macrotext1, "[@target,harm,nodead] Curse of Tongues", "a caster gets Tongues")
    contains(button.attributes.macrotext1, "[@target,harm,nodead,mod:alt] Curse of Recklessness")
    equal(button.mark.text, "T")
    local key = state.named.WarlockToolsForeverSmartCurse
    equal(key.shown, false, "the keybind's button never shows")
    equal(key.attributes.macrotext1, "#showtooltip\n/use [mod:alt] Curse of Recklessness; [mod:shift] Curse of "
        .. "Weakness; [mod:ctrl] Curse of Tongues; Curse of Tongues")
    equal(bodies[#bodies], key.attributes.macrotext1, "the owner gets the macro body")
    equal(tracker:SmartCurseBody(), key.attributes.macrotext1)
    -- In combat, a melee mob: the marker changes, the secure click waits.
    state.combat = true
    state.units.target = mob("Creature-2", "Grunt", {power = 1})
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(button.mark.text, "E", "the marker reads the mob in combat")
    contains(button.attributes.macrotext1, "[@target,harm,nodead] Curse of Tongues", "no secure change in combat")
    local count = #bodies
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    contains(button.attributes.macrotext1, "[@target,harm,nodead] Curse of the Elements", "set when combat ends")
    equal(#bodies, count + 1, "one new macro body")
    -- The same pick again rewrites nothing.
    state.units.target = mob("Creature-3", "Grunt", {power = 1})
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(#bodies, count + 1)
    -- Last-used mode: the slot recasts the last curse; no marker.
    store.curseMode = "last"
    tracker:ApplySmartCurse()
    equal(button.attributes.macrotext1, "/use [@target,harm,nodead] Curse of Weakness")
    equal(button.mark.text, "")
    -- The marker can be turned off in smart mode.
    store.curseMode, store.curseMarker = "smart", false
    tracker:ApplySmartCurse()
    equal(button.mark.text, "")
end)

test("no Curse of Weakness: no smart curse, no macro body, no keybind click", function()
    local state = fixture()
    curseWorld(state, {target = mob("Creature-1", "Grunt")}, {{1714, "Curse of Tongues"}, {172, "Corruption"}})
    local bodies = {}
    local tracker = dotTracker(state, {store = {curseMode = "smart", lastCurse = "Curse of Tongues"},
        names = {target = "T", focus = "F", list = "L", smartCurse = "SmartKey"},
        onSmartCurse = function(body) bodies[#bodies + 1] = tostring(body) end})
    equal(tracker:SmartCurseBody(), nil)
    equal(state.named.SmartKey.attributes.macrotext1, nil)
    equal(#bodies, 0, "never told: there is no macro to write")
    local button = curseButton(tracker, "target")
    equal(button.attributes.macrotext1, "/use [@target,harm,nodead] Curse of Tongues", "the last-used rule")
end)

local function combatLog(state)
    local env = state.env
    state.cleu = {}
    env.C_CombatLog = {GetCurrentEventInfo = function() return unpack(state.cleu) end,
        IsCombatLogRestricted = function() return state.restricted == true end}
    state.log = function(subevent, source, dest, spellID, amount)
        state.cleu = {state.now, subevent, false, source, "Me", 0, 0, dest, "Grunt", 0, 0, spellID,
            DOT_NAMES[spellID], 1, amount}
        emit(state, "COMBAT_LOG_EVENT_UNFILTERED")
    end
end

local function predictWorld(state)
    dotWorld(state, {player = {guid = "Player-1", name = "Me"}, target = mob("Creature-1", "Grunt")})
    combatLog(state)
    state.env.TargetFrame = nil
end

local function predictor(state, extra)
    local store = {enabled = true, plates = true, dies = true, fill = "stripes", opacity = 70, outline = "solid"}
    local spec = {addon = "WarlockToolsForever", priority = 10, class = "WARLOCK", store = store}
    for key, value in pairs(extra or {}) do spec[key] = value end
    local made, why = state.toolkit.CreateDotPredictor(spec)
    assert(made, tostring(why))
    return made, store
end

test("the predictor learns each DoT's tick from the combat log and saves it for the toolkit", function()
    local state = fixture()
    predictWorld(state)
    local made = predictor(state)
    state.log("SPELL_AURA_APPLIED", "Player-1", "Creature-1", 172, "DEBUFF")
    -- Corruption rank 1: 40 over 12 s, 4 ticks; learned at level 4 with no spell power.
    equal(made:PredictedDamage("Creature-1"), 40)
    state.now = state.now + 3
    state.log("SPELL_PERIODIC_DAMAGE", "Player-1", "Creature-1", 172, 12)
    equal(made:PredictedDamage("Creature-1"), 36, "3 ticks of the learned 12")
    equal(state.toolkit.LearnedTicks()[172].tick, 12, "in DyresToolkitDB.ticks")
    equal(state.toolkit.HealthBars.GetPredictedDamage("Creature-1"), 36, "the active HealthBars source")
    state.log("SPELL_PERIODIC_DAMAGE", "Player-2", "Creature-1", 172, 999)
    equal(made:PredictedDamage("Creature-1"), 36, "someone else's DoT never counts")
    state.log("UNIT_DIED", "", "Creature-1", 0)
    equal(made:PredictedDamage("Creature-1"), 0, "dead")
    contains(table.concat(made:DebugLines(), "|"), "No DoTs of yours")
end)

test("Curse of Agony's ramp comes from the class data's weights", function()
    local state = fixture()
    predictWorld(state)
    local made = predictor(state)
    state.log("SPELL_AURA_APPLIED", "Player-1", "Creature-1", 980, "DEBUFF")
    -- 84 over 24 s: four ticks of 3.5, four of 7, four of 10.5.
    equal(made:PredictedDamage("Creature-1"), 84)
    state.now = state.now + 2
    state.log("SPELL_PERIODIC_DAMAGE", "Player-1", "Creature-1", 980, 3.5)
    -- A first tick of 3.5 at weight 0.5 stands for an average of 7: the rest
    -- is 3 x 3.5 + 4 x 7 + 4 x 10.5 = 80.5.
    equal(made:PredictedDamage("Creature-1"), 81)
    equal(state.toolkit.LearnedTicks()[980].tick, 7, "saved as the average it stands for")
end)

test("WTF's older ticks are copied once, never over a newer one; unknown ranks are dropped", function()
    local state = fixture()
    predictWorld(state)
    predictor(state, {legacyTicks = {[172] = {tick = 11, power = 0}, [99999] = {tick = 5, power = 0},
        [348] = {tick = -1, power = 0}}})
    local ticks = state.toolkit.LearnedTicks()
    equal(ticks[172].tick, 11)
    equal(ticks[99999], nil, "not a known rank")
    equal(ticks[348], nil, "repaired")
    ticks[172] = {tick = 14, power = 0}
    state.toolkit.HealthBars.SetSourceEnabled("WarlockToolsForever", false)
    local again = state.toolkit.CreateDotPredictor({addon = "WarlockToolsForever", priority = 10, class = "WARLOCK",
        store = {enabled = true}, legacyTicks = {[172] = {tick = 9, power = 0}}})
    assert(again)
    equal(state.toolkit.LearnedTicks()[172].tick, 14, "copied once only")
end)

test("where the combat log is restricted, hidden ticks; with neither, no predictor; none outside the family", function()
    local state = fixture()
    predictWorld(state)
    state.restricted = true
    local made = state.toolkit.CreateDotPredictor({addon = "WarlockToolsForever", class = "WARLOCK", store = {}})
    equal(made.hidden, true)
    local frame = state.uiFrames[#state.uiFrames]
    equal(frame.events.COMBAT_LOG_EVENT_UNFILTERED, nil, "never registered where restricted: the client's popup")
    equal(frame.events.UNIT_COMBAT, true)
    state.toolkit.HealthBars.SetSourceEnabled("WarlockToolsForever", false)
    local timers = state.env.C_Timer
    state.env.C_Timer = nil
    local why
    made, why = state.toolkit.CreateDotPredictor({addon = "DyresDebuffTracker", class = "WARLOCK", store = {}})
    equal(made, nil)
    equal(why, "the combat log")
    state.env.C_Timer = timers
    state.restricted = false
    familyAll(state.env, {Outsider = true})
    made, why = state.toolkit.CreateDotPredictor({addon = "Outsider", class = "WARLOCK", store = {}})
    equal(made, nil)
    contains(why, "Dyre's AddOns")
end)

-- Forever: no combat log, secret amounts; tooltips without spell power.
local TOOLTIPS = {
    [172] = "Corrupts the target, causing 40 Shadow damage over 12 sec.",
    [348] = "Burns the enemy for 11 Fire damage and then an additional 20 Fire damage over 15 sec.",
    [18265] = "Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec.",
}

local function hiddenWorld(state, units)
    dotWorld(state, units or {player = {guid = "Player-1", name = "Me"}, target = mob("Creature-1", "Grunt")})
    combatLog(state)
    state.restricted = true
    state.env.TargetFrame = nil
    state.env.C_Spell.GetSpellDescription = function(id) return TOOLTIPS[id] end
    state.env.UnitLevel = function() return 60 end
    state.hit = function(unit, action, amount, school)
        emit(state, "UNIT_COMBAT", unit, action, "", amount, school)
    end
end

local SHADOW, FIRE = 32, 4

test("the owner's DIES place and offsets reach the target frame's draw; auto is the toolkit's choice", function()
    local state = fixture()
    hiddenWorld(state)
    state.env.UnitHealth = function() return 1000 end
    local made, store = predictor(state)
    local bar = healthBar()
    state.toolkit.RegisterBarAdapter("unit", {name = "Test", bar = function() return bar end})
    local styles = {}
    state.toolkit.DrawPrediction = function(_, kind, _, _, style)
        styles[kind] = style
        return false
    end
    store.diesPlace, store.diesX, store.diesY = "center", 4, -2
    cast(state, "Grunt", 172, "Cast-1")
    made:Refresh()
    equal(styles.target.side, "center")
    equal(styles.target.x, 4)
    equal(styles.target.y, -2)
    store.diesPlace = "auto"
    made:Refresh()
    equal(styles.target.side, nil, "auto")
end)

test("Forever: a cast starts the DoT, its hidden ticks count it down, and its tooltip gives the damage", function()
    local state = fixture()
    hiddenWorld(state)
    local made = predictor(state)
    equal(made.hidden, true)
    cast(state, "Grunt", 172, "Cast-1")
    equal(made:PredictedDamage("Creature-1"), 40, "the tooltip's 40, 4 ticks of 10")
    state.now = state.now + 3.1
    state.hit("target", "WOUND", SECRET, SHADOW)
    equal(made:PredictedDamage("Creature-1"), 30, "a tick by school and time, its amount secret")
    state.hit("nameplate1", "WOUND", SECRET, SHADOW)
    equal(made:PredictedDamage("Creature-1"), 30, "no nameplate shows it: not ours to count")
    state.hit("target", "WOUND", SECRET, FIRE)
    state.now = state.now + 1
    state.hit("target", "WOUND", SECRET, SHADOW)
    equal(made:PredictedDamage("Creature-1"), 30, "another school, or off the rhythm: not a tick")
    equal(made.mobs["Creature-1"].dots.corruption.applied, 100.1, "the rhythm from the first tick")
    contains(table.concat(made:DebugLines(), "|"), "hidden ticks")
end)

test("Forever: a resist in the DoT's school drops it; a melee avoid or another school does not", function()
    local state = fixture()
    hiddenWorld(state)
    local made = predictor(state)
    cast(state, "Grunt", 348, "Cast-1")
    equal(made:PredictedDamage("Creature-1"), 20, "Immolate's periodic part only")
    state.hit("target", "DODGE", nil, 1)
    state.hit("target", "MISS", nil, SHADOW)
    equal(made:PredictedDamage("Creature-1"), 20)
    state.hit("target", "RESIST", nil, FIRE)
    equal(made:PredictedDamage("Creature-1"), 0, "resisted")
    cast(state, "Grunt", 172, "Cast-2")
    state.hit("target", "MISS", nil, SECRET)
    equal(made:PredictedDamage("Creature-1"), 0, "a secret school: doubtful, shown from its first tick")
    state.now = state.now + 3
    state.hit("target", "WOUND", SECRET, SHADOW)
    equal(made:PredictedDamage("Creature-1"), 30)
end)

test("Forever: missed ticks on a mob you see drop the DoT; a mob no unit shows keeps it", function()
    local state = fixture()
    hiddenWorld(state)
    local made = predictor(state)
    cast(state, "Grunt", 172, "Cast-1")
    advance(state, 3.5)
    equal(made:PredictedDamage("Creature-1"), 30, "one missed tick: still on")
    advance(state, 3)
    equal(made:PredictedDamage("Creature-1"), 0, "two: resisted, removed, or dead")
    cast(state, "Grunt", 172, "Cast-2")
    state.units.target = nil
    advance(state, 3.5)
    advance(state, 3)
    equal(made:PredictedDamage("Creature-1"), 20, "unseen: it runs on time")
    equal(made.mobs["Creature-1"].dots.corruption.unseen, true)
end)

test("Forever: a secret GUID tracks the mob by its nameplate, and the same hit on two tokens counts once", function()
    local state = fixture()
    local grunt = mob(SECRET, "Grunt")
    hiddenWorld(state, {player = {guid = "Player-1", name = "Me"}, target = grunt, nameplate1 = grunt})
    local made = predictor(state)
    cast(state, "Grunt", 172, "Cast-1")
    equal(made:PredictedDamage("plate:nameplate1"), 40)
    state.now = state.now + 3
    state.hit("target", "WOUND", SECRET, SHADOW)
    state.hit("nameplate1", "WOUND", SECRET, SHADOW)
    equal(made:PredictedDamage("plate:nameplate1"), 30, "once")
    emit(state, "NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(made:PredictedDamage("plate:nameplate1"), 0, "a token key goes with its plate")
    state.units.nameplate1 = nil
    cast(state, "Grunt", 172, "Cast-2")
    equal(made:PredictedDamage("target"), 40, "no plate: the target only")
    emit(state, "PLAYER_TARGET_CHANGED")
    equal(made:PredictedDamage("target"), 0)
end)

test("Forever: a mouseover cast goes on that mob, and is skipped when the mob has no key", function()
    local state = fixture()
    hiddenWorld(state, {player = {guid = "Player-1", name = "Me"}, target = mob("Creature-1", "Grunt"),
        mouseover = mob("Creature-2", "Wolf")})
    local made = predictor(state)
    cast(state, "Wolf", 172, "Cast-1")
    equal(made:PredictedDamage("Creature-2"), 40, "the mob under the mouse")
    equal(made:PredictedDamage("Creature-1"), 0)
    -- A secret GUID and no plate: no key, so the cast is not put on your target.
    state.units.mouseover = mob(SECRET, "Bear")
    cast(state, "Bear", 348, "Cast-2")
    equal(made:PredictedDamage("Creature-1"), 0, "never on your target")
end)

test("Forever: with a friendly or dead target, a cast at no named mob goes to the soft enemy", function()
    local state = fixture()
    hiddenWorld(state, {player = {guid = "Player-1", name = "Me"},
        target = mob("Creature-1", "Grunt", {dead = true}), softenemy = mob("Creature-2", "Grunt")})
    local made = predictor(state)
    cast(state, "Grunt", 172, "Cast-1")
    equal(made:PredictedDamage("Creature-2"), 40, "the corpse is skipped: the next mob")
    equal(made:PredictedDamage("Creature-1"), 0)
    state.units.target = {guid = "Player-3", name = "Healer", canAttack = false, dead = false}
    cast(state, SECRET, 348, "Cast-2")
    equal(made:PredictedDamage("Creature-2"), 60, "a secret name: the soft enemy, not your friend")
    equal(made:PredictedDamage("Player-3"), 0)
    state.units.target = mob("Creature-1", "Grunt")
    state.units.softenemy = nil
    cast(state, SECRET, 18265, "Cast-3")
    assert(made:PredictedDamage("Creature-1") > 0, "an attackable target keeps the cast")
end)

test("Forever: after combat the damage meter teaches the tick, once it reads; never for Immolate", function()
    local state = fixture()
    hiddenWorld(state)
    local made = predictor(state)
    local reads = 0
    state.env.C_DamageMeter = {GetCombatSessionSourceFromType = function(_, _, guid)
        equal(guid, "Player-1")
        reads = reads + 1
        if reads == 1 then return SECRET end
        return {combatSpells = {{spellID = 172, totalAmount = 24}, {spellID = 348, totalAmount = 90}}}
    end}
    state.combat = true
    cast(state, "Grunt", 172, "Cast-1")
    cast(state, "Grunt", 348, "Cast-2")
    for _ = 1, 2 do
        state.now = state.now + 3
        state.hit("target", "WOUND", SECRET, SHADOW)
        state.hit("target", "WOUND", SECRET, FIRE)
    end
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    advance(state, 0.5)
    equal(state.toolkit.LearnedTicks()[172], nil, "the totals are not readable yet")
    advance(state, 0.5)
    local learned = state.toolkit.LearnedTicks()[172]
    equal(learned.tick, 12, "24 over the 2 ticks seen")
    equal(learned.family, "corruption")
    equal(state.toolkit.LearnedTicks()[348], nil, "a direct hit is in Immolate's total")
end)

test("Forever: a meter total far from the guess, or a fight with an unseen DoT, teaches nothing", function()
    local state = fixture()
    hiddenWorld(state)
    predictor(state)
    state.env.C_DamageMeter = {GetCombatSessionSourceFromType = function()
        return {combatSpells = {{spellID = 172, totalAmount = 200}}}
    end}
    state.combat = true
    cast(state, "Grunt", 172, "Cast-1")
    for _ = 1, 2 do
        state.now = state.now + 3
        state.hit("target", "WOUND", SECRET, SHADOW)
    end
    state.combat = false
    emit(state, "PLAYER_REGEN_ENABLED")
    advance(state, 0.5)
    equal(state.toolkit.LearnedTicks()[172], nil, "100 a tick is ten times the guess")
end)

test("WTF at 10 draws over Dyre's Debuff Tracker at 5; its rows show the active source's damage", function()
    local state = fixture()
    predictWorld(state)
    local wtf, wtfStore = predictor(state)
    local ddt = predictor(state, {addon = "DyresDebuffTracker", priority = 5})
    equal(state.toolkit.HealthBars.IsActiveSource("WarlockToolsForever"), true)
    equal(state.toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), false)
    wtfStore.enabled = false
    wtf:Refresh()
    equal(state.toolkit.HealthBars.IsActiveSource("DyresDebuffTracker"), true, "off steps aside")
    assert(ddt)
end)

local failed = 0
for index, entry in ipairs(tests) do
    local ok, message = xpcall(entry.body, debug.traceback)
    if ok then
        print("ok " .. index .. " - " .. entry.name)
    else
        failed = failed + 1
        print("not ok " .. index .. " - " .. entry.name)
        print(message)
    end
end
print("")
print(#tests .. " tests: " .. (#tests - failed) .. " passed, " .. failed .. " failed")
print("Mock results do not establish in-client compatibility.")
if failed > 0 then
    os.exit(1)
end
