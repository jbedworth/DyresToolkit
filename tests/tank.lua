-- The group warnings and tank tools suite (2.9.0), ported from Dyre's Tank
-- Tools' tests/run.lua: tests/run.lua loads this file with its test helpers
-- and the runtime list, so the tests count in one run. These mocks test the
-- logic, not Forever compatibility, protected actions, secret values,
-- layout, or taint; TESTING.md lists the in-client checks. Each test gets its
-- own globals, event frames, and namespace, and loads the toolkit files the
-- features use (the rest are stubbed: FindPlateBar, FindUnitBar, InFamily).
local test, equal, contains = ...
local ADDON = "DyresToolkit"
local FILES = {"Core.lua", "Layout.lua", "Widgets.lua", "Settings.lua", "Spells.lua", "Macros.lua", "Owners.lua",
    "Tank.lua", "Threat.lua", "PetTaunt.lua", "TankButtons.lua", "Pull.lua", "TankProbe.lua", "GroupSettings.lua"}

-- A secret stands in for the client's opaque combat values; tests mark them with
-- issecretvalue, and any comparison, concatenation, indexing, arithmetic, or
-- printing raises an error.
local function secret()
    local function refuse(what) return function() error(what .. " a secret value", 2) end end
    return setmetatable({}, {
        __eq = refuse("compared"), __lt = refuse("compared"), __le = refuse("compared"),
        __concat = refuse("concatenated"), __tostring = refuse("printed"), __index = refuse("indexed"),
        __add = refuse("did arithmetic on"), __sub = refuse("did arithmetic on"),
        __mul = refuse("did arithmetic on"), __div = refuse("did arithmetic on"),
    })
end

