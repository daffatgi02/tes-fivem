-- resources/[warzone]/warzone_spawn/server/spawn_manager.lua

WarzoneSpawnManager = {}
WarzoneSpawnManager.ActiveSpawns = {}
WarzoneSpawnManager.SpawnQueue = {}
WarzoneSpawnManager.LocationUsage = {}
WarzoneSpawnManager.PlayerPreferences = {}

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize spawn manager with Factory Pattern
function WarzoneSpawnManager.Init()
    print("^2[WARZONE SPAWN] Initializing spawn management system...^7")
    
    -- Initialize database
    WarzoneSpawnManager.InitDatabase()
    
    -- Load spawn analytics
    WarzoneSpawnManager.LoadAnalytics()
    
    -- Start monitoring threads
    WarzoneSpawnManager.StartMonitoring()
    
    print("^2[WARZONE SPAWN] Spawn management system initialized!^7")
end

-- Database initialization with proper indexing
function WarzoneSpawnManager.InitDatabase()
    -- Spawn analytics table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_spawn_analytics` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `player_identifier` VARCHAR(60) NOT NULL,
            `spawn_location` VARCHAR(100) NOT NULL,
            `spawn_category` VARCHAR(50) NOT NULL,
            `spawn_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `survival_time` INT DEFAULT 0,
            `success_rating` FLOAT DEFAULT 0.0,
            `player_level` INT DEFAULT 1,
            `crew_id` INT DEFAULT NULL,
            `zone_activity` VARCHAR(20) DEFAULT 'normal',
            INDEX `player_idx` (`player_identifier`),
            INDEX `location_idx` (`spawn_location`),
            INDEX `time_idx` (`spawn_time`),
            INDEX `crew_idx` (`crew_id`)
        )
    ]])
    
    -- Spawn preferences table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_spawn_preferences` (
            `player_identifier` VARCHAR(60) PRIMARY KEY,
            `preferred_categories` JSON,
            `avoided_locations` JSON,
            `spawn_strategy` ENUM('safe', 'balanced', 'aggressive') DEFAULT 'balanced',
            `crew_coordination` BOOLEAN DEFAULT TRUE,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX `strategy_idx` (`spawn_strategy`)
        )
    ]])
    
    -- Location performance table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_location_performance` (
            `location_id` VARCHAR(100) PRIMARY KEY,
            `total_spawns` INT DEFAULT 0,
            `successful_spawns` INT DEFAULT 0,
            `average_survival_time` FLOAT DEFAULT 0.0,
            `last_updated` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `performance_score` FLOAT DEFAULT 0.0,
            INDEX `performance_idx` (`performance_score`),
            INDEX `updated_idx` (`last_updated`)
        )
    ]])
end

