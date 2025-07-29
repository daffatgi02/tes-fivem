-- resources/[warzone]/warzone_spawn/server/queue_system.lua

WarzoneSpawnQueue = {}
local spawnQueues = {}
local queueTimers = {}
local queuePriorities = {}

-- Initialize queue system
function WarzoneSpawnQueue.Init()
    print("^2[WARZONE SPAWN] Queue system initialized^7")
    
    -- Clear any existing queues
    spawnQueues = {}
    queueTimers = {}
    queuePriorities = {}
    
    -- Start queue processing thread
    Citizen.CreateThread(function()
        while true do
            WarzoneSpawnQueue.ProcessQueues()
            Citizen.Wait(1000) -- Process every second
        end
    end)
end

-- Add player to spawn queue
function WarzoneSpawnQueue.AddToQueue(source, locationId, priority)
    local config = WarzoneSpawnConfig.GetSpawn()
    priority = priority or 1
    
    -- Remove player from any existing queue first
    WarzoneSpawnQueue.RemoveFromQueue(source)
    
    -- Check queue size limits
    if not spawnQueues[locationId] then
        spawnQueues[locationId] = {}
    end
    
    if #spawnQueues[locationId] >= config.spawn.queue.maxQueueSize then
        TriggerClientEvent('warzone_spawn:queueFull', source)
        return false
    end
    
    -- Add to queue with priority
    local queueEntry = {
        source = source,
        timestamp = GetGameTimer(),
        priority = priority,
        retryAttempts = 0
    }
    
    table.insert(spawnQueues[locationId], queueEntry)
    queuePriorities[source] = priority
    
    -- Sort queue by priority (higher priority first)
    table.sort(spawnQueues[locationId], function(a, b)
        if a.priority == b.priority then
            return a.timestamp < b.timestamp -- FIFO for same priority
        end
        return a.priority > b.priority
    end)
    
    -- Set timeout timer
    queueTimers[source] = GetGameTimer() + (config.spawn.queue.timeoutSeconds * 1000)
    
    -- Notify client
    local position = WarzoneSpawnQueue.GetQueuePosition(source, locationId)
    TriggerClientEvent('warzone_spawn:queueJoined', source, {
        locationId = locationId,
        position = position,
        queueSize = #spawnQueues[locationId],
        estimatedWait = position * 2 -- 2 seconds per position estimate
    })
    
    print(string.format("^3[QUEUE] Player %s added to queue for location %s (Priority: %d, Position: %d)^7", 
          source, locationId, priority, position))
    
    return true
end

-- Remove player from queue
function WarzoneSpawnQueue.RemoveFromQueue(source)
    for locationId, queue in pairs(spawnQueues) do
        for i = #queue, 1, -1 do
            if queue[i].source == source then
                table.remove(queue, i)
                break
            end
        end
    end
    
    queueTimers[source] = nil
    queuePriorities[source] = nil
end

-- Get player's position in queue
function WarzoneSpawnQueue.GetQueuePosition(source, locationId)
    if not spawnQueues[locationId] then return 0 end
    
    for i, entry in ipairs(spawnQueues[locationId]) do
        if entry.source == source then
            return i
        end
    end
    return 0
end

-- Process all queues
function WarzoneSpawnQueue.ProcessQueues()
    local config = WarzoneSpawnConfig.GetSpawn()
    local currentTime = GetGameTimer()
    
    for locationId, queue in pairs(spawnQueues) do
        if #queue > 0 then
            -- Process timeout removals
            for i = #queue, 1, -1 do
                local entry = queue[i]
                
                -- Check timeout
                if queueTimers[entry.source] and currentTime > queueTimers[entry.source] then
                    TriggerClientEvent('warzone_spawn:queueTimeout', entry.source)
                    table.remove(queue, i)
                    queueTimers[entry.source] = nil
                    queuePriorities[entry.source] = nil
                    print(string.format("^1[QUEUE] Player %s timed out in queue for location %s^7", 
                          entry.source, locationId))
                end
            end
            
            -- Try to process first player in queue
            if #queue > 0 then
                local firstEntry = queue[1]
                local success = WarzoneSpawnQueue.TryProcessSpawn(firstEntry, locationId)
                
                if success then
                    -- Remove from queue
                    table.remove(queue, 1)
                    queueTimers[firstEntry.source] = nil
                    queuePriorities[firstEntry.source] = nil
                    
                    -- Update positions for remaining players
                    WarzoneSpawnQueue.UpdateQueuePositions(locationId)
                elseif firstEntry.retryAttempts >= config.spawn.queue.retryAttempts then
                    -- Max retries reached, remove from queue
                    TriggerClientEvent('warzone_spawn:spawnFailed', firstEntry.source, {
                        reason = 'max_retries_reached'
                    })
                    table.remove(queue, 1)
                    queueTimers[firstEntry.source] = nil
                    queuePriorities[firstEntry.source] = nil
                else
                    -- Increment retry counter
                    firstEntry.retryAttempts = firstEntry.retryAttempts + 1
                end
            end
        end
    end
