local _, ns = ...
local DyresToolkit = ns.toolkit

-- Widgets (contract 2, author-approved 2026-10-20: "all the widget layout,
-- snapping, modifier key move rules, etc., centralized in Dyre's Tools, so
-- the individual packs do not have to worry about it"). An AddOn asks for a
-- widget, puts its own content inside, and never places, drags, scales, or
-- saves it itself. The toolkit owns:
--   - placement from the AddOn's saved table, and its default place;
--   - the gold outline and hint while frames are unlocked, and dragging with
--     every Layout.lua rule (magnetic snapping, the grid, Shift-drag groups,
--     Ctrl for an exact place, a drop in combat waits);
--   - scale, width, height, and opacity, each a setting with a gold default
--     mark and "Reset size", applied from the center (ResizeFromCenter);
--   - the mouse: a widget takes clicks only while unlocked, unless the AddOn
--     says it needs them (a visible bar of buttons) or manages them itself;
--   - combat: a protected widget (secure, or holding secure frames) moves,
--     resizes, and changes its mouse only out of combat; asked in combat, it
--     waits for PLAYER_REGEN_ENABLED. Opacity applies at once.
-- The AddOn's saved table holds the place as {point, relativePoint, x, y}
-- and the numbers as plain values, under keys it may rename for old saves.

local DEFAULT_KEYS = {position = "position", scale = "scale", width = "width", height = "height",
    opacity = "opacity"}
local LABELS = {scale = "Size", width = "Width", height = "Height", opacity = "Opacity"}
local PERCENT = {scale = true, opacity = true}
local DEFAULT_SCALE = {min = 50, max = 150, step = 5, default = 100}
local DEFAULT_OPACITY = {min = 10, max = 100, step = 5, default = 100}
local MOVER_INSET = 4
local MOVER_EDGE = 14
local GOLD = {1, 0.82, 0}

local widgets, byAddOn = {}, {}
local waiting = {}

local function IsProtected(frame)
    return type(frame.IsProtected) == "function" and frame:IsProtected() == true
end

-- Rounds to the step and clamps; anything else becomes the default.
local function Clamp(spec, value)
    if type(value) ~= "number" or value ~= value then
        return spec.default
    end
    value = spec.min + math.floor((value - spec.min) / spec.step + 0.5) * spec.step
    return math.max(spec.min, math.min(spec.max, value))
end

local function SizeSpecs(spec)
    local sizes = {}
    local wanted = spec.sizes or {}
    if wanted.scale then
        sizes.scale = type(wanted.scale) == "table" and wanted.scale or DEFAULT_SCALE
    end
    for _, name in ipairs({"width", "height"}) do
        local range = wanted[name]
        if type(range) == "table" then
            sizes[name] = {min = range.min, max = range.max, step = range.step or 1,
                default = range.default or spec[name]}
        end
    end
    if wanted.opacity then
        sizes.opacity = type(wanted.opacity) == "table" and wanted.opacity or DEFAULT_OPACITY
    end
    -- The AddOn's own size settings (a bar's line height, its text size):
    -- spec.measure turns them into the frame's width and height.
    local custom = {}
    for name, range in pairs(wanted) do
        if not sizes[name] and type(range) == "table" then
            sizes[name] = range
            custom[#custom + 1] = name
        end
    end
    table.sort(custom)
    local order = {}
    for _, name in ipairs(spec.sizeOrder or {}) do
        if sizes[name] then order[#order + 1] = name end
    end
    local listed = {}
    for _, name in ipairs(order) do listed[name] = true end
    for _, name in ipairs({"scale", "width", "height"}) do
        if sizes[name] and not listed[name] then order[#order + 1] = name; listed[name] = true end
    end
    for _, name in ipairs(custom) do
        if not listed[name] then order[#order + 1] = name; listed[name] = true end
    end
    if sizes.opacity and not listed.opacity then order[#order + 1] = "opacity" end
    sizes.order = order
    for _, name in ipairs(order) do
        local range = sizes[name]
        assert(type(range.min) == "number" and type(range.max) == "number" and range.min < range.max
            and type(range.step) == "number" and range.step > 0 and type(range.default) == "number",
            "DyresToolkit.CreateWidget: bad " .. name .. " range")
    end
    return sizes
end

local function Value(widget, name)
    return widget.dyre.store[widget.dyre.keys[name]]
end

-- The widget's scale and size now, from its settings and content.
local function Wanted(widget)
    local scale = widget.dyre.sizes.scale and Value(widget, "scale") / 100 or 1
    if widget.dyre.measure then
        local width, height = widget.dyre.measure(widget)
        return scale, width, height
    end
    local width = widget.dyre.sizes.width and Value(widget, "width") or widget.dyre.contentWidth
    local height = widget.dyre.sizes.height and Value(widget, "height") or widget.dyre.contentHeight
    return scale, width, height
end

local function MouseWanted(widget)
    if widget.dyre.mouseMode == "always" then
        return true
    end
    return not ns.db.locked
end

local function Wait(widget)
    waiting[widget] = true
    ns.widgetEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- Size, scale, and mouse; a protected widget only out of combat.
local function Apply(widget)
    if InCombatLockdown() and IsProtected(widget) then
        Wait(widget)
        return false
    end
    local scale, width, height = Wanted(widget)
    DyresToolkit.ResizeFromCenter(widget, scale, width, height, widget.dyre.growAnchor)
    -- The edge holds for this content change only; settings resize from the center.
    widget.dyre.growAnchor = nil
    if widget.dyre.mouseMode ~= "client" then
        widget:EnableMouse(MouseWanted(widget))
    end
    if widget.dyre.onLayout then
        widget.dyre.onLayout(widget, width, height, scale)
    end
    return true
end

-- Bar opacity in and out of combat (2.19.0; an MTF player asked to set the
-- Portals and Conjure bars "to 0% in-combat, 80% out-of-combat (100%
-- mouse-over)"; John, 2026-11-27: for every button bar, no checkbox, "always
-- at least 80% opacity (or the out-of-combat opacity, whichever is higher) on
-- mouseover; that solves the problem", and both sliders start at the bar's
-- current opacity). So a bar at 0% in combat shows as the mouse reaches it,
-- and a secure button is never clicked unseen. A bar is a widget laid out by
-- LayoutButtons. Its out-of-combat opacity is its Opacity setting when it has
-- one, else store.opacityOut; its in-combat opacity is store.opacityIn, set
-- to the out-of-combat one the first time. SetAlpha is allowed in combat.
-- Events only: PLAYER_REGEN_DISABLED/ENABLED and the mouse entering and
-- leaving the bar and its buttons (HookScript; the buttons' own scripts run
-- first). While frames are unlocked a bar shows fully.
DyresToolkit.BAR_OPACITY_VERSION = 1
local BAR_OPACITY = {min = 0, max = 100, step = 5, default = 100}
local MOUSEOVER_OPACITY = 80
local barCombat = type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
local hovered = setmetatable({}, {__mode = "k"})
local hoverHooked = setmetatable({}, {__mode = "k"})

local function OpacityNumber(value, default)
    if type(value) ~= "number" or value ~= value then
        return default
    end
    return Clamp(BAR_OPACITY, value)
end

local function BarOutOpacity(widget)
    if widget.dyre.sizes.opacity then
        return Value(widget, "opacity")
    end
    return OpacityNumber(widget.dyre.store.opacityOut, 100)
end

local function BarInOpacity(widget)
    local store = widget.dyre.store
    if store.opacityIn == nil then
        store.opacityIn = BarOutOpacity(widget)
    end
    return OpacityNumber(store.opacityIn, BarOutOpacity(widget))
end

-- The opacity a bar shows now, in percent.
local function BarOpacity(widget)
    if not ns.db.locked then
        return 100
    end
    local out = BarOutOpacity(widget)
    local opacity = barCombat and BarInOpacity(widget) or out
    if hovered[widget] then
        opacity = math.max(opacity, MOUSEOVER_OPACITY, out)
    end
    return opacity
end

local function ApplyOpacity(widget)
    local alpha
    if widget.dyre.bar then
        alpha = BarOpacity(widget) / 100
    elseif widget.dyre.sizes.opacity then
        alpha = Value(widget, "opacity") / 100
    else
        return
    end
    widget:SetAlpha(alpha)
    if widget.dyre.onOpacity then
        widget.dyre.onOpacity(widget, alpha)
    end
end

local function Place(widget)
    local position = Value(widget, "position")
    local default = widget.dyre.point
    widget:ClearAllPoints()
    if type(position) == "table" and type(position.x) == "number" and type(position.y) == "number" then
        widget:SetPoint(position.point or "CENTER", UIParent, position.relativePoint or "BOTTOMLEFT",
            position.x, position.y)
    else
        widget:SetPoint(default.point, UIParent, default.relativePoint, default.x, default.y)
    end
end

-- The first placement: scale and size first, so a saved place (in the
-- widget's own scaled units, as it was saved) lands where it was.
local function Setup(widget)
    if InCombatLockdown() and IsProtected(widget) then
        widget.dyre.needsSetup = true
        Wait(widget)
        return
    end
    widget.dyre.needsSetup = nil
    local scale, width, height = Wanted(widget)
    widget:SetScale(scale)
    -- A widget that grows from an edge was saved at its size then; its
    -- size now can differ (content not in yet), so it goes back at the saved
    -- size and resizes keeping that edge, or it would drift on each reload.
    local position = Value(widget, "position")
    if type(position) == "table" and type(position.anchor) == "string" and type(position.width) == "number"
            and type(position.height) == "number" then
        widget:SetSize(position.width, position.height)
        Place(widget)
        widget.dyre.lastAnchor = position.anchor
        DyresToolkit.ResizeFromCenter(widget, nil, width, height, position.anchor)
    else
        widget:SetSize(width, height)
        Place(widget)
    end
    if widget.dyre.mouseMode ~= "client" then
        widget:EnableMouse(MouseWanted(widget))
    end
    ApplyOpacity(widget)
    if widget.dyre.onLayout then
        widget.dyre.onLayout(widget, width, height, scale)
    end
end

-- Which AddOn an outline belongs to (2.17.0; John, 2026-11-27, two
-- "Warning messages" outlines in layout mode: "I can't tell what the top
-- warning messages are from"): the AddOn's title, "Dyre's " said once, before
-- the hint. The toolkit's own widgets have none.
local function OwnerPrefix(widget)
    local addon = widget.dyre.addon
    if type(addon) ~= "string" or addon == "DyresToolkit" then
        return ""
    end
    local read = type(C_AddOns) == "table" and C_AddOns.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
    local ok, title = false, nil
    if type(read) == "function" then
        ok, title = pcall(read, addon, "Title")
    end
    if not ok or type(title) ~= "string" or title == "" then
        return ""
    end
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return ns.ShortName(title) .. ": "
end

local FLIP_SIZE = 24

local function CreateMover(widget)
    local mover = CreateFrame("Frame", nil, widget, "BackdropTemplate")
    mover:SetPoint("TOPLEFT", -MOVER_INSET, MOVER_INSET)
    mover:SetPoint("BOTTOMRIGHT", MOVER_INSET, -MOVER_INSET)
    if mover.SetBackdrop then
        mover:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = MOVER_EDGE})
        mover:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3])
    end
    mover:EnableMouse(false)
    mover.hint = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mover.hint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover.hint:SetText(OwnerPrefix(widget) .. (widget.dyre.hint
        or (widget.dyre.title .. " · drag to move · /dyre lock when done")))
    -- The flip button (2.18.0; John, 2026-11-27: users "are going to want a
    -- way to flip the bar from vertical to horizontal in unlocked mode";
    -- "A button with an arrow going around"): on the outline's top-right
    -- corner, shown only on a bar laid out by LayoutButtons. The outline is
    -- ours, so no Blizzard or secure frame is touched; a right-click on the
    -- bar's own buttons would cast their spells. The texture is the model
    -- rotate arrow, UI-RotationRight-Button-Up (Blizzard's Vanilla
    -- PaperDollFrame.xml and shared ModelSceneTemplates use it).
    local flip = CreateFrame("Button", nil, mover)
    flip:SetSize(FLIP_SIZE, FLIP_SIZE)
    flip:SetPoint("CENTER", mover, "TOPRIGHT", -FLIP_SIZE / 2, -FLIP_SIZE / 2)
    if flip.SetNormalTexture then
        flip:SetNormalTexture("Interface\\Buttons\\UI-RotationRight-Button-Up")
        flip:SetPushedTexture("Interface\\Buttons\\UI-RotationRight-Button-Down")
        flip:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round", "ADD")
    end
    flip:EnableMouse(true)
    flip:SetScript("OnClick", function()
        widget:SetOrientation(widget:GetOrientation() == "vertical" and "horizontal" or "vertical")
    end)
    flip:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Switch between a row and a column.")
            GameTooltip:Show()
        end
    end)
    flip:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    flip:Hide()
    mover.flip = flip
    return mover
end

-- The lock changed: outlines, the AddOn's samples, and the mouse.
function ns.RefreshWidgets()
    local unlocked = not ns.db.locked
    for _, widget in ipairs(widgets) do
        widget.dyre.mover:SetShown(unlocked)
        if widget.dyre.bar then
            ApplyOpacity(widget)
        end
        if widget.dyre.onUnlock then
            widget.dyre.onUnlock(widget, unlocked)
        end
        if widget.dyre.mouseMode ~= "client" then
            if InCombatLockdown() and IsProtected(widget) then
                Wait(widget)
            else
                widget:EnableMouse(MouseWanted(widget))
            end
        end
    end
end

ns.widgetEvents = CreateFrame("Frame")
ns.widgetEvents:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local pending = waiting
    waiting = {}
    for _, widget in ipairs(widgets) do
        if pending[widget] then
            if widget.dyre.needsSetup then
                Setup(widget)
            else
                Apply(widget)
            end
        end
    end
end)

