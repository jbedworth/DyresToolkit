-- Lua 5.1 mock suite for Dyre's Toolkit. Run from the repository root:
--   lua5.1 tests/run.lua
-- Mocks cannot prove dragging, the settings panel, or the minimap button in
-- the client; TESTING.md lists the in-client checks.

if _VERSION ~= "Lua 5.1" then
    io.stderr:write("This suite requires Lua 5.1; found " .. tostring(_VERSION) .. "\n")
    os.exit(1)
end

local ADDON = "DyresToolkit"
local RUNTIME = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Minimap.lua"}
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
        .. "Core.lua,Layout.lua,Widgets.lua,Settings.lua,Minimap.lua")
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
