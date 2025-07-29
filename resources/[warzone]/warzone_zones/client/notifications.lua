-- resources/[warzone]/warzone_zones/client/notifications.lua

WarzoneNotifications = {}

-- Combat warnings in dangerous zones
function WarzoneNotifications.ShowCombatWarning(activityLevel, zoneName)
    if not ZoneConfig.Notifications.ShowCombatWarnings then return end
    
    local warnings = {
        red = {
            message = "⚠️ HIGH ACTIVITY ZONE - Exercise extreme caution!",
            color = "error",
            duration = 5000
        },
        yellow = {
            message = "⚠️ MODERATE ACTIVITY ZONE - Stay alert!",
            color = "warning", 
            duration = 4000
        }
    }
    
    local warning = warnings[activityLevel]
    if warning then
        ESX.ShowNotification(warning.message, warning.color, warning.duration)
    end
end

-- Zone activity notifications
function WarzoneNotifications.ShowActivityUpdate(zoneName, activityLevel, recentKills)
    if not ZoneConfig.Notifications.ShowActivityLevel then return end
    
    local zoneLabel = WarzoneNotifications.GetZoneLabel(zoneName)
    local activityText = ""
    local icon = ""
    
    if activityLevel == 'red' then
        activityText = "HIGH ACTIVITY"
        icon = "🔴"
    elseif activityLevel == 'yellow' then
        activityText = "MODERATE ACTIVITY"
        icon = "🟡"
    else
        activityText = "LOW ACTIVITY"
        icon = "⚪"
    end
    
    local message = string.format("%s %s: %s (%d recent kills)", icon, zoneLabel, activityText, recentKills)
    ESX.ShowNotification(message, "info", 3000)
end

-- Get zone label by name
function WarzoneNotifications.GetZoneLabel(zoneName)
    -- Check combat zones
    for _, zone in pairs(Config.CombatZones) do
        if zone.name == zoneName then
            return zone.label
        end
    end
    
    -- Check green zones
    for _, zone in pairs(Config.GreenZones) do
        if zone.name == zoneName then
            return zone.label
        end
    end
    
    return zoneName:gsub("_", " "):gsub("(%l)(%w*)", function(a,b) return string.upper(a)..b end)
end

-- Green zone notifications
function WarzoneNotifications.ShowGreenZoneInfo()
    ESX.ShowNotification("🛡️ SAFE ZONE\n• Weapons disabled\n• Healing enabled\n• No combat allowed", "success", 6000)
end

-- Combat prevention notification
function WarzoneNotifications.ShowCombatPrevention()
    ESX.ShowNotification("❌ Combat is disabled in this safe zone!", "error", 3000)
end

-- Zone entry/exit with details
function WarzoneNotifications.ShowDetailedZoneEntry(zoneName, zoneType, zoneLabel)
    if zoneType == 'green' then
        WarzoneNotifications.ShowGreenZoneInfo()
    elseif zoneType == 'combat' then
        local activityLevel = WarzoneZonesClient.GetZoneActivity(zoneName)
        WarzoneNotifications.ShowCombatWarning(activityLevel, zoneName)
    end
end

-- Export notification functions
exports('ShowCombatWarning', WarzoneNotifications.ShowCombatWarning)
exports('ShowActivityUpdate', WarzoneNotifications.ShowActivityUpdate)
exports('ShowGreenZoneInfo', WarzoneNotifications.ShowGreenZoneInfo)