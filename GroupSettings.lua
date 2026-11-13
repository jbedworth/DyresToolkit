local _, ns = ...
local DTT = ns.tank

-- Five sections on the toolkit's own settings page (2.9.0; John,
-- 2026-11-12): "Threat Indicators: Nameplates" (the threat view and the
-- plate labels), "Threat Indicators: Target Frame", "Threat Indicators:
-- Sounds" (red, losing, solo), "Group Warnings" (pull bars, the countdown,
-- the Pet Taunt warning), and "Tank Tools" (the button bar, the pull
-- length). Proxy settings read and write DyresToolkitCharDB. A section header shows where the client has one
-- (CreateSettingsListSectionHeaderInitializer, as Dyre's Buff Reminders
-- uses it); dropdowns only where the client has the dropdown API.
local MODE_LABELS = {auto = "Auto", tank = "Tank", dps = "DPS/Healer"}
local BAR_LABELS = {auto = "Auto (tank only)", always = "Always", never = "Never"}
local PLACE_LABELS = {right = "Right of the bar", left = "Left of the bar", above = "Above the bar",
    below = "Below the bar"}

local category, layout

local function Section(text)
    if type(CreateSettingsListSectionHeaderInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function Proxy(variable, variableType, name, default, getValue, setValue)
    return Settings.RegisterProxySetting(category, variable, variableType, name, default, getValue, setValue)
end

local function Checkbox(variable, name, key, default, tooltip, after)
    local setting = Proxy(variable, Settings.VarType.Boolean, name, default,
        function() return DTT.db[key] end,
        function(value)
            DTT.db[key] = value == true
            after()
        end)
    Settings.CreateCheckbox(category, setting, tooltip)
end

-- A dropdown over a list of string choices; skipped on a client without the
-- dropdown API (the saved value still works).
local function Dropdown(variable, name, key, choices, labels, tooltip, after, default)
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        return
    end
    local setting = Proxy(variable, Settings.VarType.String, name, default or choices[1],
        function() return DTT.db[key] end,
        function(value)
            for _, choice in ipairs(choices) do
                if value == choice then
                    DTT.db[key] = value
                end
            end
            after()
        end)
    local function Options()
        local container = Settings.CreateControlTextContainer()
        for _, choice in ipairs(choices) do
            container:Add(choice, labels[choice])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(category, setting, Options, tooltip)
end

-- A warning sound dropdown: "Game Warnings" (None and the game sounds), then
-- every Dyre's Sounds group when that library is loaded, as a nested menu
-- like Dyre's Sounds' own pickers (its Menu.lua: a submenu per group, a
-- sound without a group at the top). The settings dropdown's control frames
-- are pooled and shared (Dyre's Sounds and others wrap them too), so the
-- nested menu is built only for a dropdown set up here and every other one
-- is handed on. The plain list (every choice by its full label) stays where
-- the client has no menu hooks.
local function SoundMenuInserter()
    return function(setting, rootDescription)
        local function IsSelected(key)
            return setting:GetValue() == key
        end
        local function SetSelected(key)
            setting:SetValue(key)
        end
        local game = rootDescription:CreateButton(DTT.SOUND_GROUP)
        for _, sound in ipairs(DTT.SOUNDS) do
            game:CreateRadio(sound.label, IsSelected, SetSelected, sound.key)
        end
        local library = DTT.SoundLibrary()
        if not library then
            return
        end
        for _, group in ipairs(library.Groups()) do
            if #group.sounds == 1 and not library.Parts(group.sounds[1]) then
                rootDescription:CreateRadio(group.sounds[1].label, IsSelected, SetSelected, group.sounds[1].key)
            else
                local submenu = rootDescription:CreateButton(group.name)
                for _, sound in ipairs(group.sounds) do
                    local _, name = library.Parts(sound)
                    submenu:CreateRadio(name, IsSelected, SetSelected, sound.key)
                end
            end
        end
    end
end

-- Every choice: the game sounds, then Dyre's Sounds' (when loaded).
function DTT.SoundOptions()
    local options = {}
    for _, sound in ipairs(DTT.SOUNDS) do
        options[#options + 1] = {key = sound.key, label = DTT.SOUND_GROUP .. ": " .. sound.label,
            group = DTT.SOUND_GROUP, name = sound.label}
    end
    local library = DTT.SoundLibrary()
    for _, sound in ipairs(library and library.List() or {}) do
        local group, name = library.Parts(sound)
        options[#options + 1] = {key = sound.key, label = sound.label, group = group or sound.label, name = name}
    end
    return options
end

local function NestedSetupDropdownMenu(original)
    return function(control, button, setting, options, initTooltip, initializer)
        if not (initializer and initializer.dyreToolkitSoundMenu) then
            -- A pooled frame that showed a sound would keep its label
            -- (Dyre's Sounds' Menu.lua, found in client): clear it.
            if type(button) == "table" and type(button.SetSelectionText) == "function" then
                button:SetSelectionText(nil)
            end
            return original(control, button, setting, options, initTooltip, initializer)
        end
        Settings.InitDropdown(button, setting, SoundMenuInserter(), initTooltip)
    end
end

local function NestSoundMenu(initializer)
    if type(initializer) ~= "table" or type(initializer.InitFrame) ~= "function"
            or type(Settings.InitDropdown) ~= "function" then
        return
    end
    initializer.dyreToolkitSoundMenu = true
    initializer.data = initializer.data or {}
    initializer.data.forceSteppersHidden = true
    initializer.getSelectionTextFunc = function()
        return DTT.SoundLabel(initializer:GetSetting():GetValue()) or ""
    end
    local initFrame = initializer.InitFrame
    function initializer:InitFrame(frame)
        if type(frame.SetupDropdownMenu) == "function" and not frame.dyreToolkitSoundMenu then
            frame.dyreToolkitSoundMenu = true
            frame.SetupDropdownMenu = NestedSetupDropdownMenu(frame.SetupDropdownMenu)
        end
        return initFrame(self, frame)
    end
end

-- key: "redSound", "losingSound", "pullTick", or "pullGo". The dropdown
-- shows the choice in effect (no choice, or a saved Dyre's Sounds key
-- without its library, shows the default in effect: a Dyre's Sounds default
-- without the library shows its game fallback); a pick saves and plays once
-- (not in combat). Picking the default (or the settings' Defaults, which
-- sets the default key even without the library) saves nil: the player's
-- own choices only.
local function SoundDropdown(variable, name, key, default, speech, tooltip)
    if type(Settings.CreateDropdown) ~= "function" or type(Settings.CreateControlTextContainer) ~= "function" then
        return
    end
    local setting = Proxy(variable, Settings.VarType.String, name, default,
        function() return DTT.EffectiveSound(DTT.db[key], default) end,
        function(value)
            local choice = (value == default or DTT.SOUND_LABELS[value]) and value or DTT.LibrarySound(value)
            if choice then
                DTT.db[key] = choice ~= default and choice or nil
                DTT.PreviewSound(choice, default, speech)
            end
        end)
    local function Options()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(DTT.SoundOptions()) do
            container:Add(option.key, option.label)
        end
        return container:GetData()
    end
    NestSoundMenu(Settings.CreateDropdown(category, setting, Options, tooltip))
end

-- A slider of whole numbers with its number at the right and the gold
-- default mark (found in client, 2026-11-11: neither showed on a bare one).
local function Slider(variable, name, key, minimum, maximum, default, format, sanitize, tooltip, after)
    local setting = Proxy(variable, Settings.VarType.Number, name, default,
        function() return DTT.db[key] end,
        function(value)
            DTT.db[key] = sanitize(value)
            if after then
                after()
            end
        end)
    local options = Settings.CreateSliderOptions(minimum, maximum, 1)
    if type(options.SetLabelFormatter) == "function" and type(MinimalSliderWithSteppersMixin) == "table"
            and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format(format, value) end)
    end
    ns.AddDefaultTick(Settings.CreateSlider(category, setting, options, tooltip),
        {min = minimum, max = maximum, default = default})
end

local function OffsetSlider(variable, name, key, tooltip)
    Slider(variable, name, key, DTT.OFFSET_MIN, DTT.OFFSET_MAX, 0, "%d px", DTT.SanitizeOffset, tooltip,
        DTT.RefreshThreat)
end

local function ScaleSlider(variable, name, key, tooltip)
    Slider(variable, name, key, DTT.SCALE_MIN, DTT.SCALE_MAX, DTT.DEFAULT_SCALE, "%d%%", DTT.SanitizeScale,
        tooltip, DTT.RefreshThreat)
end

-- A change of owner: the feature turns on or off.
function DTT.OnOwnerChanged(feature)
    if feature == "threat" then
        DTT.RefreshThreat()
    elseif feature == "petTaunt" then
        DTT.CheckPetTaunt()
    elseif feature == "pullDisplay" then
        DTT.ApplyPullDisplay()
    else
        DTT.RefreshBar()
    end
end

function DTT.InitializeGroupSettings()
    category, layout = ns.HomeCategory()
    if not category then
        return
    end
    -- Four sections, then Tank Tools (John, 2026-11-12: "Group warnings has
    -- everything all mixed up; a kitchen sink of settings."). The threat
    -- view sets the labels of both kinds and the sounds: first.
    Section("Threat Indicators: Nameplates")
    Dropdown("DYRE_THREAT_MODE", "Threat view", "threatMode", DTT.THREAT_MODES, MODE_LABELS,
        "Auto: the shield (tank view) by the tank bar's rule: group role Tank or raid main tank, a Druid "
        .. "in Bear Form, a Paladin with Righteous Fury, or a Warrior in Defensive Stance; else the "
        .. "crossed swords (DPS and healer view). Tank and DPS/Healer always use that view.\n\n"
        .. "Tank view: green while the mob is on you, yellow while another unit has more threat or is "
        .. "near the pull point, blue while another tank has it, red when it is not on you. DPS/Healer view: "
        .. "green below the tank, yellow at 80% of the pull point (your target only), orange when you have "
        .. "more threat than the tank, red when it is on you.", DTT.RefreshThreat)
    Checkbox("DYRE_PLATE_THREAT", "Threat on nameplates", "plateThreat", true,
        "The view's icon and your threat percent beside enemy nameplates.", DTT.RefreshThreat)
    Dropdown("DYRE_PLATE_PLACE", "Place on nameplates", "platePlace", DTT.PLATE_PLACES, PLACE_LABELS,
        "Where the threat label sits beside a nameplate's health bar.", DTT.RefreshThreat)
    OffsetSlider("DYRE_PLATE_X", "Nameplate label: left/right", "plateX",
        "Moves the nameplate threat label right (more) or left (less) from its place, in pixels. Also the "
        .. "gap: with the label right of the bar, more is a wider gap.")
    OffsetSlider("DYRE_PLATE_Y", "Nameplate label: up/down", "plateY",
        "Moves the nameplate threat label up (more) or down (less) from its place, in pixels.")
    ScaleSlider("DYRE_PLATE_SCALE", "Nameplate label size", "plateScale",
        "The size of the nameplate threat label's icon and text: 100% is the default, 200% twice as big, "
        .. "50% half.")
    Section("Threat Indicators: Target Frame")
    Checkbox("DYRE_TARGET_THREAT", "Threat on Target Frame", "targetThreat", true,
        "The same label above your target frame's health bar.", DTT.RefreshThreat)
    OffsetSlider("DYRE_TARGET_X", "Target label: left/right", "targetX",
        "Moves the target frame's threat label right (more) or left (less) from its place, in pixels.")
    OffsetSlider("DYRE_TARGET_Y", "Target label: up/down", "targetY",
        "Moves the target frame's threat label up (more) or down (less) from its place, in pixels. Also "
        .. "the gap above the bar.")
    ScaleSlider("DYRE_TARGET_SCALE", "Target label size", "targetScale",
        "The size of the target frame's threat label icon and text: 100% is the default, 200% twice as "
        .. "big, 50% half.")
    Section("Threat Indicators: Sounds")
    SoundDropdown("DYRE_RED_SOUND", "Alert sound (red)", "redSound", DTT.DEFAULT_RED_SOUND, "Aggro",
        "A sound when a mob's threat label turns red: in the tank view, a mob left you; in the DPS/Healer "
        .. "view, a mob came to you. At most once every 2 seconds. Default: Dyre's Alerts: Bell buzz, from "
        .. "Dyre's Sounds 1.5.0 or later; without it, the game's Raid warning. Game Warnings are the game's own "
        .. "sounds; with Dyre's Sounds installed, all of its sounds follow (Text to Speech says \"Aggro lost\" "
        .. "or \"Aggro\"). A choice plays once to hear it (not in combat). None: no sound.")
    SoundDropdown("DYRE_LOSING_SOUND", "Warning sound (orange)", "losingSound", DTT.DEFAULT_LOSING_SOUND,
        "Losing",
        "A sound when a label turns orange. Tank view: a mob on a nameplate goes from you holding it "
        .. "securely to another unit having more threat (the label shows LOSING). DPS/Healer view: you have "
        .. "more threat than the tank (the early yellow plays nothing). At most once every 2 seconds. Default: "
        .. "Dyre's Alerts: Cartoon shake, from Dyre's Sounds 1.5.0 or later; without it, the game's Quest "
        .. "failed. Pick another "
        .. "sound than the red one, so you can tell them apart. With Dyre's Sounds installed, all of its "
        .. "sounds follow (Text to Speech says \"Losing\" or \"High threat\"). A choice plays once to hear it (not in combat). "
        .. "None: no sound.")
    Checkbox("DYRE_SOLO_SOUNDS", "Threat sounds when solo", "soloSounds", false,
        "On: the red and orange sounds also play when you are not in a group. Off (the default): they play "
        .. "only in a party or raid; the threat labels still change color when solo.", function() end)
    Section("Group Warnings")
    Checkbox("DYRE_PULL_BARS", "Pull bars under nameplates", "pullBars", true,
        "Tank view, in a party (not a raid): under each enemy nameplate, a thin bar per party member in its "
        .. "class color, full when that member pulls the mob. No bar for a member not on the mob's threat "
        .. "list.", DTT.RefreshThreat)
    -- Only the toolkit's own display; sending has no setting (John,
    -- 2026-11-11, read the old "Auto" as the send path).
    Checkbox("DYRE_PULL_DISPLAY", "Dyre's countdown on screen", "pullDisplay", true,
        "Sending: /dtt pull and the PULL button always use the best path: Deadly Boss Mods, then BigWigs, then "
        .. "the game's countdown, then Dyre's Toolkit's own message.\n\n"
        .. "On screen: Dyre's big countdown for a pull anyone in your group starts, in place of the game's own "
        .. "countdown, only where no boss mod shows one.\n\n"
        .. "Deadly Boss Mods: turn on its \"Do not show Pull/Break Timer bar\" and \"Do not show announce text for "
        .. "Pull/Break Timer\" (/dbm > Global Disables & Filters > Disable DBM Features) and Dyre's countdown "
        .. "shows instead.\n"
        .. "BigWigs always shows its own pull bar, so with BigWigs loaded Dyre's countdown stays hidden.\n\n"
        .. "/dyre unlock shows it to move.", DTT.ApplyPullDisplay)
    SoundDropdown("DYRE_PULL_TICK", "Countdown tick sound", "pullTick", DTT.DEFAULT_PULL_TICK, "5",
        "Dyre's countdown: the sound on each of the last 5 seconds. Text to Speech says the number. None: no "
        .. "tick.")
    SoundDropdown("DYRE_PULL_GO", "Countdown go sound", "pullGo", DTT.DEFAULT_PULL_GO, "Pull",
        "Dyre's countdown: the sound at 0, with PULL!. Text to Speech says \"Pull\". None: no sound.")
    local widget = DTT.PullDisplayWidget and DTT.PullDisplayWidget()
    if widget then
        ns.toolkit.AddWidgetSettings(category, layout, widget, {
            labels = {scale = "Countdown size (%)", opacity = "Countdown opacity (%)"}})
    end
    Checkbox("DYRE_PET_TAUNT", "Warn: pet taunt on in a group", "petTaunt", true,
        "Hunters and Warlocks: a message on screen and in chat when your pet's taunt (Growl, Torment, "
        .. "Suffering) is on autocast in a group where you are not the tank.", DTT.CheckPetTaunt)

    Section("Tank Tools")
    Dropdown("DYRE_TANK_BAR_MODE", "Tank button bar", "barMode", DTT.BAR_MODES, BAR_LABELS,
        "Skull, Next marker, pings, and PULL in a bar.\n\nAuto (tank only): shown while your group role is "
        .. "Tank (or you are a raid's main tank), or as a Warrior in Defensive Stance, a Druid in Bear or Dire "
        .. "Bear Form, or a Paladin with Righteous Fury. Always and Never force it. It shows also while frames "
        .. "are unlocked, to move it. In combat, a change waits for the end of combat.\n\nThe key bindings "
        .. "(Key Bindings > AddOns > Dyre's Toolkit) work also with the bar hidden.", DTT.RefreshBar)
    Slider("DYRE_PULL", "Pull countdown (seconds)", "pull", DTT.PULL_MIN, DTT.PULL_MAX, DTT.DEFAULT_PULL, "%d s",
        DTT.SanitizePull,
        "The length of the PULL button's countdown. /dtt pull 5 or /dyre pull 5 sets it for one pull.")
end
