-- resources/[warzone]/warzone_combat/server/config_loader.lua

WarzoneCombatConfig = {}
local configs = {}

-- Server callback to send configs to client
ESX.RegisterServerCallback('warzone_combat:getConfigs', function(source, cb)
    cb({
        combat = WarzoneCombatConfig.GetCombat(),
        weapons = WarzoneCombatConfig.GetWeapons(),
        roles = WarzoneCombatConfig.GetRoles(),
        armor = WarzoneCombatConfig.GetArmor(),
        attachments = WarzoneCombatConfig.GetAttachments()
    })
end)

-- Load JSON config file
local function LoadJSONConfig(filename)
    local file = LoadResourceFile(GetCurrentResourceName(), filename)
    if not file then
        print(string.format("^1[WARZONE COMBAT] Failed to load config: %s^7", filename))
        return {}
    end
    
    local success, result = pcall(json.decode, file)
    if not success then
        print(string.format("^1[WARZONE COMBAT] Failed to parse JSON: %s^7", filename))
        return {}
    end
    
    return result
end

-- Initialize all configs
function WarzoneCombatConfig.Init()
    print("^2[WARZONE COMBAT] Loading configuration files...^7")
    
    configs.combat = LoadJSONConfig('config/combat_config.json')
    configs.weapons = LoadJSONConfig('config/weapons_config.json')
    configs.roles = LoadJSONConfig('config/roles_config.json')
    configs.armor = LoadJSONConfig('config/armor_config.json')
    configs.attachments = LoadJSONConfig('config/attachments_config.json')
   
   -- Validate configs
    WarzoneCombatConfig.ValidateConfigs()
   
    print("^2[WARZONE COMBAT] All configuration files loaded successfully!^7")
end

-- Validate configuration integrity
function WarzoneCombatConfig.ValidateConfigs()
   local errors = {}
   
   -- Validate weapon configs
   if configs.weapons and configs.weapons.weaponCategories then
       for categoryName, category in pairs(configs.weapons.weaponCategories) do
           for weaponHash, weapon in pairs(category.weapons or {}) do
               if not weapon.damage or weapon.damage <= 0 then
                   table.insert(errors, string.format("Invalid damage for weapon: %s", weaponHash))
               end
               if not weapon.price or weapon.price < 0 then
                   table.insert(errors, string.format("Invalid price for weapon: %s", weaponHash))
               end
           end
       end
   end
   
   -- Validate role configs
   if configs.roles and configs.roles.roles then
       for roleName, role in pairs(configs.roles.roles) do
           if not role.stats or not role.stats.damageMultiplier then
               table.insert(errors, string.format("Missing damage multiplier for role: %s", roleName))
           end
       end
   end
   
   if #errors > 0 then
       print("^1[WARZONE COMBAT] Configuration validation errors:^7")
       for _, error in ipairs(errors) do
           print("^1  - " .. error .. "^7")
       end
   else
       print("^2[WARZONE COMBAT] Configuration validation passed!^7")
   end
end

-- Admin command to reload configs
ESX.RegisterCommand('reloadcombat', 'admin', function(xPlayer, args, showError)
    WarzoneCombatConfig.Reload()
    TriggerClientEvent('esx:showNotification', xPlayer.source, '✅ Combat configuration reloaded!')
end, false, {help = 'Reload combat configuration files'})

-- Getter functions
function WarzoneCombatConfig.GetCombat()
   return configs.combat or {}
end

function WarzoneCombatConfig.GetWeapons()
   return configs.weapons or {}
end

function WarzoneCombatConfig.GetRoles()
   return configs.roles or {}
end

function WarzoneCombatConfig.GetArmor()
   return configs.armor or {}
end

function WarzoneCombatConfig.GetAttachments()
   return configs.attachments or {}
end

-- Specific getters
function WarzoneCombatConfig.GetWeaponData(weaponHash)
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

function WarzoneCombatConfig.GetRoleData(roleName)
   local roleConfigs = configs.roles
   if not roleConfigs or not roleConfigs.roles then return nil end
   
   return roleConfigs.roles[roleName]
end

function WarzoneCombatConfig.GetArmorData(armorType)
   local armorConfigs = configs.armor
   if not armorConfigs or not armorConfigs.armor or not armorConfigs.armor.types then return nil end
   
   return armorConfigs.armor.types[armorType]
end

function WarzoneCombatConfig.GetAttachmentData(attachmentName)
   local attachmentConfigs = configs.attachments
   if not attachmentConfigs or not attachmentConfigs.attachments then return nil end
   
   return attachmentConfigs.attachments[attachmentName]
end

-- Hot reload function for development
function WarzoneCombatConfig.Reload()
   print("^3[WARZONE COMBAT] Reloading configuration files...^7")
   WarzoneCombatConfig.Init()
   
   -- Notify all clients to reload
   TriggerClientEvent('warzone_combat:configReloaded', -1)
end

-- Initialize when resource starts
Citizen.CreateThread(function()
   WarzoneCombatConfig.Init()
end)

-- Export functions
exports('GetCombatConfig', WarzoneCombatConfig.GetCombat)
exports('GetWeaponConfig', WarzoneCombatConfig.GetWeapons)
exports('GetRoleConfig', WarzoneCombatConfig.GetRoles)
exports('GetArmorConfig', WarzoneCombatConfig.GetArmor)
exports('GetAttachmentConfig', WarzoneCombatConfig.GetAttachments)
exports('GetWeaponData', WarzoneCombatConfig.GetWeaponData)
exports('GetRoleData', WarzoneCombatConfig.GetRoleData)
exports('GetArmorData', WarzoneCombatConfig.GetArmorData)
exports('GetAttachmentData', WarzoneCombatConfig.GetAttachmentData)
exports('ReloadConfig', WarzoneCombatConfig.Reload)