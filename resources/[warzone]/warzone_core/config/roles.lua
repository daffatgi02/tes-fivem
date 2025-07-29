-- resources/[warzone]/warzone_core/config/roles.lua
-- Extended role configurations (already defined in main.lua but separated for clarity)

Config.RoleDetails = {
    ["assault"] = {
        label = "Assault",
        description = "Heavy damage dealer with access to powerful weapons",
        icon = "🔫",
        damageMultiplier = 1.2,
        armorMultiplier = 1.0,
        ammoMultiplier = 1.0,
        reviveSpeed = 1.0,
        radarRange = 1.0,
        weaponAccess = {"heavy", "assault", "pistol"},
        abilities = {
            "explosive_ammo", -- Special ammo types
            "heavy_weapons" -- RPG, Grenade Launcher access
        },
        spawnLoadout = {
            {weapon = "WEAPON_CARBINERIFLE", ammo = 300},
            {weapon = "WEAPON_PISTOL", ammo = 250},
            {armor = 50}
        }
    },
    ["support"] = {
        label = "Support",
        description = "Team support specialist with extra ammunition",
        icon = "🎒",
        damageMultiplier = 1.0,
        armorMultiplier = 1.1,
        ammoMultiplier = 1.5,
        reviveSpeed = 1.2,
        radarRange = 1.0,
        weaponAccess = {"lmg", "assault", "pistol"},
        abilities = {
            "ammo_sharing", -- Can share ammo with teammates
            "armor_sharing", -- Can share armor kits
            "supply_drop" -- Call in supply packages
        },
        spawnLoadout = {
            {weapon = "WEAPON_COMBATMG", ammo = 500},
            {weapon = "WEAPON_PISTOL", ammo = 250},
            {armor = 75}
        }
    },
    ["medic"] = {
        label = "Medic",
        description = "Medical specialist with fast revival abilities",
        icon = "🏥",
        damageMultiplier = 0.9,
        armorMultiplier = 1.0,
        ammoMultiplier = 1.0,
        reviveSpeed = 2.0,
        radarRange = 1.0,
        weaponAccess = {"assault", "pistol", "medical"},
        abilities = {
            "fast_revive", -- 50% faster revive time
            "health_boost", -- Can overheal teammates temporarily
            "medical_supplies" -- Spawns with med kits
        },
        spawnLoadout = {
            {weapon = "WEAPON_ASSAULTRIFLE", ammo = 300},
            {weapon = "WEAPON_PISTOL", ammo = 250},
            {armor = 50},
            {item = "medkit", amount = 3}
        }
    },
    ["recon"] = {
        label = "Recon",
        description = "Long-range specialist with enhanced radar",
        icon = "🔭",
        damageMultiplier = 1.1,
        armorMultiplier = 0.9,
        ammoMultiplier = 1.0,
        reviveSpeed = 0.8,
        radarRange = 1.5,
        weaponAccess = {"sniper", "assault", "pistol"},
        abilities = {
            "enemy_spotting", -- Mark enemies for team
            "long_range", -- Increased weapon range
            "stealth_mode" -- Reduced visibility on radar
        },
        spawnLoadout = {
            {weapon = "WEAPON_SNIPERRIFLE", ammo = 100},
            {weapon = "WEAPON_CARBINERIFLE", ammo = 300},
            {weapon = "WEAPON_PISTOL", ammo = 250},
            {armor = 25}
        }
    }
}

-- Role Change Costs
Config.RoleChangeCost = 1000 -- Cost to change role

-- Role Change Cooldown (seconds)
Config.RoleChangeCooldown = 300 -- 5 minutes