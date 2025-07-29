-- resources/[warzone]/warzone_zones/shared/zones_data.lua

ZonesData = {}

-- Zone utility functions
function ZonesData.GetZoneByName(zoneName)
   -- Check combat zones
   for _, zone in pairs(Config.CombatZones) do
       if zone.name == zoneName then
           return zone, 'combat'
       end
   end
   
   -- Check green zones
   for _, zone in pairs(Config.GreenZones) do
       if zone.name == zoneName then
           return zone, 'green'
       end
   end
   
   return nil, nil
end

-- Calculate zone coverage area
function ZonesData.GetZoneCoverage(zoneName)
   local zone, zoneType = ZonesData.GetZoneByName(zoneName)
   if not zone then return 0 end
   
   -- Calculate area in square meters
   local area = math.pi * (zone.radius ^ 2)
   return math.floor(area)
end

-- Get all zone names by type
function ZonesData.GetZonesByType(zoneType)
   local zones = {}
   
   if zoneType == 'combat' then
       for _, zone in pairs(Config.CombatZones) do
           table.insert(zones, zone.name)
       end
   elseif zoneType == 'green' then
       for _, zone in pairs(Config.GreenZones) do
           table.insert(zones, zone.name)
       end
   end
   
   return zones
end

-- Distance between zones
function ZonesData.GetDistanceBetweenZones(zone1Name, zone2Name)
   local zone1, _ = ZonesData.GetZoneByName(zone1Name)
   local zone2, _ = ZonesData.GetZoneByName(zone2Name)
   
   if not zone1 or not zone2 then return -1 end
   
   return #(zone1.coords - zone2.coords)
end

-- Check if coordinates are in any zone
function ZonesData.GetZoneAtCoords(coords)
   -- Check green zones first (higher priority)
   for _, zone in pairs(Config.GreenZones) do
       local distance = #(coords - zone.coords)
       if distance <= zone.radius then
           return zone.name, 'green', zone
       end
   end
   
   -- Check combat zones
   for _, zone in pairs(Config.CombatZones) do
       local distance = #(coords - zone.coords)
       if distance <= zone.radius then
           return zone.name, 'combat', zone
       end
   end
   
   return nil, nil, nil
end

-- Get nearest zone to coordinates
function ZonesData.GetNearestZone(coords, zoneType)
   local nearestZone = nil
   local nearestDistance = math.huge
   
   local zoneList = zoneType == 'green' and Config.GreenZones or Config.CombatZones
   
   for _, zone in pairs(zoneList) do
       local distance = #(coords - zone.coords)
       if distance < nearestDistance then
           nearestDistance = distance
           nearestZone = zone
       end
   end
   
   return nearestZone, nearestDistance
end

-- Zone statistics structure
ZonesData.ActivityLevels = {
   WHITE = {
       label = "Low Activity",
       color = {r = 255, g = 255, b = 255},
       threat = 1,
       description = "Safe area with minimal combat"
   },
   YELLOW = {
       label = "Moderate Activity", 
       color = {r = 255, g = 255, b = 0},
       threat = 2,
       description = "Some combat activity, exercise caution"
   },
   RED = {
       label = "High Activity",
       color = {r = 255, g = 0, b = 0},
       threat = 3,
       description = "Active combat zone, high danger"
   }
}

-- Export shared functions
if IsDuplicityVersion() then -- Server side
   exports('GetZoneByName', ZonesData.GetZoneByName)
   exports('GetZoneCoverage', ZonesData.GetZoneCoverage)
   exports('GetZonesByType', ZonesData.GetZonesByType)
   exports('GetDistanceBetweenZones', ZonesData.GetDistanceBetweenZones)
   exports('GetZoneAtCoords', ZonesData.GetZoneAtCoords)
   exports('GetNearestZone', ZonesData.GetNearestZone)
end