-- Strategy Pattern for spawn location selection
WarzoneSpawnManager.SpawnStrategies = {
    -- Safe strategy - prioritize safety over tactical advantage
    safe = function(player, availableLocations)
        local safeLocations = {}
        
        for _, location in ipairs(availableLocations) do
            if location.riskLevel <= 2 and WarzoneSpawnManager.IsSafeLocation(location, player) then
                location.strategyScore = (3 - location.riskLevel) * 0.4 + 
                                       WarzoneSpawnManager.GetSafetyScore(location, player) * 0.6
                table.insert(safeLocations, location)
            end
        end
        
        table.sort(safeLocations, function(a, b) return a.strategyScore > b.strategyScore end)
        return safeLocations[1]
    end,
    
    -- Balanced strategy - balance safety and tactical value
    balanced = function(player, availableLocations)
        local scoredLocations = {}
        
        for _, location in ipairs(availableLocations) do
            local safetyScore = WarzoneSpawnManager.GetSafetyScore(location, player)
            local tacticalScore = WarzoneSpawnManager.GetTacticalScore(location, player)
            local performanceScore = WarzoneSpawnManager.GetLocationPerformance(location.id)
            
            location.strategyScore = safetyScore * 0.4 + tacticalScore * 0.4 + performanceScore * 0.2
            table.insert(scoredLocations, location)
        end
        
        table.sort(scoredLocations, function(a, b) return a.strategyScore > b.strategyScore end)
        return scoredLocations[1]
    end,
    
    -- Aggressive strategy - prioritize tactical advantage and high-risk/reward
    aggressive = function(player, availableLocations)
        local aggressiveLocations = {}
        
        for _, location in ipairs(availableLocations) do
            if location.riskLevel >= 3 and WarzoneSpawnManager.CanAccessLocation(location, player) then
                local tacticalScore = WarzoneSpawnManager.GetTacticalScore(location, player)
                local riskReward = location.riskLevel * 0.2
                
                location.strategyScore = tacticalScore * 0.7 + riskReward * 0.3
                table.insert(aggressiveLocations, location)
            end
        end
        
        -- Fallback to balanced if no aggressive locations available
        if #aggressiveLocations == 0 then
            return WarzoneSpawnManager.SpawnStrategies.balanced(player, availableLocations)
        end
        
        table.sort(aggressiveLocations, function(a, b) return a.strategyScore > b.strategyScore end)
        return aggressiveLocations[1]
    end
}

-- Factory method for creating spawn requests
function WarzoneSpawnManager.CreateSpawnRequest(source, requestData)
    local player = WarzonePlayer.GetBySource(source)
    if not player then
        return {success = false, error = "Player not found"}
    end
    
    local spawnRequest = {
        playerId = source,
        playerData = player,
        requestTime = os.time(),
        preferences = requestData or {},
        priority = WarzoneSpawnManager.GetPlayerPriority(player),
        attempts = 0,
        maxAttempts = 3
    }
    
    return spawnRequest
end

-- Queue system for spawn conflicts
function WarzoneSpawnManager.ProcessSpawnRequest(source, locationId, spawnStrategy)
    local spawnRequest = WarzoneSpawnManager.CreateSpawnRequest(source, {
        locationId = locationId,
        strategy = spawnStrategy or "balanced"
    })
    
    if not spawnRequest.success == false then
        return spawnRequest
    end
    
    -- Add to queue with priority
    WarzoneSpawnManager.AddToQueue(spawnRequest)
    
    -- Process queue
    WarzoneSpawnManager.ProcessQueue()
    
    return {success = true, message = "Spawn request queued"}
end

-- Advanced queue system with priority
function WarzoneSpawnManager.AddToQueue(spawnRequest)
    table.insert(WarzoneSpawnManager.SpawnQueue, spawnRequest)
    
    -- Sort by priority (higher priority first)
    table.sort(WarzoneSpawnManager.SpawnQueue, function(a, b)
        return a.priority > b.priority
    end)
    
    -- Limit queue size
    local spawnConfig = WarzoneSpawnConfig.GetSpawn()
    local maxQueueSize = spawnConfig.spawn.queue.maxQueueSize or 10
    
    while #WarzoneSpawnManager.SpawnQueue > maxQueueSize do
        local removedRequest = table.remove(WarzoneSpawnManager.SpawnQueue)
        TriggerClientEvent('warzone_spawn:requestFailed', removedRequest.playerId, 'Queue full, please try again')
    end
end

-- Process queue with sophisticated algorithm
function WarzoneSpawnManager.ProcessQueue()
    Citizen.CreateThread(function()
        while #WarzoneSpawnManager.SpawnQueue > 0 do
            local request = table.remove(WarzoneSpawnManager.SpawnQueue, 1)
            
            -- Check if request is still valid
            if WarzoneSpawnManager.IsRequestValid(request) then
                local result = WarzoneSpawnManager.ExecuteSpawn(request)
                
                if not result.success and request.attempts < request.maxAttempts then
                    request.attempts = request.attempts + 1
                    -- Re-queue with lower priority
                    request.priority = request.priority - 1
                    WarzoneSpawnManager.AddToQueue(request)
                else
                    -- Notify client of result
                    TriggerClientEvent('warzone_spawn:spawnResult', request.playerId, result)
                end
            end
            
            Citizen.Wait(100) -- Prevent server overload
        end
    end)
