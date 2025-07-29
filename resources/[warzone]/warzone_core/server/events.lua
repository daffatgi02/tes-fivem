-- resources/[warzone]/warzone_core/server/events.lua

-- Combat Events
RegisterNetEvent('warzone:enterCombat')
AddEventHandler('warzone:enterCombat', function()
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    
    if player then
        player:SetCombatStatus(true)
    end
end)

-- Kill Event (Updated with zone integration)
RegisterNetEvent('warzone:playerKilled')
AddEventHandler('warzone:playerKilled', function(killerServerId, weapon)
    local victimSource = source
    local victim = WarzonePlayer.GetBySource(victimSource)
    
    if not victim then return end
    
    local killer = nil
    local killerCoords = nil
    local victimCoords = GetEntityCoords(GetPlayerPed(victimSource))
    
    if killerServerId then
        killer = WarzonePlayer.GetBySource(killerServerId)
        killerCoords = GetEntityCoords(GetPlayerPed(killerServerId))
    end
    
    -- Process death
    victim:AddDeath(killer)
    
    -- Process kill if valid killer
    if killer and killer.identifier ~= victim.identifier then
        -- Calculate distance
        local distance = killerCoords and #(killerCoords - victimCoords) or 0
        
        -- Check for headshot
        local headshot = HasEntityBeenDamagedByWeapon(GetPlayerPed(victimSource), weapon, 4)
        
        -- Get zone information (integrated with zone system)
        local zoneName = "unknown"
        if GetResourceState('warzone_zones') == 'started' then
            local zoneData = exports.warzone_zones:GetZoneAtCoords(killerCoords)
            zoneName = zoneData or "unknown"
            
            -- Trigger zone kill recording
            TriggerEvent('warzone:killRecorded', killerServerId, victimSource, killerCoords, victimCoords, weapon, headshot)
        end
        
        -- Add kill
        if killer:AddKill(victim, weapon, zoneName, distance, headshot) then
            -- Broadcast kill feed
            TriggerClientEvent('warzone:killFeed', -1, {
                killer = killer:GetDisplayName(),
                victim = victim:GetDisplayName(),
                weapon = weapon,
                distance = math.floor(distance),
                headshot = headshot,
                zone = zoneName
            })
        end
    end
    
    -- Save both players
    if killer then killer:Save() end
    victim:Save()
    
    -- Schedule respawn
    Citizen.SetTimeout(Config.DeathTimeout * 1000, function()
        TriggerClientEvent('warzone:respawn', victimSource)
    end)
end)

-- Green Zone Combat Prevention
RegisterNetEvent('warzone:attemptCombat')
AddEventHandler('warzone:attemptCombat', function(targetSource)
    local _source = source
    
    if GetResourceState('warzone_zones') == 'started' then
        local attackerInGreen = exports.warzone_zones:IsPlayerInGreenZone(_source)
        local targetInGreen = targetSource and exports.warzone_zones:IsPlayerInGreenZone(targetSource) or false
        
        if attackerInGreen or targetInGreen then
            TriggerClientEvent('esx:showNotification', _source, '❌ Combat is disabled in safe zones!')
            return false
        end
    end
    
    return true
end)


