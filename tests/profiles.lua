-- The profile (Profiles.lua): restored from the 2.15.1 tests/tank.lua, which
-- held them until 2.16.0 moved the tank code to Dyre's Threat and Combat
-- Tools. Loaded by tests/run.lua, on its fixture.
--
-- 2.16.0: the toolkit registers no part of its own. These tests use a stand-in
-- for Dyre's Threat and Combat Tools' part (DyresCombatTools, the settings that
-- were the toolkit's part before), registered as that AddOn does: at its own
-- load, after the toolkit's SavedVariables and before PLAYER_LOGIN.
local test, equal, contains, fixture, newFrame = ...

local COMBAT = "DyresCombatTools"
local THREAT_MODES = {auto = true, tank = true, dps = true}
local BAR_MODES = {auto = true, always = true, never = true}

-- The stand-in's sanitize: repairs its known keys, keeps the rest.
local function CombatSanitize(settings)
    settings = type(settings) == "table" and settings or {}
    if not THREAT_MODES[settings.threatMode] then settings.threatMode = "auto" end
    if not BAR_MODES[settings.barMode] then settings.barMode = "auto" end
    if type(settings.petTaunt) ~= "boolean" then settings.petTaunt = true end
    if type(settings.soloSounds) ~= "boolean" then settings.soloSounds = false end
    return settings
end

-- The client pieces Profiles.lua uses: the player, popups, reload, the
-- settings list's rows (headers, buttons, a dropdown whose row frames are
-- pooled), secure hooks, and buttons that keep their text and anchors.
local function ProfileFixture(extra)
    extra = extra or {}
    local popups = {}
    local state = fixture({saved = extra.account or {}, noLogin = true, setup = function(env, state)
        env.UnitName = function() return extra.name or "Dyre" end
        env.GetRealmName = function() return "Forever" end
        env.UnitClass = function() return extra.class or "WARRIOR", extra.class or "WARRIOR" end
        env.time = function() return 1000 end
        env.StaticPopupDialogs = {}
        env.StaticPopup_Show = function(which, text, _, data)
            popups[#popups + 1] = {which = which, text = text, data = data}
        end
        env.ReloadUI = function() state.reloads = state.reloads + 1 end
        env.CreateSettingsListSectionHeaderInitializer = function(text, tooltip)
            return {name = "## " .. text, tooltip = tooltip}
        end
        env.CreateSettingsButtonInitializer = function(name, button, click, tooltip)
            return {name = name, button = button, click = click, tooltip = tooltip}
        end
        -- The client's secure hook: the original runs first, then the hook.
        env.hooksecurefunc = function(object, name, hook)
            local original = object[name]
            object[name] = function(...)
                local results = {original(...)}
                hook(...)
                return unpack(results)
            end
        end
        env.CreateFrame = function(kind, name, parent, template)
            local frame = newFrame(state, 0, 0)
            frame.kind, frame.name, frame.parent, frame.template = kind, name, parent, template
            frame.points = {}
            local setPoint, clearAllPoints = frame.SetPoint, frame.ClearAllPoints
            function frame:SetPoint(...)
                self.points[#self.points + 1] = {...}
                return setPoint(self, ...)
            end
            function frame:ClearAllPoints()
                self.points = {}
                return clearAllPoints(self)
            end
            function frame:GetScript(script) return self.scripts[script] end
            function frame:SetText(text) self.text = text end
            function frame:SetEnabled(on) self.isEnabled = on and true or false end
            function frame:SetMotionScriptsWhileDisabled() end
            return frame
        end
        -- Every row in page order: a setting's variable, or an initializer.
        state.settings = {}
        state.page = {}
        local pageLayout = {AddInitializer = function(_, initializer) state.page[#state.page + 1] = initializer end}
        -- Every setting's control, for a profile applied live (NotifyUpdate).
        function pageLayout:GetInitializers()
            local list = {}
            for _, setting in pairs(state.settings) do
                if setting.initializer then list[#list + 1] = setting.initializer end
            end
            return list
        end
        local function category(name, parent)
            return {name = name, parent = parent, GetID = function() return "id:" .. name end}
        end
        env.Settings = {
            VarType = {Boolean = "boolean", Number = "number", String = "string"},
            RegisterVerticalLayoutCategory = function(name) return category(name), pageLayout end,
            RegisterVerticalLayoutSubcategory = function(parent, name) return category(name, parent), pageLayout end,
            RegisterAddOnCategory = function(registered) state.registered = registered end,
            RegisterProxySetting = function(_, variable, varType, name, default, getValue, setValue)
                local setting = {variable = variable, name = name, default = default}
                state.page[#state.page + 1] = variable
                function setting:GetValue() return getValue() end
                function setting:SetValue(value) setValue(value) end
                function setting:NotifyUpdate() self.notified = (self.notified or 0) + 1 end
                state.settings[variable] = setting
                return setting
            end,
            CreateCheckbox = function(_, setting, tooltip) setting.tooltip = tooltip return {} end,
            CreateDropdown = function(_, setting, options, tooltip)
                setting.tooltip = tooltip
                setting.choices, setting.labels = {}, {}
                for _, choice in ipairs(options()) do
                    setting.choices[#setting.choices + 1] = choice.value
                    setting.labels[choice.value] = choice.label
                end
                local initializer = {setting = setting}
                -- Blizzard's row setup and reset of a pooled row frame.
                function initializer:InitFrame(frame) self.framed = frame end
                function initializer:Resetter(frame) self.reset = frame end
                function initializer:GetSetting() return self.setting end
                setting.initializer = initializer
                return initializer
            end,
            CreateControlTextContainer = function()
                local data = {}
                return {Add = function(_, value, label) data[#data + 1] = {value = value, label = label} end,
                    GetData = function() return data end}
            end,
            CreateSlider = function(_, setting)
                return {setting = setting, InitFrame = function() end}
            end,
            CreateSliderOptions = function() return {} end,
            OpenToCategory = function(id) state.opened = id end,
        }
    end})
    state.popups = popups
    state.reloads = 0
    state.core = state.ns
    state.profile = state.ns.profile
    -- Another Dyre's AddOn's part: its live table, and its refresh counted.
    function state.part(addon, live, opts)
        opts = opts or {}
        local part = {live = live, refreshes = 0}
        local refresh
        if not opts.noRefresh then
            refresh = function()
                part.refreshes = part.refreshes + 1
                if opts.fail then error("refresh failed") end
            end
        end
        part.ok = state.toolkit.RegisterProfilePart({
            addon = addon, title = opts.title, characterKeys = opts.characterKeys,
            current = function() return part.live end,
            sanitize = opts.sanitize or function(settings) return settings end,
            refresh = refresh,
        })
        return part
    end
    -- The stand-in for Dyre's Threat and Combat Tools: its settings repaired
    -- at its load, its part registered before the toolkit's PLAYER_LOGIN.
    if not extra.noCombat then
        state.combat_part = state.part(COMBAT, CombatSanitize(extra.combat or {}),
            {sanitize = CombatSanitize, title = "Dyre's Threat and Combat Tools"})
    end
    state.events.scripts.OnEvent(state.events, "PLAYER_LOGIN")
    function state.button(name)
        for _, entry in ipairs(state.page) do
            if type(entry) == "table" and entry.name == name then return entry end
        end
    end
    function state.fire(event, ...)
        for _, frame in ipairs(state.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    -- A shown popup's dialog, with its edit box.
    function state.dialog(popup, text)
        local box = {text = ""}
        function box:SetText(value) self.text = value end
        function box:GetText() return self.text end
        function box:HighlightText() self.highlighted = true end
        function box:SetFocus() end
        local dialog = {GetEditBox = function() return box end}
        local info = state.env.StaticPopupDialogs[popup.which]
        if info.OnShow then info.OnShow(dialog, popup.data) end
        if text then box.text = text end
        return dialog, info, box
    end
    return state
end

test("profiles: each character's profile holds a part per AddOn; the live settings stay", function()
    local state = ProfileFixture({combat = {threatMode = "tank", soloSounds = true}})
    local combat = state.combat_part
    equal(combat.ok, true)
    equal(combat.live.threatMode, "tank", "the live settings stay in the AddOn's own table")
    local entry = state.env.DyresToolkitDB.profiles["Dyre - Forever"]
    equal(entry.parts.DyresCombatTools.threatMode, "tank")
    equal(entry.parts.DyresCombatTools.soloSounds, true)
    equal(entry.class, "WARRIOR")
    equal(entry.seen, 1000)
    assert(entry.parts.DyresCombatTools ~= combat.live, "a copy, not the live table")
    local mage = state.part("MageToolsForever", {chain = true})
    equal(mage.ok, true)
    equal(entry.parts.MageToolsForever.chain, true, "a new part goes in at once")
    -- 2.16.0: the toolkit registers no part of its own.
    equal(table.concat(state.toolkit.ProfileParts(), ","), "DyresCombatTools,MageToolsForever")
    equal(entry.parts.DyresToolkit, nil)
    -- The account-wide settings are not in a profile (John: "user-centric").
    equal(type(state.env.DyresToolkitDB.grid), "boolean")
    for _, part in pairs(entry.parts) do
        equal(part.grid, nil)
        equal(part.snapToGrid, nil)
    end
    equal(state.toolkit.RegisterProfilePart({addon = "Bad:Name", current = print, sanitize = print}), nil,
        "a bad spec gives nil")
    equal(state.toolkit.RegisterProfilePart({addon = "Fine", current = print, sanitize = print, refresh = 5}),
        nil, "refresh must be a function")
end)

test("profiles: an entry from a test build becomes the toolkit's part", function()
    local account = {profiles = {["Alt - Forever"] = {settings = {threatMode = "dps"}, class = "Mage"}}}
    local state = ProfileFixture({combat = {threatMode = "tank"}, account = account})
    equal(table.concat(state.profile:Others(), ","), "Alt - Forever")
    equal(state.profile:CopyFrom("Alt - Forever"), true)
    equal(account.profiles["Alt - Forever"].parts.DyresToolkit.threatMode, "dps")
    equal(account.profiles["Alt - Forever"].settings, nil)
    -- 2.16.0: no DyresToolkit part is loaded, so it waits, and is written when
    -- an AddOn registers that part.
    local entry = account.profiles["Dyre - Forever"]
    equal(entry.pending.DyresToolkit.threatMode, "dps")
    equal(state.combat_part.live.threatMode, "tank", "another AddOn's part is not touched")
    local legacy = state.part("DyresToolkit", {threatMode = "tank"})
    equal(legacy.live.threatMode, "dps", "written at its load")
    equal(entry.pending.DyresToolkit, nil)
end)

test("profiles: copy writes every part in place and applies it live", function()
    local account = {profiles = {["Alt - Forever"] = {class = "Mage", parts = {
        DyresCombatTools = {threatMode = "dps", barMode = "sometimes", petTaunt = false,
            bar = {scale = 150, position = {point = "CENTER", relativePoint = "BOTTOMLEFT", x = 300, y = 200}}},
        MageToolsForever = {chain = false, size = 2},
        DyresShieldsUp = {sound = "bell"},
    }}, ["Broken"] = "junk"}}
    local state = ProfileFixture({combat = {threatMode = "tank", bar = {scale = 100, position = {x = 0}}},
        account = account})
    local combat = state.combat_part
    local db = combat.live
    local bar, position = db.bar, db.bar.position
    local mage = state.part("MageToolsForever", {chain = true, size = 1, extra = {kept = 1}})
    local mageTable = mage.live
    equal(table.concat(state.profile:Others(), ","), "Alt - Forever", "others, not this character, not junk")
    equal(state.profile:Label("Alt - Forever"), "Alt - Forever (Mage)")
    local ok, reload = state.profile:CopyFrom("Alt - Forever")
    equal(ok, true)
    equal(#reload, 0, "every loaded part applied live")
    -- The same tables, with the new values: widgets and trackers keep them.
    equal(combat.live, db)
    equal(db.bar, bar)
    equal(db.bar.position, position)
    equal(db.threatMode, "dps")
    equal(db.petTaunt, false)
    equal(db.barMode, "auto", "a bad value is repaired by the owner")
    equal(bar.scale, 150)
    equal(bar.position.x, 300)
    equal(combat.refreshes, 1)
    equal(mage.live, mageTable)
    equal(mageTable.chain, false)
    equal(mageTable.size, 2)
    equal(mageTable.extra, nil, "a key the source lacks goes")
    equal(mage.refreshes, 1)
    -- An AddOn not loaded here: its part waits for its next load.
    local entry = account.profiles["Dyre - Forever"]
    equal(entry.parts.DyresCombatTools.threatMode, "dps", "the copy follows")
    equal(entry.pending.DyresShieldsUp.sound, "bell")
    equal(entry.parts.DyresShieldsUp.sound, "bell")
    local shields = state.part("DyresShieldsUp", {sound = "chime", other = true})
    equal(shields.live.sound, "bell", "written at its load")
    equal(shields.live.other, nil)
    equal(shields.refreshes, 0, "no refresh at load: its frames are not built yet")
    equal(entry.pending.DyresShieldsUp, nil)
end)

test("profiles: Defaults, refusals, and a reload only where live apply is missing", function()
    local account = {profiles = {["Alt - Forever"] = {parts = {DyresCombatTools = {threatMode = "dps"},
        DyresDebuffTracker = {x = 1}, DyresQuestTargeting = {a = 2}}}}}
    local state = ProfileFixture({combat = {threatMode = "tank", petTaunt = false}, account = account})
    local combat = state.combat_part
    local plain = state.part("DyresSounds", {volume = 5}, {noRefresh = true, title = "Dyre's Sounds"})
    local ok, reload = state.profile:CopyFrom(state.profile.DEFAULTS)
    equal(ok, true)
    equal(combat.live.threatMode, "auto", "Defaults: a clean slate")
    equal(combat.live.petTaunt, true)
    equal(next(plain.live), nil)
    equal(table.concat(reload, ","), "Dyre's Sounds", "no refresh: a reload is asked")
    local failing = state.part("DyresQuestTargeting", {a = 1}, {fail = true})
    ok, reload = state.profile:CopyFrom("Alt - Forever")
    equal(ok, true)
    equal(failing.refreshes, 1)
    equal(failing.live.a, 2)
    equal(next(plain.live), nil, "a part the source lacks stays as it was")
    equal(table.concat(reload, ","), "DyresQuestTargeting", "a failed refresh: a reload is asked")
    -- One part that cannot take the settings: nothing changes anywhere.
    state.part("DyresCritMayhem", {mode = "a"}, {sanitize = function() error("bad") end})
    account.profiles["Alt - Forever"].parts.DyresCritMayhem = {mode = "b"}
    account.profiles["Alt - Forever"].parts.DyresCombatTools.threatMode = "tank"
    local before = combat.live.threatMode
    local why
    ok, why = state.profile:CopyFrom("Alt - Forever")
    equal(ok, nil)
    contains(why, "DyresCritMayhem cannot take those settings. Nothing changed.")
    equal(combat.live.threatMode, before, "all or nothing")
    ok, why = state.profile:CopyFrom("Nobody")
    equal(ok, nil)
    contains(why, "not saved")
    ok, why = state.profile:CopyFrom("Dyre - Forever")
    equal(ok, nil, "not from itself")
    state.combat = true
    ok, why = state.profile:CopyFrom(state.profile.DEFAULTS)
    equal(ok, nil, "never in combat")
    contains(why, "out of combat")
end)

test("profiles: export on one character, import on another, every part", function()
    local from = ProfileFixture({combat = {threatMode = "tank", redSound = "alarmClock", plateX = -12,
        soloSounds = true}})
    from.part("MageToolsForever", {chain = false})
    local text = from.profile:Export()
    assert(text:find("^DYRE2:profile:"), text)
    assert(not text:find("|", 1, true), "no escape codes")
    assert(not text:find("%s"), "one line, no spaces")
    local to = ProfileFixture({name = "Alt"})
    local mage = to.part("MageToolsForever", {chain = true})
    -- A line wrapped by chat or mail still imports.
    local wrapped = text:sub(1, 30) .. "\n  " .. text:sub(31)
    equal(to.profile:Import(wrapped), true)
    local db = to.combat_part.live
    equal(db.threatMode, "tank")
    equal(db.redSound, "alarmClock")
    equal(db.plateX, -12)
    equal(db.soloSounds, true)
    equal(to.combat_part.refreshes, 1)
    equal(mage.live.chain, false)
    equal(mage.refreshes, 1)
    equal(to.profile:Export(), text, "the same settings give the same line")
    -- A part for an AddOn not loaded here travels on in this character's export.
    local third = ProfileFixture({name = "Third"})
    equal(third.profile:Import(text), true)
    equal(third.env.DyresToolkitDB.profiles["Third - Forever"].pending.MageToolsForever.chain, false)
    equal(third.profile:Export(), text)
end)

test("profiles: import refuses a damaged, a newer, an older, or a foreign line", function()
    local state = ProfileFixture({combat = {threatMode = "tank"}})
    local text = state.profile:Export()
    local function refused(line, fragment)
        local ok, why = state.profile:Import(line)
        equal(ok, nil, line:sub(1, 40))
        contains(why, fragment)
    end
    refused("", "Paste")
    refused("hello", "not a Dyre's AddOns export line")
    refused((text:gsub("^DYRE2:profile:", "DYRE2:other:")), "other settings")
    refused((text:gsub("^DYRE2:", "DYRE3:")), "newer version")
    refused((text:gsub("^DYRE2:", "DYRE1:")), "test version")
    refused(text:sub(1, -3), "damaged")
    assert(text:find("Stank;", 1, true), "the line holds the value to damage")
    refused((text:gsub("Stank;", "Sdps;")), "damaged")
    refused(("x"):rep(70000), "too long")
    -- A well-formed line whose parts are not AddOn tables.
    refused(state.core.SerializeSettings("profile", {["Bad:Name"] = {}}), "damaged")
    refused(state.core.SerializeSettings("profile", {DyresCombatTools = "text"}), "damaged")
    equal(state.combat_part.live.threatMode, "tank", "nothing changed")
end)

test("profiles: the text format keeps every kind of value and runs nothing", function()
    local ns = ProfileFixture().core
    local value = {name = "a b|c:d~e;f", [1] = "x", [2] = -1.5, flag = false, on = true, big = 1e20,
        nested = {deeper = {["key with space"] = "\195\188"}}, skipped = function() end}
    local text = ns.SerializeSettings("Test", value)
    assert(text:match("^DYRE2:Test:([^:]*):%x+$"), "four parts: no ':' in the data")
    local back = ns.ParseSettings("Test", text)
    equal(back.name, "a b|c:d~e;f")
    equal(back[1], "x")
    equal(back[2], -1.5)
    equal(back.flag, false)
    equal(back.on, true)
    equal(back.big, 1e20)
    equal(back.nested.deeper["key with space"], "\195\188")
    equal(back.skipped, nil, "functions are not saved")
    equal(ns.SerializeSettings("Test", value), text, "the same settings give the same line")
    -- Code in the text is data: a string that looks like Lua stays a string.
    equal(ns.ParseSettings("Test", ns.SerializeSettings("Test", {run = "os.exit()"})).run, "os.exit()")
    -- Too deep is refused, even with a right checksum (Adler-32, taken here:
    -- the engine does not write tables past its depth limit).
    local data = ("{Snext;"):rep(30) .. "{}" .. ("}"):rep(30)
    local line = "DYRE2:Test:" .. data .. ":"
    local a, b = 1, 0
    for index = 1, #data do
        a = (a + data:byte(index)) % 65521
        b = (b + a) % 65521
    end
    local ok, why = ns.ParseSettings("Test", line .. ("%08x"):format(b * 65536 + a))
    equal(ok, nil, "too deep")
    contains(why, "damaged")
end)

test("profiles: per-character keys are never copied, exported, or imported", function()
    local state = ProfileFixture()
    local part = state.part("DyresTest", {color = "red", ownedMacros = {["! Sap"] = true}},
        {characterKeys = {"ownedMacros"}})
    local macros = part.live.ownedMacros
    local entry = state.env.DyresToolkitDB.profiles["Dyre - Forever"]
    equal(entry.parts.DyresTest.ownedMacros, nil, "not in the profile")
    assert(not state.profile:Export():find("ownedMacros", 1, true), "not exported")
    state.env.DyresToolkitDB.profiles["Alt - Forever"] = {parts = {DyresTest = {color = "blue",
        ownedMacros = {["! Fear"] = true}}}}
    equal(state.profile:CopyFrom("Alt - Forever"), true)
    equal(part.live.color, "blue")
    equal(part.live.ownedMacros, macros, "this character's own table stays, untouched")
    equal(macros["! Sap"], true)
    equal(macros["! Fear"], nil)
end)

-- Found by DSU, 2026-11-17: a saved part that is not a table reached Prepare
-- with no type check and was indexed outside the pcall.
test("profiles: a damaged saved part is refused, with no error and nothing changed", function()
    local state = ProfileFixture({combat = {threatMode = "tank"}})
    local part = state.part("DyresTest", {color = "red", ownedMacros = {}}, {characterKeys = {"ownedMacros"}})
    state.env.DyresToolkitDB.profiles["Alt - Forever"] = {parts = {DyresTest = "damaged",
        DyresCombatTools = {threatMode = "dps"}}}
    local before = state.combat_part.live.threatMode
    local ok, why = state.profile:CopyFrom("Alt - Forever")
    equal(ok, nil)
    contains(why, "DyresTest cannot take those settings. Nothing changed.")
    equal(part.live.color, "red")
    equal(state.combat_part.live.threatMode, before, "all or nothing")
end)

test("profiles: a change since login is in the profile at logout", function()
    local state = ProfileFixture({combat = {threatMode = "tank"}})
    -- As the owning AddOn's setting writes it: its own live table.
    state.combat_part.live.soloSounds = true
    local entry = state.env.DyresToolkitDB.profiles["Dyre - Forever"]
    equal(entry.parts.DyresCombatTools.soloSounds, false, "not yet")
    state.fire("PLAYER_LOGOUT")
    equal(entry.parts.DyresCombatTools.soloSounds, true)
end)

test("profiles: the Profile section names this character and works through popups", function()
    local account = {profiles = {["Alt - Forever"] = {parts = {DyresCombatTools = {threatMode = "dps"}},
        class = "Mage"}}}
    local state = ProfileFixture({combat = {threatMode = "tank"}, account = account})
    local combat = state.combat_part
    -- 2.16.0: the Profile section comes last, after the link to Dyre's Threat
    -- and Combat Tools (Core.lua); its header names this character.
    local tail = {}
    for index = #state.page - 4, #state.page do
        local entry = state.page[index]
        tail[#tail + 1] = type(entry) == "table" and tostring(entry.name) or tostring(entry)
    end
    equal(table.concat(tail, ","), "Threat, tank tools, and swing timer,## Profile: Dyre - Forever (WARRIOR),"
        .. "DYRE_PROFILE_SOURCE,Export profile,Import profile")
    local source = state.settings.DYRE_PROFILE_SOURCE
    -- Copy sits at the right of the dropdown, on its row (no row of its own).
    equal(state.button("Copy the choice above"), nil)
    local row = state.env.CreateFrame("Frame")
    row.Control = {Dropdown = {}, IncrementButton = {}}
    source.initializer:InitFrame(row)
    equal(source.initializer.framed, row, "the client's own InitFrame still runs")
    local function RowButton()
        for _, frame in ipairs(state.frames) do
            if frame.parent == row and frame.template == "UIPanelButtonTemplate" then return frame end
        end
    end
    local copy = RowButton()
    equal(row.dyreRowButton, nil, "no field of ours on the pooled row frame")
    equal(copy.text, "Copy")
    equal(copy.template, "UIPanelButtonTemplate")
    equal(copy.points[1][1], "LEFT")
    equal(copy.points[1][2], row.Control.IncrementButton)
    equal(copy.points[1][3], "RIGHT")
    equal(copy.shown, true)
    -- The list reuses row frames: the button hides when the frame is released,
    -- and the same button comes back when this row draws again.
    source.initializer:Resetter(row)
    equal(copy.shown, false)
    equal(source.initializer.reset, row, "the client's own Resetter still runs")
    source.initializer:InitFrame(row)
    equal(RowButton(), copy, "the same button")
    equal(copy.shown, true)
    equal(#copy.points, 1)
    -- This character first and chosen, Copy grey (John, 2026-11-15).
    local defaults = state.toolkit.PROFILE_DEFAULTS
    equal(source:GetValue(), "Dyre - Forever")
    equal(source.choices[1], "Dyre - Forever")
    equal(source.choices[2], defaults)
    equal(source.choices[3], "Alt - Forever")
    equal(source.labels["Dyre - Forever"], "Dyre - Forever (WARRIOR) (this character)")
    equal(source.labels[defaults], "Defaults (a clean slate)")
    equal(source.labels["Alt - Forever"], "Alt - Forever (Mage)")
    equal(copy.isEnabled, false, "grey while this character is chosen")
    local popupCount = #state.popups
    copy:GetScript("OnClick")(copy)
    equal(#state.popups, popupCount, "no copy onto itself")
    contains(state.messages[#state.messages], "Pick another character's profile")
    source:SetValue("Nobody")
    equal(source:GetValue(), "Dyre - Forever", "an unknown choice is ignored")
    equal(copy.isEnabled, false)
    source:SetValue(defaults)
    equal(copy.isEnabled, true, "Defaults can be copied")
    source:SetValue("Dyre - Forever")
    equal(copy.isEnabled, false)
    source:SetValue("Alt - Forever")
    equal(copy.isEnabled, true, "another character can be copied")
    -- Copy: a confirm popup, then the copy, live: no reload, and the
    -- settings pages read their values again.
    copy:GetScript("OnClick")(copy)
    local popup = state.popups[#state.popups]
    equal(popup.which, "DYRE_PROFILE_COPY")
    contains(popup.text, "Copy Alt - Forever (Mage) to Dyre - Forever (WARRIOR)?")
    contains(popup.text, "every Dyre's AddOn")
    equal(combat.live.threatMode, "tank", "nothing until accepted")
    local notified = source.notified or 0
    state.env.StaticPopupDialogs.DYRE_PROFILE_COPY.OnAccept(nil, popup.data)
    equal(combat.live.threatMode, "dps")
    equal(combat.refreshes, 1)
    equal(state.reloads, 0)
    equal(source.notified, notified + 1, "the settings read their values again")
    contains(state.messages[#state.messages], "Profile copied.")
    -- An AddOn with no live apply: a reload popup names it.
    state.part("DyresSounds", {volume = 5}, {noRefresh = true, title = "Dyre's Sounds"})
    source:SetValue(defaults)
    copy:GetScript("OnClick")(copy)
    state.env.StaticPopupDialogs.DYRE_PROFILE_COPY.OnAccept(nil, state.popups[#state.popups].data)
    popup = state.popups[#state.popups]
    equal(popup.which, "DYRE_PROFILE_RELOAD")
    contains(popup.text, "Reload to finish Dyre's Sounds.")
    state.env.StaticPopupDialogs.DYRE_PROFILE_RELOAD.OnAccept()
    equal(state.reloads, 1)
    -- Export: the line, selected, and typing puts it back.
    state.button("Export profile").click()
    popup = state.popups[#state.popups]
    local _, info, box = state.dialog(popup)
    equal(box.text, state.profile:Export())
    equal(box.highlighted, true)
    box.text = "typed"
    info.EditBoxOnTextChanged(box, popup.data)
    equal(box.text, state.profile:Export())
    -- Import: a bad line keeps the popup open and says why; a good one applies.
    state.button("Import profile").click()
    popup = state.popups[#state.popups]
    local dialog
    dialog, info = state.dialog(popup, "nonsense")
    equal(info.OnAccept(dialog, popup.data), true, "stays open")
    contains(state.messages[#state.messages], "not a Dyre's AddOns export line")
    local line = ProfileFixture({name = "Other", combat = {threatMode = "dps"}}).profile:Export()
    dialog, info = state.dialog(popup, line)
    equal(info.OnAccept(dialog, popup.data), nil)
    equal(combat.live.threatMode, "dps")
    contains(state.messages[#state.messages], "Profile imported.")
    -- No popups in combat.
    local shown = #state.popups
    state.combat = true
    state.button("Export profile").click()
    equal(#state.popups, shown)
    contains(state.messages[#state.messages], "out of combat")
end)
