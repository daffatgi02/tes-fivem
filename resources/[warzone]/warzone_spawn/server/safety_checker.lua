-- resources/[warzone]/warzone_spawn/server/safety_checker.lua

WarzoneSpawnSafety = {}
local recentSpawns = {}
local combatPlayers = {}
local blockedAreas = {}

-- Initialize safety checker
function WarzoneSpawnSafety.Init()
    print("^2[WARZONE SPAWN] Safety checker initialized^7")
    
    -- Clean up old spawn records every 5 minutes
    Citizen.CreateThread(function()
        while true do
            WarzoneSpawnSafety.CleanupOldRecords()
            Citizen.Wait(300000) -- 5 minutes
        end
    end)
    
    -- Monitor combat status
    Citizen.CreateThread(function()
        while true do
            WarzoneSpawnSafety.UpdateCombatStatus()
            Citizen.Wait(5000) -- Check every 5 seconds
        end
    end)
end

-- Comprehensive safety check for spawn location
function WarzoneSpawnSafety.IsLocationSafe(coords, playerSource, ignorePlayers)
    local config = WarzoneSpawnConfig.GetSpawn()
    ignorePlayers = ignorePlayers or {}
    
    -- Convert to vector3 if needed
    if type(coords) == "table" then
        coords = vector3(coords.x or coords[1], coords.y or coords[2], coords.z or coords[3])
    end
    
    -- Safety check layers
    local checks = {
        playerProximity = WarzoneSpawnSafety.CheckPlayerProximity(coords, playerSource, ignorePlayers),
        enemyProximity = WarzoneSpawnSafety.CheckEnemyProximity(coords, playerSource),
        vehicleCollision = WarzoneSpawnSafety.CheckVehicleCollision(coords),
        combatActivity = WarzoneSpawnSafety.CheckCombatActivity(coords),
        groundHeight = WarzoneSpawnSafety.CheckGroundHeight(coords),
        zoneRestrictions = WarzoneSpawnSafety.CheckZoneRestrictions(coords),
        recentActivity = WarzoneSpawnSafety.CheckRecentSpawnActivity(coords),
        blockedArea = WarzoneSpawnSafety.CheckBlockedArea(coords)
    }
    
    -- Log detailed check results
    local failedChecks = {}
    for checkName, result in pairs(checks) do
        if not result.safe then
            table.insert(failedChecks, {
                check = checkName,
                reason = result.reason,
                severity = result.severity or 'medium'
            })
        end
    end
    
    local isSafe = #failedChecks == 0
    
    -- Log safety check
    if not isSafe then
        print(string.format("^3[SAFETY] Location safety check failed at %s for player %s^7", 
              coords, playerSource))
        for _, failure in ipairs(failedChecks) do
            print(string.format("^3  - %s: %s (severity: %s)^7", 
                  failure.check, failure.reason, failure.severity))
        end
    end
    
    return {
        safe = isSafe,
        failedChecks = failedChecks,
        coords = coords,
        timestamp = GetGameTimer()
    }
end

