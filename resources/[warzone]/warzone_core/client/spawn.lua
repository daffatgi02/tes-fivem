-- resources/[warzone]/warzone_core/client/spawn.lua (File yang missing)
WarzoneSpawn = {}

local ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- Basic spawn management
function WarzoneSpawn.HandleRespawn()
    local ped = PlayerPedId()
    
    -- Reset health and revive
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    NetworkResurrectLocalPlayer(Config.DefaultSpawn.x, Config.DefaultSpawn.y, Config.DefaultSpawn.z, Config.DefaultSpawn.heading, true, false)
    
    -- Clear any existing weapons
    RemoveAllPedWeapons(ped, true)
    
    -- Give basic loadout based on role
    WarzoneSpawn.GiveRoleLoadout()
    
    ESX.ShowNotification('🔄 You have respawned!')
end

-- Give role-based loadout
function WarzoneSpawn.GiveRoleLoadout()
    local playerData = WarzonePlayer.GetData()
    if not playerData or not playerData.role then return end
    
    local ped = PlayerPedId()
    local roleConfig = Config.Roles[playerData.role]
    
    if roleConfig then
        -- Give basic weapon (Pistol for all roles)
        GiveWeaponToPed(ped, `WEAPON_PISTOL`, 250, false, true)
        
        -- Give role-specific primary weapon
        if playerData.role == 'assault' then
            GiveWeaponToPed(ped, `WEAPON_CARBINERIFLE`, 300, false, false)
        elseif playerData.role == 'support' then
            GiveWeaponToPed(ped, `WEAPON_COMBATMG`, 500, false, false)
        elseif playerData.role == 'medic' then
            GiveWeaponToPed(ped, `WEAPON_ASSAULTRIFLE`, 300, false, false)
        elseif playerData.role == 'recon' then
            GiveWeaponToPed(ped, `WEAPON_SNIPERRIFLE`, 100, false, false)
        end
        
        -- Give basic armor
        SetPedArmour(ped, 25)
    end
end

-- Event handlers
RegisterNetEvent('warzone:respawn')
AddEventHandler('warzone:respawn', function()
    WarzoneSpawn.HandleRespawn()
end)

-- Export functions
exports('HandleRespawn', WarzoneSpawn.HandleRespawn)
exports('GiveRoleLoadout', WarzoneSpawn.GiveRoleLoadout)