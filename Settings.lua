local _, ns = ...
local DyresToolkit = ns.toolkit

-- The settings home: one "Dyre's AddOns" entry in Options > AddOns with the
-- toolkit's own settings, and each Dyre's AddOn's page under it (the settings
-- list draws sub-pages to any depth: CreateSection in Blizzard's
-- CategoryList.lua). The category is made the first time anyone asks for it,
-- so it does not matter whose PLAYER_LOGIN runs first.

local HOME = "Dyre's AddOns"
local REQUIRED = {
    "RegisterVerticalLayoutCategory", "RegisterVerticalLayoutSubcategory", "RegisterProxySetting",
    "RegisterAddOnCategory", "CreateCheckbox", "CreateSlider", "CreateSliderOptions", "OpenToCategory",
}

local home, homeLayout
-- Every page's layout (the home and each Dyre's AddOn's page), so a profile
-- applied live can tell their settings to read their values again.
ns.settingsLayouts = {}

local function HasSettingsAPI()
    if type(Settings) ~= "table" or type(Settings.VarType) ~= "table" then
        return false
    end
    for _, name in ipairs(REQUIRED) do
        if type(Settings[name]) ~= "function" then
            return false
        end
    end
    return true
end

local function Home()
    if not home and HasSettingsAPI() then
        home, homeLayout = Settings.RegisterVerticalLayoutCategory(HOME)
        Settings.RegisterAddOnCategory(home)
        ns.settingsLayouts[#ns.settingsLayouts + 1] = homeLayout
    end
    return home, homeLayout
end

-- The toolkit's own page and its layout (its sections: GroupSettings.lua).
function ns.HomeCategory()
    return Home()
end

function DyresToolkit.SettingsCategory()
    return (Home())
end

-- Under the "Dyre's AddOns" heading, "Dyre's " is said once (author-approved):
-- "Dyre's Buff Reminders" shows as "Buff Reminders". Other names stay.
function ns.ShortName(name)
    local short = type(name) == "string" and name:match("^Dyre's%s+(%S.*)$")
    return short or name
end

-- A page under "Dyre's AddOns": the category and its layout, or nil without
-- the settings API (the AddOn then makes its own top-level page).
function DyresToolkit.RegisterSettingsCategory(name)
    if type(name) ~= "string" or not name:find("%S") then
        return nil
    end
    local parent = Home()
    if not parent then
        return nil
    end
    local category, layout = Settings.RegisterVerticalLayoutSubcategory(parent, ns.ShortName(name))
    if layout then
        ns.settingsLayouts[#ns.settingsLayouts + 1] = layout
    end
    return category, layout
end

-- No panels in combat.
function DyresToolkit.OpenSettings(category)
    local target = category or Home()
    if not target then
        ns.Report("The settings page is unavailable on this client. Use /dyre unlock and /dyre lock.")
        return false
    end
    if InCombatLockdown() then
        ns.Report("The settings open out of combat.")
        return false
    end
    Settings.OpenToCategory(target:GetID())
    return true
end

local function Member(addon)
    for _, info in ipairs(DyresToolkit.AddOns()) do
        if info.addon == addon then
            return info
        end
    end
end

-- A row on an AddOn's page that opens another Dyre's AddOn's page (2.3.0;
-- author-approved: a feature that moved to another AddOn is linked, not
-- mirrored). opts: addon (folder), name (the row's label), button (default
-- "Open settings"), tooltip, missing (said in chat, and the tooltip, while
-- that AddOn has not joined the toolkit: not installed or not enabled). The
-- button is greyed while it is missing; the check runs each time the page
-- draws, so an AddOn that joins later counts.
function DyresToolkit.AddSettingsLink(category, layout, opts)
    if type(opts) ~= "table" or type(opts.addon) ~= "string" or type(opts.name) ~= "string"
            or type(CreateSettingsButtonInitializer) ~= "function" or type(layout) ~= "table"
            or type(layout.AddInitializer) ~= "function" then
        return nil
    end
    local missing = opts.missing or ("Install " .. opts.addon .. " from CurseForge.")
    local function Open()
        local info = Member(opts.addon)
        if not info or type(info.openSettings) ~= "function" then
            ns.Report(missing)
            return
        end
        if InCombatLockdown() then
            ns.Report("The settings open out of combat.")
            return
        end
        info.openSettings()
    end
    local present = Member(opts.addon) ~= nil
    local initializer = CreateSettingsButtonInitializer(opts.name, opts.button or "Open settings", Open,
        present and opts.tooltip or missing, true)
    if type(initializer.AddModifyPredicate) == "function" then
        initializer:AddModifyPredicate(function() return Member(opts.addon) ~= nil end)
    end
    DyresToolkit.GreyButtonLabel(initializer)
    layout:AddInitializer(initializer)
    return initializer
end

-- Settings sections (2.17.0; John, 2026-11-26: a class AddOn that bundles
-- other Dyre's AddOns "should surface every setting in the wrapped addon's
-- settings, and just pass-through the setting to the wrapped addon"; the
-- same setting stays on the wrapped AddOn's own page). The AddOn that owns
-- a feature registers a section, a function that adds its rows to any page;
-- a host AddOn (Mage Tools Forever, Warlock Tools Forever) draws it on its
-- own page. Both pages' rows read and write the owner's live settings
-- through the owner's own get and set, so a change on one page is the
-- change on the other. CONTRACT stays 2: a host checks that
-- AddSettingsSection exists, and without it keeps its AddSettingsLink.
--
-- RegisterSettingsSection{addon, key, title, build}: addon (folder, a Dyre's
-- AddOn: `## Group: DyresToolkit`), key ([%w_]+), optional title, build =
-- function(category, layout, ctx) -> true when it added a row. Register no
-- later than your ADDON_LOADED (a host builds its page at its PLAYER_LOGIN,
-- which may come before yours); read your settings only inside get, set,
-- and predicates, never while building. A second registration of the same
-- addon and key replaces the first.
--
-- ctx: host (the page's AddOn folder), owner, key, class (the player's
-- class file), filter (the host's opts.filter, passed as is: a list of
-- keys, a class, anything the owner documents), own (true on the owner's
-- own page), part (3: "all", the default; "master", only the section's
-- top switch, for a host's top page; "rest", everything but it, for the
-- host's sub-page, greyed while the switch is off), and variable(name): the
-- setting variable to use for name.
-- Blizzard refuses a variable registered twice (Blizzard_SettingsPanel.lua
-- RegisterSetting: "Setting variable '%s' was previously registered."), so
-- on a host page every variable gets the host's prefix; on the owner's own
-- page (OwnSettingsContext) it stays as named.
-- 2: AddProcSettings and AddWidgetSettings take opts.variable (map each
-- variable, ctx.variable on a host page), and AddProcSettings opts.keys (a
-- list of proc keys to keep).
-- 3: ctx.part ("all", "master", "rest"; John, 2026-11-27: "the top-level
-- disable for each section should be on the top-level MTF panel"), and
-- opts.modify on AddWidgetSettings and AddProcSettings (John: "when the
-- top-level is off, the settings that are controlling a disabled feature
-- should be disabled too").
DyresToolkit.SETTINGS_SECTIONS_VERSION = 3
local PARTS = {all = true, master = true, rest = true}

local sections = {}
local KEY_PATTERN = "^[%w_]+$"

local function PlayerClass()
    if type(UnitClass) ~= "function" then
        return nil
    end
    local ok, _, classFile = pcall(UnitClass, "player")
    return ok and type(classFile) == "string" and classFile or nil
end

local function Context(owner, key, host, filter, part)
    local prefix = host and ("DYRE_" .. host:upper() .. "__") or ""
    return {
        host = host or owner, owner = owner, key = key, class = PlayerClass(), filter = filter, own = host == nil,
        part = PARTS[part] and part or "all",
        variable = function(name) return prefix .. tostring(name) end,
    }
end

function DyresToolkit.RegisterSettingsSection(spec)
    if type(spec) ~= "table" or type(spec.addon) ~= "string" or type(spec.key) ~= "string"
            or not spec.key:match(KEY_PATTERN) or type(spec.build) ~= "function" then
        return false, "addon, key ([%w_]+), and build are required"
    end
    if not ns.InFamily(spec.addon) then
        return false, spec.addon .. " is not a Dyre's AddOn (## Group: DyresToolkit)"
    end
    sections[spec.addon] = sections[spec.addon] or {}
    sections[spec.addon][spec.key] = {title = spec.title, build = spec.build}
    return true
end

-- The keys an AddOn has registered, sorted.
function DyresToolkit.SettingsSections(addon)
    local keys = {}
    for key in pairs(sections[addon] or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- The section's name (2.17.0; John, 2026-11-27: "let's have the same name
-- used consistently ... In DBR, we have sections for "Reminders", "Chimes",
-- and "Procs" - let's use the same name consistently everywhere"): the
-- owner's `title`, used as the host's page title and the master's label and
-- the owner's own heading. Nil when the owner has not registered it (the
-- host then uses its own fallback, the same word).
function DyresToolkit.SettingsSectionTitle(addon, key)
    local section = sections[addon] and sections[addon][key]
    return section and type(section.title) == "string" and section.title ~= "" and section.title or nil
end

-- The context for the owner's own page: variables as named.
function DyresToolkit.OwnSettingsContext(addon, key, filter, part)
    return Context(addon, key, nil, filter, part)
end

-- The primer box (2.17.0; John, 2026-11-27: when a bundled AddOn is missing,
-- "there should be a message box on those panels telling people" what they
-- get if they install it). SettingsTemplates.xml's
-- DyresToolkitSettingsPrimerTemplate, made through
-- Settings.CreateElementInitializer, which Blizzard runs securely
-- (Blizzard_SettingsInbound.lua 224-228); the row's height is the
-- template's, so no function of ours is put on the initializer. The frames
-- are the template's own (no Blizzard frame is changed).
DyresToolkitSettingsPrimerMixin = {}

function DyresToolkitSettingsPrimerMixin:Init(initializer)
    local data = type(initializer) == "table" and initializer.data
    self.Text:SetText(type(data) == "table" and type(data.text) == "string" and data.text or "")
end

DyresToolkit.SETTINGS_PRIMER_TEMPLATE = "DyresToolkitSettingsPrimerTemplate"
DyresToolkit.SETTINGS_PRIMER_MAX = 400

-- A primer box on any page: text (at most SETTINGS_PRIMER_MAX characters;
-- longer is cut, since the box does not grow). Gives the initializer, or nil
-- without the settings API.
function DyresToolkit.AddSettingsPrimer(category, layout, text)
    if type(text) ~= "string" or not text:find("%S") or type(layout) ~= "table"
            or type(layout.AddInitializer) ~= "function" or type(Settings) ~= "table"
            or type(Settings.CreateElementInitializer) ~= "function" then
        return nil
    end
    if #text > DyresToolkit.SETTINGS_PRIMER_MAX then
        text = text:sub(1, DyresToolkit.SETTINGS_PRIMER_MAX - 3) .. "..."
    end
    local initializer = Settings.CreateElementInitializer(DyresToolkit.SETTINGS_PRIMER_TEMPLATE, {text = text})
    if initializer then
        layout:AddInitializer(initializer)
    end
    return initializer
end

-- Whether an AddOn is loaded now (an older owner joins the toolkit only at
-- its PLAYER_LOGIN, which may come after the host's).
function ns.AddOnLoaded(addon)
    local loaded = type(C_AddOns) == "table" and C_AddOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    if type(loaded) ~= "function" then
        return false
    end
    local ok, answer = pcall(loaded, addon)
    return ok and answer == true
end

-- Live greying below a switch that is not the row's direct parent (2.17.0;
-- found by DBR, John's screenshot: grandchildren stayed active). A row
-- evaluates its modify predicates again only when its DIRECT parent's
-- setting changes (Blizzard_SettingControls.lua SettingsListElementMixin:Init
-- 297-302). Its initializer's AddEvaluateStateCVar(name) also makes it
-- evaluate again when that name changes (313-316): the name is any setting
-- variable, since it registers Settings.SetOnValueChangedCallback
-- (Blizzard_Settings.lua 645), not only a CVar. WatchSettings calls it for
-- each variable (Blizzard's own method: nothing of ours is put on the
-- initializer). Gives the initializer.
function DyresToolkit.WatchSettings(initializer, variables)
    if type(initializer) ~= "table" or type(initializer.AddEvaluateStateCVar) ~= "function" then
        return initializer
    end
    for _, variable in ipairs(type(variables) == "table" and variables or {variables}) do
        if type(variable) == "string" and variable ~= "" then
            initializer:AddEvaluateStateCVar(variable)
        end
    end
    return initializer
end

-- A greyed button row's label greys too (2.17.0; John's screenshot,
-- 2026-11-27: "the inconsistent label enable/disable": on Forever a button
-- row greys its button but keeps a gold label, while checkbox and slider
-- rows grey both; Classic Era's SettingsButtonControlMixin:EvaluateState
-- calls DisplayEnabled, Blizzard_SettingControls.lua 758-764). Only rows we
-- mark: hooksecurefunc on the initializer's InitFrame (as AttachRowButton)
-- and, once per pooled frame, on its EvaluateState, so Blizzard's code runs
-- first; per-frame state in weak tables; a frame we greyed is set back to the
-- normal color when it draws someone else's row.
local greyLabelRows = setmetatable({}, {__mode = "k"})
local greyHookedFrames = setmetatable({}, {__mode = "k"})
local greyedFrames = setmetatable({}, {__mode = "k"})

local function ApplyButtonLabel(frame)
    if type(frame) ~= "table" or type(frame.Text) ~= "table" or type(frame.GetElementData) ~= "function" then
        return
    end
    local ok, data = pcall(frame.GetElementData, frame)
    if ok and greyLabelRows[data] and type(frame.Button) == "table" and type(frame.Button.IsEnabled) == "function" then
        local enabled = frame.Button:IsEnabled()
        local color = enabled and NORMAL_FONT_COLOR or GRAY_FONT_COLOR
        if type(color) == "table" and type(color.GetRGB) == "function" then
            frame.Text:SetTextColor(color:GetRGB())
            greyedFrames[frame] = not enabled or nil
        end
    elseif greyedFrames[frame] and type(NORMAL_FONT_COLOR) == "table" then
        frame.Text:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
        greyedFrames[frame] = nil
    end
end

function DyresToolkit.GreyButtonLabel(initializer)
    if type(initializer) ~= "table" or type(initializer.InitFrame) ~= "function" or type(hooksecurefunc) ~= "function" then
        return initializer
    end
    if not greyLabelRows[initializer] then
        greyLabelRows[initializer] = true
        hooksecurefunc(initializer, "InitFrame", function(_, frame)
            if type(frame) == "table" and not greyHookedFrames[frame] and type(frame.EvaluateState) == "function" then
                greyHookedFrames[frame] = true
                hooksecurefunc(frame, "EvaluateState", ApplyButtonLabel)
            end
            ApplyButtonLabel(frame)
        end)
    end
    return initializer
end

local failures = {}

-- On a host's page: the owner's rows, else (owner not loaded, an older
-- owner with no such section, a build that fails or adds nothing) the
-- AddSettingsLink row from opts.link. opts: addon (the owner), key, host
-- (the caller's folder, required), filter, link (AddSettingsLink's opts;
-- its addon defaults to opts.addon), primer (text: shown in a primer box
-- above the link only while the owner is missing, that is, not loaded: no
-- section registered and not joined). Gives "rows", "link", or nil (nothing
-- could be drawn). A failing build is said only in debug mode, and its rows
-- added before the error stay (Blizzard has no way to take them back).
function DyresToolkit.AddSettingsSection(category, layout, opts)
    if type(opts) ~= "table" or type(opts.addon) ~= "string" or type(opts.key) ~= "string"
            or type(opts.host) ~= "string" or not opts.host:match(KEY_PATTERN)
            or type(layout) ~= "table" then
        return nil
    end
    local section = sections[opts.addon] and sections[opts.addon][opts.key]
    if section then
        local ok, added = pcall(section.build, category, layout,
            Context(opts.addon, opts.key, opts.host, opts.filter, opts.part))
        if ok and added then
            return "rows"
        end
        if not ok then
            failures[#failures + 1] = opts.addon .. "." .. opts.key .. " on " .. opts.host .. ": " .. tostring(added)
            if ns.debug and type(ns.Report) == "function" then
                ns.Report("Settings section " .. failures[#failures])
            end
        end
    end
    -- The master switch alone (a host's top page) has no fallback: the
    -- section's own page shows the link and the primer.
    if opts.part == "master" then
        return nil
    end
    if opts.primer and not sections[opts.addon] and not Member(opts.addon) and not ns.AddOnLoaded(opts.addon) then
        DyresToolkit.AddSettingsPrimer(category, layout, opts.primer)
    end
    local link = {}
    for name, value in pairs(type(opts.link) == "table" and opts.link or {}) do
        link[name] = value
    end
    link.addon = link.addon or opts.addon
    link.name = link.name or section and section.title or opts.key
    return DyresToolkit.AddSettingsLink(category, layout, link) and "link" or nil
end

-- For tests and debug: the section builds that failed this session.
function DyresToolkit.SettingsSectionFailures()
    return {unpack(failures)}
end

local function Flag(variable, name, get, set, tooltip)
    local setting = Settings.RegisterProxySetting(home, variable, Settings.VarType.Boolean, name, false, get, set)
    return Settings.CreateCheckbox(home, setting, tooltip)
end

function ns.InitializeSettings()
    if not Home() then
        return
    end
    Flag("DYRE_UNLOCKED", "Unlock frames", function() return not ns.db.locked end,
        function(value) DyresToolkit.SetLocked(value ~= true) end,
        "Shows every Dyre's AddOn frame so you can drag it.")
    Flag("DYRE_GRID", "Show the grid", function() return ns.db.grid end, ns.SetGrid,
        "Shows a grid across the screen while frames are unlocked.")
    Flag("DYRE_SNAP_GRID", "Snap to the grid", function() return ns.db.snapToGrid end, ns.SetSnapToGrid,
        "Frames you drop line up with the grid; hold Ctrl as you drop to place one exactly.")
    local size = Settings.RegisterProxySetting(home, "DYRE_GRID_SIZE", Settings.VarType.Number, "Grid size",
        ns.DEFAULT_GRID, function() return ns.db.gridSize end, ns.SetGridSize)
    local options = Settings.CreateSliderOptions(ns.GRID_MIN, ns.GRID_MAX, ns.GRID_STEP)
    if type(options.SetLabelFormatter) == "function" and type(MinimalSliderWithSteppersMixin) == "table"
            and MinimalSliderWithSteppersMixin.Label then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
    end
    ns.AddDefaultTick(Settings.CreateSlider(home, size, options, "The space between grid lines."),
        {min = ns.GRID_MIN, max = ns.GRID_MAX, default = ns.DEFAULT_GRID})
    Flag("DYRE_MINIMAP", "Minimap button", function() return not ns.db.minimap.hide end, ns.SetMinimapShown,
        "Shows the Dyre's AddOns button on the minimap.")
    Flag("DYRE_WELCOME", "Welcome messages at login", function() return ns.db.welcome end, ns.SetWelcome,
        "Each Dyre's AddOn says its name and version in chat at login.")
end