-- Check player proximity
function WarzoneSpawnSafety.CheckPlayerProximity(coords, playerSource, ignorePlayers)
    local config = WarzoneSpawnConfig.GetSpawn()
    local players = GetPlayers()
    local dangerousPlayers = {}
    
    for _, playerId in ipairs(players) do
        playerId = tonumber(playerId)
        
        -- Skip self and ignored players
        if playerId ~= playerSource and not ignorePlayers[playerId] then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(coords - playerCoords)
                
                if distance < config.spawn.safety.safetyCheckRadius then
                    table.insert(dangerousPlayers, {
                        id = playerId,
                        distance = distance,
                        coords = playerCoords
                    })
                end
            end
        end
    end
    
    if #dangerousPlayers > config.spawn.safety.maxPlayersNearby then
        return {
            safe = false,
            reason = string.format("Too many players nearby (%d/%d)", 
                    #dangerousPlayers, config.spawn.safety.maxPlayersNearby),
            severity = 'high',
            players = dangerousPlayers
        }
    elseif #dangerousPlayers > 0 then
        return {
            safe = false,
            reason = string.format("Players too close (%d within %dm)", 
                    #dangerousPlayers, config.spawn.safety.safetyCheckRadius),
            severity = 'medium',
            players = dangerousPlayers
        }
    end
    
    return { safe = true }
end

-- Check enemy proximity (crew-based)
function WarzoneSpawnSafety.CheckEnemyProximity(coords, playerSource)
    local config = WarzoneSpawnConfig.GetSpawn()
    
    -- Get player's crew if crew system is available
    local playerCrew = nil
    if GetResourceState('warzone_crew') == 'started' then
        playerCrew = exports.warzone_crew:GetPlayerCrew(playerSource)
    end
    
    local enemies = {}
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        playerId = tonumber(playerId)
        
        if playerId ~= playerSource then
            local playerPed = GetPlayerPed(playerId)
            if DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(coords - playerCoords)
                
                if distance < config.spawn.safety.minDistanceFromEnemies then
                    -- Check if this player is an enemy
                    local isEnemy = true
                    
                    if playerCrew and GetResourceState('warzone_crew') == 'started' then
                        local otherCrew = exports.warzone_crew:GetPlayerCrew(playerId)
                        if otherCrew and otherCrew.id == playerCrew.id then
                            isEnemy = false -- Same crew, not an enemy
                        end
                    end
                    
                    -- Check combat status
                    if isEnemy and combatPlayers[playerId] then
                        table.insert(enemies, {
                            id = playerId,
                            distance = distance,
                            inCombat = true
                        })
                    elseif isEnemy then
                        table.insert(enemies, {
                            id = playerId,
                            distance = distance,
                            inCombat = false
                        })
                    end
                end
            end
        end
    end
    
    if #enemies > 0 then
        local combatEnemies = 0
        for _, enemy in ipairs(enemies) do
            if enemy.inCombat then
                combatEnemies = combatEnemies + 1
            end
        end
        
        local severity = combatEnemies > 0 and 'high' or 'medium'
        return {
            safe = false,
            reason = string.format("Enemies nearby (%d total, %d in combat)", 
                    #enemies, combatEnemies),
            severity = severity,
            enemies = enemies
        }
    end
    
    return { safe = true }
end

-- Check vehicle collision
function WarzoneSpawnSafety.CheckVehicleCollision(coords)
    local config = WarzoneSpawnConfig.GetSpawn()
    local vehicles = {}
    
    -- Get all vehicles in area
    for vehicle in EnumerateVehicles() do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehicleCoords)
            
            if distance < config.spawn.safety.vehicleCheckRadius then
                table.insert(vehicles, {
                    handle = vehicle,
                    distance = distance,
                    coords = vehicleCoords,
                    model = GetEntityModel(vehicle)
                })
            end
        end
    end
    
    if #vehicles > 0 then
        return {
            safe = false,
            reason = string.format("Vehicles too close (%d within %dm)", 
                    #vehicles, config.spawn.safety.vehicleCheckRadius),
            severity = 'medium',
            vehicles = vehicles
        }
    end
    
    return { safe = true }
end

-- Check recent combat activity
function WarzoneSpawnSafety.CheckCombatActivity(coords)
    local config = WarzoneSpawnConfig.GetSpawn()
    local recentCombat = {}
    
    -- Check if combat system provides activity data
    if GetResourceState('warzone_combat') == 'started' then
        -- You can implement this based on your combat system
        local combatData = exports.warzone_combat:GetRecentActivity(coords, config.spawn.safety.minDistanceFromCombat)
        if combatData and combatData.recentActivity > 0 then
            return {
                safe = false,
                reason = string.format("Recent combat activity detected (%d events)", combatData.recentActivity),
                severity = 'high',
                combatData = combatData
            }
        end
    end
    
    return { safe = true }
end

-- Check ground height validity
function WarzoneSpawnSafety.CheckGroundHeight(coords)
    local groundZ, hitSomething = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 50.0, false)
    
    if not hitSomething then
        return {
            safe = false,
            reason = "Cannot determine ground height",
            severity = 'high'
        }
    end
    
    local heightDifference = math.abs(coords.z - groundZ)
    
    if heightDifference > 10.0 then
        return {
            safe = false,
            reason = string.format("Invalid height (%.2fm from ground)", heightDifference),
            severity = 'high',
            groundZ = groundZ,
            heightDifference = heightDifference
        }
    end
    
    return { safe = true, groundZ = groundZ }
end

-- Check zone restrictions
function WarzoneSpawnSafety.CheckZoneRestrictions(coords)
    local config = WarzoneSpawnConfig.GetSpawn()
    
    if config.spawn.safety.greenZoneOnly and GetResourceState('warzone_zones') == 'started' then
        local zone, zoneType = exports.warzone_zones:GetZoneAtCoords(coords)
        
        if zoneType ~= 'green' then
            return {
                safe = false,
                reason = string.format("Not in green zone (current: %s)", zoneType or 'unknown'),
                severity = 'high',
                zone = zone,
                zoneType = zoneType
            }
        end
    end
    
    return { safe = true }
end

-- Check recent spawn activity
function WarzoneSpawnSafety.CheckRecentSpawnActivity(coords)
    local recentSpawnsNearby = 0
    local currentTime = GetGameTimer()
    
    for _, spawnData in pairs(recentSpawns) do
        if currentTime - spawnData.timestamp < 30000 then -- 30 seconds
            local distance = #(coords - spawnData.coords)
            if distance < 50.0 then -- 50m radius
                recentSpawnsNearby = recentSpawnsNearby + 1
            end
        end
    end
    
    if recentSpawnsNearby > 3 then
        return {
            safe = false,
            reason = string.format("Too many recent spawns nearby (%d in last 30s)", recentSpawnsNearby),
            severity = 'medium'
        }
    end
    
    return { safe = true }
end

-- Check if area is manually blocked
function WarzoneSpawnSafety.CheckBlockedArea(coords)
    for _, blockedArea in pairs(blockedAreas) do
        local distance = #(coords - vector3(blockedArea.x, blockedArea.y, blockedArea.z))
        if distance < blockedArea.radius then
            return {
                safe = false,
                reason = string.format("Area manually blocked: %s", blockedArea.reason or "Unknown"),
                severity = 'high',
                blockedArea = blockedArea
            }
        end
    end
    
    return { safe = true }
end

-- Record successful spawn
function WarzoneSpawnSafety.RecordSpawn(coords, playerSource)
    local spawnId = string.format("%s_%d", playerSource, GetGameTimer())
    recentSpawns[spawnId] = {
        coords = coords,
        player = playerSource,
        timestamp = GetGameTimer()
    }
end

-- Update combat status for all players
function WarzoneSpawnSafety.UpdateCombatStatus()
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        playerId = tonumber(playerId)
        local playerPed = GetPlayerPed(playerId)
        
        if DoesEntityExist(playerPed) then
            local inCombat = false
            
            -- Check if player has weapon drawn
            local weaponHash = GetSelectedPedWeapon(playerPed)
            if weaponHash ~= GetHashKey("WEAPON_UNARMED") then
                inCombat = true
            end
            
            -- Check if player is shooting
            if IsPedShooting(playerPed) then
                inCombat = true
            end
            
            -- Check if player recently took damage
            if GetEntityHealth(playerPed) < 200 then
                inCombat = true
            end
            
            combatPlayers[playerId] = inCombat
        end
    end
end

-- Manually block an area
function WarzoneSpawnSafety.BlockArea(coords, radius, reason, duration)
    local blockId = string.format("block_%d", GetGameTimer())
    blockedAreas[blockId] = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        radius = radius,
        reason = reason,
        timestamp = GetGameTimer(),
        duration = duration
    }
    
    -- Auto-remove after duration
    if duration then
        Citizen.SetTimeout(duration * 1000, function()
            blockedAreas[blockId] = nil
        end)
    end
    
    return blockId
end

-- Clean up old records
function WarzoneSpawnSafety.CleanupOldRecords()
    local currentTime = GetGameTimer()
    
    -- Clean up old spawn records (older than 5 minutes)
    for spawnId, spawnData in pairs(recentSpawns) do
        if currentTime - spawnData.timestamp > 300000 then
            recentSpawns[spawnId] = nil
        end
    end
    
    -- Clean up expired blocked areas
    for blockId, blockData in pairs(blockedAreas) do
        if blockData.duration and currentTime - blockData.timestamp > (blockData.duration * 1000) then
            blockedAreas[blockId] = nil
        end
    end
end

-- Export functions
exports('IsLocationSafe', WarzoneSpawnSafety.IsLocationSafe)
exports('RecordSpawn', WarzoneSpawnSafety.RecordSpawn)
exports('BlockArea', WarzoneSpawnSafety.BlockArea)
exports('CheckPlayerProximity', WarzoneSpawnSafety.CheckPlayerProximity)

-- Utility function to enumerate vehicles
function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, vehicle = FindFirstVehicle()
        if not vehicle or vehicle == -1 then return end
        
        local success
        repeat
            coroutine.yield(vehicle)
            success, vehicle = FindNextVehicle(handle)
        until not success
        
        EndFindVehicle(handle)
    end)
end

-- Initialize when resource starts
Citizen.CreateThread(function()
    WarzoneSpawnSafety.Init()
end)