-- resources/[warzone]/warzone_spawn/server/config_loader.lua

WarzoneSpawnConfig = {}
local configs = {}

-- Load JSON config file
local function LoadJSONConfig(filename)
    local file = LoadResourceFile(GetCurrentResourceName(), filename)
    if not file then
        print(string.format("^1[WARZONE SPAWN] Failed to load config: %s^7", filename))
        return {}
    end
    
    local success, result = pcall(json.decode, file)
    if not success then
        print(string.format("^1[WARZONE SPAWN] Failed to parse JSON: %s^7", filename))
        return {}
    end
    
    return result
end

-- Initialize all configs
function WarzoneSpawnConfig.Init()
    print("^2[WARZONE SPAWN] Loading configuration files...^7")
    
    configs.spawn = LoadJSONConfig('config/spawn_config.json')
    configs.locations = LoadJSONConfig('config/locations_config.json')
    
    -- Validate configs
    WarzoneSpawnConfig.ValidateConfigs()
    
    print("^2[WARZONE SPAWN] All configuration files loaded successfully!^7")
end

-- Validate configuration integrity
function WarzoneSpawnConfig.ValidateConfigs()
    local errors = {}
    
    -- Validate spawn configs
    if not configs.spawn.spawn then
        table.insert(errors, "Missing spawn configuration")
    end
    
    -- Validate locations
    if not configs.locations.categories then
        table.insert(errors, "Missing location categories")
    else
        for categoryName, category in pairs(configs.locations.categories) do
            if not category.locations or next(category.locations) == nil then
                table.insert(errors, string.format("Category %s has no locations", categoryName))
            end
        end
    end
    
    if #errors > 0 then
        print("^1[WARZONE SPAWN] Configuration validation errors:^7")
        for _, error in ipairs(errors) do
            print("^1  - " .. error .. "^7")
        end
    else
        print("^2[WARZONE SPAWN] Configuration validation passed!^7")
    end
end

-- Getter functions
function WarzoneSpawnConfig.GetSpawn()
    return configs.spawn or {}
end

function WarzoneSpawnConfig.GetLocations()
    return configs.locations or {}
end

-- Hot reload function
function WarzoneSpawnConfig.Reload()
    print("^3[WARZONE SPAWN] Reloading configuration files...^7")
    WarzoneSpawnConfig.Init()
    
    -- Notify all clients to reload
    TriggerClientEvent('warzone_spawn:configReloaded', -1)
end

-- Initialize when resource starts
Citizen.CreateThread(function()
    WarzoneSpawnConfig.Init()
end)

-- Server callback for client configs
ESX.RegisterServerCallback('warzone_spawn:getConfigs', function(source, cb)
    cb({
        spawn = WarzoneSpawnConfig.GetSpawn(),
        locations = WarzoneSpawnConfig.GetLocations()
    })
end)

-- Admin command to reload configs
ESX.RegisterCommand('reloadspawn', 'admin', function(xPlayer, args, showError)
    WarzoneSpawnConfig.Reload()
    TriggerClientEvent('esx:showNotification', xPlayer.source, '✅ Spawn configuration reloaded!')
end, false, {help = 'Reload spawn configuration files'})

-- Export functions
exports('GetSpawnConfig', WarzoneSpawnConfig.GetSpawn)
exports('GetLocationsConfig', WarzoneSpawnConfig.GetLocations)
exports('ReloadConfig', WarzoneSpawnConfig.Reload)