-- resources/[warzone]/warzone_combat/server/weapons.lua

WarzoneWeapons = {}

local ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Initialize weapon system
function WarzoneWeapons.Init()
    -- Create weapon upgrades table
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `warzone_weapon_upgrades` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `player_identifier` VARCHAR(60) NOT NULL,
            `weapon_hash` VARCHAR(50) NOT NULL,
            `upgrades` JSON,
            `attachments` JSON,
            `kill_count` INT DEFAULT 0,
            `experience` INT DEFAULT 0,
            `level` INT DEFAULT 1,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY `player_weapon` (`player_identifier`, `weapon_hash`),
            INDEX `player_idx` (`player_identifier`)
        )
    ]])
    
    print("^2[WARZONE WEAPONS] Weapon system initialized^7")
end

-- Give weapon with role restrictions
function WarzoneWeapons.GiveWeapon(source, weaponHash, ammo)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return false, "Player not found" end
    
    local weaponData = WarzoneCombatConfig.GetWeaponData(weaponHash)
    if not weaponData then return false, "Invalid weapon" end
    
    local roleData = WarzoneCombatConfig.GetRoleData(player.role)
    if not roleData then return false, "Invalid role" end
    
    -- Check role weapon access
    if not WarzoneWeapons.CanUseWeapon(player.role, weaponData.category) then
        return false, string.format("Your role cannot use %s weapons", weaponData.category)
    end
    
    -- Check level requirement
    if weaponData.requiredLevel and player.level < weaponData.requiredLevel then
        return false, string.format("Requires level %d", weaponData.requiredLevel)
    end
    
    local playerPed = GetPlayerPed(source)
    
    -- Apply role-specific ammo multiplier
    local finalAmmo = ammo or weaponData.maxAmmo or 250
    if roleData.stats and roleData.stats.ammoCapacityMultiplier then
        finalAmmo = math.floor(finalAmmo * roleData.stats.ammoCapacityMultiplier)
    end
    
    -- Give weapon
    GiveWeaponToPed(playerPed, weaponHash, finalAmmo, false, true)
    
    -- Load weapon upgrades and attachments
    WarzoneWeapons.LoadWeaponData(source, weaponHash)
    
    TriggerClientEvent('esx:showNotification', source, 
        string.format('🔫 Received: %s (%d rounds)', weaponData.name, finalAmmo))
    
    return true, "Weapon given successfully"
end

-- Check if role can use weapon category
function WarzoneWeapons.CanUseWeapon(roleName, weaponCategory)
    local roleData = WarzoneCombatConfig.GetRoleData(roleName)
    if not roleData or not roleData.weaponAccess then return false end
    
    -- Check if category is in allowed list
    for _, allowedCategory in ipairs(roleData.weaponAccess.categories or {}) do
        if allowedCategory == weaponCategory then
            -- Check if not in restriction list
            for _, restrictedCategory in ipairs(roleData.weaponAccess.restrictions or {}) do
                if restrictedCategory == weaponCategory then
                    return false
                end
            end
            return true
        end
    end
    
    return false
end

-- Give role-based loadout
function WarzoneWeapons.GiveRoleLoadout(source)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return false end
    
    local roleData = WarzoneCombatConfig.GetRoleData(player.role)
    if not roleData or not roleData.loadout then return false end
    
    local playerPed = GetPlayerPed(source)
    RemoveAllPedWeapons(playerPed, true)
    
    local loadout = roleData.loadout
    
    -- Give primary weapon
    if loadout.primary then
        WarzoneWeapons.GiveWeapon(source, loadout.primary)
    end
    
    -- Give secondary weapon
    if loadout.secondary then
        WarzoneWeapons.GiveWeapon(source, loadout.secondary)
    end
    
    -- Give sidearm
    if loadout.sidearm then
        WarzoneWeapons.GiveWeapon(source, loadout.sidearm)
    end
    
    -- Give explosives
    if loadout.explosives then
        for _, explosive in ipairs(loadout.explosives) do
            GiveWeaponToPed(playerPed, explosive, 5, false, false)
        end
    end
    
    -- Set armor
    if loadout.armor then
        SetPedArmour(playerPed, loadout.armor)
        if player.AddArmor then
            player:AddArmor(loadout.armor)
        end
    end
    
    -- Set health
    if loadout.health then
        SetEntityHealth(playerPed, loadout.health)
    end
    
    TriggerClientEvent('esx:showNotification', source, 
        string.format('🎖️ %s loadout equipped!', roleData.label))
    
    return true
end

-- Load weapon data from database
function WarzoneWeapons.LoadWeaponData(source, weaponHash)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return end
    
    local weaponData = MySQL.single.await('SELECT * FROM warzone_weapon_upgrades WHERE player_identifier = ? AND weapon_hash = ?', 
        {player.identifier, weaponHash})
    
    if weaponData then
        -- Apply upgrades and attachments
        TriggerClientEvent('warzone_combat:applyWeaponData', source, weaponHash, {
            upgrades = json.decode(weaponData.upgrades) or {},
            attachments = json.decode(weaponData.attachments) or {},
            killCount = weaponData.kill_count,
            experience = weaponData.experience,
            level = weaponData.level
        })
    end
end

-- Save weapon data to database
function WarzoneWeapons.SaveWeaponData(source, weaponHash, data)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return end
    
    MySQL.insert('INSERT INTO warzone_weapon_upgrades (player_identifier, weapon_hash, upgrades, attachments, kill_count, experience, level) VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE upgrades = VALUES(upgrades), attachments = VALUES(attachments), kill_count = VALUES(kill_count), experience = VALUES(experience), level = VALUES(level), updated_at = NOW()', 
        {player.identifier, weaponHash, json.encode(data.upgrades or {}), json.encode(data.attachments or {}), data.killCount or 0, data.experience or 0, data.level or 1})