end

-- Execute spawn with comprehensive validation
function WarzoneSpawnManager.ExecuteSpawn(spawnRequest)
    local config = WarzoneSpawnConfig.GetSpawn()
    local locations = WarzoneSpawnConfig.GetLocations()
    
    -- Get available locations
    local availableLocations = WarzoneSpawnManager.GetAvailableLocations(spawnRequest.playerData)
    
    if #availableLocations == 0 then
        return {success = false, error = "No available spawn locations"}
    end
    
    -- Apply spawn strategy
    local strategy = spawnRequest.preferences.strategy or "balanced"
    local selectedLocation = WarzoneSpawnManager.SpawnStrategies[strategy](spawnRequest.playerData, availableLocations)
    
    if not selectedLocation then
        return {success = false, error = "No suitable location found"}
    end
    
    -- Get optimal spawn point within location
    local spawnPoint = WarzoneSpawnManager.GetOptimalSpawnPoint(selectedLocation, spawnRequest.playerData)
    
    if not spawnPoint then
        return {success = false, error = "No safe spawn point available"}
    end
    
    -- Perform final safety check
    if not WarzoneSpawnManager.FinalSafetyCheck(spawnPoint, spawnRequest.playerData) then
        return {success = false, error = "Spawn point unsafe"}
    end
    
    -- Execute the spawn
    local success = WarzoneSpawnManager.TeleportPlayer(spawnRequest.playerId, spawnPoint, selectedLocation)
    
    if success then
        -- Record analytics
        WarzoneSpawnManager.RecordSpawnAnalytics(spawnRequest, selectedLocation, spawnPoint)
        
        return {
            success = true, 
            location = selectedLocation,
            spawnPoint = spawnPoint,
            message = string.format("Spawned at %s", selectedLocation.name)
        }
    else
        return {success = false, error = "Teleportation failed"}
    end
end

