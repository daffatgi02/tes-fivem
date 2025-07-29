-- resources/[warzone]/warzone_combat/client/config_loader.lua

WarzoneCombatConfigClient = {}
local configs = {}

-- Load config from server
function WarzoneCombatConfigClient.Init()
    -- Request configs from server
    ESX.TriggerServerCallback('warzone_combat:getConfigs', function(serverConfigs)
        configs = serverConfigs
        print("^2[WARZONE COMBAT] Client configs loaded^7")
        
        -- Trigger config loaded event
        TriggerEvent('warzone_combat:configsLoaded')
    end)
end

-- Getter functions (same as server)
function WarzoneCombatConfigClient.GetCombat()
    return configs.combat or {}
end

function WarzoneCombatConfigClient.GetWeapons()
    return configs.weapons or {}
end

function WarzoneCombatConfigClient.GetRoles()
    return configs.roles or {}
end

function WarzoneCombatConfigClient.GetArmor()
    return configs.armor or {}
end

function WarzoneCombatConfigClient.GetAttachments()
    return configs.attachments or {}
end

function WarzoneCombatConfigClient.GetWeaponData(weaponHash)
    local weaponConfigs = configs.weapons
    if not weaponConfigs or not weaponConfigs.weaponCategories then return nil end
    
    for categoryName, category in pairs(weaponConfigs.weaponCategories) do
        if category.weapons and category.weapons[weaponHash] then
            local weapon = category.weapons[weaponHash]
            weapon.category = categoryName
            return weapon
        end
    end
    return nil
end

function WarzoneCombatConfigClient.GetRoleData(roleName)
    local roleConfigs = configs.roles
    if not roleConfigs or not roleConfigs.roles then return nil end
    
    return roleConfigs.roles[roleName]
end

-- Handle config reload
RegisterNetEvent('warzone_combat:configReloaded')
AddEventHandler('warzone_combat:configReloaded', function()
    WarzoneCombatConfigClient.Init()
    ESX.ShowNotification('🔄 Combat configuration reloaded!')
end)

-- Initialize when ready
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    WarzoneCombatConfigClient.Init()
end)