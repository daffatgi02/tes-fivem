-- resources/[warzone]/warzone_core/config/main.lua
Config = {}

-- General Settings
Config.ServerName = "WARZONE INDONESIA"
Config.MaxPlayers = 64
Config.DefaultMoney = 500
Config.KillReward = 100

-- Combat Settings
Config.FriendlyFire = true
Config.CombatTimeout = 90 -- seconds
Config.DeathTimeout = 10 -- respawn delay
Config.MaxArmor = 100
Config.MaxArmorKits = 3

-- Anti-Farm Settings
Config.KillCooldown = 90 -- seconds before same target can give reward again
Config.MaxKillsPerTarget = 3 -- max kills from same target per session

-- Debug Settings
Config.Debug = true
Config.ShowZoneDebug = false

-- Default Spawn Location
Config.DefaultSpawn = {
    x = -1037.77,
    y = -2737.84,
    z = 20.17,
    heading = 0.0
}

-- Roles Configuration
Config.Roles = {
    ["assault"] = {
        label = "Assault",
        damageMultiplier = 1.2,
        armorMultiplier = 1.0,
        weaponAccess = {"heavy", "assault", "pistol"}
    },
    ["support"] = {
        label = "Support",
        damageMultiplier = 1.0,
        armorMultiplier = 1.1,
        ammoMultiplier = 1.5,
        weaponAccess = {"lmg", "assault", "pistol"}
    },
    ["medic"] = {
        label = "Medic",
        damageMultiplier = 0.9,
        armorMultiplier = 1.0,
        reviveSpeed = 2.0,
        weaponAccess = {"assault", "pistol", "medical"}
    },
    ["recon"] = {
        label = "Recon",
        damageMultiplier = 1.1,
        armorMultiplier = 0.9,
        radarRange = 1.5,
        weaponAccess = {"sniper", "assault", "pistol"}
    }
}