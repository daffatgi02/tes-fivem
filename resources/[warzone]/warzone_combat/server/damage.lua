-- resources/[warzone]/warzone_combat/server/damage.lua

WarzoneDamage = {}

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize damage system
function WarzoneDamage.Init()
    print("^2[WARZONE COMBAT] Damage system initialized^7")
end

-- Calculate damage with all modifiers
function WarzoneDamage.CalculateDamage(attackerSource, victimSource, weaponHash, damageComponent, baseDamage)
    local attacker = WarzonePlayer.GetBySource(attackerSource)
    local victim = WarzonePlayer.GetBySource(victimSource)
    
    if not attacker or not victim then return baseDamage end
    
    local combatConfig = WarzoneCombatConfig.GetCombat()
    local weaponData = WarzoneCombatConfig.GetWeaponData(weaponHash)
    local attackerRole = WarzoneCombatConfig.GetRoleData(attacker.role)
    local victimRole = WarzoneCombatConfig.GetRoleData(victim.role)
    
    local finalDamage = baseDamage
    
    -- Apply weapon-specific damage
    if weaponData and weaponData.damage then
        finalDamage = weaponData.damage
    end
    
    -- Apply attacker role damage multiplier
    if attackerRole and attackerRole.stats and attackerRole.stats.damageMultiplier then
        finalDamage = finalDamage * attackerRole.stats.damageMultiplier
    end
    
    -- Apply headshot multiplier
    if damageComponent == 0 then -- Head component
        local headshotMultiplier = combatConfig.combat and combatConfig.combat.general and combatConfig.combat.general.headshotMultiplier or 2.0
        finalDamage = finalDamage * headshotMultiplier
    end
    
    -- Apply distance modifiers
    local distance = WarzoneDamage.GetDistance(attackerSource, victimSource)
    finalDamage = WarzoneDamage.ApplyDistanceModifier(finalDamage, weaponData, distance)
    
    -- Apply zone modifiers
    local zone = WarzoneDamage.GetPlayerZone(victimSource)
    finalDamage = WarzoneDamage.ApplyZoneModifier(finalDamage, zone)
    
    -- Apply armor reduction
    finalDamage = WarzoneDamage.ApplyArmorReduction(finalDamage, victim)
    
    -- Apply victim role armor multiplier
    if victimRole and victimRole.stats and victimRole.stats.armorMultiplier then
        local armorReduction = 1.0 - (victimRole.stats.armorMultiplier - 1.0)
        finalDamage = finalDamage * armorReduction
    end
    
    -- Log damage for analytics
    WarzoneDamage.LogDamage(attackerSource, victimSource, weaponHash, baseDamage, finalDamage, damageComponent)
    
    return math.max(1, math.floor(finalDamage))
end

-- Apply distance-based damage modifier
function WarzoneDamage.ApplyDistanceModifier(damage, weaponData, distance)
    if not weaponData or not weaponData.range then return damage end
    
    local optimalRange = weaponData.range * 0.5
    local maxRange = weaponData.range
    
    if distance <= optimalRange then
        -- Full damage at optimal range
        return damage
    elseif distance <= maxRange then
        -- Linear damage drop-off
        local dropOffFactor = 1.0 - ((distance - optimalRange) / (maxRange - optimalRange)) * 0.5
        return damage * dropOffFactor
    else
        -- Heavy damage penalty beyond max range
        return damage * 0.3
    end
end

-- Apply zone-based damage modifier
function WarzoneDamage.ApplyZoneModifier(damage, zone)
    local combatConfig = WarzoneCombatConfig.GetCombat()
    if not combatConfig.combat or not combatConfig.combat.zones then return damage end
    
    local zoneConfig = combatConfig.combat.zones[zone]
    if zoneConfig and zoneConfig.damageMultiplier then
        return damage * zoneConfig.damageMultiplier
    end
    
    return damage
end

-- Apply armor damage reduction
function WarzoneDamage.ApplyArmorReduction(damage, victim)
    if not victim.armor or victim.armor <= 0 then return damage end
    
    local combatConfig = WarzoneCombatConfig.GetCombat()
    local armorReduction = combatConfig.combat and combatConfig.combat.general and combatConfig.combat.general.armorDamageReduction or 0.5
    
    local armorFactor = math.min(victim.armor / 100, 1.0)
    local reducedDamage = damage * (1.0 - (armorReduction * armorFactor))
    
    -- Damage armor
    local armorDamage = math.min(damage * 0.1, victim.armor)
    victim.armor = math.max(0, victim.armor - armorDamage)
    
    return reducedDamage
end

-- Get distance between players
function WarzoneDamage.GetDistance(source1, source2)
    local ped1 = GetPlayerPed(source1)
    local ped2 = GetPlayerPed(source2)
    
    if ped1 == 0 or ped2 == 0 then return 0 end
    
    local coords1 = GetEntityCoords(ped1)
    local coords2 = GetEntityCoords(ped2)
    
    return #(coords1 - coords2)
end

-- Get player's current zone
function WarzoneDamage.GetPlayerZone(source)
    if GetResourceState('warzone_zones') ~= 'started' then return 'normal' end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local zone, zoneType = exports.warzone_zones:GetZoneAtCoords(playerCoords)
    
    if zoneType == 'green' then
        return 'greenZone'
    elseif zone then
        local zoneData = exports.warzone_zones:GetZoneActivity(zone.name)
        if zoneData == 'red' then
            return 'redZone'
        elseif zoneData == 'yellow' then
            return 'yellowZone'
        end
    end
    
    return 'normal'
end

-- Log damage for analytics
function WarzoneDamage.LogDamage(attackerSource, victimSource, weaponHash, baseDamage, finalDamage, bodyPart)
    if not Config.Debug then return end
    
    local attacker = WarzonePlayer.GetBySource(attackerSource)
    local victim = WarzonePlayer.GetBySource(victimSource)
    
    if attacker and victim then
        print(string.format("^3[DAMAGE] %s -> %s | Weapon: %s | Base: %d | Final: %d | Body: %d^7",
            attacker:GetDisplayName(), victim:GetDisplayName(), weaponHash, baseDamage, finalDamage, bodyPart))
    end
end

-- Handle damage events
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local componentHash = args[3]
        local weaponHash = args[5]
        local damage = args[6]
        local damageComponent = args[10]
        
        local victimSource = NetworkGetPlayerIndexFromPed(victim)
        local attackerSource = NetworkGetPlayerIndexFromPed(attacker)
        
        if victimSource ~= -1 and attackerSource ~= -1 then
            victimSource = GetPlayerServerId(victimSource)
            attackerSource = GetPlayerServerId(attackerSource)
            
            if victimSource ~= attackerSource then
                local finalDamage = WarzoneDamage.CalculateDamage(attackerSource, victimSource, weaponHash, damageComponent, damage)
                
                -- Apply the calculated damage
                local victimPed = GetPlayerPed(victimSource)
                local currentHealth = GetEntityHealth(victimPed)
                local newHealth = math.max(0, currentHealth - finalDamage)
                
                SetEntityHealth(victimPed, newHealth)
                
                -- Trigger damage event for other systems
                TriggerEvent('warzone_combat:damageDealt', attackerSource, victimSource, weaponHash, finalDamage, damageComponent)
            end
        end
    end
end)

-- Initialize
Citizen.CreateThread(function()
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneDamage.Init()
end)

-- Export functions
exports('CalculateDamage', WarzoneDamage.CalculateDamage)
exports('GetDistance', WarzoneDamage.GetDistance)