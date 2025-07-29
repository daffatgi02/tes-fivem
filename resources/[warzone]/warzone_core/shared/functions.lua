-- resources/[warzone]/warzone_core/shared/functions.lua

-- Global Warzone Functions

-- Calculate K/D Ratio
function CalculateKDRatio(kills, deaths)
    if deaths == 0 then
        return kills
    end
    return WarzoneUtils.Round(kills / deaths, 2)
end

-- Format K/D Display
function FormatKDDisplay(kills, deaths)
    local kd = CalculateKDRatio(kills, deaths)
    return string.format("%d/%d (%.2f)", kills, deaths, kd)
end

-- Check if weapon is valid
function IsValidWeapon(weaponHash)
    if type(weaponHash) == "string" then
        weaponHash = GetHashKey(weaponHash)
    end
    
    return IsWeaponValid(weaponHash)
end

-- Get weapon category
function GetWeaponCategory(weaponHash)
    if type(weaponHash) == "string" then
        weaponHash = GetHashKey(weaponHash)
    end
    
    for categoryName, categoryData in pairs(Config.WeaponCategories) do
        for _, weapon in pairs(categoryData.weapons) do
            if weapon.hash == weaponHash then
                return categoryName
            end
        end
    end
    
    return "unknown"
end

-- Get weapon data
function GetWeaponData(weaponHash)
    if type(weaponHash) == "string" then
        weaponHash = GetHashKey(weaponHash)
    end
    
    for categoryName, categoryData in pairs(Config.WeaponCategories) do
        for _, weapon in pairs(categoryData.weapons) do
            if weapon.hash == weaponHash then
                return weapon
            end
        end
    end
    
    return nil
end

-- Format money display
function FormatMoney(amount)
    if amount >= 1000000 then
        return string.format("$%.1fM", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("$%.1fK", amount / 1000)
    else
        return string.format("$%d", amount)
    end
end

-- Role permission check
function HasRolePermission(role, permission)
    local roleConfig = Config.Roles[role]
    if not roleConfig then return false end
    
    if permission == "heavyWeapons" then
        return WarzoneUtils.ArrayContains(roleConfig.weaponAccess or {}, "heavy")
    elseif permission == "medical" then
        return role == "medic" or WarzoneUtils.ArrayContains(roleConfig.weaponAccess or {}, "medical")
    elseif permission == "radar" then
        return roleConfig.radarRange and roleConfig.radarRange > 1.0
    end
    
    return false
end

-- Get role multiplier
function GetRoleMultiplier(role, multiplierType)
    local roleConfig = Config.Roles[role]
    if not roleConfig then return 1.0 end
    
    return roleConfig[multiplierType] or 1.0
end