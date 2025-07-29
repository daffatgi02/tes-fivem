-- resources/[warzone]/warzone_zones/config.lua
ZoneConfig = {}

-- Zone Visual Settings
ZoneConfig.Visual = {
    DrawDistance = 500.0, -- Distance to draw zone markers
    MarkerType = 1, -- Cylinder marker
    MarkerSize = vector3(2.0, 2.0, 1.0),
    MarkerBobUpAndDown = false,
    MarkerRotate = false,
    
    -- Zone Colors
    Colors = {
        white = {r = 255, g = 255, b = 255, a = 100}, -- Safe zone
        yellow = {r = 255, g = 255, b = 0, a = 120}, -- Moderate activity
        red = {r = 255, g = 0, b = 0, a = 150}, -- High activity
        green = {r = 0, g = 255, b = 0, a = 80} -- Green zone (safe)
    }
}

-- Zone Notification Settings
ZoneConfig.Notifications = {
    ShowZoneEntry = true,
    ShowZoneExit = true,
    ShowActivityLevel = true,
    ShowCombatWarnings = true
}

-- Green Zone Settings
ZoneConfig.GreenZone = {
    DisableWeapons = true,
    DisableCombat = true,
    DisableVehicleDamage = true,
    CombatEntryBlocked = true, -- Prevent entry while in combat
    CombatCheckRadius = 5.0, -- Distance to check for combat players
    
    -- Healing settings
    EnableHealing = true,
    HealRate = 2, -- HP per second
    MaxHealth = 200,
    
    -- Armor restoration
    EnableArmorRestore = true,
    ArmorRestoreRate = 1, -- Armor per second
    MaxArmor = 100
}

-- Activity Tracking Settings
ZoneConfig.Activity = {
    TrackingEnabled = true,
    UpdateInterval = 30000, -- 30 seconds
    CleanupInterval = 300000, -- 5 minutes
    
    -- Kill tracking
    MaxKillDistance = 1000.0, -- Max distance to count kill in zone
    HeadshotMultiplier = 1.5, -- Activity multiplier for headshots
    
    -- Activity decay
    DecayRate = 0.8, -- Activity reduces by 20% every update
    MinActivityThreshold = 0.1 -- Minimum activity to keep tracking
}

-- Blip Settings
ZoneConfig.Blips = {
    ShowGreenZones = true,
    ShowCombatZones = true,
    ShowActivityLevels = true,
    
    -- Blip update frequency
    UpdateInterval = 15000, -- 15 seconds
    
    -- Blip scaling based on activity
    ScaleMultiplier = {
        white = 1.0,
        yellow = 1.2,
        red = 1.5
    }
}