-- Comprehensive safety scoring algorithm
function WarzoneSpawnManager.GetSafetyScore(location, player)
    local score = 0.0
    local config = WarzoneSpawnConfig.GetSpawn()
    
    -- Base safety from location risk level
    score = score + (5 - location.riskLevel) * 0.2
    
    -- Check nearby enemies
    local nearbyEnemies = WarzoneSpawnManager.GetNearbyEnemies(location.coords, config.spawn.safety.minDistanceFromEnemies)
    score = score + math.max(0, (1 - (#nearbyEnemies / 5))) * 0.3
    
    -- Check recent combat activity
    local recentCombat = WarzoneSpawnManager.GetRecentCombatActivity(location.coords, config.spawn.safety.minDistanceFromCombat)
    score = score + (1 - recentCombat) * 0.2
    
    -- Check zone activity if zones enabled
    if GetResourceState('warzone_zones') == 'started' then
        local zone, zoneType = exports.warzone_zones:GetZoneAtCoords(location.coords)
        if zoneType == 'green' then
            score = score + 0.3
        elseif zone then
            local activity = exports.warzone_zones:GetZoneActivity(zone.name)
            if activity == 'red' then
                score = score - 0.2
            elseif activity == 'yellow' then
                score = score - 0.1
            end
        end
    end
    
    return math.max(0, math.min(1, score))
end

-- Tactical value calculation
function WarzoneSpawnManager.GetTacticalScore(location, player)
    local score = 0.0
    
    -- Role compatibility
    if location.recommendedRoles then
        for _, role in ipairs(location.recommendedRoles) do
            if role == player.role then
                score = score + 0.3
                break
            end
        end
    end
    
    -- Crew coordination bonus
    if WarzoneSpawnManager.HasCrewNearby(location, player) then
        score = score + 0.25
    end
    
    -- Strategic advantages
    if location.advantages then
        score = score + (#location.advantages * 0.05)
    end
    
    -- Location capacity utilization (prefer less crowded)
    local currentUsage = WarzoneSpawnManager.LocationUsage[location.id] or 0
    local capacityRatio = currentUsage / (location.maxCapacity or 8)
    score = score + math.max(0, (1 - capacityRatio)) * 0.2
    
    return math.max(0, math.min(1, score))
end

-- Performance-based location scoring
function WarzoneSpawnManager.GetLocationPerformance(locationId)
    local performance = MySQL.single.await('SELECT performance_score FROM warzone_location_performance WHERE location_id = ?', {locationId})
    return performance and performance.performance_score or 0.5
end

-- Observer pattern for real-time monitoring
function WarzoneSpawnManager.StartMonitoring()
    -- Monitor location usage
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(30000) -- Every 30 seconds
            WarzoneSpawnManager.UpdateLocationUsage()
            WarzoneSpawnManager.UpdateLocationPerformance()
        end
    end)
    
    -- Monitor queue health
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(5000) -- Every 5 seconds
            WarzoneSpawnManager.CleanupExpiredRequests()
        end
    end)
end

-- Update location usage tracking
function WarzoneSpawnManager.UpdateLocationUsage()
    local locations = WarzoneSpawnConfig.GetLocations()
    
    for categoryName, category in pairs(locations.categories) do
        for locationId, location in pairs(category.locations) do
            local playersNearby = 0
            
            for _, playerId in ipairs(GetPlayers()) do
                local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(playerId)))
                local distance = #(vector3(location.coords.x, location.coords.y, location.coords.z) - playerCoords)
                
                if distance <= (location.safetyRadius or 30.0) then
                    playersNearby = playersNearby + 1
                end
            end
            
            WarzoneSpawnManager.LocationUsage[locationId] = playersNearby
        end
    end
end

-- Adaptive algorithm for location performance
function WarzoneSpawnManager.UpdateLocationPerformance()
    local recentSpawns = MySQL.query.await([[
        SELECT spawn_location, 
               COUNT(*) as total_spawns,
               AVG(survival_time) as avg_survival,
               AVG(success_rating) as avg_rating
        FROM warzone_spawn_analytics 
        WHERE spawn_time > DATE_SUB(NOW(), INTERVAL 1 HOUR)
        GROUP BY spawn_location
    ]])
    
    for _, data in ipairs(recentSpawns) do
        local performanceScore = (data.avg_survival / 300) * 0.4 + -- Normalize survival time
                                (data.avg_rating) * 0.6 -- Weight success rating higher
        
        MySQL.query('INSERT INTO warzone_location_performance (location_id, total_spawns, successful_spawns, average_survival_time, performance_score) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE total_spawns = total_spawns + VALUES(total_spawns), average_survival_time = VALUES(average_survival_time), performance_score = VALUES(performance_score)', 
           {data.spawn_location, data.total_spawns, math.floor(data.total_spawns * data.avg_rating), data.avg_survival, performanceScore})
   end
end

