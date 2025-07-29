-- resources/[warzone]/warzone_zones/server/activity.lua

WarzoneActivity = {}

-- Activity tracking for advanced analytics
function WarzoneActivity.TrackPlayerActivity(source, activityType, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end
    
    local currentTime = os.time()
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local zone, zoneType = WarzoneZones.GetZoneByCoords(playerCoords)
    
-- resources/[warzone]/warzone_zones/server/activity.lua (continued)

local eventData = {
       type = activityType,
       coords = {x = playerCoords.x, y = playerCoords.y, z = playerCoords.z},
       zone = zone and zone.name or "unknown",
       timestamp = currentTime,
       additional = data or {}
   }
   
   -- Store in database for analytics
   MySQL.insert('INSERT INTO warzone_zone_events (zone_name, event_type, player_identifier, event_data) VALUES (?, ?, ?, ?)', 
       {eventData.zone, activityType, xPlayer.identifier, json.encode(eventData)})
end

-- Get zone analytics
function WarzoneActivity.GetZoneAnalytics(zoneName, timeframe)
   timeframe = timeframe or 3600 -- Default 1 hour
   
   local analytics = MySQL.query.await([[
       SELECT 
           event_type,
           COUNT(*) as count,
           AVG(JSON_EXTRACT(event_data, '$.coords.x')) as avg_x,
           AVG(JSON_EXTRACT(event_data, '$.coords.y')) as avg_y
       FROM warzone_zone_events 
       WHERE zone_name = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? SECOND)
       GROUP BY event_type
   ]], {zoneName, timeframe})
   
   return analytics
end

-- Get hotspots (areas with most activity)
function WarzoneActivity.GetHotspots(limit)
   limit = limit or 5
   
   local hotspots = MySQL.query.await([[
       SELECT 
           zone_name,
           COUNT(*) as activity_count,
           COUNT(CASE WHEN event_type = 'kill' THEN 1 END) as kills,
           COUNT(DISTINCT player_identifier) as unique_players
       FROM warzone_zone_events 
       WHERE created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
       GROUP BY zone_name 
       ORDER BY activity_count DESC 
       LIMIT ?
   ]], {limit})
   
   return hotspots
end

-- Activity heat map data
function WarzoneActivity.GetHeatMapData(timeframe)
   timeframe = timeframe or 1800 -- 30 minutes
   
   local heatData = MySQL.query.await([[
       SELECT 
           zone_name,
           activity_level,
           kills_last_5min,
           last_activity
       FROM warzone_zones_activity 
       WHERE last_activity > DATE_SUB(NOW(), INTERVAL ? SECOND)
       ORDER BY kills_last_5min DESC
   ]], {timeframe})
   
   return heatData
end

-- Cleanup old activity data
function WarzoneActivity.CleanupOldData()
   local cleanupTime = ZoneConfig.Activity.CleanupInterval / 1000 -- Convert to seconds
   
   MySQL.query('DELETE FROM warzone_zone_events WHERE created_at < DATE_SUB(NOW(), INTERVAL ? SECOND)', {cleanupTime})
   
   if Config.Debug then
       print("[WARZONE ZONES] Cleaned up old activity data")
   end
end

-- Start cleanup thread
Citizen.CreateThread(function()
   while true do
       Citizen.Wait(ZoneConfig.Activity.CleanupInterval)
       WarzoneActivity.CleanupOldData()
   end
end)

-- Export functions for other resources
exports('GetZoneAnalytics', WarzoneActivity.GetZoneAnalytics)
exports('GetHotspots', WarzoneActivity.GetHotspots)
exports('GetHeatMapData', WarzoneActivity.GetHeatMapData)