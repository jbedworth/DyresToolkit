local addonName, ns = ...
local DyresToolkit = ns.toolkit

-- The minimap button, the standard way (author-approved): a LibDataBroker
-- launcher shown by LibDBIcon, both embedded. Forever has no AddOn
-- compartment (Blizzard_Minimap.toc loads it for mainline only). Left-click
-- locks or unlocks every Dyre's AddOn's frames; right-click opens a menu.

local ICON = "Interface\\Icons\\INV_Misc_Wrench_01"
local icon

local function Libraries()
    if type(LibStub) ~= "table" and type(LibStub) ~= "function" then
        return nil
    end
    local broker = LibStub("LibDataBroker-1.1", true)
    local dbicon = LibStub("LibDBIcon-1.0", true)
    if broker and dbicon then
        return broker, dbicon
    end
end

local function BuildMenu(owner, root)
    root:CreateTitle(ns.TITLE)
    root:CreateButton(ns.db.locked and "Unlock frames" or "Lock frames", DyresToolkit.ToggleLock)
    root:CreateCheckbox("Show the grid", function() return ns.db.grid end,
        function() ns.SetGrid(not ns.db.grid) end)
    root:CreateCheckbox("Snap to the grid", function() return ns.db.snapToGrid end,
        function() ns.SetSnapToGrid(not ns.db.snapToGrid) end)
    root:CreateButton("Settings", function() DyresToolkit.OpenSettings() end)
    local addons = DyresToolkit.AddOns()
    local withSettings = {}
    for _, info in ipairs(addons) do
        if type(info.openSettings) == "function" then
            withSettings[#withSettings + 1] = info
        end
    end
    if #withSettings > 0 then
        root:CreateDivider()
        for _, info in ipairs(withSettings) do
            root:CreateButton(ns.ShortName(info.title), function() info.openSettings() end)
        end
    end
end

function ns.OpenMenu(owner)
    if type(MenuUtil) ~= "table" or type(MenuUtil.CreateContextMenu) ~= "function" then
        return false
    end
    MenuUtil.CreateContextMenu(owner, BuildMenu)
    return true
end

function ns.RefreshMinimap()
    local _, dbicon = Libraries()
    if not dbicon or not icon then
        return
    end
    if ns.db.minimap.hide then
        dbicon:Hide(addonName)
    else
        dbicon:Show(addonName)
    end
end

function ns.SetMinimapShown(shown)
    ns.db.minimap.hide = not shown
    ns.RefreshMinimap()
end

function ns.InitializeMinimap()
    local broker, dbicon = Libraries()
    if not broker then
        return
    end
    icon = broker:NewDataObject(addonName, {
        type = "launcher",
        text = ns.TITLE,
        icon = ICON,
        OnClick = function(owner, button)
            if button == "RightButton" then
                ns.OpenMenu(owner)
            else
                DyresToolkit.ToggleLock()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(ns.TITLE)
            tooltip:AddLine(ns.db.locked and "Left-click: unlock frames" or "Left-click: lock frames", 1, 1, 1)
            tooltip:AddLine("Right-click: menu", 1, 1, 1)
        end,
    })
    if icon then
        dbicon:Register(addonName, icon, ns.db.minimap)
    end
end