-- Advanced safety checking with multiple layers
function WarzoneSpawnManager.FinalSafetyCheck(spawnPoint, player)
   local config = WarzoneSpawnConfig.GetSpawn()
   local coords = vector3(spawnPoint.x, spawnPoint.y, spawnPoint.z)
   
   -- Layer 1: Basic distance checks
   local nearbyPlayers = WarzoneSpawnManager.GetPlayersInRadius(coords, config.spawn.safety.safetyCheckRadius)
   if #nearbyPlayers > config.spawn.safety.maxPlayersNearby then
       return false
   end
   
   -- Layer 2: Enemy proximity check
   local nearbyEnemies = WarzoneSpawnManager.GetNearbyEnemies(coords, config.spawn.safety.minDistanceFromEnemies)
   if #nearbyEnemies > 0 then
       return false
   end
   
   -- Layer 3: Vehicle collision check
   local nearbyVehicles = WarzoneSpawnManager.GetVehiclesInRadius(coords, config.spawn.safety.vehicleCheckRadius)
   if #nearbyVehicles > 0 then
       return false
   end
   
   -- Layer 4: Height validation
   local groundZ = WarzoneSpawnManager.GetGroundZ(coords.x, coords.y, coords.z)
   if math.abs(coords.z - groundZ) > 10.0 then
       return false
   end
   
   -- Layer 5: Green zone validation if enabled
   if config.spawn.safety.greenZoneOnly then
       if GetResourceState('warzone_zones') == 'started' then
           local zone, zoneType = exports.warzone_zones:GetZoneAtCoords(coords)
           if zoneType ~= 'green' then
               return false
           end
       end
   end
   
   return true
end

-- Intelligent spawn point selection within location
function WarzoneSpawnManager.GetOptimalSpawnPoint(location, player)
   local config = WarzoneSpawnConfig.GetSpawn()
   local spawnPoints = location.spawnPoints or {}
   
   if #spawnPoints == 0 then
       -- Generate dynamic spawn point if none configured
       return WarzoneSpawnManager.GenerateDynamicSpawnPoint(location, player)
   end
   
   -- Score each spawn point
   local scoredPoints = {}
   for _, point in ipairs(spawnPoints) do
       local score = WarzoneSpawnManager.ScoreSpawnPoint(point, player, location)
       if score > 0 then
           point.score = score
           table.insert(scoredPoints, point)
       end
   end
   
   if #scoredPoints == 0 then
       return nil
   end
   
   -- Sort by score and return best
   table.sort(scoredPoints, function(a, b) return a.score > b.score end)
   return scoredPoints[1]
end