-- Combat starts or ends: every bar takes its opacity for it.
local barEvents = CreateFrame("Frame")
barEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
barEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
barEvents:SetScript("OnEvent", function(_, event)
    barCombat = event == "PLAYER_REGEN_DISABLED"
    for _, widget in ipairs(widgets) do
        if widget.dyre.bar then
            ApplyOpacity(widget)
        end
    end
end)

local function SetHovered(widget, on)
    on = on and true or nil
    if hovered[widget] ~= on then
        hovered[widget] = on
        ApplyOpacity(widget)
    end
end

-- The mouse over the bar or one of its buttons shows the bar.
local function HookHover(widget, frame)
    if type(frame) ~= "table" or hoverHooked[frame] or type(frame.HookScript) ~= "function" then
        return
    end
    hoverHooked[frame] = true
    frame:HookScript("OnEnter", function() SetHovered(widget, true) end)
    frame:HookScript("OnLeave", function()
        SetHovered(widget, type(widget.IsMouseOver) == "function" and widget:IsMouseOver() == true)
    end)
end

local WidgetMethods = {}

-- A size that comes from the content (a bar holding as many buttons as
-- spells you know), not from a setting. Applied from the center.
-- anchor: "LEFT", "RIGHT", "TOP", "BOTTOM", or a corner ("TOPLEFT") keeps
-- that edge or corner fixed (a bar growing left to right, a box collapsing
-- toward its top); "CENTER" (the default) keeps the center.
function WidgetMethods.SetContentSize(widget, width, height, anchor)
    widget.dyre.contentWidth, widget.dyre.contentHeight = width, height
    widget.dyre.growAnchor = anchor
    if anchor and anchor ~= "CENTER" then
        widget.dyre.lastAnchor = anchor
    end
    Apply(widget)
