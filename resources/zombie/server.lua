ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local activeGames = {}

RegisterNetEvent('enemygame:startGame')
AddEventHandler('enemygame:startGame', function(enemyCount, spawnDistance)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    -- Check if player already has active game
    for gameId, gameData in pairs(activeGames) do
        if gameData.playerId == _source then
            TriggerClientEvent('enemygame:gameStopped', _source)
            activeGames[gameId] = nil
            break
        end
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(_source))
    local gameId = #activeGames + 1
    
    activeGames[gameId] = {
        playerId = _source,
        enemyCount = enemyCount,
        spawnDistance = spawnDistance,
        enemiesAlive = enemyCount,
        enemies = {},
        playerCoords = playerCoords,
        active = true,
        startTime = os.time()
    }
    
    print(string.format('[EnemyGame] Player %s started game with %d enemies', xPlayer.getName(), enemyCount))
    TriggerClientEvent('enemygame:gameStarted', _source, gameId, enemyCount)
end)

RegisterNetEvent('enemygame:enemyKilled')
AddEventHandler('enemygame:enemyKilled', function(gameId, enemyId)
    local _source = source
    
    if activeGames[gameId] and activeGames[gameId].playerId == _source then
        activeGames[gameId].enemiesAlive = activeGames[gameId].enemiesAlive - 1
        
        if activeGames[gameId].enemies[enemyId] then
            activeGames[gameId].enemies[enemyId] = nil
        end
        
        TriggerClientEvent('enemygame:updateUI', _source, activeGames[gameId].enemiesAlive)
        
        if activeGames[gameId].enemiesAlive <= 0 then
            local xPlayer = ESX.GetPlayerFromId(_source)
            if xPlayer then
                local gameTime = os.time() - activeGames[gameId].startTime
                print(string.format('[EnemyGame] Player %s completed game in %d seconds', xPlayer.getName(), gameTime))
            end
            
            TriggerClientEvent('enemygame:gameCompleted', _source)
            activeGames[gameId] = nil
        end
    end
end)

RegisterNetEvent('enemygame:stopGame')
AddEventHandler('enemygame:stopGame', function(gameId)
    local _source = source
    
    if gameId and activeGames[gameId] and activeGames[gameId].playerId == _source then
        local xPlayer = ESX.GetPlayerFromId(_source)
        if xPlayer then
            print(string.format('[EnemyGame] Player %s stopped game manually', xPlayer.getName()))
        end
        
        activeGames[gameId] = nil
        TriggerClientEvent('enemygame:gameStopped', _source)
    else
        -- If no specific gameId, find and stop player's active game
        for gId, gameData in pairs(activeGames) do
            if gameData.playerId == _source then
                local xPlayer = ESX.GetPlayerFromId(_source)
                if xPlayer then
                    print(string.format('[EnemyGame] Player %s stopped game manually', xPlayer.getName()))
                end
                
                activeGames[gId] = nil
                TriggerClientEvent('enemygame:gameStopped', _source)
                break
            end
        end
    end
end)

RegisterNetEvent('enemygame:playerDied')
AddEventHandler('enemygame:playerDied', function(gameId)
    local _source = source
    
    if gameId and activeGames[gameId] and activeGames[gameId].playerId == _source then
        local xPlayer = ESX.GetPlayerFromId(_source)
        if xPlayer then
            print(string.format('[EnemyGame] Player %s died, game reset', xPlayer.getName()))
        end
        
        activeGames[gameId] = nil
        -- Client handles the reset, so we don't send gameStopped event here
    end
end)

-- Player disconnect cleanup
AddEventHandler('playerDropped', function(reason)
    local _source = source
    
    for gameId, gameData in pairs(activeGames) do
        if gameData.playerId == _source then
            print(string.format('[EnemyGame] Player disconnected, cleaning up game %d', gameId))
            activeGames[gameId] = nil
            break
        end
    end
end)

-- Cleanup inactive games (safety measure)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300000) -- Check every 5 minutes
        
        local currentTime = os.time()
        for gameId, gameData in pairs(activeGames) do
            -- Remove games older than 30 minutes
            if currentTime - gameData.startTime > 1800 then
                print(string.format('[EnemyGame] Cleaning up stale game %d', gameId))
                
                if GetPlayerPing(gameData.playerId) > 0 then
                    TriggerClientEvent('enemygame:gameStopped', gameData.playerId)
                end
                
                activeGames[gameId] = nil
            end
        end
    end
end)

-- Admin command to stop all games
RegisterCommand('stopallgames', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if source == 0 or (xPlayer and xPlayer.getGroup() == 'admin') then
        local count = 0
        for gameId, gameData in pairs(activeGames) do
            TriggerClientEvent('enemygame:gameStopped', gameData.playerId)
            count = count + 1
        end
        
        activeGames = {}
        
        if source == 0 then
            print(string.format('[EnemyGame] Stopped %d active games', count))
        else
            TriggerClientEvent('chat:addMessage', source, {
                args = {'EnemyGame', string.format('Stopped %d active games', count)}
            })
        end
    end
end, true)