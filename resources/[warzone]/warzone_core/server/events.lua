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

-- Kill Event
RegisterNetEvent('warzone:playerKilled')
-- resources/[warzone]/warzone_core/server/events.lua (continued)
AddEventHandler('warzone:playerKilled', function(killerServerId, weapon)
   local victimSource = source
   local victim = WarzonePlayer.GetBySource(victimSource)
   
   if not victim then return end
   
   local killer = nil
   if killerServerId then
       killer = WarzonePlayer.GetBySource(killerServerId)
   end
   
   -- Process death
   victim:AddDeath(killer)
   
   -- Process kill if valid killer
   if killer and killer.identifier ~= victim.identifier then
       -- Calculate distance
       local killerPed = GetPlayerPed(killerServerId)
       local victimPed = GetPlayerPed(victimSource)
       local killerCoords = GetEntityCoords(killerPed)
       local victimCoords = GetEntityCoords(victimPed)
       local distance = #(killerCoords - victimCoords)
       
       -- Check for headshot (simplified)
       local headshot = HasEntityBeenDamagedByWeapon(victimPed, weapon, 4) -- component 4 = head
       
       -- Determine zone (will be expanded in zone system)
       local zone = "unknown"
       
       -- Add kill
       if killer:AddKill(victim, weapon, zone, distance, headshot) then
           -- Broadcast kill feed
           TriggerClientEvent('warzone:killFeed', -1, {
               killer = killer:GetDisplayName(),
               victim = victim:GetDisplayName(),
               weapon = weapon,
               distance = math.floor(distance),
               headshot = headshot
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