-- Score individual spawn points
function WarzoneSpawnManager.ScoreSpawnPoint(point, player, location)
   local score = 1.0
   local coords = vector3(point.x, point.y, point.z)
   
   -- Penalize crowded points
   local nearbyPlayers = WarzoneSpawnManager.GetPlayersInRadius(coords, 15.0)
   score = score - (#nearbyPlayers * 0.2)
   
   -- Bonus for crew proximity if crew coordination enabled
   if player.crew_id then
       local crewNearby = WarzoneSpawnManager.GetCrewMembersInRadius(coords, 50.0, player.crew_id)
       if #crewNearby > 0 and #crewNearby <= 2 then
           score = score + 0.3
       end
   end
   
   -- Penalize recent usage
   local recentUsage = WarzoneSpawnManager.GetRecentPointUsage(point)
   score = score - (recentUsage * 0.1)
   
   return math.max(0, score)
end

-- Dynamic spawn point generation for emergencies
function WarzoneSpawnManager.GenerateDynamicSpawnPoint(location, player)
   local baseCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
   local radius = location.safetyRadius or 30.0
   local attempts = 0
   local maxAttempts = 10
   
   while attempts < maxAttempts do
       attempts = attempts + 1
       
       -- Generate random point within radius
       local angle = math.random() * 2 * math.pi
       local distance = math.random() * radius * 0.8 -- Keep within 80% of radius
       
       local x = baseCoords.x + math.cos(angle) * distance
       local y = baseCoords.y + math.sin(angle) * distance
       local z = WarzoneSpawnManager.GetGroundZ(x, y, baseCoords.z + 10.0)
       
       local dynamicPoint = {
           x = x,
           y = y,
           z = z + 1.0, -- Slight elevation to avoid clipping
           w = math.random(0, 360)
       }
       
       -- Validate dynamic point
       if WarzoneSpawnManager.FinalSafetyCheck(dynamicPoint, player) then
           return dynamicPoint
       end
   end
   
   return nil -- Failed to generate safe point
end

-- Execute player teleportation with effects
function WarzoneSpawnManager.TeleportPlayer(source, spawnPoint, location)
   local playerPed = GetPlayerPed(source)
   if playerPed == 0 then return false end
   
   -- Pre-teleport effects
   TriggerClientEvent('warzone_spawn:preTeleport', source, location)
   
   -- Teleport player
   SetEntityCoords(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z)
   SetEntityHeading(playerPed, spawnPoint.w or 0.0)
   
   -- Apply spawn protection
   local config = WarzoneSpawnConfig.GetSpawn()
   local protectionTime = config.spawn.general.spawnProtectionTime or 15
   
   TriggerEvent('warzone_spawn:giveSpawnProtection', source, protectionTime)
   
   -- Post-teleport effects
   TriggerClientEvent('warzone_spawn:postTeleport', source, spawnPoint, location)
   
   -- Update location usage
   WarzoneSpawnManager.LocationUsage[location.id] = (WarzoneSpawnManager.LocationUsage[location.id] or 0) + 1
   
   return true
end

-- Analytics and learning system
function WarzoneSpawnManager.RecordSpawnAnalytics(spawnRequest, location, spawnPoint)
   local player = spawnRequest.playerData
   
   MySQL.insert([[
       INSERT INTO warzone_spawn_analytics 
       (player_identifier, spawn_location, spawn_category, player_level, crew_id, zone_activity) 
       VALUES (?, ?, ?, ?, ?, ?)
   ]], {
       player.identifier,
       location.id,
       location.category,
       player.level or 1,
       player.crew_id,
       WarzoneSpawnManager.GetCurrentZoneActivity(spawnPoint)
   })
end

-- Utility functions
function WarzoneSpawnManager.GetPlayersInRadius(coords, radius)
   local players = {}
   for _, playerId in ipairs(GetPlayers()) do
       local playerCoords = GetEntityCoords(GetPlayerPed(tonumber(playerId)))
       if #(coords - playerCoords) <= radius then
           table.insert(players, tonumber(playerId))
       end
   end
   return players
end

function WarzoneSpawnManager.GetNearbyEnemies(coords, radius)
   local enemies = {}
   local players = WarzoneSpawnManager.GetPlayersInRadius(coords, radius)
   
   for _, playerId in ipairs(players) do
       -- Implementation depends on crew system
       -- For now, consider all players as potential enemies
       table.insert(enemies, playerId)
   end
   
   return enemies
end

function WarzoneSpawnManager.GetVehiclesInRadius(coords, radius)
   local vehicles = {}
   local entities = GetAllVehicles()
   
   for _, vehicle in ipairs(entities) do
       local vehicleCoords = GetEntityCoords(vehicle)
       if #(coords - vehicleCoords) <= radius then
           table.insert(vehicles, vehicle)
       end
   end
   
   return vehicles
end

function WarzoneSpawnManager.GetGroundZ(x, y, z)
   local found, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
   return found and groundZ or z
end

function WarzoneSpawnManager.GetPlayerPriority(player)
   local config = WarzoneSpawnConfig.GetSpawn()
   local priorities = config.spawn.queue.prioritySystem
   
   -- Crew members get higher priority
   if player.crew_id then
       return priorities.crewMembers or 3
   end
   
   -- Premium players (could be based on donations, VIP status, etc.)
   if player.premium then
       return priorities.premiumPlayers or 2
   end
   
   return priorities.regularPlayers or 1
end

function WarzoneSpawnManager.IsRequestValid(request)
   local currentTime = os.time()
   local config = WarzoneSpawnConfig.GetSpawn()
   local timeout = config.spawn.queue.timeoutSeconds or 30
   
   return (currentTime - request.requestTime) <= timeout
end

function WarzoneSpawnManager.CleanupExpiredRequests()
   local currentTime = os.time()
   local config = WarzoneSpawnConfig.GetSpawn()
   local timeout = config.spawn.queue.timeoutSeconds or 30
   
   for i = #WarzoneSpawnManager.SpawnQueue, 1, -1 do
       local request = WarzoneSpawnManager.SpawnQueue[i]
       if (currentTime - request.requestTime) > timeout then
           table.remove(WarzoneSpawnManager.SpawnQueue, i)
           TriggerClientEvent('warzone_spawn:requestExpired', request.playerId)
       end
   end
end

-- Load player preferences and analytics
function WarzoneSpawnManager.LoadAnalytics()
   -- Load recent location performance
   local locationPerf = MySQL.query.await('SELECT * FROM warzone_location_performance')
   for _, perf in ipairs(locationPerf) do
       -- Cache performance data for quick access
       WarzoneSpawnManager.LocationPerformance = WarzoneSpawnManager.LocationPerformance or {}
       WarzoneSpawnManager.LocationPerformance[perf.location_id] = perf.performance_score
   end
   
   print("^2[WARZONE SPAWN] Analytics data loaded^7")
end

-- Events
RegisterNetEvent('warzone_spawn:requestSpawn')
AddEventHandler('warzone_spawn:requestSpawn', function(locationId, strategy)
   local result = WarzoneSpawnManager.ProcessSpawnRequest(source, locationId, strategy)
   TriggerClientEvent('warzone_spawn:requestResult', source, result)
end)

RegisterNetEvent('warzone_spawn:updatePreferences')
AddEventHandler('warzone_spawn:updatePreferences', function(preferences)
   local player = WarzonePlayer.GetBySource(source)
   if not player then return end
   
   MySQL.insert([[
       INSERT INTO warzone_spawn_preferences 
       (player_identifier, preferred_categories, avoided_locations, spawn_strategy, crew_coordination) 
       VALUES (?, ?, ?, ?, ?) 
       ON DUPLICATE KEY UPDATE 
       preferred_categories = VALUES(preferred_categories),
       avoided_locations = VALUES(avoided_locations),
       spawn_strategy = VALUES(spawn_strategy),
       crew_coordination = VALUES(crew_coordination)
   ]], {
       player.identifier,
       json.encode(preferences.categories or {}),
       json.encode(preferences.avoided or {}),
       preferences.strategy or 'balanced',
       preferences.crewCoordination or true
   })
end)

-- Player spawn protection system
RegisterNetEvent('warzone_spawn:giveSpawnProtection')
AddEventHandler('warzone_spawn:giveSpawnProtection', function(playerId, duration)
   local playerPed = GetPlayerPed(playerId)
   if playerPed == 0 then return end
   
   -- Make player invulnerable
   SetEntityInvincible(playerPed, true)
   
   -- Visual effect for spawn protection
   TriggerClientEvent('warzone_spawn:spawnProtectionActive', playerId, duration)
   
   -- Remove protection after duration
   Citizen.SetTimeout(duration * 1000, function()
       if GetPlayerPed(playerId) ~= 0 then
           SetEntityInvincible(GetPlayerPed(playerId), false)
           TriggerClientEvent('warzone_spawn:spawnProtectionExpired', playerId)
       end
   end)
end)

-- Initialize when core is ready
Citizen.CreateThread(function()
   while GetResourceState('warzone_core') ~= 'started' do
       Citizen.Wait(100)
   end
   
   WarzoneSpawnManager.Init()
end)

-- Export functions for other resources
exports('ProcessSpawnRequest', WarzoneSpawnManager.ProcessSpawnRequest)
exports('GetAvailableLocations', WarzoneSpawnManager.GetAvailableLocations)
exports('GetLocationUsage', function() return WarzoneSpawnManager.LocationUsage end)
exports('TeleportPlayer', WarzoneSpawnManager.TeleportPlayer)