end

-- Add weapon kill experience
function WarzoneWeapons.AddWeaponExperience(source, weaponHash, expGain)
    local player = WarzonePlayer.GetBySource(source)
    if not player then return end
    
    local currentData = MySQL.single.await('SELECT * FROM warzone_weapon_upgrades WHERE player_identifier = ? AND weapon_hash = ?', 
        {player.identifier, weaponHash})
    
    local killCount = (currentData and currentData.kill_count or 0) + 1
    local experience = (currentData and currentData.experience or 0) + expGain
    local level = math.floor(experience / 100) + 1 -- 100 exp per level
    
    if currentData then
        MySQL.update('UPDATE warzone_weapon_upgrades SET kill_count = ?, experience = ?, level = ? WHERE player_identifier = ? AND weapon_hash = ?', 
            {killCount, experience, level, player.identifier, weaponHash})
    else
        MySQL.insert('INSERT INTO warzone_weapon_upgrades (player_identifier, weapon_hash, kill_count, experience, level) VALUES (?, ?, ?, ?, ?)', 
            {player.identifier, weaponHash, killCount, experience, level})
    end
    
    -- Check for level up
    local previousLevel = currentData and math.floor(currentData.experience / 100) + 1 or 1
    if level > previousLevel then
        TriggerClientEvent('esx:showNotification', source, 
            string.format('🆙 %s leveled up! (Level %d)', WarzoneCombatConfig.GetWeaponData(weaponHash).name, level))
        
        -- Trigger level up rewards
        WarzoneWeapons.HandleWeaponLevelUp(source, weaponHash, level)
    end
end

-- Handle weapon level up rewards
function WarzoneWeapons.HandleWeaponLevelUp(source, weaponHash, newLevel)
    local weaponData = WarzoneCombatConfig.GetWeaponData(weaponHash)
    if not weaponData then return end
    
    -- Give upgrade points or unlock attachments based on level
    local rewards = {
        [5] = "Unlock: Extended Magazine",
        [10] = "Unlock: Scope",
        [15] = "+10% Damage",
        [20] = "Unlock: Advanced Attachments",
        [25] = "+15% Accuracy",
        [30] = "Master Level: All bonuses unlocked"
    }
    
    local reward = rewards[newLevel]
    if reward then
        TriggerClientEvent('esx:showNotification', source, 
            string.format('🎁 %s: %s', weaponData.name, reward))
    end
end

-- Events
RegisterNetEvent('warzone_combat:requestLoadout')
AddEventHandler('warzone_combat:requestLoadout', function()
    WarzoneWeapons.GiveRoleLoadout(source)
end)

RegisterNetEvent('warzone_combat:weaponKill')
AddEventHandler('warzone_combat:weaponKill', function(weaponHash)
    WarzoneWeapons.AddWeaponExperience(source, weaponHash, 25) -- 25 exp per kill
end)

RegisterNetEvent('warzone_combat:saveWeaponData')
AddEventHandler('warzone_combat:saveWeaponData', function(weaponHash, data)
    WarzoneWeapons.SaveWeaponData(source, weaponHash, data)
end)

-- Commands
ESX.RegisterCommand('loadout', 'user', function(xPlayer, args, showError)
    local success = WarzoneWeapons.GiveRoleLoadout(xPlayer.source)
    if not success then
        TriggerClientEvent('esx:showNotification', xPlayer.source, '❌ Failed to give loadout')
    end
end, false, {help = 'Get your role loadout'})

ESX.RegisterCommand('weaponstats', 'user', function(xPlayer, args, showError)
    local weaponHash = args.weapon
    if not weaponHash then
        return showError('Usage: /weaponstats [weapon_hash]')
    end
    
    local player = WarzonePlayer.GetBySource(xPlayer.source)
    if not player then return end
    
    local weaponData = MySQL.single.await('SELECT * FROM warzone_weapon_upgrades WHERE player_identifier = ? AND weapon_hash = ?', 
        {player.identifier, weaponHash})
    
    if weaponData then
        local weaponInfo = WarzoneCombatConfig.GetWeaponData(weaponHash)
        local message = string.format([[
🔫 %s STATS
💀 Kills: %d
⭐ Experience: %d
📈 Level: %d
        ]], weaponInfo and weaponInfo.name or weaponHash, weaponData.kill_count, weaponData.experience, weaponData.level)
        
        TriggerClientEvent('esx:showNotification', xPlayer.source, message)
    else
        TriggerClientEvent('esx:showNotification', xPlayer.source, '❌ No data for this weapon')
    end
end, false, {
    help = 'Check weapon statistics',
    validate = true,
    arguments = {
        {name = 'weapon', help = 'Weapon hash', type = 'string'}
    }
})

-- Initialize
Citizen.CreateThread(function()
    while GetResourceState('warzone_core') ~= 'started' do
        Citizen.Wait(100)
    end
    
    WarzoneWeapons.Init()
end)

-- Export functions
exports('GiveWeapon', WarzoneWeapons.GiveWeapon)
exports('CanUseWeapon', WarzoneWeapons.CanUseWeapon)
exports('GiveRoleLoadout', WarzoneWeapons.GiveRoleLoadout)
exports('AddWeaponExperience', WarzoneWeapons.AddWeaponExperience)