end

-- Button bars, horizontal or vertical (2.18.0; a CurseForge player asked for
-- MTF's portal and conjure bars: "Is it possible to add an option to change
-- the portal and conjure bars from horizontal to vertical?"; John,
-- 2026-11-27: a Toolkit feature for every button bar). The orientation is
-- saved in the widget's store (`orientation`: "vertical", else horizontal),
-- so it is in the AddOn's own settings and profile part.
-- widget:LayoutButtons(buttons, opts) places the buttons in order, from the
-- top-left: a row, or a column; opts.size (each button's size, default 36),
-- opts.gap (default 4), opts.padding (default 0), opts.anchor (the edge kept
-- in place as the size changes, as SetContentSize; default the center, so a
-- switch keeps the bar where it was). The buttons may be secure: they move
-- only out of combat (DyresToolkit.OutOfCombat; a change in combat applies
-- when combat ends). The last call is kept, so a change of orientation lays
-- the same buttons out again.
DyresToolkit.BAR_LAYOUT_VERSION = 1
local ORIENTATIONS = {horizontal = true, vertical = true}

function WidgetMethods.GetOrientation(widget)
    return widget.dyre.store.orientation == "vertical" and "vertical" or "horizontal"
end

function WidgetMethods.LayoutButtons(widget, buttons, opts)
    opts = type(opts) == "table" and opts or {}
    widget.dyre.bar = {buttons = buttons, opts = opts}
    BarInOpacity(widget)
    HookHover(widget, widget)
    for _, button in ipairs(type(buttons) == "table" and buttons or {}) do
        HookHover(widget, button)
    end
    if widget.dyre.mover and widget.dyre.mover.flip then
        widget.dyre.mover.flip:Show()
    end
    local size, gap, padding = opts.size or 36, opts.gap or 4, opts.padding or 0
    local vertical = widget:GetOrientation() == "vertical"
    local count = math.max(type(buttons) == "table" and #buttons or 0, 1)
    local long = padding * 2 + count * size + (count - 1) * gap
    local short = padding * 2 + size
    DyresToolkit.OutOfCombat("dyreBar:" .. tostring(widget.dyre.addon) .. ":" .. tostring(widget.dyre.widgetKey),
        function()
            for index, button in ipairs(type(buttons) == "table" and buttons or {}) do
                local step = padding + (index - 1) * (size + gap)
                button:ClearAllPoints()
                if vertical then
                    button:SetPoint("TOPLEFT", widget, "TOPLEFT", padding, -step)
                else
                    button:SetPoint("TOPLEFT", widget, "TOPLEFT", step, -padding)
                end
            end
        end)
    if vertical then
        widget:SetContentSize(short, long, opts.anchor)
    else
        widget:SetContentSize(long, short, opts.anchor)
    end
    ApplyOpacity(widget)
    return vertical and "vertical" or "horizontal"
end

-- Saves the orientation and lays the last buttons out again.
function WidgetMethods.SetOrientation(widget, value)
    if not ORIENTATIONS[value] then
        return
    end
    widget.dyre.store.orientation = value == "vertical" and "vertical" or nil
    if widget.dyre.bar then
        widget:LayoutButtons(widget.dyre.bar.buttons, widget.dyre.bar.opts)
    end
    -- An open settings page shows the new value (a flip from the outline).
    for _, variable in ipairs(widget.dyre.layoutVariables or {}) do
        if type(Settings) == "table" and type(Settings.NotifyUpdate) == "function" then
            pcall(Settings.NotifyUpdate, variable)
        end
    end
end

-- The "Layout" row: Horizontal or Vertical. opts: label (default "Layout"),
-- tooltip, variable (a settings section's ctx.variable), modify and watch
-- (greyed while the bar is off, as AddWidgetSettings). Gives the initializer,
-- or nil without the settings API (a dropdown, else a "Vertical" checkbox).
function DyresToolkit.AddBarLayoutSetting(category, layout, widget, opts)
    if type(Settings) ~= "table" or type(Settings.RegisterProxySetting) ~= "function" or type(category) ~= "table"
            or type(widget) ~= "table" or type(widget.dyre) ~= "table" then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local name = ("DYRE_" .. widget.dyre.addon .. "_" .. widget.dyre.widgetKey .. "_ORIENTATION"):upper()
        :gsub("[^%w_]", "_")
    if type(opts.variable) == "function" then
        name = opts.variable(name)
    end
    local tooltip = opts.tooltip or "Lay the buttons out in a row or a column."
    widget.dyre.layoutVariables = widget.dyre.layoutVariables or {}
    table.insert(widget.dyre.layoutVariables, name)
    local initializer
    if type(Settings.CreateDropdown) == "function" and type(Settings.CreateControlTextContainer) == "function"
            and Settings.VarType.String then
        local setting = Settings.RegisterProxySetting(category, name, Settings.VarType.String, opts.label or "Layout",
            "horizontal", function() return widget:GetOrientation() end,
            function(value) widget:SetOrientation(value) end)
        local function Options()
            local container = Settings.CreateControlTextContainer()
            container:Add("horizontal", "Horizontal")
            container:Add("vertical", "Vertical")
            return container:GetData()
        end
        initializer = Settings.CreateDropdown(category, setting, Options, tooltip)
    elseif type(Settings.CreateCheckbox) == "function" then
        local setting = Settings.RegisterProxySetting(category, name, Settings.VarType.Boolean, "Vertical", false,
            function() return widget:GetOrientation() == "vertical" end,
            function(value) widget:SetOrientation(value and "vertical" or "horizontal") end)
        initializer = Settings.CreateCheckbox(category, setting, tooltip)
    end
    if type(initializer) == "table" then
        if type(opts.modify) == "function" and type(initializer.AddModifyPredicate) == "function" then
            initializer:AddModifyPredicate(opts.modify)
        end
        if opts.watch and type(DyresToolkit.WatchSettings) == "function" then
            DyresToolkit.WatchSettings(initializer, opts.watch)
        end
    end
    -- The bar's opacity in and out of combat, under its Layout row (2.19.0).
    if opts.opacity ~= false and type(DyresToolkit.AddBarOpacitySettings) == "function" then
        DyresToolkit.AddBarOpacitySettings(category, widget, opts)
    end
    return initializer
end

-- A bar's opacity out of combat or in combat ("out", "in"), in percent.
function WidgetMethods.GetBarOpacity(widget, which)
    if which == "in" then
        return BarInOpacity(widget)
    end
    return BarOutOpacity(widget)
end

function WidgetMethods.SetBarOpacity(widget, which, value)
    value = OpacityNumber(value, nil)
    if value == nil then
        return
    end
    BarInOpacity(widget)
    if which == "in" then
        widget.dyre.store.opacityIn = value
    elseif widget.dyre.sizes.opacity then
        widget:SetSetting("opacity", value)
        return
    else
        widget.dyre.store.opacityOut = value
    end
    ApplyOpacity(widget)
end

-- One of scale, width, height, opacity: clamped, saved, and applied.
function WidgetMethods.SetSetting(widget, name, value)
    local range = name ~= "order" and widget.dyre.sizes[name]
    if not range then
        return
    end
    widget.dyre.store[widget.dyre.keys[name]] = Clamp(range, value)
    if name == "opacity" then
        ApplyOpacity(widget)
    else
        Apply(widget)
    end
end

function WidgetMethods.GetSetting(widget, name)
    return name ~= "order" and widget.dyre.sizes[name] and Value(widget, name) or nil
end

-- Back to the default scale, width, and height; opacity stays (as MTF's and
-- WTF's "Reset size").
function WidgetMethods.ResetSize(widget)
    for _, name in ipairs(widget.dyre.resetSizes or widget.dyre.sizes.order) do
        local range = widget.dyre.sizes[name]
        if range and name ~= "order" and (widget.dyre.resetSizes or name ~= "opacity") then
            widget.dyre.store[widget.dyre.keys[name]] = range.default
        end
    end
    Apply(widget)
end

-- A child the player may drag the widget by (a bar's buttons, which leave
-- only a thin edge of the bar itself). Clicks still reach the child.
function WidgetMethods.AddDragHandle(widget, child)
    child:RegisterForDrag("LeftButton")
    child:SetScript("OnDragStart", function() DyresToolkit.BeginDrag(widget) end)
    child:SetScript("OnDragStop", function() DyresToolkit.EndDrag(widget) end)
end

function WidgetMethods.ResetPosition(widget)
    widget.dyre.store[widget.dyre.keys.position] = nil
    if InCombatLockdown() and IsProtected(widget) then
        widget.dyre.needsSetup = true
        Wait(widget)
        return
    end
    Place(widget)
end

-- spec: addon, key, title, store (the AddOn's saved table), width, height
-- (the size at 100%), point {point, relativePoint, x, y} from UIParent
-- (default its center); optional frame (the AddOn's own frame, such as a
-- named secure button), name, keys (renamed save keys), sizes {scale = true
-- or a range, width/height = ranges, opacity = true or a range, and any
-- AddOn setting = a range with label (and percent = true)}, sizeOrder (the
-- sliders' order; opacity last), measure(widget) -> width, height (the frame
-- size from the settings, for sizes such as a bar's line height),
-- resetSizes (what "Reset size" restores; default every size but opacity),
-- hint (the outline's text while unlocked), mouse
-- ("unlocked", the default; "always"; "client"), and callbacks
-- onLayout(widget, width, height, scale), onOpacity(widget, alpha),
-- onUnlock(widget, unlocked).
function DyresToolkit.CreateWidget(spec)
    assert(type(spec) == "table", "DyresToolkit.CreateWidget: spec table expected")
    assert(type(spec.addon) == "string" and type(spec.key) == "string", "DyresToolkit.CreateWidget: addon and key")
    assert(type(spec.store) == "table", "DyresToolkit.CreateWidget: store must be the AddOn's saved table")
    assert(type(spec.width) == "number" and type(spec.height) == "number", "DyresToolkit.CreateWidget: width, height")
    local widget = spec.frame or CreateFrame("Frame", spec.name, UIParent)
    assert(widget.dyre == nil, "DyresToolkit.CreateWidget: this frame is a widget already")
    -- All the toolkit's state lives here, so it never clashes with the AddOn's own fields.
    widget.dyre = {}
    widget.dyre.addon, widget.dyre.widgetKey = spec.addon, spec.key
    widget.dyre.title = spec.title or spec.key
    widget.dyre.store = spec.store
    widget.dyre.keys = {}
    widget.dyre.sizes = SizeSpecs(spec)
    for name, key in pairs(DEFAULT_KEYS) do
        widget.dyre.keys[name] = spec.keys and spec.keys[name] or key
    end
    for _, name in ipairs(widget.dyre.sizes.order) do
        widget.dyre.keys[name] = widget.dyre.keys[name] or (spec.keys and spec.keys[name]) or name
    end
    widget.dyre.measure = spec.measure
    widget.dyre.resetSizes = spec.resetSizes
    widget.dyre.hint = spec.hint
    widget.dyre.contentWidth, widget.dyre.contentHeight = spec.width, spec.height
    local point = spec.point or {}
    widget.dyre.point = {point = point.point or point[1] or "CENTER", relativePoint = point.relativePoint or point[2]
        or "CENTER", x = point.x or point[3] or 0, y = point.y or point[4] or 0}
    widget.dyre.mouseMode = spec.mouse or "unlocked"
    widget.dyre.onLayout, widget.dyre.onOpacity, widget.dyre.onUnlock = spec.onLayout, spec.onOpacity, spec.onUnlock
    -- Repair the saved numbers.
    for _, name in ipairs(widget.dyre.sizes.order) do
        local key = widget.dyre.keys[name]
        widget.dyre.store[key] = Clamp(widget.dyre.sizes[name], widget.dyre.store[key])
    end
    for name, method in pairs(WidgetMethods) do
        widget[name] = method
    end
    widget:SetMovable(true)
    widget:SetClampedToScreen(true)
    widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnDragStart", DyresToolkit.BeginDrag)
    widget:SetScript("OnDragStop", DyresToolkit.EndDrag)
    DyresToolkit.RegisterMovable(widget, function(position)
        -- The size and grow edge too, so Setup can restore the place exactly.
        if widget.dyre.lastAnchor then
            position.anchor = widget.dyre.lastAnchor
            position.width, position.height = widget:GetWidth(), widget:GetHeight()
        end
        widget.dyre.store[widget.dyre.keys.position] = position
    end)
    widget.dyre.mover = CreateMover(widget)
    widget.dyre.mover:SetShown(not ns.db.locked)
    widgets[#widgets + 1] = widget
    byAddOn[spec.addon] = byAddOn[spec.addon] or {}
    byAddOn[spec.addon][#byAddOn[spec.addon] + 1] = widget
    Setup(widget)
    if widget.dyre.onUnlock and not ns.db.locked then
        widget.dyre.onUnlock(widget, true)
    end
    return widget
end

-- An AddOn's reset command: every widget of it back to its default place.
function DyresToolkit.ResetWidgets(addon)
    for _, widget in ipairs(byAddOn[addon] or {}) do
        widget:ResetPosition()
    end
end

-- New saved values in a widget's store (a profile copied or imported, 2.10.0):
-- the numbers are repaired, then place, scale, size, and opacity are set
-- again from the store, as at creation. A protected widget waits for the end
-- of combat. The store must be the same table (Profiles.lua writes in place).
function DyresToolkit.ReapplyWidgets(addon)
    for _, widget in ipairs(byAddOn[addon] or {}) do
        for _, name in ipairs(widget.dyre.sizes.order) do
            local key = widget.dyre.keys[name]
            widget.dyre.store[key] = Clamp(widget.dyre.sizes[name], widget.dyre.store[key])
        end
        widget.dyre.lastAnchor = nil
        Setup(widget)
    end
end

function DyresToolkit.Widgets(addon)
    local list = {}
    for _, widget in ipairs(byAddOn[addon] or {}) do
        list[#list + 1] = widget
    end
    return list
end

-- Settings: a slider per size the widget has, each with a gold mark at its
-- default, then "Reset size". The settings panel reuses slider frames, so the
-- mark is drawn when this setting's frame is set up and hidden on release.
local TICK_WIDTH, TICK_HEIGHT = 2, 12

-- Each pooled slider's gold mark, kept here, not as a field on Blizzard's frame.
local defaultTicks = setmetatable({}, {__mode = "k"})

local function PlaceTick(slider)
    local tick = defaultTicks[slider]
    local info = tick.info
    local thumb = slider:GetThumbTexture()
    local half = thumb and thumb:GetWidth() / 2 or 0
    local fraction = (info.default - info.min) / (info.max - info.min)
    tick:ClearAllPoints()
    tick:SetPoint("CENTER", slider, "LEFT", half + fraction * (slider:GetWidth() - 2 * half), 0)
end

function ns.AddDefaultTick(initializer, range)
    if type(initializer) ~= "table" or type(initializer.InitFrame) ~= "function" then
        return
    end
    initializer.dyreDefault = range
    -- A secure hook, not a replacement: Blizzard's row setup runs first,
    -- untainted (the settings list's frames are pooled and shared with
    -- Blizzard's own settings; 2026-11-19 taint fix).
    if type(hooksecurefunc) ~= "function" then
        return
    end
    hooksecurefunc(initializer, "InitFrame", function(self, frame)
        local slider = frame.SliderWithSteppers and frame.SliderWithSteppers.Slider
        if not slider then
            return
        end
        local tick = defaultTicks[slider]
        if not tick then
            tick = slider:CreateTexture(nil, "BORDER")
            tick:SetSize(TICK_WIDTH, TICK_HEIGHT)
            tick:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
            defaultTicks[slider] = tick
            slider:HookScript("OnSizeChanged", function()
                if tick:IsShown() then
                    PlaceTick(slider)
                end
            end)
            hooksecurefunc(frame, "Release", function()
                tick:Hide()
            end)
        end
        tick.info = initializer.dyreDefault
        PlaceTick(slider)
        tick:Show()
    end)
end

-- For an AddOn's own sliders (2.2.0): range = {min, max, default}.
DyresToolkit.AddDefaultTick = ns.AddDefaultTick

local function SliderOptions(name, range)
    local options = Settings.CreateSliderOptions(range.min, range.max, range.step)
    if type(MinimalSliderWithSteppersMixin) == "table" and type(options.SetLabelFormatter) == "function" then
        local formatter = (PERCENT[name] or range.percent) and function(value) return string.format("%d%%", value) end or nil
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
    end
    return options
end

-- "Opacity out of combat" and "Opacity in combat" for a bar (2.19.0), added
-- by AddBarLayoutSetting under its Layout row. opts as there (variable,
-- modify, watch). Gives the two initializers, or nil without the settings API.
function DyresToolkit.AddBarOpacitySettings(category, widget, opts)
    if type(Settings) ~= "table" or type(Settings.RegisterProxySetting) ~= "function"
            or type(Settings.CreateSlider) ~= "function" or type(Settings.CreateSliderOptions) ~= "function"
            or type(category) ~= "table" or type(widget) ~= "table" or type(widget.dyre) ~= "table" then
        return nil
    end
    opts = type(opts) == "table" and opts or {}
    local rows = {}
    local specs = {
        {which = "out", suffix = "OPACITY_OUT", label = "Opacity out of combat",
            tooltip = "How solid the bar is out of combat."},
        {which = "in", suffix = "OPACITY_IN", label = "Opacity in combat",
            tooltip = "How solid the bar is in combat. It shows at 80% or more while your mouse is over it."},
    }
    for _, spec in ipairs(specs) do
        local name = ("DYRE_" .. widget.dyre.addon .. "_" .. widget.dyre.widgetKey .. "_" .. spec.suffix):upper()
            :gsub("[^%w_]", "_")
        if type(opts.variable) == "function" then
            name = opts.variable(name)
        end
        local setting = Settings.RegisterProxySetting(category, name, Settings.VarType.Number, spec.label,
            BAR_OPACITY.default, function() return widget:GetBarOpacity(spec.which) end,
            function(value) widget:SetBarOpacity(spec.which, value) end)
        local slider = Settings.CreateSlider(category, setting, SliderOptions("opacity", BAR_OPACITY), spec.tooltip)
        if type(slider) == "table" then
            if type(opts.modify) == "function" and type(slider.AddModifyPredicate) == "function" then
                slider:AddModifyPredicate(opts.modify)
            end
            if opts.watch then
                DyresToolkit.WatchSettings(slider, opts.watch)
            end
            ns.AddDefaultTick(slider, BAR_OPACITY)
        end
        rows[spec.which] = slider
    end
    return rows
end

local function VariableName(widget, name)
    return ("DYRE_" .. widget.dyre.addon .. "_" .. widget.dyre.widgetKey .. "_" .. name):upper():gsub("[^%w_]", "_")
end

-- opts: labels (name -> text), tooltips (name -> text), resetLabel, resetTooltip,
-- variable (2.17.0: a function that maps each setting variable, such as a
-- settings section's ctx.variable on a host page, where the owner's page has
-- registered the plain names already), modify (2.17.0: a function; the rows
-- are greyed while it gives false, e.g. the feature's switch is off), watch
-- (2.17.0: a variable or a list; the rows check modify again live when one
-- of them changes; see WatchSettings), skip (2.19.0: size names to leave
-- out, such as {"opacity"} for a bar whose Layout row brings its opacity
-- sliders), resetName (2.18.1: the Reset row's
-- name, default the widget's title; John's client, 2026-11-27: a host page
-- calls the section "Shield display" while the title is "Dyre's Shields Up";
-- feature flag WIDGET_RESET_NAME).
DyresToolkit.WIDGET_RESET_NAME = 1
function DyresToolkit.AddWidgetSettings(category, layout, widget, opts)
    if type(Settings) ~= "table" or type(category) ~= "table" or type(widget) ~= "table" or not widget.dyre.sizes then
        return false
    end
    opts = opts or {}
    local labels, tooltips = opts.labels or {}, opts.tooltips or {}
    local variables = {}
    local skip = {}
    for _, name in ipairs(type(opts.skip) == "table" and opts.skip or {}) do
        skip[name] = true
    end
    for _, name in ipairs(widget.dyre.sizes.order) do
        local range = not skip[name] and widget.dyre.sizes[name]
        if range then
            local variable = VariableName(widget, name)
            if type(opts.variable) == "function" then
                variable = opts.variable(variable)
            end
            variables[#variables + 1] = variable
            local label = labels[name] or range.label or LABELS[name] or name
            local setting = Settings.RegisterProxySetting(category, variable, Settings.VarType.Number, label,
                range.default, function() return widget:GetSetting(name) end,
                function(value) widget:SetSetting(name, value) end)
            local tooltip = tooltips[name] or (name == "opacity"
                and "How solid it is."
                or ("Its " .. label:lower():gsub(" %(%%%)", "") .. "."))
            local slider = Settings.CreateSlider(category, setting, SliderOptions(name, range), tooltip)
            if type(opts.modify) == "function" and type(slider) == "table"
                    and type(slider.AddModifyPredicate) == "function" then
                slider:AddModifyPredicate(opts.modify)
            end
            if opts.watch then
                DyresToolkit.WatchSettings(slider, opts.watch)
            end
            ns.AddDefaultTick(slider, range)
        end
    end
    local resizable = #widget.dyre.sizes.order > (widget.dyre.sizes.opacity and 1 or 0)
    if resizable and type(CreateSettingsButtonInitializer) == "function" and type(layout) == "table"
            and type(layout.AddInitializer) == "function" then
        local resetName = type(opts.resetName) == "string" and opts.resetName ~= "" and opts.resetName
            or widget.dyre.title
        local reset = CreateSettingsButtonInitializer(resetName, opts.resetLabel or "Reset size",
            function()
                widget:ResetSize()
                for _, variable in ipairs(variables) do
                    Settings.NotifyUpdate(variable)
                end
            end, opts.resetTooltip or "Puts it back to its normal size.", true)
        if type(opts.modify) == "function" and type(reset.AddModifyPredicate) == "function" then
            reset:AddModifyPredicate(opts.modify)
        end
        if opts.watch then
            DyresToolkit.WatchSettings(reset, opts.watch)
        end
        if type(DyresToolkit.GreyButtonLabel) == "function" then
            DyresToolkit.GreyButtonLabel(reset)
        end
        layout:AddInitializer(reset)
    end
    return true
end
