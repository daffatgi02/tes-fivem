-- resources/[warzone]/warzone_combat/server/armor.lua

WarzoneArmor = {}

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize armor system
function WarzoneArmor.Init()
    print("^2[WARZONE ARMOR] Server armor system initialized^7")
end

-- Give armor kits to player
function WarzoneArmor.GiveArmorKits(source, amount)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return false end
    
    local armorConfig = WarzoneCombatConfig.GetArmor()
    local maxKits = armorConfig.armor and armorConfig.armor.system and armorConfig.armor.system.maxArmorKits or 3
    
    player.armorKits = math.min(maxKits, (player.armorKits or 0) + amount)
    
    TriggerClientEvent('warzone_combat:updateArmorKits', source, player.armorKits)
    TriggerClientEvent('esx:showNotification', source, 
        string.format('📦 Received %d armor kit(s) | Total: %d/%d', amount, player.armorKits, maxKits))
    
    return true
end

-- Handle armor repair
RegisterNetEvent('warzone_combat:armorRepaired')
AddEventHandler('warzone_combat:armorRepaired', function(repairAmount)
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    if not player then return end
    
    -- Log armor usage for statistics
    if Config.Debug then
        print(string.format("^3[ARMOR] %s repaired %d armor^7", player:GetDisplayName(), repairAmount))
    end
end)

-- Handle armor sharing
RegisterNetEvent('warzone_combat:shareArmor')
AddEventHandler('warzone_combat:shareArmor', function(targetSource)
    local _source = source
    local player = WarzonePlayer.GetBySource(_source)
    local target = WarzonePlayer.GetBySource(targetSource)
    
    if not player or not target then return end
    
    -- Check if players are in same crew
    if GetResourceState('warzone_crew') == 'started' then
        local playerCrew = exports.warzone_crew:GetPlayerCrew(_source)
        local targetCrew = exports.warzone_crew:GetPlayerCrew(targetSource)
        
        if not playerCrew or not targetCrew or playerCrew.id ~= targetCrew.id then
            TriggerClientEvent('esx:showNotification', _source, '❌ Can only share armor with crew members')
            return
        end
    end
    
    -- Check distance
    local playerPed = GetPlayerPed(_source)
    local targetPed = GetPlayerPed(targetSource)
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    if distance > 10.0 then
        TriggerClientEvent('esx:showNotification', _source, '❌ Target too far away')
        return
    end
    
    -- Share armor kit
    TriggerClientEvent('warzone_combat:receiveArmorKit', targetSource, player:GetDisplayName())
    
    TriggerClientEvent('esx:showNotification', _source, 
        string.format('🤝 Shared armor kit with %s', target:GetDisplayName()))
end)

-- Give role-based armor on spawn
function WarzoneArmor.GiveRoleArmor(source, roleName)
    local roleData = WarzoneCombatConfig.GetRoleData(roleName)
    if not roleData or not roleData.loadout then return end
   
   local playerPed = GetPlayerPed(source)
   local armorAmount = roleData.loadout.armor or 50
   
   -- Apply role armor multiplier
   if roleData.stats and roleData.stats.armorMultiplier then
       armorAmount = math.floor(armorAmount * roleData.stats.armorMultiplier)
   end
   
   SetPedArmour(playerPed, math.min(100, armorAmount))
   
   -- Give armor kits based on role
   local kitsToGive = 1
   if roleName == "support" then
       kitsToGive = 3 -- Support gets more kits
   elseif roleName == "medic" then
       kitsToGive = 2 -- Medic gets extra for team support
   end
   
   WarzoneArmor.GiveArmorKits(source, kitsToGive)
end

-- Initialize
Citizen.CreateThread(function()
   while GetResourceState('warzone_core') ~= 'started' do
       Citizen.Wait(100)
   end
   
   WarzoneArmor.Init()
end)

-- Export functions
exports('GiveArmorKits', WarzoneArmor.GiveArmorKits)
exports('GiveRoleArmor', WarzoneArmor.GiveRoleArmor)