end

-- Try to process spawn for queued player
function WarzoneSpawnQueue.TryProcessSpawn(queueEntry, locationId)
    local source = queueEntry.source
    
    -- Check if player is still connected
    if not GetPlayerPed(source) or GetPlayerPed(source) == 0 then
        return true -- Remove from queue
    end
    
    -- Try to spawn player
    local success = exports.warzone_spawn:TrySpawnPlayer(source, locationId, 'queue')
    
    if success then
        TriggerClientEvent('warzone_spawn:spawnSuccess', source, {
            locationId = locationId,
            method = 'queue'
        })
        print(string.format("^2[QUEUE] Player %s spawned successfully from queue at location %s^7", 
              source, locationId))
        return true
    end
    
    return false
end

-- Update queue positions for all players in location queue
function WarzoneSpawnQueue.UpdateQueuePositions(locationId)
    if not spawnQueues[locationId] then return end
    
    for i, entry in ipairs(spawnQueues[locationId]) do
        TriggerClientEvent('warzone_spawn:queueUpdated', entry.source, {
            locationId = locationId,
            position = i,
            queueSize = #spawnQueues[locationId],
            estimatedWait = i * 2
        })
    end
end

-- Get queue statistics
function WarzoneSpawnQueue.GetQueueStats(locationId)
    if locationId then
        return {
            queueSize = spawnQueues[locationId] and #spawnQueues[locationId] or 0,
            averageWait = spawnQueues[locationId] and #spawnQueues[locationId] * 2 or 0
        }
    else
        local totalQueued = 0
        local totalLocations = 0
        
        for _, queue in pairs(spawnQueues) do
            if #queue > 0 then
                totalQueued = totalQueued + #queue
                totalLocations = totalLocations + 1
            end
        end
        
        return {
            totalQueued = totalQueued,
            activeLocations = totalLocations
        }
    end
end

-- Get player priority
function WarzoneSpawnQueue.GetPlayerPriority(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return 1 end
    
    local config = WarzoneSpawnConfig.GetSpawn()
    
    -- Check crew member priority
    if GetResourceState('warzone_crew') == 'started' then
        local crewData = exports.warzone_crew:GetPlayerCrew(source)
        if crewData then
            return config.spawn.queue.prioritySystem.crewMembers or 3
        end
    end
    
    -- Check premium player (you can implement your own logic)
    if xPlayer.getGroup() == 'vip' or xPlayer.getGroup() == 'premium' then
        return config.spawn.queue.prioritySystem.premiumPlayers or 2
    end
    
    return config.spawn.queue.prioritySystem.regularPlayers or 1
end

-- Export functions
exports('AddToQueue', WarzoneSpawnQueue.AddToQueue)
exports('RemoveFromQueue', WarzoneSpawnQueue.RemoveFromQueue)
exports('GetQueuePosition', WarzoneSpawnQueue.GetQueuePosition)
exports('GetQueueStats', WarzoneSpawnQueue.GetQueueStats)
exports('GetPlayerPriority', WarzoneSpawnQueue.GetPlayerPriority)

-- Server events
RegisterNetEvent('warzone_spawn:joinQueue')
AddEventHandler('warzone_spawn:joinQueue', function(locationId)
    local source = source
    local priority = WarzoneSpawnQueue.GetPlayerPriority(source)
    WarzoneSpawnQueue.AddToQueue(source, locationId, priority)
end)

RegisterNetEvent('warzone_spawn:leaveQueue')
AddEventHandler('warzone_spawn:leaveQueue', function()
    local source = source
    WarzoneSpawnQueue.RemoveFromQueue(source)
    TriggerClientEvent('warzone_spawn:queueLeft', source)
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function()
    local source = source
    WarzoneSpawnQueue.RemoveFromQueue(source)
end)

-- Initialize when resource starts
Citizen.CreateThread(function()
    WarzoneSpawnQueue.Init()
end)