-- Add crew spawn coordination
RegisterNetEvent('warzone:requestCrewSpawn')
AddEventHandler('warzone:requestCrewSpawn', function(targetMemberId)
    local _source = source
    
    if GetResourceState('warzone_crew') ~= 'started' then
        TriggerClientEvent('esx:showNotification', _source, '❌ Crew system not available')
        return
    end
    
    local playerCrew = exports.warzone_crew:GetPlayerCrew(_source)
    if not playerCrew then
        TriggerClientEvent('esx:showNotification', _source, '❌ You are not in a crew')
        return
    end
    
    local targetMember = playerCrew.members[targetMemberId]
    if not targetMember or not targetMember.online then
        TriggerClientEvent('esx:showNotification', _source, '❌ Target crew member not online')
        return
    end
    
    local targetSource = targetMember.source
    if not targetSource then return end
    
    -- Get target position
    local targetPed = GetPlayerPed(targetSource)
    local targetCoords = GetEntityCoords(targetPed)
    
    -- Check if target is in green zone
    if GetResourceState('warzone_zones') == 'started' then
        local zone, zoneType = exports.warzone_zones:GetZoneAtCoords(targetCoords)
        if zoneType == 'green' then
            TriggerClientEvent('esx:showNotification', _source, '❌ Cannot spawn in green zone')
            return
        end
    end
    
    -- Find safe spawn location near target
    local spawnCoords = WarzoneSpawn.FindSafeLocationNear(targetCoords, CrewConfig.Bonuses.MaxSpawnDistance)
    
    if spawnCoords then
        -- Teleport player
        local playerPed = GetPlayerPed(_source)
        SetEntityCoords(playerPed, spawnCoords.x, spawnCoords.y, spawnCoords.z)
        SetEntityHeading(playerPed, spawnCoords.w or 0.0)
        
        -- Give spawn protection
        TriggerEvent('warzone:giveSpawnProtection', _source, CrewConfig.Bonuses.SpawnProtectionTime)
        
        TriggerClientEvent('esx:showNotification', _source, 
            string.format('✅ Spawned near %s', targetMember.displayName))
        TriggerClientEvent('esx:showNotification', targetSource, 
            string.format('👥 %s spawned near you', WarzonePlayer.GetBySource(_source):GetDisplayName()))
    else
        TriggerClientEvent('esx:showNotification', _source, '❌ No safe spawn location found')
    end
end)

-- Money Events
RegisterNetEvent('warzone:addMoney')
AddEventHandler('warzone:addMoney', function(amount, reason)
   local _source = source
   local player = WarzonePlayer.GetBySource(_source)
   
   if player and amount > 0 then
       player.money = player.money + amount
       
       local xPlayer = ESX.GetPlayerFromId(_source)
       if xPlayer then
           xPlayer.addMoney(amount)
       end
       
       TriggerClientEvent('esx:showNotification', _source, 
           string.format('💰 +$%d (%s)', amount, reason or "Unknown"))
   end
end)

RegisterNetEvent('warzone:removeMoney')
AddEventHandler('warzone:removeMoney', function(amount, reason)
   local _source = source
   local player = WarzonePlayer.GetBySource(_source)
   
   if player and amount > 0 and player.money >= amount then
       player.money = player.money - amount
       
       local xPlayer = ESX.GetPlayerFromId(_source)
       if xPlayer then
           xPlayer.removeMoney(amount)
       end
       
       TriggerClientEvent('esx:showNotification', _source, 
           string.format('💰 -$%d (%s)', amount, reason or "Unknown"))
       return true
   end
   return false
end)

-- Role Change Event
RegisterNetEvent('warzone:changeRole')
AddEventHandler('warzone:changeRole', function(newRole)
   local _source = source
   local player = WarzonePlayer.GetBySource(_source)
   
   if player and Config.Roles[newRole] then
       player.role = newRole
       player:Save()
       
       TriggerClientEvent('esx:showNotification', _source, 
           string.format('🎖️ Role changed to: %s', Config.Roles[newRole].label))
       
       -- Update client data
       TriggerClientEvent('warzone:updateRole', _source, newRole)
   end
end)

-- Data Sync Events
RegisterNetEvent('warzone:requestPlayerData')
AddEventHandler('warzone:requestPlayerData', function()
   local _source = source
   local player = WarzonePlayer.GetBySource(_source)
   
   if player then
       TriggerClientEvent('warzone:receivePlayerData', _source, {
           nickname = player.nickname,
           tag = player.tag,
           role = player.role,
           kills = player.kills,
           deaths = player.deaths,
           money = player.money,
           crew_id = player.crew_id
       })
   end
end)