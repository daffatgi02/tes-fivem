-- resources/[warzone]/warzone_core/server/main.lua
ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize Warzone Framework
Citizen.CreateThread(function()
    while ESX == nil do
        Citizen.Wait(10)
    end
    
    -- Initialize Database
    WarzoneDB.Init()
    
    print("^2[WARZONE]^7 Server initialized successfully!")
    print("^2[WARZONE]^7 Framework: ESX Legacy")
    print("^2[WARZONE]^7 Gamemode: Tactical Warfare")
end)

-- Player Connection Handler
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.identifier
    
    -- Check if player exists in warzone database
    local warzonePlayer = WarzoneDB.GetPlayer(identifier)
    
    if not warzonePlayer then
        -- New player - create warzone profile
        TriggerClientEvent('warzone:showCharacterCreation', playerId)
    else
        -- Existing player - load data
        WarzonePlayer.Load(playerId, warzonePlayer)
        WarzoneDB.StartSession(identifier)
        
        if Config.Debug then
            print(string.format("[WARZONE] Player loaded: %s#%s", warzonePlayer.nickname, warzonePlayer.tag))
        end
    end
end)

-- Player Disconnect Handler
AddEventHandler('esx:playerDropped', function(playerId, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        WarzoneDB.EndSession(xPlayer.identifier)
        WarzonePlayer.Save(playerId)
        
        if Config.Debug then
            print(string.format("[WARZONE] Player disconnected: %s", xPlayer.identifier))
        end
    end
end)

-- Character Creation Handler
RegisterNetEvent('warzone:createCharacter')
AddEventHandler('warzone:createCharacter', function(nickname, tag)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    
    if not xPlayer then return end
    
    -- Validate input
    if not nickname or not tag then
        TriggerClientEvent('esx:showNotification', _source, '❌ Nickname dan Tag harus diisi!')
        return
    end
    
    -- Validate nickname length
    if string.len(nickname) < 3 or string.len(nickname) > 20 then
        TriggerClientEvent('esx:showNotification', _source, '❌ Nickname harus 3-20 karakter!')
        return
    end
    
    -- Validate tag length
    if string.len(tag) < 2 or string.len(tag) > 6 then
        TriggerClientEvent('esx:showNotification', _source, '❌ Tag harus 2-6 karakter!')
        return
    end
    
    -- Check if nickname#tag already exists
    if WarzoneDB.CheckNicknameTag(nickname, tag) then
        TriggerClientEvent('esx:showNotification', _source, '❌ Nickname#Tag sudah digunakan!')
        return
    end
    
    -- Create player
    if WarzoneDB.CreatePlayer(xPlayer.identifier, nickname, tag) then
        local warzonePlayer = WarzoneDB.GetPlayer(xPlayer.identifier)
        WarzonePlayer.Load(_source, warzonePlayer)
        WarzoneDB.StartSession(xPlayer.identifier)
        
        TriggerClientEvent('esx:showNotification', _source, '✅ Karakter berhasil dibuat!')
        TriggerClientEvent('warzone:characterCreated', _source)
    else
        TriggerClientEvent('esx:showNotification', _source, '❌ Gagal membuat karakter!')
    end
end)

-- Command: Set player role
ESX.RegisterCommand('setrole', 'admin', function(xPlayer, args, showError)
    local targetId = args.playerId.source
    local role = args.role
    
    if not Config.Roles[role] then
        return showError('Role tidak valid! Available: assault, support, medic, recon')
    end
    
    local targetPlayer = WarzonePlayer.GetBySource(targetId)
    if targetPlayer then
        targetPlayer.role = role
        WarzoneDB.UpdatePlayer(targetPlayer.identifier, {current_role = role})
        
        TriggerClientEvent('esx:showNotification', targetId, 
            string.format('🎖️ Role diubah menjadi: %s', Config.Roles[role].label))
        TriggerClientEvent('esx:showNotification', xPlayer.source, 
            string.format('✅ Role %s diubah menjadi: %s', targetPlayer.nickname, Config.Roles[role].label))
    end
end, true, {
    help = 'Set player role',
    validate = true,
    arguments = {
        {name = 'playerId', help = 'Player ID', type = 'player'},
        {name = 'role', help = 'Role name (assault/support/medic/recon)', type = 'string'}
    }
})

-- Command: Check player stats
ESX.RegisterCommand('stats', 'user', function(xPlayer, args, showError)
    local targetId = args.playerId and args.playerId.source or xPlayer.source
    local targetPlayer = WarzonePlayer.GetBySource(targetId)
    
    if targetPlayer then
        local kd = targetPlayer.deaths > 0 and (targetPlayer.kills / targetPlayer.deaths) or targetPlayer.kills
        local message = string.format([[
📊 STATISTICS - %s#%s
🎖️ Role: %s
💀 Kills: %d | Deaths: %d | K/D: %.2f
💰 Money: $%d
👥 Crew: %s
        ]], 
            targetPlayer.nickname, targetPlayer.tag,
            Config.Roles[targetPlayer.role].label,
            targetPlayer.kills, targetPlayer.deaths, kd,
            targetPlayer.money,
            targetPlayer.crew_id and "Yes" or "None"
        )
        
        TriggerClientEvent('esx:showNotification', xPlayer.source, message)
    end
end, true, {
    help = 'Check player statistics',
    validate = false,
    arguments = {
        {name = 'playerId', help = 'Player ID (optional)', type = 'player'}
    }
})