local function tocFiles(path)
    local files = {}
    for line in io.lines(path) do
        if line:match("%S") and not line:match("^#") then
            files[#files + 1] = line
        end
    end
    return files
end

-- Frames ---------------------------------------------------------------------------

-- Methods that the client refuses on a protected frame in combat.
local PROTECTED_METHODS = {Show = true, Hide = true, SetShown = true, SetPoint = true, ClearAllPoints = true,
    SetAttribute = true, SetSize = true}

local function newRegion(state, kind, parent)
    local region = {kind = kind, parent = parent, events = {}, units = {}, attributes = {}, scripts = {},
        hooks = {}, shown = true, points = {}}
    local methods = {}
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:RegisterUnitEvent(event, ...)
        if select("#", ...) > 2 then error("RegisterUnitEvent takes at most two units") end
        self.events[event] = true
        self.units[event] = {...}
    end
    function methods:SetScript(name, script) self.scripts[name] = script end
    function methods:GetScript(name) return self.scripts[name] end
    function methods:HookScript(name, hook) self.hooks[name] = hook end
    function methods:Show() self.shown = true end
    function methods:Hide() self.shown = false end
    function methods:SetShown(shown) self.shown = shown and true or false end
    function methods:IsShown() return self.shown end
    function methods:SetPoint(...) self.points[#self.points + 1] = {...} end
    function methods:ClearAllPoints() self.points = {} end
    function methods:GetPoint() local p = self.points[1] or {}; return p[1], p[2], p[3], p[4], p[5] end
    function methods:SetAttribute(name, value) self.attributes[name] = value end
    function methods:GetAttribute(name) return self.attributes[name] end
    function methods:CreateTexture() return newRegion(state, "Texture", self) end
    function methods:CreateFontString() return newRegion(state, "FontString", self) end
    function methods:SetTexture(texture) self.texture = texture end
    function methods:SetVertexColor(r, g, b) self.vertexColor = {r, g, b} end
    function methods:SetAllPoints(region) self.allPoints = region end
    function methods:SetText(text) self.text, self.secretText = text, nil end
    function methods:SetTextColor(r, g, b) self.color = {r, g, b} end
    function methods:SetFormattedText(format, ...)
        local args = {...}
        for index = 1, select("#", ...) do
            if state.secrets[args[index]] then
                -- The client shows a secret; the mock only records that it got one.
                self.text, self.secretText = format, true
                return
            end
        end
        self.text, self.secretText = string.format(format, ...), nil
    end
    function methods:StartMoving()
        if not self.movable then error("StartMoving on a frame that is not movable") end
        self.moving = true
    end
    function methods:SetMovable(movable) self.movable = movable end
    function methods:EnableMouse(enabled) self.mouse = enabled end
    function methods:SetFrameLevel(level) self.level = level end
    function methods:GetFrameLevel() return self.level or 1 end
    function methods:IsProtected() return self.protected end
    -- What Widgets.lua and Layout.lua read: a size, a scale, and an anchor.
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetWidth() return self.width or 0 end
    function methods:GetHeight() return self.height or 0 end
    function methods:SetScale(scale) self.scale = scale end
    function methods:GetScale() return self.scale or 1 end
    function methods:GetEffectiveScale() return self.scale or 1 end
    function methods:GetNumPoints() return #self.points end
    function methods:GetCenter() return 0, 0 end
    function methods:SetAlpha(alpha) self.alpha = alpha end
    function methods:GetAlpha() return self.alpha or 1 end
    function methods:IsMouseEnabled() return self.mouse end
    function methods:StopMovingOrSizing() self.moving = false end
    function methods:CreateAnimationGroup()
        local group = newRegion(state, "AnimationGroup", self)
        function group:CreateAnimation() return newRegion(state, "Animation", group) end
        function group:Play() self.playing = true end
        function group:Stop() self.playing = false end
        function group:IsPlaying() return self.playing == true end
        return group
    end
    setmetatable(region, {__index = function(_, key)
        -- options.noUnitEvents: a client without RegisterUnitEvent.
        if key == "RegisterUnitEvent" and state.noUnitEvents then return nil end
        local method = methods[key]
        if method then
            if PROTECTED_METHODS[key] then
                return function(self, ...)
                    if self.protected and state.combat and not state.restricted then
                        error("blocked: " .. key .. " on a protected frame in combat", 2)
                    end
                    return method(self, ...)
                end
            end
            return method
        end
        -- Any other widget method (capitalized): a no-op, recorded; any other field is nil.
        if type(key) ~= "string" or not key:find("^%u") then return nil end
        return function(self, ...) self["last" .. key] = {...} end
    end})
    return region
end

-- The client ---------------------------------------------------------------------------

-- A fresh client and a fresh load of the toolkit's files (FILES), then
-- ADDON_LOADED and PLAYER_LOGIN unless options.noLogin. Options:
--   pings       true: the client has /ping (Forever); false: Classic Era
--   loaded      AddOns loaded, by name; slashes: other AddOns' slash commands
--   threat      unit -> {isTanking, status, scaled} for UnitDetailedThreatSituation
--   simple      unit -> status for UnitThreatSituation
--   db          saved DyresToolkitCharDB; remove: globals to drop
local function fixture(options)
    options = options or {}
    options.toolkit = nil
    local state = {frames = {}, messages = {}, combat = false, secrets = {}, countdowns = {}, slashCalls = {},
        threat = options.threat or {}, simple = options.simple or {}, units = options.units or {target = true},
        plates = {}, wraps = {}, noUnitEvents = options.noUnitEvents}
    local env = setmetatable({}, {__index = _G})
    env._G = env
    env.SlashCmdList = {}
    env.DEFAULT_CHAT_FRAME = {AddMessage = function(_, message) state.messages[#state.messages + 1] = message end}
    env.issecretvalue = function(value) return state.secrets[value] == true end
    function state.secret()
        local value = secret()
        state.secrets[value] = true
        return value
    end
    local class = options.class or "WARRIOR"
    env.UnitClass = function() return class, class end
    -- Who tanks: options.group {role = "TANK", raid, mainTank}, options.form
    -- (GetShapeshiftFormID), options.talents {points per tab: only to prove
    -- talents have no effect; no toolkit code reads them}, options.pet
    -- (its family; petSpells: names on its bar).
    state.group = options.group
    state.form = options.form
    state.talents = options.talents or {0, 0, 0}
    state.pet = options.pet
    env.IsInGroup = function() return state.group ~= nil end
    env.IsInRaid = function() return state.group ~= nil and state.group.raid == true end
    -- state.group.members[unit] = {role, mainTank} for party and raid units.
    local function Member(unit) return state.group and state.group.members and state.group.members[unit] end
    env.UnitGroupRolesAssigned = function(unit)
        if unit ~= "player" then return Member(unit) and Member(unit).role or "NONE" end
        return state.group and state.group.role or "NONE"
    end
    env.GetPartyAssignment = function(_, unit)
        if unit ~= "player" then return Member(unit) ~= nil and Member(unit).mainTank == true end
        return state.group and state.group.mainTank == true
    end
    env.GetNumGroupMembers = function() return state.group and state.group.count or 0 end
    -- state.sameAsTarget[plate]: what UnitIsUnit(plate, "target") gives (true, false, or a secret).
    state.sameAsTarget = {}
    env.UnitIsUnit = function(a, b)
        if b == "target" and state.sameAsTarget[a] ~= nil then return state.sameAsTarget[a] end
        return a == b
    end
    state.sounds = {}
    state.now = 0
    env.GetTime = function() return state.now end
    env.PlaySound = function(sound, channel) state.sounds[#state.sounds + 1] = {sound, channel} end
    env.GetShapeshiftFormID = function() return state.form end
    env.GetTalentTabInfo = function(index)
        -- The newer return order: id, name, description, icon, pointsSpent.
        return index, "Tab" .. index, "", 1, state.talents[index]
    end
    env.C_Spell = {GetSpellName = function(id)
        return ({[3716] = "Torment", [5487] = "Bear Form", [2649] = "Growl", [14916] = "Growl",
            [71] = "Defensive Stance", [25780] = "Righteous Fury", [355] = "Taunt", [694] = "Mocking Blow",
            [1161] = "Challenging Shout", [5209] = "Challenging Roar", [17735] = "Suffering",
            [20736] = "Distracting Shot", [17734] = "Suffering", [133] = "Fireball",
            [99] = state.secretSpellName})[id]
    end}
    -- The player's auras by spell ID (options.auras): true, or state.secretAura.
    state.auras = options.auras or {}
    env.C_UnitAuras = {GetPlayerAuraBySpellID = function(id)
        if state.secretAura then return state.secretAura end
        return state.auras[id] and {spellId = id} or nil
    end}
    -- options.cSecrets: the client has C_Secrets.ShouldSpellAuraBeSecret;
    -- it gives state.auraSecret (true, false, nil), a secret for "secret",
    -- or raises an error for "error". Without it, C_Secrets is missing (Era).
    if options.cSecrets then
        state.auraSecret = options.auraSecret
        state.auraSecretAsked = {}
        env.C_Secrets = {ShouldSpellAuraBeSecret = function(id)
            state.auraSecretAsked[id] = (state.auraSecretAsked[id] or 0) + 1
            if state.auraSecret == "error" then error("refused") end
            if state.auraSecret == "secret" then return state.secret() end
            return state.auraSecret
        end}
    end
    -- Spells you know (options.known: IDs), for the Pet Taunt warning's knownBy.
    env.C_SpellBook = {IsSpellKnown = function(id) return (options.known or {})[id] == true end}
    env.UnitCreatureFamily = function() return state.pet end
    -- options.petSpells: names on the pet bar; state.autocast[slot]: autocast on.
    state.autocast = options.autocast or {}
    env.GetPetActionInfo = function(slot)
        local spells = options.petSpells or {}
        return spells[slot], nil, false, nil, nil, state.autocast[slot] == true
    end
    env.InCombatLockdown = function() return state.combat end
    env.UnitExists = function(unit)
        if unit == "pet" then return state.pet ~= nil end
        if state.group and state.group.members and state.group.members[unit] then return true end
        return state.units[unit] == true
    end
    env.UnitCanAttack = function(_, unit) return state.units[unit] == true end
    -- state.others[member][mob]: another group unit's threat on a mob.
    state.others = options.others or {}
    env.UnitDetailedThreatSituation = function(who, unit)
        local entry = state.threat[unit]
        if who ~= "player" then
            entry = state.others[who] and state.others[who][unit]
        end
        if entry then
            return entry[1], entry[2], entry[3], entry[4], entry[5]
        end
    end
    env.UnitThreatSituation = function(_, unit) return state.simple[unit] end
    env.GetBuildInfo = function() return "1.16.1", "70338" end
    env.IsInInstance = function() return false, "none" end
    env.IsAltKeyDown = function() return state.alt == true end
    env.IsControlKeyDown = function() return state.ctrl == true end
    env.IsShiftKeyDown = function() return state.shift == true end
    env.GetBindingKey = function() return nil end
    env.SetRaidTarget = function() error("SetRaidTarget called: the client blocks it in combat") end
    state.timers = {}
    env.C_Timer = {After = function() end, NewTimer = function(seconds, callback)
        local timer = {due = state.now + seconds, callback = callback}
        function timer:Cancel() self.cancelled = true end
        state.timers[#state.timers + 1] = timer
        return timer
    end}
    function state.advance(seconds)
        state.now = state.now + seconds
        for _, timer in ipairs(state.timers) do
            if not timer.cancelled and not timer.ran and timer.due <= state.now then
                timer.ran = true
                timer.callback()
            end
        end
    end
    function state.liveTimers()
        local count = 0
        for _, timer in ipairs(state.timers) do
            if not timer.cancelled and not timer.ran then count = count + 1 end
        end
        return count
    end
    env.C_AddOns = {
        GetAddOnMetadata = function(name, field)
            if name ~= ADDON then return nil end
            return ({Title = "Dyre's Tank Tools", Version = "0.1.0-beta", Author = "Dyre"})[field]
        end,
        IsAddOnLoaded = function(name) return (options.loaded or {})[name] == true, false end,
    }
    if options.countdown ~= false then
        env.C_PartyInfo = {DoCountdown = function(seconds) state.countdowns[#state.countdowns + 1] = seconds end}
    end
    if options.pings ~= false then
        env.SLASH_PING1 = "/ping"
    end
    for key, slash in pairs(options.slashes or {}) do
        env["SLASH_" .. key .. "1"] = slash
        env.SlashCmdList[key] = function(message) state.slashCalls[#state.slashCalls + 1] = {key, message} end
    end
    env.UIParent = newRegion(state, "Frame")
    env.GameTooltip = newRegion(state, "GameTooltip")
    env.TargetFrameHealthBar = newRegion(state, "StatusBar")
    env.C_NamePlate = {GetNamePlateForUnit = function(unit) return state.plates[unit] end}
    env.CreateFrame = function(kind, name, parent, template)
        local frame = newRegion(state, kind, parent)
        frame.name, frame.template = name, template
        if template == "SecureActionButtonTemplate" or template == "SecureHandlerBaseTemplate" then
            frame.protected = true
            -- A frame holding a protected frame is protected too.
            local ancestor = parent
            while ancestor do
                ancestor.protected = true
                ancestor = ancestor.parent
            end
        end
        if name then env[name] = frame end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    env.SecureHandlerWrapScript = function(frame, script, header, preBody)
        state.wraps[#state.wraps + 1] = {frame = frame, script = script, header = header, preBody = preBody}
    end
    -- Settings: records every setting by variable.
    state.settings = {}
    state.page = {}
    local pageLayout = {AddInitializer = function(_, initializer) state.page[#state.page + 1] = initializer end}
    env.Settings = {
        VarType = {Boolean = "boolean", Number = "number", String = "string"},
        RegisterVerticalLayoutCategory = function(name)
            state.category = {name = name, GetID = function() return 7 end}
            return state.category, pageLayout
        end,
        RegisterVerticalLayoutSubcategory = function(parent, name)
            state.category = {name = name, parent = parent, GetID = function() return 8 end}
            return state.category, pageLayout
        end,
        RegisterProxySetting = function(_, variable, varType, name, default, getValue, setValue)
            local setting = {variable = variable, name = name, default = default}
            state.page[#state.page + 1] = variable
            function setting:GetValue() return getValue() end
            function setting:SetValue(value) setValue(value) end
            state.settings[variable] = setting
            return setting
        end,
        RegisterAddOnCategory = function(registered) state.registered = registered end,
        CreateCheckbox = function(_, setting, tooltip) setting.tooltip = tooltip return {} end,
        InitDropdown = function(button, setting, inserter)
            state.dropdownInits = state.dropdownInits or {}
            state.dropdownInits[#state.dropdownInits + 1] = {button = button, setting = setting, inserter = inserter}
        end,
        CreateDropdown = function(_, setting, options, tooltip)
            setting.tooltip = tooltip
            setting.choices, setting.labels = {}, {}
            for _, choice in ipairs(options()) do
                setting.choices[#setting.choices + 1] = choice.value
                setting.labels[choice.value] = choice.label
            end
            setting.options = options
            local initializer = {data = {}, setting = setting}
            function initializer:InitFrame(frame) self.framed = frame end
            function initializer:GetSetting() return self.setting end
            setting.initializer = initializer
            if true then return initializer end
        end,
        CreateControlTextContainer = function()
            local data = {}
            return {Add = function(_, value, label) data[#data + 1] = {value = value, label = label} end,
                GetData = function() return data end}
        end,
        CreateSlider = function(_, setting, sliderOptions)
            local initializer = {options = sliderOptions, InitFrame = function() end}
            state.sliders = state.sliders or {}
            state.sliders[setting.variable] = initializer
            return initializer
        end,
        CreateSliderOptions = function(minValue, maxValue, step)
            local sliderOptions = {minValue, maxValue, step}
            function sliderOptions:SetLabelFormatter(where, formatter) self.where, self.formatter = where, formatter end
            return sliderOptions
        end,
        OpenToCategory = function(id) state.opened = id end,
    }
    for key, value in pairs(options.globals or {}) do env[key] = value end
    for _, name in ipairs(options.remove or {}) do env[name] = nil end
    env.DyresToolkitCharDB = options.db
    env.MenuUtil = {CreateContextMenu = function() end}
    -- The files not loaded: the minimap button, and the family gate.
    local ns = {InitializeMinimap = function() end, InFamily = function(addon) return addon == "DyresBuffReminders" end}
    for _, path in ipairs(FILES) do
        local chunk = assert(loadfile(path))
        setfenv(chunk, env)
        chunk(ADDON, ns)
    end
    local toolkit = env.DyresToolkit
    -- HealthBars.lua's bar finders, as the plates and target frame give them.
    function toolkit.FindPlateBar(unit) return state.plates[unit] and state.plates[unit].bar end
    function toolkit.FindUnitBar() return state.targetBar end
    state.toolkit, state.core = toolkit, ns
    -- The tests read the tank table, as they read DTT's namespace before.
    state.env, state.ns = env, ns.tank
    local function ForUnit(units, unit)
        if not units then return true end
        for _, registered in ipairs(units) do
            if registered == unit then return true end
        end
        return false
    end
    -- route: the unit the client sends the event for (a unit event goes to
    -- the frames registered for it); the arguments go as they are, so a
    -- test can send a secret unit argument (state.fireAs).
    function state.fireAs(route, event, ...)
        local frames = {}
        for _, frame in ipairs(state.frames) do frames[#frames + 1] = frame end
        for _, frame in ipairs(frames) do
            local script = frame.scripts.OnEvent
            if frame.events[event] and script and ForUnit(frame.units[event], route) then
                script(frame, event, ...)
            end
        end
    end
    function state.fire(event, ...)
        state.fireAs((...), event, ...)
    end
    function state.find(fragment)
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then return message end
        end
    end
    function state.count(fragment)
        local count = 0
        for _, message in ipairs(state.messages) do
            if message:find(fragment, 1, true) then count = count + 1 end
        end
        return count
    end
    -- A click as the client runs it: the wrapped pre-snippet, then the action, then PostClick.
    function state.click(frame, down)
        for _, wrap in ipairs(state.wraps) do
            if wrap.frame == frame and wrap.script == "OnClick" then
                local snippet = assert(loadstring("local self, button, down = ...\n" .. wrap.preBody))
                -- Restricted code may change attributes in combat.
                state.restricted = true
                snippet(frame, "LeftButton", down)
                state.restricted = false
            end
        end
        if frame.scripts.OnClick then frame.scripts.OnClick(frame, "LeftButton", down) end
        if frame.hooks.PostClick then frame.hooks.PostClick(frame, "LeftButton", down) end
    end
    function state.enterCombat()
        state.combat = true
        state.fire("PLAYER_REGEN_DISABLED")
    end
    function state.leaveCombat()
        state.combat = false
        state.fire("PLAYER_REGEN_ENABLED")
    end
    if not options.noLogin then
        state.fire("ADDON_LOADED", ADDON)
        state.fire("PLAYER_LOGIN")
    end
    return state
end

-- Startup ------------------------------------------------------------------------------

test("a client without a threat API keeps the features off, quiet at login, and the diagnostics run", function()
    local state = fixture({remove = {"UnitDetailedThreatSituation"}})
    equal(state.ns.available, false)
    equal(#state.messages, 0, "the toolkit loads with every Dyre's AddOn: nothing said at login")
    state.env.SlashCmdList.DYRESTOOLKITTANK("pull")
    contains(state.find("off on this client"), "lacks UnitDetailedThreatSituation")
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug")
    contains(state.find("debug available=false"), "class=WARRIOR")
end)

test("a missing file is reported as a mixed install when a command runs", function()
    local state = fixture({noLogin = true})
    state.ns.StartPull = nil
    state.fire("ADDON_LOADED", ADDON)
    state.fire("PLAYER_LOGIN")
    state.env.SlashCmdList.DYRESTOOLKITTANK("reset")
    contains(state.find("different versions"), "StartPull")
end)

-- The taunt probe (John, 2026-11-12: "probe first, then build it").
local function Casts(state, kind, place)
    return state.ns.TauntProbeState().counts[kind][place]
end

test("taunt probe: registers two units per frame for party, party pets, you, and your pet", function()
    local state = fixture()
    local probe = state.ns.TauntProbeState()
    equal(probe.method, "RegisterUnitEvent")
    equal(table.concat(probe.registered, " "),
        "player=ok pet=ok party1,party2=ok party3,party4=ok partypet1,partypet2=ok partypet3,partypet4=ok")
    local registered = {}
    for _, frame in ipairs(state.frames) do
        local units = frame.units.UNIT_SPELLCAST_SUCCEEDED
        if units then registered[#registered + 1] = table.concat(units, ",") end
    end
    contains(table.concat(registered, " "), "party3,party4")
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 355)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "raid5", "guid", 355)
    for _, kind in ipairs(state.ns.TAUNT_KINDS) do
        equal(Casts(state, kind, "calm").events, nil, kind .. ": other units are not counted")
    end
end)

test("taunt probe: readable casts are counted by kind and place, and watched spells by name", function()
    local state = fixture()
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid-1", 355)
    state.combat = true
    state.now = 100
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "partypet2", "guid-2", 14916)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "party3", "guid-3", 133)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "partypet4", "guid-4", 17734)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid-5", 25780)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "pet", "guid-6", 3716)
    equal(Casts(state, "party", "calm").events, 1)
    equal(Casts(state, "party", "calm").spellRead, 1)
    equal(Casts(state, "party", "combat").events, 1, "Fireball: counted, not watched")
    equal(Casts(state, "partypet", "combat").events, 2)
    equal(Casts(state, "partypet", "combat").spellSecret, nil)
    local matches = state.ns.TauntProbeState().matches
    equal(matches.Taunt.party, 1)
    equal(matches.Growl.partypet, 1, "Growl rank 2 by name")
    equal(matches.Suffering.partypet, 1, "another rank of Suffering by name")
    equal(matches["Righteous Fury"].player, 1, "your own casts: the control")
    equal(matches.Torment.pet, 1)
    local recent = state.ns.TauntProbeState().recent
    equal(#recent, 5)
    equal(recent[1].unit, "party1")
    equal(recent[1].combat, false)
    equal(recent[2].unit, "partypet2")
    equal(recent[2].spell, "Growl")
    equal(recent[2].combat, true)
    state.now = 110
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug_taunts")
    contains(state.find("debug_taunts registered (RegisterUnitEvent)"), "party1,party2=ok")
    equal(state.find("debug_taunts party "),
        "Dyre: debug_taunts party combat: events=1 spellRead=1; calm: events=1 spellRead=1")
    contains(state.find("debug_taunts partypet "), "combat: events=2 spellRead=2")
    contains(state.find("debug_taunts matches:"), "Taunt party=1")
    contains(state.find("debug_taunts matches:"), "Growl partypet=1")
    contains(state.find("debug_taunts matches:"), "Righteous Fury player=1")
    contains(state.find("debug_taunts recent 10s ago combat pet"), "Torment")
    contains(state.find("debug_taunts recent 110s ago calm party1"), "Taunt")
end)

test("taunt probe: secret arguments are counted, never compared, printed, or indexed", function()
    local state = fixture()
    state.combat = true
    state.fireAs("party2", "UNIT_SPELLCAST_SUCCEEDED", state.secret(), state.secret(), state.secret())
    state.fireAs("partypet1", "UNIT_SPELLCAST_SUCCEEDED", state.secret(), "guid", 2649)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", state.secret(), nil)
    state.secretSpellName = state.secret()
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "party4", "guid", 99)
    local party = Casts(state, "party", "combat")
    equal(party.events, 3)
    equal(party.unitSecret, 1, "kind from the frame, so a secret unit still counts")
    equal(party.guidSecret, 2)
    equal(party.spellSecret, 1)
    equal(party.spellOther, 1, "no spell ID")
    equal(party.nameSecret, 1)
    equal(party.spellRead, 1)
    equal(state.ns.TauntProbeState().matches.Growl.partypet, 1, "a readable spell with a secret unit matches")
    equal(state.ns.TauntProbeState().recent[1].unit, "secret", "a secret unit is never kept")
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug_taunts")
    equal(state.find("debug_taunts party "), "Dyre: debug_taunts party combat: events=3 spellRead=1 "
        .. "spellSecret=1 spellOther=1 nameSecret=1 guidSecret=2 unitSecret=1; calm: none")
    contains(state.find("debug_taunts recent"), "combat secret Growl")
end)

test("taunt probe: only counts; sends nothing, saves nothing, keeps the last 10", function()
    local state = fixture()
    state.env.SendChatMessage = function() error("the probe sent a chat message") end
    state.env.DoEmote = function() error("the probe sent an emote") end
    for index = 1, 12 do
        state.now = index
        state.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "guid", 355)
    end
    equal(#state.ns.TauntProbeState().recent, 10)
    equal(state.ns.TauntProbeState().recent[1].time, 3, "the oldest two dropped")
    for key in pairs(state.env.DyresToolkitCharDB) do
        assert(not key:lower():find("taunt%a*probe") and not key:lower():find("cast"), key)
    end
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug")
    equal(state.find("debug taunt probe:"),
        "Dyre: debug taunt probe: 12 casts seen, 12 watched; /dtt debug_taunts for details")
    state.env.SlashCmdList.DYRESTOOLKIT("taunt_debug")
    assert(state.find("debug_taunts registered"), "/dyre taunt_debug")
end)

test("taunt probe: without RegisterUnitEvent, one frame keeps only these units", function()
    local state = fixture({noUnitEvents = true})
    local probe = state.ns.TauntProbeState()
    equal(probe.method, "RegisterEvent")
    equal(probe.registered[1], "all units=ok")
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "partypet3", "guid", 2649)
    state.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "guid", 355)
    state.fireAs("party1", "UNIT_SPELLCAST_SUCCEEDED", state.secret(), "guid", 355)
    equal(Casts(state, "partypet", "calm").events, 1)
    equal(Casts(state, "party", "calm").events, nil, "a secret unit cannot be told apart: not counted")
    equal(probe.matches.Growl.partypet, 1)
end)

test("/dyre runs the tank words and leaves its own words to the toolkit", function()
    local state = fixture({loaded = {}})
    state.env.SlashCmdList.DYRESTOOLKIT("pull 7")
    equal(state.countdowns[1], 7, "/dyre pull 7")
    state.env.SlashCmdList.DYRESTOOLKIT("threat_debug")
    assert(state.find("debug_threat client="), "/dyre threat_debug")
    state.env.SlashCmdList.DYRESTOOLKIT("tank_debug")
    assert(state.find("debug available=true"), "/dyre tank_debug")
    state.env.SlashCmdList.DYRESTOOLKIT("unlock")
    equal(state.toolkit.IsLocked(), false, "/dyre unlock is still the toolkit's")
    state.env.SlashCmdList.DYRESTOOLKIT("wipe")
    contains(state.messages[#state.messages], "/dyre pull [seconds]")
end)

test("the toolkit owns its kinds above a class Tools AddOn, and a feature stops when another owns it", function()
    local state = fixture({toolkit = true, units = {target = true, nameplate1 = true}, threat = {target = {true, 3, 100}},
        group = {role = "TANK"}})
    local toolkit = state.toolkit
    for _, kind in ipairs({"threat", "warn:petTaunt", "tank:markers", "tank:pings", "tank:pull"}) do
        equal(toolkit.KindOwner(kind), "DyresToolkit", kind)
    end
    equal(toolkit.ClaimOwner("warn:petTaunt", "DyresBuffReminders", 10), false, "DBR yields")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local _, target = state.ns.ThreatLabels()
    equal(target.shown, true)
    toolkit.ClaimOwner("threat", "DyresBuffReminders", 99)
    equal(target.shown, false, "another owner: the labels go")
    toolkit.ClaimOwner("tank:markers", "DyresBuffReminders", 99)
    local buttons = state.ns.Buttons()
    equal(buttons.skull:GetAttribute("macrotext"), nil, "another owner: no marker text")
    equal(buttons.skull.shown, false)
    equal(toolkit.ClaimOwner("threat", "SomeOtherAddOn", 999), false, "only Dyre's AddOns claim")
end)

-- Settings and commands ------------------------------------------------------------

test("saved settings are repaired", function()
    local state = fixture({db = {plateThreat = "yes", targetThreat = false, pull = 99.5,
        markerOrder = {8, 8, 9, "x", 7, 0}, position = {point = "CENTER"}}})
    local db = state.env.DyresToolkitCharDB
    equal(db.plateThreat, true, "a non-boolean is the default")
    equal(db.targetThreat, false)
    equal(db.barMode, "auto", "Auto (tank only) is the default")
    equal(db.pull, 10, "a broken pull length is the default")
    equal(table.concat(db.markerOrder, ","), "8,7", "duplicates and bad markers dropped")
    equal(db.position, nil, "a broken position is dropped")
    equal(db.threatMode, "auto")
    equal(db.platePlace, "right")
    local other = fixture({db = {threatMode = "tank", platePlace = "nowhere", barMode = "never"}}).env.DyresToolkitCharDB
    equal(other.barMode, "never")
    equal(fixture({db = {barMode = "sometimes"}}).env.DyresToolkitCharDB.barMode, "auto", "a bad mode is the default")
    equal(other.threatMode, "tank")
    equal(other.platePlace, "right", "a bad place is the default")
    equal(state.ns.SanitizePull(120), 60)
    equal(table.concat(state.ns.SanitizeMarkerOrder({}), ","), "8,7,6,4,3,2,1", "empty is the default")
end)

test("commands parse with a seconds argument only for pull", function()
    local state = fixture()
    local parse = state.ns.ParseCommand
    equal(parse(""), "")
    equal(parse("  Debug_Threat "), "debug_threat")
    local command, seconds = parse("pull 15")
    equal(command, "pull")
    equal(seconds, 15)
    local none, message = parse("pull 61")
    equal(none, nil)
    contains(message, "whole seconds, 1 to 60, or 0 to cancel")
    equal(select(2, parse("pull 0")), 0, "0 cancels")
    equal((parse("pull 2.5")), nil)
    equal((parse("options now")), nil)
    equal((parse("wipe")), nil)
    state.env.SlashCmdList.DYRESTOOLKITTANK("wipe")
    contains(state.messages[#state.messages], "Use /dtt")
end)

test("/dtt opens the settings out of combat only", function()
    local state = fixture()
    state.env.SlashCmdList.DYRESTOOLKITTANK("")
    equal(state.opened, 7)
    state.opened = nil
    state.combat = true
    state.env.SlashCmdList.DYRESTOOLKITTANK("options")
    equal(state.opened, nil)
    contains(state.messages[#state.messages], "out of combat")
end)

-- Marking and pings -----------------------------------------------------------------

test("the marker and ping macro texts", function()
    local state = fixture()
    local ns = state.ns
    equal(ns.MarkLine({"target"}, 8), "/tm [@target,harm,nodead,exists] !8")
    equal(ns.MarkLine({"mouseover", "target"}, 7),
        "/tm [@mouseover,harm,nodead,exists][@target,harm,nodead,exists] !7")
    equal(ns.MarkLine({"target"}, 9), nil)
    equal(ns.PingLine("attack"), "/ping [@target,harm,exists] attack")
    equal(ns.PingLine("onmyway"), "/ping [@target,exists] onmyway")
    local buttons = ns.Buttons()
    equal(buttons.skull:GetAttribute("type"), "macro")
    equal(buttons.skull:GetAttribute("macrotext"), "/tm [@target,harm,nodead,exists] !8")
    equal(buttons.mouseover:GetAttribute("macrotext"), "/tm [@mouseover,harm,nodead,exists] !8")
    equal(buttons.markPing:GetAttribute("macrotext"),
        "/tm [@target,harm,nodead,exists] !8\n/ping [@target,harm,exists] attack")
    equal(state.env.DyresToolkitPingOnmyway, buttons.pingonmyway, "binding names match the buttons")
    equal(state.env["BINDING_NAME_CLICK DyresToolkitPingOnmyway:LeftButton"], "Ping On my way on your target")
end)

test("the binding file names every button DTT creates", function()
    local state = fixture()
    local xml = assert(io.open("Bindings.xml")):read("*a")
    local count = 0
    for name in xml:gmatch("CLICK (%w+):LeftButton") do
        count = count + 1
        if not state.env[name] then error("Bindings.xml names a missing button: " .. name) end
    end
    equal(count, 9)
end)

test("next marker cycles skull, cross, square in combat and starts again after it", function()
    local state = fixture()
    local button = state.ns.Buttons().next
    equal(button:GetAttribute("macrotext"),
        "/tm [@mouseover,harm,nodead,exists][@target,harm,nodead,exists] !8", "skull before the first press")
    state.enterCombat()
    local seen = {}
    for _ = 1, 3 do
        state.click(button, true) -- the press: no step
        state.click(button, false) -- the release acts
        seen[#seen + 1] = button:GetAttribute("macrotext"):match("!(%d)$")
    end
    equal(table.concat(seen, ","), "8,7,6")
    contains(button.icon.texture, "UI-RaidTargetingIcon_4", "the icon shows the marker that comes next")
    state.leaveCombat()
    equal(button:GetAttribute("dtt-index"), 0)
    contains(button:GetAttribute("macrotext"), "!8")
end)

test("next marker wraps around the order", function()
    local state = fixture({db = {markerOrder = {8, 7}}})
    local button = state.ns.Buttons().next
    local seen = {}
    for _ = 1, 3 do
        state.click(button, false)
        seen[#seen + 1] = button:GetAttribute("macrotext"):match("!(%d)$")
    end
    equal(table.concat(seen, ","), "8,7,8")
end)

test("Classic Era without /ping hides the ping buttons", function()
    local state = fixture({pings = false})
    local buttons = state.ns.Buttons()
    equal(buttons.pingattack.shown, false)
    equal(buttons.markPing.shown, false)
    equal(buttons.pingattack:GetAttribute("macrotext"), nil, "a binding does nothing")
    equal(buttons.skull.shown, true)
    equal(buttons.next.shown, true)
    equal(buttons.pull.shown, true)
    local forever = fixture()
    equal(forever.ns.Buttons().pingattack.shown, true)
end)

-- The tank bar in Auto (John, 2026-11-11): group role Tank, Warrior
-- Defensive Stance, Druid Bear Form, Paladin Righteous Fury; else hidden.
local function BarShown(state)
    return select(2, state.ns.Buttons()).shown
end

test("Auto: the bar shows for the group's tank, also for a class that does not tank", function()
    local state = fixture({class = "MAGE"})
    equal(BarShown(state), false, "a Mage solo")
    state.group = {role = "TANK"}
    state.fire("GROUP_ROSTER_UPDATE")
    equal(BarShown(state), true, "group role Tank")
    state.group = {role = "DAMAGER"}
    state.fire("GROUP_ROSTER_UPDATE")
    equal(BarShown(state), true, "sticky: still shown")
    state.advance(30)
    equal(BarShown(state), false, "30 s with no reason: hidden")
    state.group = {raid = true, mainTank = true}
    state.fire("GROUP_ROSTER_UPDATE")
    equal(BarShown(state), true, "a raid's main tank")
end)

test("Auto: while the role is Tank, the bar never hides", function()
    local state = fixture({group = {role = "TANK"}, form = 17})
    equal(BarShown(state), true, "group role Tank in Battle Stance")
    state.fire("UPDATE_SHAPESHIFT_FORM")
    state.advance(120)
    equal(BarShown(state), true, "no hide wait while the role is Tank")
    equal(state.liveTimers(), 0)
end)

test("Auto: a Warrior's bar shows at once in Defensive Stance and hides 30 s after it", function()
    local state = fixture({form = 17})
    equal(BarShown(state), false, "Battle Stance")
    state.form = 18
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(state), true, "Defensive Stance: at once")
    state.form = 19
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(state), true, "Berserker Stance: still shown")
    state.advance(29)
    equal(BarShown(state), true, "29 s: still shown")
    state.advance(1)
    equal(BarShown(state), false, "30 s out of Defensive Stance: hidden")
end)

test("Auto: stance dancing under 30 s keeps the bar, with one timer at a time", function()
    local state = fixture({form = 18})
    for _ = 1, 5 do
        state.form = 17
        state.fire("UPDATE_SHAPESHIFT_FORM")
        state.fire("UPDATE_SHAPESHIFT_FORM")
        equal(state.liveTimers(), 1, "one hide timer")
        state.advance(20)
        state.form = 18
        state.fire("UPDATE_SHAPESHIFT_FORM")
        equal(state.liveTimers(), 0, "back in Defensive Stance: the timer is cancelled")
        state.advance(20)
        equal(BarShown(state), true)
    end
end)

test("Auto: a Druid's bar follows Bear and Dire Bear Form", function()
    local state = fixture({class = "DRUID"})
    equal(BarShown(state), false, "no form")
    state.form = 5
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(state), true, "Bear Form")
    state.form = 1
    state.fire("UPDATE_SHAPESHIFT_FORM")
    state.advance(30)
    equal(BarShown(state), false, "30 s in Cat Form")
    state.form = 8
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(state), true, "Dire Bear Form")
end)

test("Auto: a Paladin's bar follows Righteous Fury, from the player's own aura events", function()
    local state = fixture({class = "PALADIN"})
    equal(BarShown(state), false, "no Righteous Fury")
    state.auras[25780] = true
    state.fire("UNIT_AURA", "target")
    equal(BarShown(state), false, "another unit's auras are not watched")
    state.fire("UNIT_AURA", "player")
    equal(BarShown(state), true, "Righteous Fury")
    state.auras[25780] = nil
    state.fire("UNIT_AURA", "player")
    state.advance(30)
    equal(BarShown(state), false, "30 s after Righteous Fury")
    local warrior = fixture({auras = {[25780] = true}})
    equal(BarShown(warrior), false, "only a Paladin's Righteous Fury counts")
end)

test("Auto: an answer the client hides keeps the bar as it is", function()
    local state = fixture({class = "PALADIN", auras = {[25780] = true}})
    equal(BarShown(state), true)
    state.secretAura = state.secret()
    state.fire("UNIT_AURA", "player")
    state.advance(60)
    equal(BarShown(state), true, "a secret aura: no change, no hide")
    local warrior = fixture({form = 17})
    warrior.form = warrior.secret()
    warrior.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(warrior), false, "a secret stance: no change")
    contains(select(2, warrior.ns.BarShown()), "kept")
end)

test("combat stops the hide wait; it starts again after combat", function()
    local state = fixture({form = 18})
    local _, bar = state.ns.Buttons()
    equal(bar.protected, true, "the bar holds secure buttons")
    state.form = 17
    state.fire("UPDATE_SHAPESHIFT_FORM")
    state.advance(20)
    state.enterCombat()
    equal(state.liveTimers(), 0, "combat cancels the wait")
    state.advance(60)
    equal(bar.shown, true, "never hidden in combat")
    state.leaveCombat()
    equal(state.liveTimers(), 1, "a new wait after combat")
    state.advance(29)
    equal(bar.shown, true, "the wait starts again from 0")
    state.advance(1)
    equal(bar.shown, false, "30 s after combat: hidden")
end)

test("a show in combat waits for the end of combat", function()
    local state = fixture({form = 17})
    local _, bar = state.ns.Buttons()
    state.enterCombat()
    state.form = 18
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(bar.shown, false, "unchanged in combat")
    state.leaveCombat()
    equal(bar.shown, true, "shown after combat")
    state.enterCombat()
    state.settings.DYRE_TANK_BAR_MODE:SetValue("never")
    equal(bar.shown, true, "a setting changed in combat waits too")
    state.leaveCombat()
    equal(bar.shown, false, "hidden after combat")
end)

test("Always and Never force the bar; unlocked frames show it to move", function()
    local state = fixture({class = "MAGE"})
    local setting = state.settings.DYRE_TANK_BAR_MODE
    equal(table.concat(setting.choices, ","), "auto,always,never")
    equal(setting.name, "Tank button bar")
    setting:SetValue("always")
    equal(BarShown(state), true, "Always")
    state.advance(60)
    equal(BarShown(state), true, "Always: no hide timer")
    equal(state.liveTimers(), 0)
    local stance = fixture({form = 18})
    stance.settings.DYRE_TANK_BAR_MODE:SetValue("never")
    equal(BarShown(stance), false, "Never, also in Defensive Stance")
    stance.form = 17
    stance.form = 18
    stance.fire("UPDATE_SHAPESHIFT_FORM")
    equal(BarShown(stance), false, "Never: the events change nothing")
    stance.advance(60)
    equal(stance.liveTimers(), 0, "Never: no hide timer")
    stance.toolkit.Unlock()
    equal(BarShown(stance), true, "unlocked: shown to move")
    stance.toolkit.Lock()
    equal(BarShown(stance), false, "locked again: Never")
    stance.env.SlashCmdList.DYRESTOOLKITTANK("pull")
    equal(stance.countdowns[1], 10, "the buttons still work with the bar hidden")
end)

test("the settings: John's name for the target label, and the pull slider shows its number and default", function()
    local state = fixture({globals = {MinimalSliderWithSteppersMixin = {Label = {Right = "RIGHT"}}}})
    equal(state.settings.DYRE_TARGET_THREAT.name, "Threat on Target Frame")
    local slider = state.sliders.DYRE_PULL
    equal(slider.options.where, "RIGHT", "the number at the right")
    equal(slider.options.formatter(5), "5 s")
    equal(slider.dyreDefault.default, 10, "the gold mark at the default")
    equal(slider.dyreDefault.min, 1)
    equal(slider.dyreDefault.max, 60)
end)

-- The bar is a toolkit widget: it drags with every Dyre's frame while
-- unlocked, and by Ctrl-drag while locked, by the bar or any button (the
-- buttons cover almost all of it; found in client, 2026-11-10: /dyre unlock
-- and Ctrl-drag did not move DTT's bar), never in combat.
test("the bar drags by any button while unlocked, by Ctrl-drag while locked, never in combat", function()
    local state = fixture({form = 18})
    local buttons, bar = state.ns.Buttons()
    equal(bar.dyre.addon, "DyresToolkit", "a toolkit widget")
    for _, frame in ipairs({buttons.skull, buttons.next, buttons.pingattack, buttons.pull}) do
        frame.scripts.OnDragStart(frame)
        equal(bar.moving, nil, "locked, no Ctrl: no drag")
    end
    state.ctrl = true
    buttons.skull.scripts.OnDragStart(buttons.skull)
    equal(bar.moving, true, "locked with Ctrl: the bar moves")
    buttons.skull.scripts.OnDragStop(buttons.skull)
    equal(bar.moving, false)
    assert(state.env.DyresToolkitCharDB.bar.position, "the place is saved for this character")
    state.ctrl = false
    state.toolkit.Unlock()
    state.combat = true
    buttons.pull.scripts.OnDragStart(buttons.pull)
    equal(bar.moving, false, "no drag in combat")
    state.combat = false
    buttons.pull.scripts.OnDragStart(buttons.pull)
    equal(bar.moving, true, "unlocked: any button drags the bar")
    buttons.pull.scripts.OnDragStop(buttons.pull)
    state.env.SlashCmdList.DYRESTOOLKITTANK("reset")
    equal(state.env.DyresToolkitCharDB.bar.position, nil, "/dtt reset: back to the first place")
end)

-- Threat ---------------------------------------------------------------------------------

local function TargetLabel(state)
    local _, target = state.ns.ThreatLabels()
    return target
end

test("tank view: green on you, yellow when another has more, red when lost; the shield icon", function()
    local state = fixture({threat = {target = {true, 3, 100}}, group = {role = "TANK"}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.shown, true)
    equal(label.text.text, "100%")
    equal(label.icon.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\ShieldFill")
    equal(label.edge.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\ShieldEdge")
    equal(label.text.color[1], 0.2, "green")
    equal(label.text.color[2], 1)
    state.threat.target = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[1], 1, "yellow")
    equal(label.text.color[2], 0.85)
    for _, status in ipairs({1, 0}) do
        state.threat.target = {false, status, 80}
        state.fire("UNIT_THREAT_LIST_UPDATE", "target")
        equal(label.text.text, "80%")
        equal(label.text.color[2], 0.2, "red")
    end
    equal(label.points[1][1], "BOTTOM", "above the target bar")
end)

test("DPS view: green below the tank, orange above, red with aggro; crossed swords", function()
    local state = fixture({threat = {target = {false, 0, 42.4}}, group = {role = "DAMAGER"}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.text.text, "42%")
    equal(label.icon.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\SwordsFill")
    equal(label.edge.texture, "Interface\\AddOns\\DyresToolkit\\Textures\\SwordsEdge")
    equal(label.text.color[2], 1, "green")
    state.threat.target = {false, 1, 99}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 0.5, "orange (John, 2026-11-13)")
    equal(label.text.text, "99%", "the percent, not a word")
    for _, status in ipairs({2, 3}) do
        state.threat.target = {true, status, 100}
        state.fire("UNIT_THREAT_LIST_UPDATE", "target")
        equal(label.text.color[2], 0.2, "red")
    end
end)

-- John, 2026-11-13: "Can we make it symmetrical for DPS? Green, on threat
-- table, but not 1st or 2nd. Orange, in danger of pulling aggro, Red, you
-- pulled aggro. And play the same sounds?"
local function SoundCount(state, id)
    local count = 0
    for _, sound in ipairs(state.sounds) do
        if sound[1] == id then count = count + 1 end
    end
    return count
end
local function LosingCount(state) return SoundCount(state, 847) end

-- John, 2026-11-13: "An early yellow for DPS would be nice (no sound, just
-- flip it yellow when they get above 80%)."
test("DPS view: early yellow at 80% of the pull point, below the tank, with no sound", function()
    local state = fixture({threat = {target = {false, 0, 79}}, group = {role = "DAMAGER"}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.text.color[2], 1, "79%: green")
    state.combat = true
    state.threat.target = {false, 0, 80}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 0.85, "80%: yellow")
    equal(label.text.text, "80%")
    equal(#state.sounds, 0, "yellow plays nothing")
    state.threat.target = {false, 1, 95}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 0.5, "above the tank: orange")
    equal(LosingCount(state), 1, "yellow to orange: the orange sound")
    state.threat.target = {false, 0, state.secret()}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 1, "a secret percent: no early yellow, green from the status")
end)

test("DPS view: green to orange plays the orange sound once; orange to red the red sound", function()
    local state = fixture({threat = {target = {false, 0, 40}}, group = {role = "DAMAGER"}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.threat.target = {false, 1, 95}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(LosingCount(state), 1, "green to orange: the orange sound")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(LosingCount(state), 1, "still orange: no second sound")
    state.now = 5
    state.threat.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(SoundCount(state, 8959), 1, "orange to red: the red sound")
    equal(LosingCount(state), 1)
    equal(state.ns.soundCounts.losing.played, 1)
end)

test("DPS view: a first reading already orange is silent; solo off is silent", function()
    local first = fixture({threat = {target = {false, 1, 95}}, group = {role = "DAMAGER"}})
    first.combat = true
    first.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(LosingCount(first), 0, "no known green before it")
    equal(first.ns.soundCounts.losing.first, 1)
    local solo = fixture({threat = {target = {false, 0, 40}}})
    solo.fire("UNIT_THREAT_LIST_UPDATE", "target")
    solo.combat = true
    solo.threat.target = {false, 1, 95}
    solo.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(LosingCount(solo), 0, "solo, Threat sounds when solo off")
    equal(solo.ns.soundCounts.losing.solo, 1)
end)

test("without a percent the label shows the view's word", function()
    local state = fixture({group = {role = "TANK"}})
    state.simple.target = 1
    state.fire("UNIT_THREAT_SITUATION_UPDATE", "target")
    equal(TargetLabel(state).text.text, "LOST")
    state.settings.DYRE_THREAT_MODE:SetValue("dps")
    equal(TargetLabel(state).text.text, "HIGH")
end)

-- John, 2026-11-11: "Threat label rules should be exactly the same as Tank
-- bar rules. Druid in Bear, Paladin with Righteous Fury up, Warrior in
-- Defensive Stance or anyone designated Group Tank or Raid Main Tank get the
-- bar and are treated like tanks for aggro indicators."
test("auto view: exactly the tank bar's rule", function()
    local function View(options)
        local state = fixture(options)
        local view = state.ns.ThreatRole()
        local bar = state.ns.TankBarWanted()
        equal(bar, view == "tank", "the bar and the view agree")
        return view
    end
    equal(View({class = "PALADIN", auras = {[25780] = true}}), "tank", "Paladin with Righteous Fury")
    equal(View({class = "PALADIN"}), "dps", "Paladin without Righteous Fury")
    equal(View({class = "PALADIN", talents = {0, 31, 20}}), "dps", "Protection talents without Righteous Fury")
    equal(View({class = "WARRIOR", form = 18}), "tank", "Defensive Stance")
    equal(View({class = "WARRIOR", form = 17}), "dps", "Battle Stance")
    equal(View({class = "WARRIOR", form = 17, talents = {5, 0, 31}}), "dps", "Protection talents in Battle Stance")
    -- John, 2026-11-11: "Drop any attempt to look at talent builds to
    -- determine, that was wrong. Especially given the new tendency towards
    -- hybrid builds that mix Arms, Prot and Fury."
    equal(View({class = "WARRIOR", form = 17, talents = {20, 0, 31}}), "dps", "a hybrid Warrior in Battle Stance")
    equal(View({class = "WARRIOR", form = 18, talents = {20, 0, 31}}), "tank", "a hybrid Warrior in Defensive Stance")
    equal(View({class = "WARRIOR", form = 18, talents = {31, 20, 0}}), "tank", "an Arms Warrior in Defensive Stance")
    equal(View({class = "DRUID", form = 5}), "tank", "Bear Form")
    equal(View({class = "DRUID", form = 8}), "tank", "Dire Bear Form")
    equal(View({class = "DRUID", form = 1}), "dps", "Cat Form")
    equal(View({class = "DRUID", form = 5, group = {role = "HEALER"}}), "tank", "Bear Form wins over a Healer role")
    for _, class in ipairs({"MAGE", "PRIEST", "ROGUE", "WARLOCK", "HUNTER", "WARRIOR", "DRUID"}) do
        equal(View({class = class, group = {role = "TANK"}}), "tank", "group role Tank: " .. class)
        equal(View({class = class, group = {raid = true, mainTank = true, role = "DAMAGER"}}), "tank",
            "raid main tank, even with the Damage role: " .. class)
    end
    equal(View({class = "WARLOCK"}), "dps", "no pet rule: a Warlock solo")
    equal(View({class = "WARLOCK", pet = "Imp"}), "dps", "no drain tank rule")
    equal(View({class = "HUNTER"}), "dps", "no 'solo without a pet' rule")
    equal(View({class = "MAGE"}), "dps")
end)

test("auto view follows Righteous Fury on UNIT_AURA; a secret answer keeps the view", function()
    local state = fixture({class = "PALADIN", threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "dps")
    equal(label.text.color[2], 0.2, "no Righteous Fury: the mob on you is red")
    state.auras[25780] = true
    state.fire("UNIT_AURA", "player")
    equal(label.role, "tank", "Righteous Fury on: the tank view at once")
    equal(label.text.color[2], 1, "the mob on you is green")
    state.secretAura = state.secret()
    state.fire("UNIT_AURA", "player")
    equal(label.role, "tank", "a secret answer: the view is kept")
    equal((state.ns.ThreatRole()), "tank")
    equal(state.ns.TankBarWanted(), nil, "the bar keeps its state too")
    state.secretAura = nil
    state.auras[25780] = nil
    state.fire("UNIT_AURA", "player")
    equal(label.role, "dps", "Righteous Fury off: the DPS view")
    local fresh = fixture({class = "PALADIN"})
    fresh.secretAura = fresh.secret()
    equal((fresh.ns.ThreatRole()), "dps", "secret with no view yet: DPS")
end)

test("forced modes ignore the rule", function()
    local state = fixture({class = "WARRIOR", form = 18, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "tank")
    state.settings.DYRE_THREAT_MODE:SetValue("dps")
    equal(label.role, "dps")
    state.settings.DYRE_THREAT_MODE:SetValue("auto")
    state.form = 17
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "dps", "Battle Stance: the DPS view")
    state.settings.DYRE_THREAT_MODE:SetValue("tank")
    equal(label.role, "tank")
    equal(table.concat(state.settings.DYRE_THREAT_MODE.choices, ","), "auto,tank,dps")
    state.settings.DYRE_THREAT_MODE:SetValue("bogus")
    equal(state.env.DyresToolkitCharDB.threatMode, "tank", "an unknown choice is ignored")
end)

test("tank view: early yellow when another member nears the pull point; blue when another tank has it", function()
    local members = {party1 = {role = "DAMAGER"}, party2 = {role = "TANK"}}
    local state = fixture({group = {role = "TANK", members = members}, threat = {target = {true, 3, 100}},
        others = {party1 = {target = {false, 0, 60}}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.text.color[2], 1, "green: party1 at 60%")
    state.others.party1.target = {false, 0, 85}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 0.85, "early yellow: party1 at 85%")
    members.partypet1 = {}
    state.others.partypet1 = {target = {false, 0, 90}}
    state.others.party1.target = {false, 0, 10}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 0.85, "a pet near the pull point counts too")
    state.others.partypet1 = nil
    state.others.party1.target = {false, 0, state.secret()}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[2], 1, "a secret percent counts as unknown")
    state.threat.target = {false, 0, 70}
    state.others.party2 = {target = {true, 3, 100}}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[3], 1, "blue: the other tank has it")
    equal(label.text.color[1], 0.3)
    state.others.party2 = nil
    state.others.party1.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.text.color[1], 1, "red: a DPS has it")
    equal(label.text.color[2], 0.2)
    local dps = fixture({group = {role = "DAMAGER", members = members}, threat = {target = {false, 0, 70}},
        others = {party2 = {target = {true, 3, 100}}}})
    dps.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(TargetLabel(dps).text.color[2], 1, "the DPS view has no blue: green")
end)

test("a raid's main tank counts as another tank", function()
    local state = fixture({group = {raid = true, count = 2, role = "TANK",
        members = {raid2 = {mainTank = true}}}, threat = {target = {false, 1, 90}},
        others = {raid2 = {target = {true, 3, 100}}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(TargetLabel(state).text.color[1], 0.3, "blue")
end)

test("a sound plays when a mob turns red on a threat event, once, and not again within 2 seconds", function()
    local state = fixture({toolkit = true, units = {target = true, nameplate1 = true, nameplate2 = true},
        group = {role = "TANK"}, threat = {target = {true, 3, 100}}})
    state.plates.nameplate1 = {bar = state.env.UIParent:CreateTexture()}
    state.plates.nameplate2 = {bar = state.env.UIParent:CreateTexture()}
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(#state.sounds, 0, "a plate that comes into view red: no sound")
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(#state.sounds, 0, "still red: no sound")
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(#state.sounds, 1, "green to red: the sound")
    equal(state.sounds[1][1], 8959)
    equal(state.sounds[1][2], "Master")
    state.now = 1
    state.threat.nameplate2 = {true, 3, 100}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    state.threat.nameplate2 = {false, 0, 40}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    equal(#state.sounds, 1, "a second mob within 2 seconds: no second sound")
    state.now = 5
    state.threat.target = {false, 1, 90}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(#state.sounds, 2, "the target turns red later: the sound again")
    state.settings.DYRE_RED_SOUND:SetValue("none")
    state.now = 10
    state.threat.nameplate2 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    state.threat.nameplate2 = {false, 0, 40}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    equal(#state.sounds, 2, "off in the settings")
end)

-- The red sound from a change of state (John, 2026-11-11: it "fires only
-- about 10% of the time, randomly").
local function RedSounds(state)
    local count = 0
    for _, sound in ipairs(state.sounds) do
        if sound[1] == 8959 then count = count + 1 end
    end
    return count
end

test("a pull: PLAYER_REGEN_DISABLED before the threat event plays the red sound once", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(state), 0, "green")
    state.threat.target = {true, 3, 100}
    state.fire("PLAYER_REGEN_DISABLED")
    equal(RedSounds(state), 1, "combat starts and the label turns red: the sound (before: none)")
    state.combat = true
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
    equal(RedSounds(state), 1, "still red: no second sound")
    equal(state.ns.soundCounts.red.played, 1)
end)

test("a pull: the threat event before PLAYER_REGEN_DISABLED plays the red sound once", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.threat.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(state), 1)
    state.fire("PLAYER_REGEN_DISABLED")
    state.combat = true
    state.fire("GROUP_ROSTER_UPDATE")
    equal(RedSounds(state), 1, "the refresh after it: no second sound")
end)

test("in combat, any update that shows the change plays it; out of combat a refresh stays calm", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.threat.target = {true, 3, 100}
    state.fire("GROUP_ROSTER_UPDATE")
    equal(RedSounds(state), 1, "in combat: a roster event shows it, the sound plays")
    local calm = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    calm.fire("UNIT_THREAT_LIST_UPDATE", "target")
    calm.threat.target = {true, 3, 100}
    calm.fire("GROUP_ROSTER_UPDATE")
    equal(RedSounds(calm), 0, "out of combat, not a threat event")
    equal(calm.ns.soundCounts.red.calm, 1)
end)

-- John, 2026-11-11: "If a mob attacks me, and threat turns red, I should
-- still hear the chime that I got aggro, right?"
test("a target change onto a mob on you, in combat, plays the red sound (the gap allowing)", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.threat.target = {true, 3, 100}
    state.fire("PLAYER_TARGET_CHANGED")
    equal(RedSounds(state), 1)
    equal(state.ns.soundCounts.red.seen, 1)
    state.now = 1
    state.threat.target = {false, 0, 20}
    state.fire("PLAYER_TARGET_CHANGED")
    state.threat.target = {true, 3, 100}
    state.fire("PLAYER_TARGET_CHANGED")
    equal(RedSounds(state), 1, "another within 2 s: the gap")
    equal(state.ns.soundCounts.red.gap, 1)
end)

test("a new plate already red in combat plays the red sound", function()
    local state = fixture({group = {role = "DAMAGER"}})
    state.combat = true
    state.plates.nameplate1 = {bar = state.env.UIParent:CreateTexture()}
    state.units.nameplate1 = true
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(RedSounds(state), 1)
    local calm = fixture({group = {role = "DAMAGER"}})
    calm.plates.nameplate1 = {bar = calm.env.UIParent:CreateTexture()}
    calm.units.nameplate1 = true
    calm.threat.nameplate1 = {true, 3, 100}
    calm.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(RedSounds(calm), 0, "out of combat: calm")
end)

test("a form change that turns a label red plays nothing (the player changed the view)", function()
    -- Caster form, then Bear Form in combat (the reverse is the next test).
    local state = fixture({class = "DRUID", threat = {target = {false, 1, 90}}, db = {soloSounds = true}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(TargetLabel(state).text.color[2], 0.5, "caster form, DPS view: orange")
    state.combat = true
    state.form = 5
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(TargetLabel(state).text.color[2], 0.2, "Bear Form, tank view: the mob is not on you, red")
    equal(RedSounds(state), 0)
    equal(state.ns.soundCounts.red.view, 1)
    state.threat.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.threat.target = {false, 0, 20}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(state), 1, "a real change after it plays")
end)

-- John's Druid test, 2026-11-11: Bear Form in and out in combat gave green
-- in Bear and red out of it, at once. The form API is not hidden in combat,
-- so form and stance answers are never held.
test("in combat a Druid leaving Bear Form gets the DPS view at once", function()
    local state = fixture({class = "DRUID", form = 5, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "tank")
    equal(label.text.color[2], 1, "Bear Form, the mob on you: green")
    state.fire("PLAYER_REGEN_DISABLED")
    state.combat = true
    state.form = nil
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "dps", "caster form in combat: dps at once")
    equal(label.text.color[2], 0.2, "the mob on you in the DPS view: red")
    equal(RedSounds(state), 0, "the player changed the view: silent")
    equal(state.ns.TankBarWanted(), false, "the bar's rule says no at once too")
    equal(state.ns.tankCounts.held, 0, "nothing held")
    equal(state.ns.tankCounts.viewChanges, 1)
    state.form = 5
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "tank", "back in Bear Form: tank at once")
end)

test("in combat a Warrior leaving Defensive Stance gets the DPS view at once", function()
    local state = fixture({form = 18, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "tank")
    state.combat = true
    state.form = 17
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "dps", "Battle Stance in combat: dps at once")
    equal(state.ns.TankBarWanted(), false)
    state.form = 18
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "tank", "Defensive Stance again: tank at once")
end)

test("in combat a secret form ID keeps the view", function()
    local state = fixture({form = 18, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    state.combat = true
    state.form = state.secret()
    state.fire("UPDATE_SHAPESHIFT_FORM")
    equal(label.role, "tank", "a secret stance: the tank view stays")
    equal(state.ns.TankBarWanted(), nil, "hidden: the bar keeps its state")
    local druid = fixture({class = "DRUID", threat = {target = {true, 3, 100}}})
    druid.fire("UNIT_THREAT_LIST_UPDATE", "target")
    druid.combat = true
    druid.form = druid.secret()
    druid.fire("UPDATE_SHAPESHIFT_FORM")
    equal(TargetLabel(druid).role, "dps", "a secret form: the DPS view stays")
end)

-- Dyre's Buff Reminders' Druid probe (DyresBuffReminders TESTING.md:63-68):
-- in combat GetPlayerAuraBySpellID gave a plain nil for an aura that was up,
-- and ShouldSpellAuraBeSecret said true; out of combat it said false.
test("Righteous Fury read nil while ShouldSpellAuraBeSecret says true, secret, or fails: the tank view stays", function()
    for _, answer in ipairs({true, "secret", "error"}) do
        local state = fixture({class = "PALADIN", auras = {[25780] = true}, cSecrets = true,
            auraSecret = false, threat = {target = {true, 3, 100}}})
        state.fire("UNIT_THREAT_LIST_UPDATE", "target")
        local label = TargetLabel(state)
        equal(label.role, "tank", tostring(answer))
        state.combat = true
        state.auraSecret = answer
        state.auras[25780] = nil
        state.fire("UNIT_AURA", "player")
        state.fire("UNIT_THREAT_LIST_UPDATE", "target")
        equal(label.role, "tank", tostring(answer) .. ": a nil read is hidden, the view stays")
        equal(label.text.color[2], 1, tostring(answer) .. ": the mob on you stays green")
        equal(state.ns.TankBarWanted(), nil, tostring(answer) .. ": the bar keeps its state")
        assert(state.ns.tankCounts.held >= 1, "held counted")
        equal(state.auraSecretAsked[25780] >= 2, true, "asked for Righteous Fury's spell ID")
    end
    -- Also out of combat: a true answer keeps the view.
    local calm = fixture({class = "PALADIN", auras = {[25780] = true}, cSecrets = true, auraSecret = false})
    calm.auraSecret = true
    calm.auras[25780] = nil
    calm.fire("UNIT_AURA", "player")
    equal(calm.ns.TankBarWanted(), nil, "true out of combat: hidden too")
end)

test("Righteous Fury read nil while ShouldSpellAuraBeSecret says false: the DPS view at once, in combat too", function()
    local state = fixture({class = "PALADIN", auras = {[25780] = true}, cSecrets = true,
        auraSecret = false, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "tank")
    state.combat = true
    state.auras[25780] = nil
    state.fire("UNIT_AURA", "player")
    equal(label.role, "dps", "false in combat: Righteous Fury is off, dps at once")
    equal(state.ns.TankBarWanted(), false)
    equal(state.ns.tankCounts.held, 0, "nothing held")
    state.auras[25780] = true
    state.auraSecret = true
    state.fire("UNIT_AURA", "player")
    equal(label.role, "tank", "a found aura is always true, whatever C_Secrets says")
    -- The debug line shows C_Secrets' answers in and out of combat.
    state.ns.ReportThreatProbe()
    local line = state.find("righteous fury reads")
    -- (Both the view and the bar read the rule, so the counts are not 1.)
    assert(line:find("combat: aura=%d+ nil=%d+, aura secret true=%d+ false=%d+;"), line)
    assert(line:find("calm: aura=%d+, aura secret false=%d+;"), line)
end)

-- John's test, Forever 1.60.1 70888, 2026-11-11: a Paladin with Righteous
-- Fury up the whole fight saw green turn red at 100% after a few swings
-- (UNIT_AURA=46, red view=6). Without C_Secrets (Era), a nil read in
-- combat is held: it keeps the view.
test("without C_Secrets, a nil Righteous Fury read in combat keeps the tank view; combat's end reads it again", function()
    local state = fixture({class = "PALADIN", auras = {[25780] = true}, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.role, "tank")
    state.fire("PLAYER_REGEN_DISABLED")
    state.combat = true
    state.auras[25780] = nil
    for _ = 1, 5 do state.fire("UNIT_AURA", "player") end
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(label.role, "tank", "the aura read gives nil in combat: the view stays tank")
    equal(label.text.color[2], 1, "the mob on you stays green")
    equal(state.ns.soundCounts.red.view, 0, "no view change, no silent red")
    equal(state.ns.TankBarWanted(), nil, "the bar keeps its state too")
    equal(state.ns.tankCounts.viewChanges, 0)
    assert(state.ns.tankCounts.held >= 5, "held counted")
    equal(state.ns.auraReads.combat["nil"] >= 5, true, "nil reads in combat counted")
    equal(state.ns.auraReads.calm.aura >= 1, true, "aura reads out of combat counted")
    -- Combat ends with no Righteous Fury: the view becomes dps then.
    state.combat = false
    state.fire("PLAYER_REGEN_ENABLED")
    equal(label.role, "dps", "PLAYER_REGEN_ENABLED: read again, the DPS view")
    equal(state.ns.TankBarWanted(), false)
    -- Out of combat, false gives dps at once; in combat, true gives tank at once.
    state.combat = true
    state.auras[25780] = true
    state.fire("UNIT_AURA", "player")
    equal(label.role, "tank", "in combat, true switches to tank at once")
    equal(state.ns.tankCounts.viewChanges, 1, "a view change in combat counted")
    state.auras[25780] = nil
    state.fire("UNIT_AURA", "player")
    equal(label.role, "tank", "false then true in combat: stays tank")
    state.combat = false
    state.fire("UNIT_AURA", "player")
    equal(label.role, "dps", "out of combat, false gives dps")
    -- The debug line.
    state.ns.ReportThreatProbe()
    contains(state.find("righteous fury reads"), "aura secret missing=")
    contains(state.find("righteous fury reads"), "held=")
    contains(state.find("righteous fury reads"), "view changes in combat=1")
end)

test("the target and its plate turning red together play once and count once", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.plates.nameplate1 = {bar = state.env.UIParent:CreateTexture()}
    state.units.nameplate1 = true
    state.sameAsTarget.nameplate1 = true
    state.threat.nameplate1 = {false, 0, 20}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.threat.target = {true, 3, 100}
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(RedSounds(state), 1)
    equal(state.ns.soundCounts.red.seen, 1, "one mob")
    equal(state.ns.soundCounts.red.same, 1)
    local secret = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    secret.plates.nameplate1 = {bar = secret.env.UIParent:CreateTexture()}
    secret.units.nameplate1 = true
    secret.sameAsTarget.nameplate1 = secret.secret()
    secret.threat.nameplate1 = {false, 0, 20}
    secret.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    secret.fire("UNIT_THREAT_LIST_UPDATE", "target")
    secret.combat = true
    secret.threat.target = {true, 3, 100}
    secret.threat.nameplate1 = {true, 3, 100}
    secret.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(secret.ns.soundCounts.red.same, 0, "a secret UnitIsUnit: a different mob")
    equal(secret.ns.soundCounts.red.seen, 2)
    equal(secret.ns.soundCounts.red.gap, 1, "the second within 2 s")
end)

test("UNIT_THREAT_SITUATION_UPDATE for the player reads every plate again", function()
    local state = fixture({group = {role = "DAMAGER"}})
    state.plates.nameplate1 = {bar = state.env.UIParent:CreateTexture()}
    state.units.nameplate1 = true
    state.threat.nameplate1 = {false, 0, 30}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = state.ns.ThreatLabels().nameplate1
    equal(label.text.color[2], 1, "green")
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_SITUATION_UPDATE", "player")
    equal(label.text.color[2], 0.2, "red: the plate was read again")
    equal(RedSounds(state), 1)
end)

test("a new view is a first reading; the sound counts show in /dtt debug_threat", function()
    local state = fixture({class = "DRUID", group = {role = "DAMAGER"}, threat = {target = {true, 3, 100}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.settings.DYRE_THREAT_MODE:SetValue("tank")
    equal(TargetLabel(state).text.color[2], 1, "tank view: green")
    state.settings.DYRE_THREAT_MODE:SetValue("dps")
    equal(TargetLabel(state).text.color[2], 0.2, "DPS view: red")
    equal(RedSounds(state), 0, "a view change is not a threat change")
    state.settings.DYRE_RED_SOUND:SetValue("none")
    state.threat.target = {false, 0, 20}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.threat.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(state.ns.soundCounts.red.none, 1)
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug_threat")
    contains(state.find("red sound:"), "seen=2 played=0 skipped gap=0 none=1 calm=1 solo=0 view=1 same=0")
    assert(state.find("losing sound:"), "the losing line")
end)

-- John, 2026-11-12: "super useful in groups, but can get tiresome when solo
-- grinding hearing it on every pull".
-- John, 2026-11-12: "Change it to default off. Most people, when solo, will
-- not want the sound."
test("Threat sounds when solo: off by default, no red sound out of a group, the label still red", function()
    local solo = fixture({threat = {target = {false, 0, 20}}})
    equal(solo.env.DyresToolkitCharDB.soloSounds, false, "default off")
    solo.fire("UNIT_THREAT_LIST_UPDATE", "target")
    solo.combat = true
    solo.threat.target = {true, 3, 100}
    solo.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(solo), 0, "solo: no sound")
    equal(solo.ns.soundCounts.red.solo, 1)
    equal(TargetLabel(solo).text.color[2], 0.2, "the label still turns red")
    local group = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    group.settings.DYRE_SOLO_SOUNDS:SetValue(false)
    group.fire("UNIT_THREAT_LIST_UPDATE", "target")
    group.combat = true
    group.threat.target = {true, 3, 100}
    group.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(group), 1, "in a group: the sound plays")
    local on = fixture({threat = {target = {false, 0, 20}}})
    on.settings.DYRE_SOLO_SOUNDS:SetValue(true)
    equal(on.env.DyresToolkitCharDB.soloSounds, true, "saved")
    on.fire("UNIT_THREAT_LIST_UPDATE", "target")
    on.combat = true
    on.threat.target = {true, 3, 100}
    on.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(RedSounds(on), 1, "on: solo plays too")
end)


test("no sound for a secret status or a new target that is already red", function()
    local state = fixture({group = {role = "DAMAGER"}, threat = {target = {false, 0, 20}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.threat.target = {true, 3, 100}
    state.fire("PLAYER_TARGET_CHANGED")
    equal(#state.sounds, 0, "a target change is not a threat change")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(#state.sounds, 0, "still red")
    state.threat.target = {state.secret(), state.secret(), state.secret()}
    state.simple.target = state.secret()
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.now = 10
    state.threat.target = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(#state.sounds, 1, "from white (secret) to red: the sound")
end)

test("a secret status and percent show the percent in white, never compared", function()
    local state = fixture()
    state.threat.target = {state.secret(), state.secret(), state.secret()}
    state.simple.target = state.secret()
    local reading = state.ns.ReadThreat("target")
    equal(reading.status, nil)
    equal(reading.secretStatus, true)
    state.fire("UNIT_THREAT_SITUATION_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.text.secretText, true, "the secret percent reached SetFormattedText")
    equal(label.text.text, "%.0f%%")
    equal(label.text.color[1], 1)
    equal(label.text.color[2], 1)
    equal(label.shown, true)
    equal(label.icon.texture ~= nil, true, "the icon shows also with a secret")
end)

test("a secret detailed status falls back to a readable UnitThreatSituation", function()
    local state = fixture()
    state.threat.target = {state.secret(), state.secret(), nil}
    state.simple.target = 2
    local reading = state.ns.ReadThreat("target")
    equal(reading.status, 2)
    equal(reading.secretStatus, nil)
    equal(reading.hasPercent, nil)
end)

-- John's /dtt debug_threat in combat on Forever (build 70888, 2026-11-11):
-- the "target" token reads; every detailed value on a "nameplateN" token is
-- secret, but UnitThreatSituation reads there.
local function ForeverPlate(state, unit)
    state.plates[unit] = {bar = state.env.UIParent:CreateTexture()}
    state.units[unit] = true
    state.threat[unit] = {state.secret(), state.secret(), state.secret(), state.secret(), state.secret()}
    state.simple[unit] = 3
end

test("Forever plates: the color from UnitThreatSituation, the secret percent in that color", function()
    local state = fixture({group = {role = "TANK"}})
    ForeverPlate(state, "nameplate1")
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = state.ns.ThreatLabels().nameplate1
    equal(label.shown, true)
    equal(label.text.secretText, true, "the secret percent reached SetFormattedText")
    equal(label.text.color[1], 0.2, "green: status 3 from UnitThreatSituation")
    state.simple.nameplate1 = 0
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(label.text.color[1], 1, "red")
    equal(label.text.color[2], 0.2)
end)

test("the plate of your target reads the target token: a readable percent and the group's threat", function()
    local members = {party1 = {role = "DAMAGER"}}
    local state = fixture({group = {role = "TANK", members = members}, threat = {target = {true, 3, 100}},
        others = {party1 = {target = {false, 0, 85}}}})
    ForeverPlate(state, "nameplate1")
    state.sameAsTarget.nameplate1 = true
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local label = state.ns.ThreatLabels().nameplate1
    equal(label.text.text, "100%", "the target token's readable percent")
    equal(label.text.secretText, nil)
    equal(label.text.color[1], 1, "early yellow: party1 at 85% of the pull point")
    equal(label.text.color[2], 0.85)
    state.sameAsTarget.nameplate1 = state.secret()
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(label.text.secretText, true, "a secret UnitIsUnit: the plate's own token")
    equal(label.text.color[1], 0.2, "no early yellow from secret plate values: green")
    state.sameAsTarget.nameplate1 = false
    state.fire("PLAYER_TARGET_CHANGED")
    equal(label.text.secretText, true, "another target: the plate's own token")
end)

-- Losing a mob and pull bars (John, 2026-11-11: "a visible clue that threat
-- is getting low on a mob").
local function Plate(state, unit, entry)
    state.plates[unit] = {bar = state.env.UIParent:CreateTexture()}
    state.units[unit] = true
    state.threat[unit] = entry
end

local function Sounds(state, id)
    local count = 0
    for _, sound in ipairs(state.sounds) do
        if sound[1] == id then count = count + 1 end
    end
    return count
end

test("tank view: a plate at status 2 says LOSING in orange; the target label keeps its percent", function()
    local state = fixture({group = {role = "TANK"}, threat = {target = {true, 2, 100}}})
    Plate(state, "nameplate1", {true, 2, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local plates, target = state.ns.ThreatLabels()
    equal(plates.nameplate1.text.text, "LOSING")
    equal(plates.nameplate1.text.color[1], 1)
    equal(plates.nameplate1.text.color[2], 0.5, "orange")
    equal(target.text.text, "100%", "the target label keeps its percent")
    equal(target.text.color[2], 0.85, "yellow")
    local dps = fixture({group = {role = "DAMAGER"}})
    Plate(dps, "nameplate1", {true, 2, 100})
    dps.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(dps.ns.ThreatLabels().nameplate1.text.text, "100%", "the DPS view keeps the percent")
    local forever = fixture({group = {role = "TANK"}})
    Plate(forever, "nameplate1", {forever.secret(), forever.secret(), forever.secret()})
    forever.simple.nameplate1 = 2
    forever.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(forever.ns.ThreatLabels().nameplate1.text.text, "LOSING", "from UnitThreatSituation, with a secret percent")
end)

test("Threat sounds when solo off: no losing sound out of a group", function()
    local state = fixture({})
    state.settings.DYRE_THREAT_MODE:SetValue("tank")
    state.settings.DYRE_SOLO_SOUNDS:SetValue(false)
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.combat = true
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 0, "solo: no losing sound")
    equal(state.ns.soundCounts.losing.solo, 1)
    equal(state.ns.ThreatLabels().nameplate1.text.text, "LOSING", "the label still shows it")
end)

test("losing a mob (3 to 2) plays its own sound once, at most once in 2 seconds", function()
    local state = fixture({group = {role = "TANK"}})
    Plate(state, "nameplate1", {true, 2, 100})
    Plate(state, "nameplate2", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 0, "a plate that comes into view at 2: no sound")
    state.threat.nameplate2 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    equal(Sounds(state, 847), 1, "3 to 2: the losing sound")
    equal(state.sounds[1][2], "Master")
    equal(Sounds(state, 8959), 0, "not the red sound")
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate2")
    equal(Sounds(state, 847), 1, "still 2: no second sound")
    state.now = 1
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 1, "another mob within 2 seconds: no sound")
    state.now = 5
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 2, "later: the sound again")
    state.settings.DYRE_LOSING_SOUND:SetValue("none")
    state.now = 10
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 2, "off in the settings")
end)

test("no losing sound in the DPS view or for a secret status", function()
    local dps = fixture({group = {role = "DAMAGER"}})
    Plate(dps, "nameplate1", {true, 3, 100})
    dps.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    dps.threat.nameplate1 = {true, 2, 100}
    dps.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(dps, 847), 0, "DPS view")
    local state = fixture({group = {role = "TANK"}})
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.threat.nameplate1 = {state.secret(), state.secret(), state.secret()}
    state.simple.nameplate1 = state.secret()
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.simple.nameplate1 = nil
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(Sounds(state, 847), 0, "3, then secret, then 2: never from a secret")
end)

local function Party(extra)
    local options = {group = {role = "TANK", members = {party1 = {role = "DAMAGER"}, party2 = {role = "HEALER"}}},
        globals = {RAID_CLASS_COLORS = {WARRIOR = {r = 0.78, g = 0.61, b = 0.43}}}}
    for key, value in pairs(extra or {}) do options[key] = value end
    return fixture(options)
end

local function Bars(state, unit)
    return select(3, state.ns.ThreatLabels())[unit]
end

test("pull bars: one per party member on the mob's list, filled with its scaled threat", function()
    local state = Party({others = {party1 = {nameplate1 = {false, 0, 60}}}})
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local holder = Bars(state, "nameplate1")
    equal(holder.shown, true)
    local one, two = holder.bars[1], holder.bars[2]
    equal(one.shown, true)
    equal(one.lastSetValue[1], 60)
    equal(one.lastSetMinMaxValues[2], 100)
    equal(one.lastSetStatusBarColor[1], 0.78, "the member's class color")
    equal(two.shown, false, "party2 is not on the threat list: no bar")
    state.others.party2 = {nameplate1 = {false, 0, 30}}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(two.shown, true)
    equal(two.lastSetValue[1], 30)
    state.others.party1 = {}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(one.shown, false, "off the list: the bar hides")
    equal(two.points[1][5], 0, "the shown bar moves up to the first row")
    state.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(holder.shown, false, "the plate went")
end)

test("pull bars take a secret value as it is, never compared", function()
    local state = Party()
    local value = state.secret()
    state.others.party1 = {nameplate1 = {state.secret(), state.secret(), value}}
    Plate(state, "nameplate1", {state.secret(), state.secret(), state.secret()})
    state.simple.nameplate1 = 3
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local bar = Bars(state, "nameplate1").bars[1]
    equal(bar.shown, true)
    assert(rawequal(bar.lastSetValue[1], value), "the secret went to SetValue")
end)

test("pull bars: not in a raid, not in the DPS view, not solo, and off in the settings", function()
    local raid = fixture({group = {raid = true, count = 2, role = "TANK", members = {raid2 = {role = "DAMAGER"}}},
        others = {raid2 = {nameplate1 = {false, 0, 60}}}})
    Plate(raid, "nameplate1", {true, 3, 100})
    raid.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(Bars(raid, "nameplate1"), nil, "a raid: no bars")
    local dps = Party({others = {party1 = {nameplate1 = {false, 0, 60}}}})
    dps.group.role = "DAMAGER"
    Plate(dps, "nameplate1", {false, 0, 50})
    dps.fire("GROUP_ROSTER_UPDATE")
    dps.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(Bars(dps, "nameplate1"), nil, "the DPS view: no bars")
    local solo = fixture()
    Plate(solo, "nameplate1", {true, 3, 100})
    solo.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(Bars(solo, "nameplate1"), nil, "solo: no bars")
    local state = Party({others = {party1 = {nameplate1 = {false, 0, 60}}}})
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(Bars(state, "nameplate1").shown, true)
    state.settings.DYRE_PULL_BARS:SetValue(false)
    equal(Bars(state, "nameplate1").shown, false, "off in the settings")
    state.settings.DYRE_PULL_BARS:SetValue(true)
    state.group.raid = true
    state.fire("GROUP_ROSTER_UPDATE")
    equal(Bars(state, "nameplate1").shown, false, "the party became a raid")
end)

test("pull bars sit under the health bar; a label placed below goes under them", function()
    local state = Party({others = {party1 = {nameplate1 = {false, 0, 60}}}})
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    local holder = Bars(state, "nameplate1")
    equal(holder.points[1][1], "TOPLEFT")
    equal(holder.points[1][2], state.plates.nameplate1.bar)
    equal(holder.points[1][3], "BOTTOMLEFT")
    state.settings.DYRE_PLATE_PLACE:SetValue("below")
    local label = state.ns.ThreatLabels().nameplate1
    equal(label.points[1][2], holder, "below: under the pull bars")
    state.settings.DYRE_PLATE_PLACE:SetValue("right")
    equal(label.points[1][2], state.plates.nameplate1.bar, "right: beside the health bar")
end)

test("/dtt debug_threat lists each party member's threat on the target and the first plate", function()
    local state = Party({others = {party1 = {target = {false, 0, 40}}}})
    Plate(state, "nameplate1", {true, 3, 100})
    state.others.party2 = {nameplate1 = {state.secret(), state.secret(), state.secret(), state.secret()}}
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug_threat")
    contains(state.find("target party1:"), "scaled=40")
    contains(state.find("target party2:"), "scaled=nil")
    contains(state.find("nameplate1 party2:"), "scaled=secret(")
    local solo = fixture()
    solo.env.SlashCmdList.DYRESTOOLKITTANK("debug_threat")
    assert(solo.find("target group: no party members or pets"))
end)

-- Round 6 (John, 2026-11-11): sound choices and tinted icons.
-- John, 2026-11-12: "Group warnings has everything all mixed up; a kitchen
-- sink of settings."
test("settings page: the threat sections, then Group Warnings, then Tank Tools", function()
    local state = fixture({globals = {CreateSettingsListSectionHeaderInitializer = function(text)
        return "## " .. text
    end}})
    local order = {}
    for _, entry in ipairs(state.page) do
        if type(entry) == "string" and (entry:find("^## ") or entry:find("^DYRE_")) then
            order[#order + 1] = entry
        end
    end
    equal(table.concat(order, ","), table.concat({
        "DYRE_UNLOCKED", "DYRE_GRID", "DYRE_SNAP_GRID", "DYRE_GRID_SIZE", "DYRE_MINIMAP",
        "## Threat Indicators: Nameplates", "DYRE_THREAT_MODE", "DYRE_PLATE_THREAT", "DYRE_PLATE_PLACE",
        "DYRE_PLATE_X", "DYRE_PLATE_Y", "DYRE_PLATE_SCALE",
        "## Threat Indicators: Target Frame", "DYRE_TARGET_THREAT", "DYRE_TARGET_X", "DYRE_TARGET_Y",
        "DYRE_TARGET_SCALE",
        "## Threat Indicators: Sounds", "DYRE_RED_SOUND", "DYRE_LOSING_SOUND", "DYRE_SOLO_SOUNDS",
        "## Group Warnings", "DYRE_PULL_BARS", "DYRE_PULL_DISPLAY", "DYRE_PULL_TICK", "DYRE_PULL_GO",
        "DYRE_DYRESTOOLKIT_PULLTIMER_SCALE", "DYRE_DYRESTOOLKIT_PULLTIMER_OPACITY", "DYRE_PET_TAUNT",
        "## Tank Tools", "DYRE_TANK_BAR_MODE", "DYRE_PULL"}, ","))
end)

local SOUND_ORDER = "none,raidWarning,questFailed,readyCheck,alarmClock,bossEmote,bossWhisper,queueReady,mapPing,"
    .. "countdownTick,countdownGo"

test("sound dropdowns: None and the game sounds; without Dyre's Sounds the defaults show their game fallbacks", function()
    local state = fixture()
    local red, losing = state.settings.DYRE_RED_SOUND, state.settings.DYRE_LOSING_SOUND
    equal(table.concat(red.choices, ","), SOUND_ORDER)
    equal(table.concat(losing.choices, ","), SOUND_ORDER, "the same list for both")
    equal(red.labels.none, "Game Warnings: None")
    equal(red.labels.raidWarning, "Game Warnings: Raid warning")
    equal(red.name, "Alert sound (red)", "John, 2026-11-12")
    equal(losing.name, "Warning sound (orange)")
    equal(red.default, "alertbellbuzz", "John, 2026-11-11: Dyre's Alerts: Bell buzz")
    equal(losing.default, "alertshake", "Dyre's Alerts: Cartoon shake")
    equal(red:GetValue(), "raidWarning", "no Dyre's Sounds: the game fallback shows as chosen")
    equal(losing:GetValue(), "questFailed")
    equal(state.settings.DYRE_THREAT_SOUND, nil, "the old checkbox is gone")
    local ids = {}
    for _, choice in ipairs(red.choices) do ids[#ids + 1] = tostring((state.ns.SoundID(choice))) end
    equal(table.concat(ids, ","), "nil,8959,847,8960,12889,12197,37666,8459,3175,25477,25478",
        "numbers without SOUNDKIT")
    equal(state.ns.SoundID("bogus"), nil)
    local kit = fixture({globals = {SOUNDKIT = {RAID_WARNING = 111, MAP_PING = "x"}}})
    equal(kit.ns.SoundID("raidWarning"), 111, "SOUNDKIT where it has the key")
    equal(kit.ns.SoundID("mapPing"), 3175, "a non-number SOUNDKIT value: the number")
    equal(kit.ns.SoundID("readyCheck"), 8960, "a missing key: the number")
    equal(kit.ns.SoundID("questFailed"), 847, "no SOUNDKIT key on either client: the number")
end)

test("sound settings migrate from the old switches and repair unknown values", function()
    local function db(saved) return fixture({db = saved}).env.DyresToolkitCharDB end
    local fresh = db(nil)
    equal(fresh.redSound, nil, "nil is the default: only a player's own choice is saved")
    equal(fresh.losingSound, nil)
    equal(fresh.soundSaves, 1)
    equal(fresh.sound, nil, "the old key is dropped")
    equal(db({sound = false}).redSound, "none", "red switch off: None")
    equal(db({sound = true}).redSound, nil, "red switch on: the default")
    equal(db({losingSound = false}).losingSound, "none", "losing switch off: None")
    equal(db({losingSound = true}).losingSound, nil, "losing switch on: the default")
    local bad = db({redSound = "bogus", losingSound = 42})
    equal(bad.redSound, "bogus", "a key-shaped choice is kept (a Dyre's Sounds key may come back)")
    equal(bad.losingSound, nil, "a number: the default")
    equal(db({redSound = "two words"}).redSound, nil, "not a key: the default")
    equal(db({redSound = string.rep("a", 65)}).redSound, nil, "too long: the default")
    local kept = db({redSound = "mapPing", losingSound = "none", sound = false})
    equal(kept.redSound, "mapPing", "a choice wins over the old switch")
    equal(kept.losingSound, "none")
end)

-- John, 2026-11-11: "set these as the defaults". The saves before could not
-- tell a choice from a default (SanitizeDB wrote the default), so the old
-- defaults become nil once; after that a game sound saved is a choice.
test("old saves: the old default sounds become the new defaults once; other choices stay", function()
    local function db(saved) return fixture({db = saved}).env.DyresToolkitCharDB end
    local old = db({redSound = "raidWarning", losingSound = "questFailed", pullTick = "countdownTick",
        pullGo = "countdownGo"})
    equal(old.redSound, nil, "the old red default: now the default")
    equal(old.losingSound, nil, "the old losing default: now the default")
    equal(old.pullTick, nil)
    equal(old.pullGo, nil)
    equal(old.soundSaves, 1, "once")
    local chosen = db({redSound = "mapPing", losingSound = "alarmClock"})
    equal(chosen.redSound, "mapPing", "another game sound is a choice: kept")
    equal(chosen.losingSound, "alarmClock")
    local crossed = db({redSound = "questFailed", losingSound = "raidWarning"})
    equal(crossed.redSound, "questFailed", "only each setting's own old default moves")
    equal(crossed.losingSound, "raidWarning")
    local after = db({redSound = "raidWarning", losingSound = "questFailed", soundSaves = 1})
    equal(after.redSound, "raidWarning", "after the move, a saved game sound is the player's choice")
    equal(after.losingSound, "questFailed")
end)

test("a sound picked in the settings plays once out of combat, and the alarms use the choice", function()
    local state = fixture({group = {role = "TANK"}})
    state.settings.DYRE_RED_SOUND:SetValue("mapPing")
    equal(#state.sounds, 1, "the preview")
    equal(state.sounds[1][1], 3175)
    equal(state.sounds[1][2], "Master")
    state.settings.DYRE_LOSING_SOUND:SetValue("readyCheck")
    equal(state.sounds[2][1], 8960)
    state.settings.DYRE_RED_SOUND:SetValue("none")
    equal(#state.sounds, 2, "None plays nothing")
    state.settings.DYRE_RED_SOUND:SetValue("bogus")
    equal(state.env.DyresToolkitCharDB.redSound, "none", "an unknown choice is not saved from the menu")
    equal(#state.sounds, 2)
    state.combat = true
    state.settings.DYRE_RED_SOUND:SetValue("alarmClock")
    equal(#state.sounds, 2, "no preview in combat")
    equal(state.env.DyresToolkitCharDB.redSound, "alarmClock", "the choice still saves in combat")
    state.combat = false
    -- The alarms play the choices.
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[#state.sounds][1], 8960, "losing: the chosen ready check")
    state.now = 5
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[#state.sounds][1], 12889, "red: the chosen alarm clock")
end)

-- Dyre's Sounds (John, 2026-11-11: "add all the Dyre's Sounds as options"):
-- a mock of its library interface (src/DyresSounds 1.4.0 Sounds.lua).
-- alerts: 1.5.0's "Dyre's Alerts" (src/DyresSounds Catalog.lua), with the
-- two default keys.
local function SoundLibrary(contract, alerts)
    local played = {}
    local catalog = {
        {key = "bell", label = "Interface: Bell"},
        {key = "gong", label = "Interface: Gong"},
        {key = "roar", label = "Dyre's Bears: Roar"},
        {key = "voice", label = "Text to Speech", voice = true},
    }
    if alerts then
        table.insert(catalog, {key = "alertbellbuzz", label = "Dyre's Alerts: Bell buzz"})
        table.insert(catalog, {key = "alertshake", label = "Dyre's Alerts: Cartoon shake"})
    end
    local byKey, aliases = {}, {oldbell = "bell"}
    for _, sound in ipairs(catalog) do byKey[sound.key] = sound end
    local api = {CONTRACT = contract or 1, played = played, silent = {}}
    function api.RequireContract(minimum) if minimum <= api.CONTRACT then return api end end
    function api.Resolve(key) local sound = byKey[aliases[key] or key] return sound and sound.key end
    function api.Label(key) local sound = byKey[api.Resolve(key)] return sound and sound.label end
    function api.Parts(sound) local group, name = sound.label:match("^(.-): (.+)$") return group, name or sound.label end
    function api.Playable(key) return byKey[key] ~= nil end
    function api.List() return catalog end
    function api.Groups()
        local groups, byName = {}, {}
        for _, sound in ipairs(catalog) do
            local group = api.Parts(sound) or sound.label
            if not byName[group] then
                byName[group] = {name = group, sounds = {}}
                groups[#groups + 1] = byName[group]
            end
            table.insert(byName[group].sounds, sound)
        end
        return groups
    end
    function api.Play(key, speech, channel)
        if api.silent[key] then return false end
        played[#played + 1] = {key, speech, channel}
        return true
    end
    return api
end

-- The menu a sound dropdown builds: {{button or radio, label, children}}.
local function SoundMenu(state, variable)
    local setting = state.settings[variable]
    local initializer = setting.initializer
    local frame = {SetupDropdownMenu = function() state.originalMenu = true end}
    initializer:InitFrame(frame)
    frame.SetupDropdownMenu({}, {}, setting, nil, nil, initializer)
    local init = state.dropdownInits[#state.dropdownInits]
    local function Node()
        local node = {children = {}}
        function node:CreateButton(label)
            local child = Node()
            child.kind, child.label = "button", label
            table.insert(self.children, child)
            return child
        end
        function node:CreateRadio(label, isSelected, setSelected, key)
            table.insert(self.children, {kind = "radio", label = label, key = key, isSelected = isSelected,
                setSelected = setSelected})
        end
        return node
    end
    local root = Node()
    init.inserter(setting, root)
    return root, frame, initializer
end

test("sounds without Dyre's Sounds: only Game Warnings; a saved Dyre's Sounds key is kept, the default plays", function()
    local state = fixture({group = {role = "TANK"}, db = {redSound = "bell"}})
    equal(state.env.DyresToolkitCharDB.redSound, "bell", "kept")
    equal(state.settings.DYRE_RED_SOUND:GetValue(), "raidWarning", "the dropdown shows the default as chosen")
    equal(#state.settings.DYRE_RED_SOUND.choices, 11, "Game Warnings only")
    local root = SoundMenu(state, "DYRE_RED_SOUND")
    equal(#root.children, 1)
    equal(root.children[1].label, "Game Warnings")
    equal(#root.children[1].children, 11)
    equal(root.children[1].children[1].label, "None")
    equal(root.children[1].children[2].key, "raidWarning")
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[1][1], 8959, "the default's game fallback, the raid warning")
    equal(state.env.DyresToolkitCharDB.redSound, "bell", "still kept")
    local old = fixture({db = {redSound = "bell"}, globals = {DyresSounds = SoundLibrary(0)}})
    equal(old.settings.DYRE_RED_SOUND:GetValue(), "raidWarning", "a contract too old counts as missing")
    equal(#old.settings.DYRE_RED_SOUND.choices, 11)
end)

test("sounds with Dyre's Sounds: its groups follow Game Warnings, saved by key, played through it", function()
    local library = SoundLibrary()
    local state = fixture({group = {role = "TANK"}, globals = {DyresSounds = library}})
    local red = state.settings.DYRE_RED_SOUND
    equal(table.concat(red.choices, ","), SOUND_ORDER .. ",bell,gong,roar,voice")
    equal(red.labels.bell, "Interface: Bell", "its full label in the plain list")
    local root, _, initializer = SoundMenu(state, "DYRE_RED_SOUND")
    equal(initializer.data.forceSteppersHidden, true)
    local labels = {}
    for _, child in ipairs(root.children) do labels[#labels + 1] = child.kind .. ":" .. child.label end
    equal(table.concat(labels, ","), "button:Game Warnings,button:Interface,button:Dyre's Bears,radio:Text to Speech",
        "Game Warnings first, then its groups; a sound without a group at the top")
    equal(root.children[2].children[1].label, "Bell", "the name within its group")
    root.children[2].children[2].setSelected("gong")
    equal(state.env.DyresToolkitCharDB.redSound, "gong", "saved by its key")
    equal(library.played[1][1], "gong", "the preview through Dyre's Sounds")
    equal(library.played[1][3], "Master")
    equal(#state.sounds, 0, "no game sound for it")
    equal(root.children[2].children[2].isSelected("gong"), true)
    equal(initializer.getSelectionTextFunc(), "Interface: Gong")
    red:SetValue("oldbell")
    equal(state.env.DyresToolkitCharDB.redSound, "bell", "an older key saved as its own (Resolve)")
    red:SetValue("nothing")
    equal(state.env.DyresToolkitCharDB.redSound, "bell", "a key it does not have is not saved")
    red:SetValue("voice")
    equal(library.played[#library.played][2], "Aggro", "text to speech says something")
    -- The alarm.
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    local last = library.played[#library.played]
    equal(last[1], "voice")
    equal(last[2], "Aggro lost", "the tank view's words")
    equal(last[3], "Master")
    -- A sound it cannot play: the default game sound.
    state.settings.DYRE_LOSING_SOUND:SetValue("roar")
    library.silent.roar = true
    state.now = 10
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[#state.sounds][1], 847, "it did not play: the default quest failed sound")
end)

test("DPS view: the orange sound's text to speech says \"High threat\"", function()
    local library = SoundLibrary()
    local state = fixture({group = {role = "DAMAGER"}, globals = {DyresSounds = library},
        db = {losingSound = "voice"}, threat = {target = {false, 0, 40}}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    state.combat = true
    state.threat.target = {false, 1, 95}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local last = library.played[#library.played]
    equal(last[1], "voice")
    equal(last[2], "High threat")
end)

test("defaults with Dyre's Sounds 1.5.0: Bell buzz and Cartoon shake play and show as chosen", function()
    local library = SoundLibrary(nil, true)
    local state = fixture({group = {role = "TANK"}, globals = {DyresSounds = library}})
    local red, losing = state.settings.DYRE_RED_SOUND, state.settings.DYRE_LOSING_SOUND
    equal(red:GetValue(), "alertbellbuzz")
    equal(losing:GetValue(), "alertshake")
    equal(red.initializer.getSelectionTextFunc(), "Dyre's Alerts: Bell buzz")
    Plate(state, "nameplate1", {true, 3, 100})
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(library.played[#library.played][1], "alertshake", "losing: Cartoon shake")
    equal(library.played[#library.played][3], "Master")
    state.now = 5
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(library.played[#library.played][1], "alertbellbuzz", "red: Bell buzz")
    equal(#state.sounds, 0, "no game sound")
    -- Picking the default saves nil; another pick saves; Defaults goes back to nil.
    red:SetValue("gong")
    equal(state.env.DyresToolkitCharDB.redSound, "gong")
    red:SetValue("alertbellbuzz")
    equal(state.env.DyresToolkitCharDB.redSound, nil, "the default: nothing saved")
    -- Not playable (DyresSounds.Playable false): the game fallback shows and plays.
    local playable = library.Playable
    library.Playable = function(key) return key ~= "alertbellbuzz" and playable(key) end
    equal(red:GetValue(), "raidWarning", "not playable: the game fallback as chosen")
    equal(losing:GetValue(), "alertshake")
    state.now = 10
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {false, 0, 50}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[#state.sounds][1], 8959, "red: the raid warning")
    -- Play returns false: the default's game fallback.
    library.Playable = playable
    library.silent.alertshake = true
    state.now = 20
    state.threat.nameplate1 = {true, 3, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.threat.nameplate1 = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    equal(state.sounds[#state.sounds][1], 847, "losing did not play: quest failed")
    -- An old save (the old defaults) plays the new defaults after its one move.
    local migrated = fixture({group = {role = "TANK"}, globals = {DyresSounds = SoundLibrary(nil, true)},
        db = {redSound = "raidWarning", losingSound = "questFailed"}})
    equal(migrated.settings.DYRE_RED_SOUND:GetValue(), "alertbellbuzz")
    equal(migrated.settings.DYRE_LOSING_SOUND:GetValue(), "alertshake")
end)

test("defaults with Dyre's Sounds before 1.5.0 or missing: the game fallbacks; a saved key stays", function()
    for _, globals in ipairs({{}, {DyresSounds = SoundLibrary()}, {DyresSounds = SoundLibrary(0, true)}}) do
        local state = fixture({group = {role = "TANK"}, globals = globals, db = {losingSound = "alertshake"}})
        equal(state.settings.DYRE_RED_SOUND:GetValue(), "raidWarning")
        equal(state.settings.DYRE_LOSING_SOUND:GetValue(), "questFailed")
        equal(state.env.DyresToolkitCharDB.redSound, nil)
        equal(state.env.DyresToolkitCharDB.losingSound, "alertshake", "the saved value is kept")
        Plate(state, "nameplate1", {true, 3, 100})
        state.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
        state.threat.nameplate1 = {true, 2, 100}
        state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
        equal(state.sounds[#state.sounds][1], 847, "losing: quest failed")
        state.now = 5
        state.threat.nameplate1 = {false, 0, 50}
        state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
        equal(state.sounds[#state.sounds][1], 8959, "red: the raid warning")
        -- The settings' Defaults sets the default key: saved as nil, the fallback previews.
        state.settings.DYRE_LOSING_SOUND:SetValue("alertshake")
        equal(state.env.DyresToolkitCharDB.losingSound, nil)
        equal(state.sounds[#state.sounds][1], 847, "the preview: the fallback")
    end
end)

test("sound menus wrap pooled dropdown frames only for their own dropdowns", function()
    local state = fixture({globals = {DyresSounds = SoundLibrary()}})
    local _, frame = SoundMenu(state, "DYRE_RED_SOUND")
    state.originalMenu = nil
    local cleared
    local button = {SetSelectionText = function(_, text) cleared = text == nil end}
    frame.SetupDropdownMenu({}, button, {}, nil, nil, {})
    equal(state.originalMenu, true, "another dropdown gets the original menu")
    equal(cleared, true, "and a cleared label")
end)

test("the icon takes the label's color: green, yellow, red, blue, orange, and white for a secret", function()
    local function Tint(label) return table.concat(label.icon.vertexColor, ",") end
    local state = fixture({threat = {target = {true, 3, 100}}, group = {role = "TANK"}})
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = TargetLabel(state)
    equal(label.edge.allPoints, label.icon, "the outline lies on the fill")
    equal(label.edge.vertexColor, nil, "the outline is never tinted")
    equal(Tint(label), "0.2,1,0.2", "green")
    equal(Tint(label), table.concat(label.text.color, ","), "the text's color")
    state.threat.target = {true, 2, 100}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(Tint(label), "1,0.85,0", "yellow")
    state.threat.target = {false, 0, 80}
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(Tint(label), "1,0.2,0.2", "red")
    local blue = fixture({group = {raid = true, count = 2, role = "TANK", members = {raid2 = {mainTank = true}}},
        threat = {target = {false, 1, 90}}, others = {raid2 = {target = {true, 3, 100}}}})
    blue.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(Tint(TargetLabel(blue)), "0.3,0.6,1", "blue")
    local losing = fixture({group = {role = "TANK"}})
    Plate(losing, "nameplate1", {true, 2, 100})
    losing.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    equal(Tint(losing.ns.ThreatLabels().nameplate1), "1,0.5,0", "orange for LOSING")
    state.threat.target = {state.secret(), state.secret(), state.secret()}
    state.simple.target = state.secret()
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(Tint(label), "1,1,1", "white for a secret status")
    equal(label.edge.vertexColor, nil, "the outline still untinted")
end)

test("no threat hides the label", function()
    local state = fixture()
    local reading = state.ns.ReadThreat("target")
    equal(reading.status, nil)
    equal(reading.hasPercent, nil)
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    equal(TargetLabel(state).shown, false)
end)

test("nameplate labels sit right of the bar by default, move with the setting, and go when removed", function()
    local state = fixture({toolkit = true, units = {nameplate3 = true}, group = {role = "DAMAGER"}})
    state.plates.nameplate3 = {bar = state.env.UIParent:CreateTexture()}
    state.threat.nameplate3 = {false, 1, 90}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    local label = state.ns.ThreatLabels().nameplate3
    assert(label, "a label on the plate")
    equal(label.text.text, "90%")
    equal(label.points[1][1], "LEFT")
    equal(label.points[1][2], state.plates.nameplate3.bar, "beside the bar the Toolkit found")
    equal(label.points[1][3], "RIGHT")
    for _, case in ipairs({{"left", "RIGHT"}, {"above", "BOTTOM"}, {"below", "TOP"}, {"right", "LEFT"}}) do
        state.settings.DYRE_PLATE_PLACE:SetValue(case[1])
        equal(label.points[1][1], case[2], case[1])
    end
    state.fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    equal(label.shown, false)
    state.settings.DYRE_PLATE_THREAT:SetValue(false)
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    equal(label.shown, false, "off in the settings")
end)

-- Offsets (John, 2026-11-11: "Gap Distance" or "vertical/horizontal adjustments").
test("label offsets: sliders -50 to 50 with the number and the default mark, repaired when saved", function()
    local state = fixture({globals = {MinimalSliderWithSteppersMixin = {Label = {Right = "RIGHT"}}},
        db = {plateX = 12, plateY = -60, targetX = 2.5, targetY = "x"}})
    for _, variable in ipairs({"DYRE_PLATE_X", "DYRE_PLATE_Y", "DYRE_TARGET_X", "DYRE_TARGET_Y"}) do
        local slider = state.sliders[variable]
        assert(slider, variable)
        equal(slider.options[1], -50, variable)
        equal(slider.options[2], 50)
        equal(slider.options[3], 1, "whole pixels")
        equal(slider.options.formatter(-7), "-7 px")
        equal(slider.dyreDefault.default, 0, "the gold mark at 0")
        equal(state.settings[variable].default, 0)
    end
    local db = state.env.DyresToolkitCharDB
    equal(db.plateX, 12)
    equal(db.plateY, -50, "clamped")
    equal(db.targetX, 0, "not whole: 0")
    equal(db.targetY, 0, "not a number: 0")
    state.settings.DYRE_PLATE_X:SetValue(99)
    equal(db.plateX, 50)
end)

test("label offsets add to every place, 0 keeps it, and shown labels move at once, also in combat", function()
    local state = fixture({toolkit = true, units = {target = true, nameplate3 = true}, group = {role = "DAMAGER"},
        threat = {target = {false, 1, 90}}})
    state.plates.nameplate3 = {bar = state.env.UIParent:CreateTexture()}
    state.threat.nameplate3 = {false, 1, 90}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = state.ns.ThreatLabels().nameplate3
    equal(label.points[1][4], 4, "right: the 4 px gap")
    equal(label.points[1][5], 0)
    state.combat = true
    state.settings.DYRE_PLATE_X:SetValue(10)
    state.settings.DYRE_PLATE_Y:SetValue(-3)
    equal(label.points[1][4], 14, "right: gap + x, at once, in combat")
    equal(label.points[1][5], -3)
    local expected = {left = {"RIGHT", 6, -3}, above = {"BOTTOM", 10, -1}, below = {"TOP", 10, -5}}
    for place, want in pairs(expected) do
        state.settings.DYRE_PLATE_PLACE:SetValue(place)
        equal(label.points[1][1], want[1], place)
        equal(label.points[1][4], want[2], place .. " x")
        equal(label.points[1][5], want[3], place .. " y")
    end
    local target = TargetLabel(state)
    equal(target.points[1][1], "BOTTOM")
    equal(target.points[1][4], 0)
    equal(target.points[1][5], 2, "above the target bar: half the gap")
    state.settings.DYRE_TARGET_X:SetValue(-8)
    state.settings.DYRE_TARGET_Y:SetValue(6)
    equal(target.points[1][4], -8, "the target label moves on its own sliders")
    equal(target.points[1][5], 8)
    equal(label.points[1][4], 10, "the plate label keeps its own")
end)

-- Size (John, 2026-11-13: "scale up or down, up to 100% (2x) it's default size").
test("label size: sliders 50 to 200% with the number and the default mark, repaired when saved", function()
    local state = fixture({globals = {MinimalSliderWithSteppersMixin = {Label = {Right = "RIGHT"}}},
        db = {plateScale = 250, targetScale = 1.5}})
    for _, variable in ipairs({"DYRE_PLATE_SCALE", "DYRE_TARGET_SCALE"}) do
        local slider = state.sliders[variable]
        assert(slider, variable)
        equal(slider.options[1], 50, variable)
        equal(slider.options[2], 200)
        equal(slider.options.formatter(150), "150%")
        equal(slider.dyreDefault.default, 100, "the gold mark at 100")
        equal(state.settings[variable].default, 100)
    end
    local db = state.env.DyresToolkitCharDB
    equal(db.plateScale, 200, "clamped")
    equal(db.targetScale, 100, "not whole: the default")
    state.settings.DYRE_PLATE_SCALE:SetValue(10)
    equal(db.plateScale, 50)
end)

test("label size scales the label at once, also in combat, and keeps the gap and offsets in pixels", function()
    local state = fixture({toolkit = true, units = {target = true, nameplate3 = true}, group = {role = "DAMAGER"},
        threat = {target = {false, 1, 90}}})
    state.plates.nameplate3 = {bar = state.env.UIParent:CreateTexture()}
    state.threat.nameplate3 = {false, 1, 90}
    state.fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    state.fire("UNIT_THREAT_LIST_UPDATE", "target")
    local label = state.ns.ThreatLabels().nameplate3
    equal(label.scale, 1, "100% by default")
    state.combat = true
    state.settings.DYRE_PLATE_X:SetValue(6)
    state.settings.DYRE_PLATE_Y:SetValue(-4)
    state.settings.DYRE_PLATE_SCALE:SetValue(200)
    equal(label.scale, 2, "twice the size, at once, in combat")
    equal(label.points[1][4], 5, "(4 px gap + 6) / 2: 10 screen pixels")
    equal(label.points[1][5], -2, "-4 / 2: -4 screen pixels")
    local target = TargetLabel(state)
    equal(target.scale, 1, "the target label keeps its own size")
    state.settings.DYRE_TARGET_SCALE:SetValue(50)
    equal(target.scale, 0.5)
    equal(target.points[1][5], 4, "half the gap (2) / 0.5: 2 screen pixels")
    equal(label.scale, 2, "the plate label keeps its own")
end)

-- Pull ---------------------------------------------------------------------------------

-- The pull countdown display (John, 2026-11-11: "our own pull timer indicator
-- that plays if bigwigs or whatever isn't installed").
local function PullFixture(extra)
    local sent, prefixes = {}, {}
    local options = {group = {role = "DAMAGER"}, globals = {
        C_EventUtils = {IsEventValid = function(event)
            return event == "START_PLAYER_COUNTDOWN" or event == "CANCEL_PLAYER_COUNTDOWN"
        end},
        C_ChatInfo = {
            RegisterAddonMessagePrefix = function(prefix) prefixes[prefix] = true return true end,
            SendAddonMessage = function(prefix, text, channel) sent[#sent + 1] = {prefix, text, channel} end,
        },
    }}
    for key, value in pairs(extra or {}) do
        if key == "solo" then
            options.group = nil
        elseif key == "globals" then
            for name, global in pairs(value) do options.globals[name] = global end
        else
            options[key] = value
        end
    end
    local state = fixture(options)
    state.sent, state.prefixes = sent, prefixes
    local _, display = state.ns.PullCountdownState()
    state.display = display
    return state
end

-- What the display shows: the number, else the splash text, else nil.
local function Shown(state)
    local display = state.display
    if not display.content.shown then return nil end
    if display.number.shown then return display.number.text end
    if display.splash.shown then return display.splash.text end
end

local function Finished(group)
    group.playing = false
    group.scripts.OnFinished(group)
end

test("pull display: the number pops each second, gold then orange at 3 and red at 1, ticks the last 5, PULL! at 0", function()
    local state = PullFixture()
    equal(state.prefixes.DyresToolkit, true, "its own prefix")
    equal(state.prefixes.D5, true, "DBM's")
    equal(state.prefixes.BigWigs, true, "BigWigs'")
    local display = state.display
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10, true, "Dyre")
    equal(Shown(state), "10")
    equal(display.line.text, "Pull in 10 - Dyre", "who started it")
    equal(display.number.color[1], 1, "gold")
    equal(display.number.color[2], 0.82)
    equal(display.pop.playing, true, "the pop")
    equal(display.drain.playing, true, "the bar drains")
    equal(display.drainScale.lastSetDuration[1], 10.1, "over the whole pull")
    equal(display.bar.lastSetWidth[1], 200, "full at the start")
    equal(#state.sounds, 0, "no tick at 10")
    for second = 9, 6, -1 do
        state.advance(1)
        equal(Shown(state), tostring(second))
    end
    equal(#state.sounds, 0, "no tick before the last 5")
    state.advance(1)
    equal(Shown(state), "5")
    equal(state.sounds[1][1], 25477, "the tick")
    equal(state.sounds[1][2], "Master")
    state.advance(1)
    state.advance(1)
    equal(Shown(state), "3")
    equal(display.number.color[2], 0.5, "orange at 3")
    state.advance(1)
    equal(display.number.color[2], 0.5, "orange at 2")
    state.advance(1)
    equal(Shown(state), "1")
    equal(display.number.color[2], 0.2, "red at 1")
    equal(display.line.text, "Pull in 1 - Dyre")
    equal(#state.sounds, 5, "a tick on each of 5, 4, 3, 2, 1")
    state.advance(1)
    equal(Shown(state), "PULL!")
    equal(display.splash.color[2], 1, "green")
    equal(display.go.playing, true, "the splash grows and fades")
    equal(display.bar.shown, false, "the bar goes")
    equal(state.sounds[6][1], 25478, "the go sound")
    equal(state.liveTimers(), 0, "no timer: the splash's end hides it")
    Finished(display.go)
    equal(Shown(state), nil, "hidden when the splash ends")
end)

test("pull display: one timer at a time; a cancel says so, then hides; combat does not cancel", function()
    local state = PullFixture()
    state.fire("START_PLAYER_COUNTDOWN", 1, 8, 8)
    equal(state.liveTimers(), 1)
    equal(state.display.line.text, "Pull in 8", "no starter named")
    state.combat = true
    state.fire("PLAYER_REGEN_DISABLED")
    state.advance(1)
    equal(Shown(state), "7", "combat does not cancel")
    equal(state.liveTimers(), 1)
    state.fire("CANCEL_PLAYER_COUNTDOWN", 1)
    equal(Shown(state), "Pull cancelled")
    equal(state.display.cancelled.playing, true)
    equal(state.liveTimers(), 0)
    Finished(state.display.cancelled)
    equal(Shown(state), nil, "then hidden")
    state.fire("CANCEL_PLAYER_COUNTDOWN", 1)
    equal(Shown(state), nil, "a cancel with nothing running shows nothing")
end)

test("pull display: the same pull from two sources counts once; a partial start fills the bar part way", function()
    local state = PullFixture()
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
    state.now = state.now + 0.4
    state.fire("CHAT_MSG_ADDON", "D5", "Tank-Realm\t1\tPT\t10\t0\t", "PARTY", "Tank-Realm")
    equal(state.liveTimers(), 1, "the second start is the same pull")
    equal(select(1, state.ns.PullCountdownState()).source, "game")
    equal(select(1, state.ns.PullCountdownState()).starter, "Tank-Realm", "the second source named the starter")
    state.now = state.now + 2
    state.fire("CHAT_MSG_ADDON", "BigWigs", "P^Pull^15", "PARTY", "Other")
    equal(Shown(state), "15", "a new pull later restarts it")
    equal(select(1, state.ns.PullCountdownState()).source, "bigwigs")
    state.fire("CHAT_MSG_ADDON", "BigWigs", "P^Pull^0", "PARTY", "Other")
    equal(Shown(state), "Pull cancelled", "BigWigs' cancel")
    state.fire("START_PLAYER_COUNTDOWN", 1, 5, 20, true, "Dyre")
    equal(state.display.bar.lastSetWidth[1], 50, "5 of 20 seconds left: a quarter")
    equal(state.display.drainScale.lastSetDuration[1], 5.1)
    state.fire("START_PLAYER_COUNTDOWN", 1, 4, 10, true, state.secret())
    equal(Shown(state), "5", "within 1 s and about the same end: the same pull")
    local secret = PullFixture()
    secret.fire("START_PLAYER_COUNTDOWN", 1, 9, 9, true, secret.secret())
    equal(secret.display.line.text, "Pull in 9", "a secret name is never shown")
    secret.fire("START_PLAYER_COUNTDOWN", 1, secret.secret(), 9, true, "x")
    equal(Shown(secret), "9", "a secret time is ignored")
    local escape = PullFixture({globals = {Ambiguate = function(name) return (name:gsub("%-MyRealm$", "")) end}})
    escape.fire("CHAT_MSG_ADDON", "DyresToolkit", "1\tPULL\t6", "PARTY", "|cffff0000Bad|r-MyRealm")
    equal(escape.display.line.text, "Pull in 6 - cffff0000Badr", "no escape codes")
end)

test("pull messages: DBM (D5, D4), BigWigs, the toolkit's; 0 cancels; secrets and others are ignored", function()
    local state = PullFixture()
    local read = state.ns.ReadPullMessage
    equal(read("D5", "Tank-Realm\t1\tPT\t12\t0\t"), 12)
    equal(select(2, read("D5", "Tank-Realm\t1\tPT\t12\t0\t")), "dbm")
    equal(read("D4", "PT\t8\t0"), 8)
    equal(read("D5", "Tank-Realm\t1\tPT\t0\t0\t"), 0, "DBM's cancel")
    equal(read("D5", "Tank-Realm\t1\tV\t1\t2"), nil, "another DBM message")
    equal(read("BigWigs", "P^Pull^7"), 7)
    equal(read("BigWigs", "P^Pull^0"), 0)
    equal(read("BigWigs", "B^Something"), nil)
    equal(read("DyresToolkit", "1\tPULL\t9"), 9)
    equal(read("DyresToolkit", "1\tCANCEL"), 0)
    equal(read("DyresToolkit", "2\tPULL\t9"), nil, "another protocol")
    equal(read("Other", "PT\t9"), nil)
    equal(read(state.secret(), "PT\t9"), nil, "a secret prefix")
    equal(read("D4", state.secret()), nil, "a secret text")
    state.fire("CHAT_MSG_ADDON", "D4", "PT\t500\t0", "PARTY", "x")
    equal(Shown(state), nil, "over 300 seconds: ignored")
end)

test("Dyre's countdown on screen: a checkbox, on by default; hidden with a boss mod; off never; migrated", function()
    local dbm = PullFixture({loaded = {["DBM-Core"] = true}})
    dbm.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
    equal(Shown(dbm), nil, "with DBM: DBM shows its own")
    local bigwigs = PullFixture({loaded = {BigWigs = true}})
    bigwigs.fire("CHAT_MSG_ADDON", "BigWigs", "P^Pull^9", "PARTY", "x")
    equal(Shown(bigwigs), nil, "with BigWigs")
    local state = PullFixture()
    local setting = state.settings.DYRE_PULL_DISPLAY
    equal(setting.name, "Dyre's countdown on screen")
    equal(setting.default, true)
    equal(setting:GetValue(), true)
    equal(setting.choices, nil, "a checkbox, not a dropdown")
    contains(setting.tooltip, "Sending: /dtt pull and the PULL button always use the best path: Deadly Boss Mods, "
        .. "then BigWigs, then the game's countdown, then Dyre's Toolkit's own message.")
    contains(setting.tooltip, "On screen:")
    contains(setting.tooltip, "/dyre unlock")
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
    equal(Shown(state), "10")
    setting:SetValue(false)
    equal(Shown(state), nil, "off: a running one goes at once")
    equal(state.liveTimers(), 0)
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
    equal(Shown(state), nil, "off: never")
    local function saved(value) return fixture({db = {pullDisplay = value}}).env.DyresToolkitCharDB.pullDisplay end
    equal(saved("auto"), true, "the old Auto is on")
    equal(saved("always"), true, "the old Always is on")
    equal(saved("never"), false, "the old Never is off")
    equal(saved(false), false)
    equal(saved(nil), true)
    equal(saved("sometimes"), true)
end)

-- TimerTracker: the game's own countdown display (Blizzard_FrameXML Timer.lua).
local function Tracker()
    local tracker = {events = {START_PLAYER_COUNTDOWN = true, CANCEL_PLAYER_COUNTDOWN = true, START_TIMER = true},
        calls = 0}
    function tracker:RegisterEvent(event) self.events[event] = true self.calls = self.calls + 1 end
    function tracker:UnregisterEvent(event) self.events[event] = nil self.calls = self.calls + 1 end
    return tracker
end

test("Dyre's countdown replaces the game's own (as BigWigs does): only its two events, given back when off", function()
    local tracker = Tracker()
    local state = PullFixture({globals = {TimerTracker = tracker}})
    equal(tracker.events.START_PLAYER_COUNTDOWN, nil, "taken at login")
    equal(tracker.events.CANCEL_PLAYER_COUNTDOWN, nil)
    equal(tracker.events.START_TIMER, true, "its other timers stay")
    equal(state.ns.TookGameCountdown(), true)
    state.combat = true
    state.settings.DYRE_PULL_DISPLAY:SetValue(false)
    equal(tracker.events.START_PLAYER_COUNTDOWN, nil, "not in combat")
    state.combat = false
    state.fire("PLAYER_REGEN_ENABLED")
    equal(tracker.events.START_PLAYER_COUNTDOWN, true, "given back after combat")
    equal(tracker.events.CANCEL_PLAYER_COUNTDOWN, true)
    state.settings.DYRE_PULL_DISPLAY:SetValue(true)
    equal(tracker.events.START_PLAYER_COUNTDOWN, nil, "taken again")
    local calls = tracker.calls
    state.settings.DYRE_PULL_DISPLAY:SetValue(true)
    equal(tracker.calls, calls, "no change, no calls")
    -- A boss mod loaded later (on demand): DBM draws over the game's, so give it back.
    state.loadedNow = true
    state.env.C_AddOns.IsAddOnLoaded = function(name) return name == "DBM-Core", false end
    state.fire("ADDON_LOADED", "DBM-Core")
    equal(tracker.events.START_PLAYER_COUNTDOWN, true, "given back for DBM")
end)

test("the game's countdown is left alone with a boss mod, and never handed back over BigWigs", function()
    local tracker = Tracker()
    PullFixture({loaded = {["DBM-Core"] = true}, globals = {TimerTracker = tracker}})
    equal(tracker.calls, 0, "DBM: untouched")
    local bigwigs = Tracker()
    bigwigs.events.START_PLAYER_COUNTDOWN, bigwigs.events.CANCEL_PLAYER_COUNTDOWN = nil, nil
    PullFixture({loaded = {BigWigs = true}, globals = {TimerTracker = bigwigs}})
    equal(bigwigs.calls, 0, "BigWigs took them itself")
    local late = Tracker()
    local state = PullFixture({globals = {TimerTracker = late}})
    late.events.START_PLAYER_COUNTDOWN = nil
    state.env.C_AddOns.IsAddOnLoaded = function(name) return name == "BigWigs", false end
    state.fire("ADDON_LOADED", "BigWigs")
    equal(late.events.START_PLAYER_COUNTDOWN, nil, "BigWigs loaded later: not handed back over it")
    PullFixture({globals = {TimerTracker = false}})
    PullFixture({globals = {TimerTracker = {}}})
end)

-- DBM detection (John, 2026-11-11: "If DBM is installed and configured to be
-- "the" pull timer, let it. Don't try to override existing addons.").
local function DBMOptions(values)
    -- Read-only: a write fails the test.
    return setmetatable(values, {__newindex = function() error("wrote DBM.Options") end})
end

test("DBM with its own pull bar off: Dyre's countdown shows and takes the game's countdown; read, never written", function()
    local tracker = Tracker()
    local options = DBMOptions({DontShowPT2 = true})
    local state = PullFixture({loaded = {["DBM-Core"] = true},
        globals = {TimerTracker = tracker, DBM = {Options = options}}})
    equal(state.ns.BossModShowingPull(), nil, "DBM is not the pull timer")
    equal(tracker.events.START_PLAYER_COUNTDOWN, nil, "the game's countdown is Dyre's")
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10, true, "Dyre")
    equal(Shown(state), "10")
    -- DBM's option turned back on (no event): read fresh at the next pull.
    rawset(options, "DontShowPT2", false)
    state.fire("CANCEL_PLAYER_COUNTDOWN", 1)
    Finished(state.display.cancelled)
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10, true, "Dyre")
    equal(Shown(state), nil, "DBM's bar is back: Dyre's steps aside")
    equal(tracker.events.START_PLAYER_COUNTDOWN, true, "and gives the game's countdown back for the next pull")
end)

test("DBM shows its own pull bar (option off, missing, or unreadable): Dyre's steps aside", function()
    for _, dbm in ipairs({{Options = DBMOptions({DontShowPT2 = false})}, {Options = DBMOptions({})}, {}, false,
            {Options = "x"}}) do
        local tracker = Tracker()
        local state = PullFixture({loaded = {["DBM-Core"] = true}, globals = {TimerTracker = tracker, DBM = dbm}})
        equal(state.ns.BossModShowingPull(), "dbm")
        state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
        equal(Shown(state), nil)
        equal(tracker.calls, 0, "the game's countdown untouched")
    end
end)

test("BigWigs always shows its own pull bar: Dyre's steps aside, also with DBM's bar off", function()
    local state = PullFixture({loaded = {["DBM-Core"] = true, BigWigs = true},
        globals = {DBM = {Options = DBMOptions({DontShowPT2 = true})}}})
    equal(state.ns.BossModShowingPull(), "bigwigs")
    state.fire("START_PLAYER_COUNTDOWN", 1, 10, 10)
    equal(Shown(state), nil)
    local tooltip = state.settings.DYRE_PULL_DISPLAY.tooltip
    contains(tooltip, "Do not show Pull/Break Timer bar")
    contains(tooltip, "/dbm > Global Disables & Filters > Disable DBM Features")
    contains(tooltip, "BigWigs always shows its own pull bar")
end)

test("pull display: scale and opacity sliders; unlocked shows a sample to move", function()
    local state = PullFixture({globals = {MinimalSliderWithSteppersMixin = {Label = {Right = "RIGHT"}}}})
    equal(state.display.frame.dyre.addon, "DyresToolkit", "a toolkit widget")
    equal(state.display.frame.dyre.widgetKey, "pullTimer")
    assert(state.settings.DYRE_DYRESTOOLKIT_PULLTIMER_SCALE, "a scale slider")
    assert(state.settings.DYRE_DYRESTOOLKIT_PULLTIMER_OPACITY, "an opacity slider")
    equal(state.settings.DYRE_DYRESTOOLKIT_PULLTIMER_SCALE.name, "Countdown size (%)")
    state.env.SlashCmdList.DYRESTOOLKIT("unlock")
    equal(Shown(state), "10", "a sample to move")
    equal(state.display.line.text, "Pull in 10")
    state.env.SlashCmdList.DYRESTOOLKIT("lock")
    equal(Shown(state), nil)
end)

test("countdown sounds: tick and go menus like the warning sounds, None, and Dyre's Sounds", function()
    local state = PullFixture()
    local tick, go = state.settings.DYRE_PULL_TICK, state.settings.DYRE_PULL_GO
    equal(tick.name, "Countdown tick sound")
    equal(go.name, "Countdown go sound")
    equal(tick.default, "countdownTick")
    equal(go.default, "countdownGo")
    equal(table.concat(tick.choices, ","), SOUND_ORDER, "the same Game Warnings list")
    tick:SetValue("none")
    go:SetValue("readyCheck")
    state.sounds = {}
    state.fire("START_PLAYER_COUNTDOWN", 1, 2, 2)
    state.advance(1)
    state.advance(1)
    equal(#state.sounds, 1, "no ticks with None")
    equal(state.sounds[1][1], 8960, "the chosen go sound")
    local library = SoundLibrary()
    local voiced = PullFixture({globals = {DyresSounds = library}, db = {pullTick = "voice", pullGo = "voice"}})
    voiced.fire("START_PLAYER_COUNTDOWN", 1, 3, 3)
    equal(library.played[1][2], "3", "text to speech says the number")
    voiced.advance(1)
    voiced.advance(1)
    voiced.advance(1)
    equal(library.played[#library.played][2], "Pull")
    equal(#voiced.sounds, 0)
end)

test("/dtt pull without a boss mod or a game countdown: the toolkit tells the group and shows it", function()
    local state = PullFixture({countdown = false, group = {role = "TANK"}})
    state.env.SlashCmdList.DYRESTOOLKITTANK("pull 6")
    equal(#state.sent, 1)
    equal(state.sent[1][1], "DyresToolkit")
    equal(state.sent[1][2], "1\tPULL\t6")
    equal(state.sent[1][3], "PARTY")
    equal(Shown(state), "6", "shown here at once")
    state.fire("CHAT_MSG_ADDON", "DyresToolkit", "1\tPULL\t6", "PARTY", "Me")
    equal(state.liveTimers(), 1, "its own echo is the same pull")
    local raid = PullFixture({countdown = false, group = {raid = true, count = 2, role = "TANK"}})
    raid.env.SlashCmdList.DYRESTOOLKITTANK("pull 5")
    equal(raid.sent[1][3], "RAID")
    local solo = PullFixture({countdown = false, solo = true})
    solo.env.SlashCmdList.DYRESTOOLKITTANK("pull 5")
    equal(#solo.sent, 0, "solo: nobody to tell")
    equal(Shown(solo), "5", "still shown here")
end)

-- The version list, heard only (John, 2026-11-11: "build the version list too").
local function VersionFixture(extra)
    local names = {party1 = "Tanky", party2 = "Healz-OtherRealm", party3 = "Pew"}
    local options = {group = {role = "TANK", members = {party1 = {}, party2 = {}, party3 = {}}}, globals = {
        GetUnitName = function(unit) return names[unit] end,
        Ambiguate = function(name) return (name:gsub("%-MyRealm$", "")) end,
    }}
    for key, value in pairs(extra or {}) do
        if key == "globals" then
            for name, global in pairs(value) do options.globals[name] = global end
        else
            options[key] = value
        end
    end
    local state = PullFixture(options)
    state.names = names
    return state
end

local function Lines(state)
    return table.concat(state.ns.GroupAddOnLines(), "; ")
end

test("version list: DBM's V and BigWigs' Q/V name each member's boss mod; others are unknown", function()
    local state = VersionFixture()
    state.fire("CHAT_MSG_ADDON", "D5", "Tanky-MyRealm\t3\tV\t23456\t23400\t11.2.3\tenUS\ttrue\t0\t0\t0",
        "PARTY", "Tanky-MyRealm")
    state.fire("CHAT_MSG_ADDON", "BigWigs", "V^427^abc123^0^", "PARTY", "Healz-OtherRealm")
    equal(Lines(state), "Tanky: DBM 11.2.3; Healz-OtherRealm: BigWigs 427; Pew: unknown")
    state.fire("CHAT_MSG_ADDON", "BigWigs", "Q^0^fakehash^0^", "PARTY", "Pew")
    equal(Lines(state), "Tanky: DBM 11.2.3; Healz-OtherRealm: BigWigs 427; Pew: unknown",
        "version 0 is DBM's query, not a version")
    state.fire("CHAT_MSG_ADDON", "D5", "Pew-MyRealm\t1\tH\t", "PARTY", "Pew-MyRealm")
    equal(state.ns.GroupAddOnLines()[3], "Pew: DBM or BigWigs", "a hello alone")
    state.fire("CHAT_MSG_ADDON", "DyresToolkit", "1\tPULL\t9", "PARTY", "Pew-MyRealm")
    equal(state.ns.GroupAddOnLines()[3], "Pew: Dyre's Toolkit", "a toolkit pull marks the toolkit")
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug")
    contains(state.find("debug group boss mods (heard):"), "Tanky: DBM 11.2.3")
    equal(#state.sent, 0, "nothing is sent for the list")
end)

test("version list: guild and whisper messages, secrets, and unsafe text are not taken as they come", function()
    local state = VersionFixture()
    state.fire("CHAT_MSG_ADDON", "D5", "Tanky-MyRealm\t3\tGV\t1\t1\t9.9.9", "GUILD", "Tanky-MyRealm")
    state.fire("CHAT_MSG_ADDON", "D5", "Tanky-MyRealm\t3\tV\t1\t1\t9.9.9", "WHISPER", "Tanky-MyRealm")
    equal(state.ns.GroupAddOnLines()[1], "Tanky: unknown", "only party, raid, and instance messages")
    state.fire("CHAT_MSG_ADDON", "D5", state.secret(), "PARTY", "Tanky-MyRealm")
    state.fire("CHAT_MSG_ADDON", "D5", "Tanky-MyRealm\t3\tV\t1\t1\t1.0", "PARTY", state.secret())
    equal(state.ns.GroupAddOnLines()[1], "Tanky: unknown", "a secret field is skipped")
    state.fire("CHAT_MSG_ADDON", "D5", "Tanky-MyRealm\t3\tV\t1\t1\t|cffff0000red|r and a very long text here",
        "PARTY", "Tanky-MyRealm")
    local line = state.ns.GroupAddOnLines()[1]
    equal(line:find("|", 1, true), nil, "no escape codes")
    equal(line, "Tanky: DBM cffff0000redr and a very", "cut to 24 characters")
end)

test("version list: a member who leaves is dropped at GROUP_ROSTER_UPDATE; solo lists nobody", function()
    local state = VersionFixture()
    state.fire("CHAT_MSG_ADDON", "BigWigs", "V^427^abc^0^", "PARTY", "Pew-MyRealm")
    equal(state.ns.GroupAddOnLines()[3], "Pew: BigWigs 427")
    state.group.members.party3 = nil
    state.names.party3 = nil
    state.fire("GROUP_ROSTER_UPDATE")
    equal(Lines(state), "Tanky: unknown; Healz-OtherRealm: unknown")
    state.group.members.party3 = {}
    state.names.party3 = "Pew"
    state.fire("GROUP_ROSTER_UPDATE")
    equal(state.ns.GroupAddOnLines()[3], "Pew: unknown", "back in the group: heard again only")
    state.group = nil
    state.fire("GROUP_ROSTER_UPDATE")
    equal(#state.ns.GroupAddOnLines(), 0)
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug")
    contains(state.find("debug group boss mods (heard):"), "no group")
end)

test("/dtt pull: the game refuses its countdown, so the toolkit tells its users at once and says why", function()
    local state = PullFixture({globals = {C_PartyInfo = {DoCountdown = function(seconds)
        return false
    end}}})
    state.env.SlashCmdList.DYRESTOOLKITTANK("pull 7")
    equal(state.sent[1][2], "1\tPULL\t7", "the toolkit's message at once")
    equal(Shown(state), "7", "shown here")
    assert(state.find("The game refused its countdown"), "says why")
end)

test("/dtt pull 0 cancels: the game's DoCountdown(0), DBM's and BigWigs' /pull 0, the toolkit's cancel", function()
    local game = PullFixture()
    game.env.SlashCmdList.DYRESTOOLKITTANK("pull 0")
    equal(game.countdowns[1], 0, "DoCountdown(0)")
    equal(#game.sent, 0)
    local dbm = PullFixture({loaded = {["DBM-Core"] = true}, slashes = {DEADLYBOSSMODS = "/dbm"}})
    dbm.env.SlashCmdList.DYRESTOOLKITTANK("pull 0")
    equal(dbm.slashCalls[1][2], "pull 0")
    local bigwigs = PullFixture({loaded = {BigWigs = true}, slashes = {BIGWIGSPULL = "/pull"}})
    bigwigs.env.SlashCmdList.DYRESTOOLKITTANK("pull 0")
    equal(bigwigs.slashCalls[1][2], "0")
    local toolkit = PullFixture({countdown = false})
    toolkit.env.SlashCmdList.DYRESTOOLKITTANK("pull 6")
    equal(Shown(toolkit), "6")
    toolkit.env.SlashCmdList.DYRESTOOLKITTANK("pull 0")
    equal(toolkit.sent[2][2], "1\tCANCEL", "the toolkit's cancel")
    equal(Shown(toolkit), "Pull cancelled", "said here")
end)

test("/dtt pull with the game's countdown: no toolkit message where the game's event reaches the group", function()
    local state = PullFixture()
    state.env.SlashCmdList.DYRESTOOLKITTANK("pull 9")
    equal(state.countdowns[1], 9)
    equal(#state.sent, 0, "the game's event reaches everyone")
    local noEvent = PullFixture({globals = {C_EventUtils = {IsEventValid = function() return false end}}})
    noEvent.env.SlashCmdList.DYRESTOOLKITTANK("pull 9")
    equal(noEvent.countdowns[1], 9)
    equal(noEvent.sent[1][2], "1\tPULL\t9", "no game event: tell toolkit users")
end)


test("pull hands off to DBM, then BigWigs, else the game's countdown", function()
    local dbm = fixture({loaded = {["DBM-Core"] = true}, slashes = {DEADLYBOSSMODS = "/dbm"}})
    dbm.env.SlashCmdList.DYRESTOOLKITTANK("pull 12")
    equal(dbm.slashCalls[1][2], "pull 12")
    equal(#dbm.countdowns, 0)
    local bigwigs = fixture({loaded = {BigWigs = true}, slashes = {BIGWIGSPULL = "/pull"}})
    bigwigs.env.DyresToolkitPull.scripts.OnClick()
    equal(bigwigs.slashCalls[1][2], "10", "the saved length")
    local game = fixture()
    game.env.SlashCmdList.DYRESTOOLKITTANK("pull")
    equal(game.countdowns[1], 10)
    local none = fixture({countdown = false})
    none.env.SlashCmdList.DYRESTOOLKITTANK("pull 5")
    contains(none.messages[#none.messages], "no pull countdown")
end)

test("DBM loaded without its slash command falls back to the game", function()
    local state = fixture({loaded = {["DBM-Core"] = true}})
    state.env.SlashCmdList.DYRESTOOLKITTANK("pull 8")
    equal(state.countdowns[1], 8)
end)

-- Diagnostics -------------------------------------------------------------------------

test("debug_threat reports secrets as secret and never fails on them", function()
    local state = fixture({units = {target = true, nameplate1 = true, nameplate2 = true}})
    state.env.CreateColor = function(r, g, b) return {r, g, b} end
    state.env.GetThreatStatusColor = function() return state.secret(), state.secret(), state.secret() end
    state.threat.target = {state.secret(), state.secret(), state.secret(), state.secret(), state.secret()}
    state.simple.target = state.secret()
    state.threat.nameplate1 = {true, 3, 100, 120, 5000}
    state.enterCombat()
    state.fire("UNIT_THREAT_LIST_UPDATE", "nameplate1")
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug_threat")
    contains(state.find("debug_threat client="), "combat=true")
    contains(state.find("debug_threat target: "), "status=secret(table)")
    contains(state.find("debug_threat target: "), "UnitThreatSituation=secret(table)")
    contains(state.find("debug_threat target show:"), "formatPercent=ok")
    contains(state.find("debug_threat target show:"), "statusColor=secret(table) textColor=ok")
    contains(state.find("debug_threat nameplate1: "), "status=3.0 scaled=100.0")
    contains(state.find("debug_threat events since login:"), "UNIT_THREAT_LIST_UPDATE=1")
    equal(state.find("nameplate2:"), "Dyre: debug_threat nameplate2: tanking=nil status=nil scaled=nil raw=nil value=nil; UnitThreatSituation=nil")
end)

test("debug prints the pull runner, pings, and marker order", function()
    local state = fixture({pings = false})
    state.env.SlashCmdList.DYRESTOOLKITTANK("debug")
    contains(state.find("debug available=true"), "pings=false pull=the game's countdown")
    contains(state.find("debug plates="), "order=Skull,Cross,Square,Triangle,Diamond,Circle,Star")
    contains(state.find("debug next index="), "skull=unbound")
end)

test("no tank or warning file calls SetRaidTarget, registers the combat log, or polls", function()
    for _, path in ipairs({"Tank.lua", "Threat.lua", "PetTaunt.lua", "TankButtons.lua", "Pull.lua", "TankProbe.lua",
            "GroupSettings.lua"}) do
        local text = assert(io.open(path)):read("*a")
        for line in text:gmatch("[^\n]+") do
            if not line:match("^%s*%-%-") then
                if line:find("SetRaidTarget", 1, true) then error(path .. " calls SetRaidTarget") end
                if line:find("COMBAT_LOG_EVENT", 1, true) then error(path .. " registers the combat log") end
                if line:find("OnUpdate", 1, true) then error(path .. " uses OnUpdate") end
            end
        end
    end
end)


-- The Pet Taunt warning (from Dyre's Buff Reminders) ---------------------------------

local function hunter(options)
    options = options or {}
    options.class = "HUNTER"
    options.pet = options.pet or "Wolf"
    options.petSpells = {"Bite", "Growl"}
    options.known = {[883] = true}
    options.autocast = options.autocast or {[2] = true}
    if options.group == nil then options.group = {role = "DAMAGER"} end
    if options.group == false then options.group = nil end
    return fixture(options)
end

test("pet taunt: Growl on autocast in a group where you are not the tank warns on screen and in chat", function()
    local state = hunter()
    contains(state.find("Pet taunt on"), "Growl is on autocast in a group. Turn it off.")
    local pop = state.env.DyresToolkitWarning
    assert(pop, "the message box is a named widget")
    equal(pop.dyre.addon, "DyresToolkit")
    equal(state.count("Pet taunt on"), 1)
    state.fire("PET_BAR_UPDATE")
    equal(state.count("Pet taunt on"), 1, "nothing changed: no second warning")
    state.now = 31
    state.fire("PLAYER_REGEN_DISABLED")
    equal(state.count("Pet taunt on"), 2, "once more as combat starts")
    state.now = 40
    state.fire("PLAYER_REGEN_DISABLED")
    equal(state.count("Pet taunt on"), 2, "at most once in 30 seconds")
end)

test("pet taunt: no warning solo, as the tank, with autocast off, unknown, off, or owned by another", function()
    equal(hunter({group = false}).count("Pet taunt on"), 0, "solo")
    equal(hunter({group = {role = "TANK"}}).count("Pet taunt on"), 0, "the group's tank")
    equal(hunter({group = {raid = true, mainTank = true}}).count("Pet taunt on"), 0, "a raid's main tank")
    equal(hunter({autocast = {}}).count("Pet taunt on"), 0, "autocast off")
    equal(hunter({db = {petTaunt = false}}).count("Pet taunt on"), 0, "off in the settings")
    local state = hunter({autocast = {}})
    state.autocast[2] = true
    state.fire("PET_BAR_UPDATE")
    equal(state.count("Pet taunt on"), 1, "autocast turned on: the warning")
    local mage = fixture({class = "MAGE", group = {role = "DAMAGER"}})
    equal(mage.env.DyresToolkitWarning, nil, "no message box for a class without a pet taunt")
    local quiet = hunter({noLogin = true})
    quiet.fire("ADDON_LOADED", ADDON)
    quiet.fire("PLAYER_LOGIN")
    quiet.toolkit.ClaimOwner("warn:petTaunt", "DyresBuffReminders", 99)
    quiet.messages = {}
    quiet.now = 100
    quiet.fire("GROUP_ROSTER_UPDATE")
    quiet.fire("PLAYER_REGEN_DISABLED")
    equal(quiet.count("Pet taunt on"), 0, "another owner: no warning from the toolkit")
end)

test("pet taunt: checks run out of combat only, and a secret answer gives no warning", function()
    local state = hunter({autocast = {}})
    state.combat = true
    state.autocast[2] = true
    state.fire("PET_BAR_UPDATE")
    equal(state.count("Pet taunt on"), 0, "in combat: no check")
    state.combat = false
    state.fire("PLAYER_REGEN_ENABLED")
    equal(state.count("Pet taunt on"), 1, "checked after combat")
    local secret = hunter({autocast = {}, noLogin = true})
    secret.env.GetPetActionInfo = function(slot)
        if slot == 2 then return "Growl", nil, false, nil, nil, secret.secret() end
    end
    secret.fire("ADDON_LOADED", ADDON)
    secret.fire("PLAYER_LOGIN")
    equal(secret.count("Pet taunt on"), 0)
end)

test("pet taunt: a Warlock's Voidwalker with Torment on autocast warns too", function()
    local state = fixture({class = "WARLOCK", pet = "Voidwalker", petSpells = {"Torment"}, autocast = {[1] = true},
        known = {[697] = true}, group = {role = "HEALER"}})
    contains(state.find("Pet taunt on"), "Torment is on autocast")
end)
